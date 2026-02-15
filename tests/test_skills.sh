#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_skills"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- skills_discover returns empty array when no skills exist ----

test_start "skills_discover returns empty when no skills dir"
setup_test_env
_source_libs
result="$(skills_discover "main")"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "0"
teardown_test_env

# ---- skills_discover finds skills with SKILL.md ----

test_start "skills_discover finds skills with SKILL.md"
setup_test_env
_source_libs
skills_dir="${BASHCLAW_STATE_DIR}/agents/main/skills/coding"
mkdir -p "$skills_dir"
printf '# Coding Skill\nHelps with coding tasks.\n' > "${skills_dir}/SKILL.md"
result="$(skills_discover "main")"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "1"
name="$(printf '%s' "$result" | jq -r '.[0].name')"
assert_eq "$name" "coding"
teardown_test_env

# ---- skills_discover skips dirs without SKILL.md ----

test_start "skills_discover skips dirs without SKILL.md"
setup_test_env
_source_libs
skills_base="${BASHCLAW_STATE_DIR}/agents/main/skills"
mkdir -p "${skills_base}/valid_skill"
printf '# Valid\n' > "${skills_base}/valid_skill/SKILL.md"
mkdir -p "${skills_base}/invalid_skill"
printf 'not a skill\n' > "${skills_base}/invalid_skill/README.md"
result="$(skills_discover "main")"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "1"
teardown_test_env

# ---- skills_discover loads skill.json metadata ----

test_start "skills_discover loads skill.json metadata"
setup_test_env
_source_libs
skills_dir="${BASHCLAW_STATE_DIR}/agents/main/skills/research"
mkdir -p "$skills_dir"
printf '# Research\n' > "${skills_dir}/SKILL.md"
cat > "${skills_dir}/skill.json" <<'EOF'
{"description": "Web research skill", "tags": ["search", "web"]}
EOF
result="$(skills_discover "main")"
desc="$(printf '%s' "$result" | jq -r '.[0].meta.description')"
assert_eq "$desc" "Web research skill"
teardown_test_env

# ---- skills_list returns formatted metadata ----

test_start "skills_list returns formatted metadata"
setup_test_env
_source_libs
skills_dir="${BASHCLAW_STATE_DIR}/agents/test_agent/skills/writing"
mkdir -p "$skills_dir"
printf '# Writing\n' > "${skills_dir}/SKILL.md"
cat > "${skills_dir}/skill.json" <<'EOF'
{"description": "Technical writing", "tags": ["docs"]}
EOF
result="$(skills_list "test_agent")"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "1"
name="$(printf '%s' "$result" | jq -r '.[0].name')"
assert_eq "$name" "writing"
desc="$(printf '%s' "$result" | jq -r '.[0].description')"
assert_eq "$desc" "Technical writing"
teardown_test_env

# ---- skills_list returns empty array when no skills ----

test_start "skills_list returns empty array when no skills"
setup_test_env
_source_libs
result="$(skills_list "no_agent")"
assert_eq "$result" "[]"
teardown_test_env

# ---- skills_load reads SKILL.md content ----

test_start "skills_load reads SKILL.md content"
setup_test_env
_source_libs
skills_dir="${BASHCLAW_STATE_DIR}/agents/main/skills/testing"
mkdir -p "$skills_dir"
printf '# Testing Skill\nRun unit tests and verify coverage.\n' > "${skills_dir}/SKILL.md"
result="$(skills_load "main" "testing")"
assert_contains "$result" "Testing Skill"
assert_contains "$result" "unit tests"
teardown_test_env

# ---- skills_load fails for nonexistent skill ----

test_start "skills_load fails for nonexistent skill"
setup_test_env
_source_libs
set +e
skills_load "main" "nonexistent" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- skills_inject_prompt generates formatted block ----

test_start "skills_inject_prompt generates formatted block"
setup_test_env
_source_libs
skills_dir="${BASHCLAW_STATE_DIR}/agents/main/skills/debug"
mkdir -p "$skills_dir"
printf '# Debug\n' > "${skills_dir}/SKILL.md"
cat > "${skills_dir}/skill.json" <<'EOF'
{"description": "Debug and diagnose issues", "tags": ["debug"]}
EOF
result="$(skills_inject_prompt "main")"
assert_contains "$result" "Available Skills"
assert_contains "$result" "debug"
assert_contains "$result" "Debug and diagnose issues"
teardown_test_env

# ---- skills_inject_prompt returns nothing when no skills ----

test_start "skills_inject_prompt returns empty for no skills"
setup_test_env
_source_libs
result="$(skills_inject_prompt "empty_agent" 2>/dev/null)" || result=""
if [[ -z "$result" ]]; then
  _test_pass
else
  _test_fail "expected empty result, got: $result"
fi
teardown_test_env

# ---- skills_discover with multiple skills ----

test_start "skills_discover with multiple skills"
setup_test_env
_source_libs
base="${BASHCLAW_STATE_DIR}/agents/multi/skills"
mkdir -p "${base}/skill_a" "${base}/skill_b" "${base}/skill_c"
printf '# A\n' > "${base}/skill_a/SKILL.md"
printf '# B\n' > "${base}/skill_b/SKILL.md"
printf '# C\n' > "${base}/skill_c/SKILL.md"
result="$(skills_discover "multi")"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "3"
teardown_test_env

report_results
