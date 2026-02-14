#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_hooks"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- hooks_register creates hook config ----

test_start "hooks_register creates hook config"
setup_test_env
_source_libs
hook_script="${BASHCLAW_STATE_DIR}/my_hook.sh"
printf '#!/usr/bin/env bash\necho ok\n' > "$hook_script"
chmod +x "$hook_script"
hooks_register "my_hook" "pre_message" "$hook_script"
hooks_dir="${BASHCLAW_STATE_DIR}/hooks"
assert_file_exists "${hooks_dir}/my_hook.json"
teardown_test_env

# ---- hooks_run executes hook scripts ----

test_start "hooks_run executes hook scripts"
setup_test_env
_source_libs
hook_script="${BASHCLAW_STATE_DIR}/exec_hook.sh"
cat > "$hook_script" <<'HOOKEOF'
#!/usr/bin/env bash
echo "hook_executed"
HOOKEOF
chmod +x "$hook_script"
hooks_register "exec_hook" "pre_message" "$hook_script"
result="$(hooks_run "pre_message" "" 2>/dev/null)"
assert_contains "$result" "hook_executed"
teardown_test_env

# ---- hooks_run passes JSON through stdin ----

test_start "hooks_run passes JSON through stdin"
setup_test_env
_source_libs
hook_script="${BASHCLAW_STATE_DIR}/stdin_hook.sh"
cat > "$hook_script" <<'HOOKEOF'
#!/usr/bin/env bash
cat
HOOKEOF
chmod +x "$hook_script"
hooks_register "stdin_hook" "pre_message" "$hook_script"
input_json='{"message":"hello","channel":"telegram"}'
result="$(hooks_run "pre_message" "$input_json" 2>/dev/null)"
assert_json_valid "$result"
msg="$(printf '%s' "$result" | jq -r '.message')"
assert_eq "$msg" "hello"
teardown_test_env

# ---- hooks_list shows registered hooks ----

test_start "hooks_list shows registered hooks"
setup_test_env
_source_libs
hook_script="${BASHCLAW_STATE_DIR}/list_hook.sh"
printf '#!/usr/bin/env bash\necho ok\n' > "$hook_script"
chmod +x "$hook_script"
hooks_register "list_test" "pre_message" "$hook_script"
result="$(hooks_list)"
assert_json_valid "$result"
assert_contains "$result" "list_test"
teardown_test_env

# ---- hooks_enable / hooks_disable toggles ----

test_start "hooks_enable / hooks_disable toggles"
setup_test_env
_source_libs
hook_script="${BASHCLAW_STATE_DIR}/toggle_hook.sh"
cat > "$hook_script" <<'HOOKEOF'
#!/usr/bin/env bash
echo "toggled"
HOOKEOF
chmod +x "$hook_script"
hooks_register "toggle_hook" "pre_message" "$hook_script"
hooks_disable "toggle_hook"
result="$(hooks_run "pre_message" "" 2>/dev/null)"
assert_not_contains "$result" "toggled"
hooks_enable "toggle_hook"
result="$(hooks_run "pre_message" "" 2>/dev/null)"
assert_contains "$result" "toggled"
teardown_test_env

# ---- Hook script transforms message content ----

test_start "hook script transforms message content"
setup_test_env
_source_libs
hook_script="${BASHCLAW_STATE_DIR}/transform_hook.sh"
cat > "$hook_script" <<'HOOKEOF'
#!/usr/bin/env bash
input="$(cat)"
printf '%s' "$input" | jq -c '.message = (.message + " [modified]")'
HOOKEOF
chmod +x "$hook_script"
hooks_register "transform_hook" "pre_message" "$hook_script"
input_json='{"message":"original"}'
result="$(hooks_run "pre_message" "$input_json" 2>/dev/null)"
msg="$(printf '%s' "$result" | jq -r '.message')"
assert_contains "$msg" "modified"
teardown_test_env

# ---- Multiple hooks chain correctly ----

test_start "multiple hooks chain correctly"
setup_test_env
_source_libs
hook1="${BASHCLAW_STATE_DIR}/chain_hook1.sh"
hook2="${BASHCLAW_STATE_DIR}/chain_hook2.sh"
cat > "$hook1" <<'HOOKEOF'
#!/usr/bin/env bash
input="$(cat)"
printf '%s' "$input" | jq -c '.step1 = true'
HOOKEOF
cat > "$hook2" <<'HOOKEOF'
#!/usr/bin/env bash
input="$(cat)"
printf '%s' "$input" | jq -c '.step2 = true'
HOOKEOF
chmod +x "$hook1" "$hook2"
hooks_register "chain1" "pre_message" "$hook1"
hooks_register "chain2" "pre_message" "$hook2"
result="$(hooks_run "pre_message" '{}' 2>/dev/null)"
assert_json_valid "$result"
s1="$(printf '%s' "$result" | jq -r '.step1')"
s2="$(printf '%s' "$result" | jq -r '.step2')"
assert_eq "$s1" "true"
assert_eq "$s2" "true"
teardown_test_env

report_results
