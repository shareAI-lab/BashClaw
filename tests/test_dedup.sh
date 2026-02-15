#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_dedup"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- dedup_record creates cache file ----

test_start "dedup_record creates cache file"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "test_key_1" "some_result"
dir="$(_dedup_dir)"
safe_key="$(printf '%s' "test_key_1" | tr -c '[:alnum:]._-' '_' | head -c 200)"
assert_file_exists "${dir}/${safe_key}.json"
teardown_test_env

# ---- dedup_record stores valid JSON ----

test_start "dedup_record stores valid JSON"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "json_test" "result_value"
dir="$(_dedup_dir)"
safe_key="$(printf '%s' "json_test" | tr -c '[:alnum:]._-' '_' | head -c 200)"
file="${dir}/${safe_key}.json"
content="$(cat "$file")"
assert_json_valid "$content"
stored_key="$(printf '%s' "$content" | jq -r '.key')"
assert_eq "$stored_key" "json_test"
stored_result="$(printf '%s' "$content" | jq -r '.result')"
assert_eq "$stored_result" "result_value"
teardown_test_env

# ---- dedup_check returns 0 for existing key within TTL ----

test_start "dedup_check returns 0 for existing key within TTL"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "fresh_key" "value"
if dedup_check "fresh_key" 300; then
  _test_pass
else
  _test_fail "should find fresh key"
fi
teardown_test_env

# ---- dedup_check returns 1 for nonexistent key ----

test_start "dedup_check returns 1 for nonexistent key"
setup_test_env
_source_libs
_DEDUP_DIR=""
set +e
dedup_check "nonexistent_key" 300
rc=$?
set -e
assert_eq "$rc" "1"
teardown_test_env

# ---- dedup_check returns 1 for expired key ----

test_start "dedup_check returns 1 for expired key"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "expire_key" "value"
# Manually set timestamp to the past
dir="$(_dedup_dir)"
safe_key="$(printf '%s' "expire_key" | tr -c '[:alnum:]._-' '_' | head -c 200)"
file="${dir}/${safe_key}.json"
old_ts=$(( $(date +%s) - 9999 ))
updated="$(jq --argjson ts "$old_ts" '.timestamp = $ts' < "$file")"
printf '%s\n' "$updated" > "$file"
set +e
dedup_check "expire_key" 300
rc=$?
set -e
assert_eq "$rc" "1"
teardown_test_env

# ---- dedup_get retrieves cached result ----

test_start "dedup_get retrieves cached result"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "get_key" "cached_value"
result="$(dedup_get "get_key" 300)"
assert_eq "$result" "cached_value"
teardown_test_env

# ---- dedup_get returns empty for expired key ----

test_start "dedup_get returns empty for expired key"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "exp_get" "value"
dir="$(_dedup_dir)"
safe_key="$(printf '%s' "exp_get" | tr -c '[:alnum:]._-' '_' | head -c 200)"
file="${dir}/${safe_key}.json"
old_ts=$(( $(date +%s) - 9999 ))
updated="$(jq --argjson ts "$old_ts" '.timestamp = $ts' < "$file")"
printf '%s\n' "$updated" > "$file"
set +e
result="$(dedup_get "exp_get" 300 2>/dev/null)"
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- dedup_cleanup removes expired entries ----

test_start "dedup_cleanup removes expired entries"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "cleanup_fresh" "value1"
dedup_record "cleanup_old" "value2"
# Age the old entry
dir="$(_dedup_dir)"
safe_key="$(printf '%s' "cleanup_old" | tr -c '[:alnum:]._-' '_' | head -c 200)"
file="${dir}/${safe_key}.json"
old_ts=$(( $(date +%s) - 9999 ))
updated="$(jq --argjson ts "$old_ts" '.timestamp = $ts' < "$file")"
printf '%s\n' "$updated" > "$file"
dedup_cleanup 3600
# Old entry should be removed
assert_file_not_exists "$file"
# Fresh entry should remain
safe_fresh="$(printf '%s' "cleanup_fresh" | tr -c '[:alnum:]._-' '_' | head -c 200)"
assert_file_exists "${dir}/${safe_fresh}.json"
teardown_test_env

# ---- dedup_cleanup removes invalid JSON entries ----

test_start "dedup_cleanup removes invalid JSON entries"
setup_test_env
_source_libs
_DEDUP_DIR=""
dir="$(_dedup_dir)"
printf 'not json at all' > "${dir}/bad_entry.json"
dedup_cleanup 3600
assert_file_not_exists "${dir}/bad_entry.json"
teardown_test_env

# ---- dedup_message_key generates consistent keys ----

test_start "dedup_message_key generates consistent keys"
setup_test_env
_source_libs
key1="$(dedup_message_key "telegram" "user1" "hello world")"
key2="$(dedup_message_key "telegram" "user1" "hello world")"
assert_eq "$key1" "$key2"
teardown_test_env

# ---- dedup_message_key generates different keys for different content ----

test_start "dedup_message_key generates different keys for different content"
setup_test_env
_source_libs
key1="$(dedup_message_key "telegram" "user1" "hello")"
key2="$(dedup_message_key "telegram" "user1" "goodbye")"
assert_ne "$key1" "$key2"
teardown_test_env

# ---- dedup_message_key generates different keys for different senders ----

test_start "dedup_message_key generates different keys for different senders"
setup_test_env
_source_libs
key1="$(dedup_message_key "telegram" "user1" "same message")"
key2="$(dedup_message_key "telegram" "user2" "same message")"
assert_ne "$key1" "$key2"
teardown_test_env

# ---- dedup_record file permissions are 600 ----

test_start "dedup_record file has restricted permissions"
setup_test_env
_source_libs
_DEDUP_DIR=""
dedup_record "perm_key" "value"
dir="$(_dedup_dir)"
safe_key="$(printf '%s' "perm_key" | tr -c '[:alnum:]._-' '_' | head -c 200)"
file="${dir}/${safe_key}.json"
perms="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null)"
assert_eq "$perms" "600"
teardown_test_env

report_results
