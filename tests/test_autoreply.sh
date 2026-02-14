#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_autoreply"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- autoreply_add creates rule ----

test_start "autoreply_add creates rule"
setup_test_env
_source_libs
id="$(autoreply_add "hello|hi|hey" "Hello! How can I help?")"
result="$(autoreply_list)"
assert_json_valid "$result"
assert_contains "$result" "hello|hi|hey"
teardown_test_env

# ---- autoreply_check matches pattern ----

test_start "autoreply_check matches pattern"
setup_test_env
_source_libs
autoreply_add "hello|hi|hey" "Hello! How can I help?" >/dev/null
result="$(autoreply_check "hello there")"
assert_eq "$result" "Hello! How can I help?"
teardown_test_env

# ---- autoreply_check no match returns empty ----

test_start "autoreply_check no match returns failure"
setup_test_env
_source_libs
autoreply_add "hello|hi|hey" "Hello!" >/dev/null
set +e
result="$(autoreply_check "goodbye" 2>/dev/null)"
rc=$?
set -e
if (( rc != 0 )); then
  _test_pass
else
  if [[ -z "$result" ]]; then
    _test_pass
  else
    _test_fail "no-match should return failure or empty"
  fi
fi
teardown_test_env

# ---- autoreply_remove deletes rule ----

test_start "autoreply_remove deletes rule"
setup_test_env
_source_libs
id="$(autoreply_add "hello" "Hello!")"
autoreply_remove "$id"
result="$(autoreply_list)"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "0"
teardown_test_env

# ---- autoreply_list shows all rules ----

test_start "autoreply_list shows all rules"
setup_test_env
_source_libs
autoreply_add "hello" "Hello!" >/dev/null
autoreply_add "goodbye|bye" "Goodbye!" >/dev/null
autoreply_add "help|assist" "How can I help?" >/dev/null
result="$(autoreply_list)"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "3"
teardown_test_env

# ---- Channel filter restricts matching ----

test_start "channel filter restricts matching"
setup_test_env
_source_libs
autoreply_add "hello" "Telegram hello!" --channel "telegram" >/dev/null
# Should match for telegram channel
result="$(autoreply_check "hello" "telegram")"
assert_eq "$result" "Telegram hello!"
# Should NOT match for discord channel
set +e
result="$(autoreply_check "hello" "discord" 2>/dev/null)"
rc=$?
set -e
if (( rc != 0 )) || [[ -z "$result" ]]; then
  _test_pass
else
  _test_fail "channel filter should prevent match (got: $result)"
fi
teardown_test_env

report_results
