#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_process"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- process_enqueue / process_dequeue FIFO order ----

test_start "process_enqueue / process_dequeue FIFO order"
setup_test_env
_source_libs
id1="$(process_enqueue "main" "msg_alpha")"
sleep 0.1
id2="$(process_enqueue "main" "msg_beta")"
sleep 0.1
id3="$(process_enqueue "main" "msg_gamma")"

first="$(process_dequeue)"
first_cmd="$(printf '%s' "$first" | jq -r '.command')"
assert_eq "$first_cmd" "msg_alpha"

second="$(process_dequeue)"
second_cmd="$(printf '%s' "$second" | jq -r '.command')"
assert_eq "$second_cmd" "msg_beta"

third="$(process_dequeue)"
third_cmd="$(printf '%s' "$third" | jq -r '.command')"
assert_eq "$third_cmd" "msg_gamma"
teardown_test_env

# ---- process_status shows correct depth ----

test_start "process_status shows correct counts"
setup_test_env
_source_libs
process_enqueue "main" "a" >/dev/null
sleep 0.05
process_enqueue "main" "b" >/dev/null
sleep 0.05
process_enqueue "main" "c" >/dev/null
status="$(process_status)"
assert_json_valid "$status"
pending="$(printf '%s' "$status" | jq -r '.pending')"
assert_eq "$pending" "3"
teardown_test_env

# ---- Empty queue returns empty ----

test_start "empty queue dequeue returns failure"
setup_test_env
_source_libs
set +e
result="$(process_dequeue 2>/dev/null)"
rc=$?
set -e
if (( rc != 0 )); then
  _test_pass
else
  _test_fail "dequeue on empty queue should return non-zero"
fi
teardown_test_env

report_results
