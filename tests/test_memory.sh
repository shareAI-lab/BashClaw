#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_memory"

# Helper to source all libs in a fresh test env
_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- memory_store + memory_get round-trip ----

test_start "memory_store + memory_get round-trip"
setup_test_env
_source_libs
memory_store "test_key" "test_value"
result="$(memory_get "test_key")"
assert_eq "$result" "test_value"
teardown_test_env

# ---- memory_store with tags ----

test_start "memory_store with tags"
setup_test_env
_source_libs
memory_store "tagged_key" "tagged_value" --tags "tag1,tag2"
result="$(memory_get "tagged_key")"
assert_eq "$result" "tagged_value"
# Verify tags are stored in the JSON file
dir="$(memory_dir)"
safe_key="$(_memory_key_to_filename "tagged_key")"
tags="$(jq -r '.tags | join(",")' < "${dir}/${safe_key}.json")"
assert_contains "$tags" "tag1"
assert_contains "$tags" "tag2"
teardown_test_env

# ---- memory_search keyword matching ----

test_start "memory_search keyword matching"
setup_test_env
_source_libs
memory_store "fruit_apple" "red fruit"
memory_store "fruit_banana" "yellow fruit"
memory_store "veggie_carrot" "orange vegetable"
result="$(memory_search "fruit")"
assert_json_valid "$result"
assert_contains "$result" "fruit_apple"
assert_contains "$result" "fruit_banana"
teardown_test_env

# ---- memory_search no results ----

test_start "memory_search no results"
setup_test_env
_source_libs
memory_store "alpha" "value_a"
result="$(memory_search "zzz_nonexistent")"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "0"
teardown_test_env

# ---- memory_list with limit ----

test_start "memory_list with limit"
setup_test_env
_source_libs
memory_store "k1" "v1"
memory_store "k2" "v2"
memory_store "k3" "v3"
memory_store "k4" "v4"
memory_store "k5" "v5"
result="$(memory_list --limit 3)"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "3"
teardown_test_env

# ---- memory_delete removes entry ----

test_start "memory_delete removes entry"
setup_test_env
_source_libs
memory_store "del_key" "del_value"
result="$(memory_get "del_key")"
assert_eq "$result" "del_value"
memory_delete "del_key"
set +e
result="$(memory_get "del_key" 2>/dev/null)"
rc=$?
set -e
if (( rc != 0 )); then
  _test_pass
else
  _test_fail "memory_get should fail after delete"
fi
teardown_test_env

# ---- memory_export valid JSON array ----

test_start "memory_export valid JSON array"
setup_test_env
_source_libs
memory_store "exp1" "val1"
memory_store "exp2" "val2"
result="$(memory_export)"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_ge "$length" 2
teardown_test_env

# ---- memory_import restores entries ----

test_start "memory_import restores entries"
setup_test_env
_source_libs
memory_store "imp1" "val1"
memory_store "imp2" "val2"
# Export to a file
export_file="${BASHCLAW_STATE_DIR}/export.json"
memory_export > "$export_file"
# Clear entries
memory_delete "imp1"
memory_delete "imp2"
# Import from file
memory_import "$export_file"
result1="$(memory_get "imp1")"
assert_eq "$result1" "val1"
result2="$(memory_get "imp2")"
assert_eq "$result2" "val2"
teardown_test_env

# ---- memory_compact deduplicates ----

test_start "memory_compact removes invalid entries"
setup_test_env
_source_libs
memory_store "dup_key" "first"
memory_store "dup_key" "second"
# Create an invalid JSON file in memory dir
dir="$(memory_dir)"
printf 'not json' > "${dir}/bad_entry.json"
memory_compact
result="$(memory_get "dup_key")"
assert_eq "$result" "second"
# bad_entry.json should be removed
assert_file_not_exists "${dir}/bad_entry.json"
teardown_test_env

# ---- access_count increments on get ----

test_start "access_count increments on get"
setup_test_env
_source_libs
memory_store "access_key" "val"
memory_get "access_key" >/dev/null
memory_get "access_key" >/dev/null
memory_get "access_key" >/dev/null
dir="$(memory_dir)"
safe_key="$(_memory_key_to_filename "access_key")"
ac="$(jq -r '.access_count // 0' < "${dir}/${safe_key}.json")"
assert_ge "$ac" 3
teardown_test_env

report_results
