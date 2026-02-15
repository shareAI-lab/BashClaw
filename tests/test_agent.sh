#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

export BASHCLAW_STATE_DIR="/tmp/bashclaw-test-bootstrap"
export LOG_LEVEL="silent"
mkdir -p "$BASHCLAW_STATE_DIR"
for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
  [[ -f "$_lib" ]] && source "$_lib"
done
unset _lib

begin_test_file "test_agent"

# ---- agent_resolve_model ----

test_start "agent_resolve_model reads from config"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"model": "claude-sonnet-4-20250514"},
    "list": [{"id": "research", "model": "gpt-4o"}]
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_resolve_model "research")"
assert_eq "$result" "gpt-4o"
teardown_test_env

test_start "agent_resolve_model falls back to defaults"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"model": "claude-sonnet-4-20250514"},
    "list": [{"id": "research"}]
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_resolve_model "research")"
assert_eq "$result" "claude-sonnet-4-20250514"
teardown_test_env

test_start "agent_resolve_model uses MODEL_ID env"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {"defaults": {}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
export MODEL_ID="glm-5"
result="$(agent_resolve_model "main")"
assert_eq "$result" "glm-5"
unset MODEL_ID
teardown_test_env

# ---- agent_resolve_provider ----

test_start "agent_resolve_provider returns anthropic for claude models"
setup_test_env
result="$(agent_resolve_provider "claude-sonnet-4-20250514")"
assert_eq "$result" "anthropic"
teardown_test_env

test_start "agent_resolve_provider returns openai for gpt models"
setup_test_env
result="$(agent_resolve_provider "gpt-4o")"
assert_eq "$result" "openai"
teardown_test_env

test_start "agent_resolve_provider returns zhipu for glm models"
setup_test_env
result="$(agent_resolve_provider "glm-4.7-flash")"
assert_eq "$result" "zhipu"
teardown_test_env

test_start "agent_resolve_provider returns anthropic for unknown models"
setup_test_env
result="$(agent_resolve_provider "unknown-model-xyz")"
assert_eq "$result" "anthropic"
teardown_test_env

# ---- agent_build_system_prompt ----

test_start "agent_build_system_prompt includes identity"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"identity": "a helpful coding assistant"},
    "list": []
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_build_system_prompt "main")"
assert_contains "$result" "a helpful coding assistant"
teardown_test_env

test_start "agent_build_system_prompt includes tool descriptions"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {"defaults": {}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_build_system_prompt "main")"
assert_contains "$result" "Available tools"
assert_contains "$result" "web_fetch"
assert_contains "$result" "shell"
assert_contains "$result" "memory"
teardown_test_env

test_start "agent_build_system_prompt default identity"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {"defaults": {}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_build_system_prompt "main")"
assert_contains "$result" "helpful AI assistant"
teardown_test_env

test_start "agent_build_system_prompt includes custom systemPrompt"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"systemPrompt": "Always respond in haiku format."},
    "list": []
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_build_system_prompt "main")"
assert_contains "$result" "haiku format"
teardown_test_env

# ---- agent_build_messages ----

test_start "agent_build_messages produces correct message array"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "hello"
session_append "$f" "assistant" "hi there"
result="$(agent_build_messages "$f" "new question" 50)"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "3"
# Last message should be the new user question
last_role="$(printf '%s' "$result" | jq -r '.[-1].role')"
assert_eq "$last_role" "user"
last_content="$(printf '%s' "$result" | jq -r '.[-1].content')"
assert_eq "$last_content" "new question"
teardown_test_env

test_start "agent_build_messages empty session"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="${BASHCLAW_STATE_DIR}/sessions/empty.jsonl"
result="$(agent_build_messages "$f" "first message" 50)"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "1"
teardown_test_env

# ---- agent_build_tools_spec ----

test_start "agent_build_tools_spec generates valid tool specs"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {"defaults": {}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_build_tools_spec "main")"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_gt "$length" 0
teardown_test_env

test_start "agent_build_tools_spec filters to configured tools"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"tools": ["memory", "shell"]},
    "list": []
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(agent_build_tools_spec "main")"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "2"
names="$(printf '%s' "$result" | jq -r '.[].name' | sort | tr '\n' ',')"
assert_contains "$names" "memory"
assert_contains "$names" "shell"
teardown_test_env

report_results
