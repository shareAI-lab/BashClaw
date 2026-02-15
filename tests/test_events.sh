#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_events"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- events_enqueue creates event file ----

test_start "events_enqueue creates event file"
setup_test_env
_source_libs
events_enqueue "main_default" "test event message" "test_source"
dir="$(events_dir)"
safe_key="$(_events_safe_key "main_default")"
file="${dir}/${safe_key}.jsonl"
assert_file_exists "$file"
teardown_test_env

# ---- events_enqueue appends valid JSONL ----

test_start "events_enqueue appends valid JSONL"
setup_test_env
_source_libs
events_enqueue "sess1" "event one" "source_a"
events_enqueue "sess1" "event two" "source_b"
dir="$(events_dir)"
safe_key="$(_events_safe_key "sess1")"
file="${dir}/${safe_key}.jsonl"
count="$(wc -l < "$file" | tr -d ' ')"
assert_eq "$count" "2"
# Verify each line is valid JSON
all_valid=true
while IFS= read -r line; do
  if ! printf '%s' "$line" | jq empty 2>/dev/null; then
    all_valid=false
    break
  fi
done < "$file"
if [[ "$all_valid" == "true" ]]; then
  _test_pass
else
  _test_fail "event lines should be valid JSON"
fi
teardown_test_env

# ---- events_enqueue deduplicates consecutive identical text ----

test_start "events_enqueue deduplicates consecutive identical text"
setup_test_env
_source_libs
events_enqueue "dedup_sess" "same message" "source"
events_enqueue "dedup_sess" "same message" "source"
events_enqueue "dedup_sess" "same message" "source"
dir="$(events_dir)"
safe_key="$(_events_safe_key "dedup_sess")"
file="${dir}/${safe_key}.jsonl"
count="$(wc -l < "$file" | tr -d ' ')"
assert_eq "$count" "1"
teardown_test_env

# ---- events_enqueue allows different consecutive messages ----

test_start "events_enqueue allows different consecutive messages"
setup_test_env
_source_libs
events_enqueue "diff_sess" "message A" "source"
events_enqueue "diff_sess" "message B" "source"
events_enqueue "diff_sess" "message A" "source"
dir="$(events_dir)"
safe_key="$(_events_safe_key "diff_sess")"
file="${dir}/${safe_key}.jsonl"
count="$(wc -l < "$file" | tr -d ' ')"
assert_eq "$count" "3"
teardown_test_env

# ---- events_enqueue enforces FIFO max capacity ----

test_start "events_enqueue enforces max capacity"
setup_test_env
_source_libs
local_max=$EVENTS_MAX_PER_SESSION
for i in $(seq 1 $((local_max + 5))); do
  events_enqueue "overflow_sess" "event $i" "source"
done
dir="$(events_dir)"
safe_key="$(_events_safe_key "overflow_sess")"
file="${dir}/${safe_key}.jsonl"
count="$(wc -l < "$file" | tr -d ' ')"
assert_eq "$count" "$local_max"
teardown_test_env

# ---- events_drain returns JSON array and clears queue ----

test_start "events_drain returns JSON array and clears queue"
setup_test_env
_source_libs
events_enqueue "drain_sess" "event one" "a"
events_enqueue "drain_sess" "event two" "b"
result="$(events_drain "drain_sess")"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "2"
# Queue should be cleared
result2="$(events_drain "drain_sess")"
length2="$(printf '%s' "$result2" | jq 'length')"
assert_eq "$length2" "0"
teardown_test_env

# ---- events_drain on empty queue returns empty array ----

test_start "events_drain on empty queue returns empty array"
setup_test_env
_source_libs
result="$(events_drain "nonexistent_sess")"
assert_eq "$result" "[]"
teardown_test_env

# ---- events_count returns correct count ----

test_start "events_count returns correct count"
setup_test_env
_source_libs
events_enqueue "count_sess" "ev1" "a"
events_enqueue "count_sess" "ev2" "b"
events_enqueue "count_sess" "ev3" "c"
count="$(events_count "count_sess")"
assert_eq "$count" "3"
teardown_test_env

# ---- events_count returns 0 for nonexistent session ----

test_start "events_count returns 0 for nonexistent session"
setup_test_env
_source_libs
count="$(events_count "no_such_session")"
assert_eq "$count" "0"
teardown_test_env

# ---- events_inject prepends events as system messages ----

test_start "events_inject prepends events as system messages"
setup_test_env
_source_libs
events_enqueue "inject_sess" "something happened" "alert"
messages_json='[{"role":"user","content":"hello"}]'
result="$(events_inject "inject_sess" "$messages_json")"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "2"
first_content="$(printf '%s' "$result" | jq -r '.[0].content')"
assert_contains "$first_content" "SYSTEM EVENT"
assert_contains "$first_content" "something happened"
teardown_test_env

# ---- events_inject with no events returns original messages ----

test_start "events_inject with no events returns original messages"
setup_test_env
_source_libs
messages_json='[{"role":"user","content":"hello"}]'
result="$(events_inject "empty_sess" "$messages_json")"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "1"
teardown_test_env

# ---- _events_safe_key sanitizes special characters ----

test_start "_events_safe_key sanitizes special characters"
setup_test_env
_source_libs
result="$(_events_safe_key "main/default:user@host")"
assert_not_contains "$result" "/"
assert_not_contains "$result" ":"
assert_not_contains "$result" "@"
teardown_test_env

report_results
