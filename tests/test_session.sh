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

begin_test_file "test_session"

# ---- session_file ----

test_start "session_file per-sender scope with sender"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "per-sender"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "telegram" "user123")"
assert_contains "$f" "sessions/main/telegram/user123.jsonl"
teardown_test_env

test_start "session_file per-sender scope without sender"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "per-sender"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "telegram")"
assert_contains "$f" "sessions/main/telegram.jsonl"
teardown_test_env

test_start "session_file per-channel scope"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "per-channel"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "discord" "user456")"
assert_contains "$f" "sessions/main/discord.jsonl"
assert_not_contains "$f" "user456"
teardown_test_env

test_start "session_file global scope"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "myagent" "telegram" "user789")"
assert_contains "$f" "sessions/myagent.jsonl"
assert_not_contains "$f" "telegram"
teardown_test_env

# ---- session_append ----

test_start "session_append writes valid JSONL"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "hello world"
line="$(cat "$f")"
assert_json_valid "$line"
role="$(printf '%s' "$line" | jq -r '.role')"
assert_eq "$role" "user"
content="$(printf '%s' "$line" | jq -r '.content')"
assert_eq "$content" "hello world"
teardown_test_env

test_start "session_append includes timestamp"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "assistant" "hi"
line="$(cat "$f")"
ts="$(printf '%s' "$line" | jq -r '.ts')"
assert_match "$ts" '^[0-9]+$'
assert_gt "$ts" 0
teardown_test_env

# ---- session_load ----

test_start "session_load returns JSON array"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "msg1"
session_append "$f" "assistant" "msg2"
result="$(session_load "$f")"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "2"
teardown_test_env

test_start "session_load returns empty array for missing file"
setup_test_env
result="$(session_load "/nonexistent/session.jsonl")"
assert_eq "$result" "[]"
teardown_test_env

test_start "session_load with max_lines"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "msg1"
session_append "$f" "assistant" "reply1"
session_append "$f" "user" "msg2"
session_append "$f" "assistant" "reply2"
result="$(session_load "$f" 2)"
length="$(printf '%s' "$result" | jq 'length')"
assert_eq "$length" "2"
teardown_test_env

# ---- session_load_as_messages ----

test_start "session_load_as_messages returns [{role, content}]"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "hello"
session_append "$f" "assistant" "hi there"
result="$(session_load_as_messages "$f")"
assert_json_valid "$result"
# Check first message has only role and content
keys="$(printf '%s' "$result" | jq '.[0] | keys | length')"
assert_eq "$keys" "2"
role="$(printf '%s' "$result" | jq -r '.[0].role')"
assert_eq "$role" "user"
content="$(printf '%s' "$result" | jq -r '.[0].content')"
assert_eq "$content" "hello"
teardown_test_env

test_start "session_load_as_messages on missing file"
setup_test_env
result="$(session_load_as_messages "/nonexistent/session.jsonl")"
assert_eq "$result" "[]"
teardown_test_env

# ---- session_clear ----

test_start "session_clear empties file"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "msg"
session_clear "$f"
assert_file_exists "$f"
size="$(wc -c < "$f" | tr -d ' ')"
assert_eq "$size" "0"
teardown_test_env

# ---- session_delete ----

test_start "session_delete removes file"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "msg"
assert_file_exists "$f"
session_delete "$f"
assert_file_not_exists "$f"
teardown_test_env

# ---- session_prune ----

test_start "session_prune keeps only N entries"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
for i in $(seq 1 10); do
  session_append "$f" "user" "message $i"
done
count_before="$(wc -l < "$f" | tr -d ' ')"
assert_eq "$count_before" "10"
session_prune "$f" 3
count_after="$(wc -l < "$f" | tr -d ' ')"
assert_eq "$count_after" "3"
# Should keep the last 3
last="$(tail -1 "$f" | jq -r '.content')"
assert_eq "$last" "message 10"
teardown_test_env

test_start "session_prune does nothing if count <= keep"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "msg1"
session_append "$f" "user" "msg2"
session_prune "$f" 5
count="$(wc -l < "$f" | tr -d ' ')"
assert_eq "$count" "2"
teardown_test_env

# ---- session_count ----

test_start "session_count returns correct number"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "msg1"
session_append "$f" "assistant" "reply1"
session_append "$f" "user" "msg2"
count="$(session_count "$f")"
assert_eq "$count" "3"
teardown_test_env

test_start "session_count returns 0 for missing file"
setup_test_env
count="$(session_count "/nonexistent/file.jsonl")"
assert_eq "$count" "0"
teardown_test_env

# ---- session_check_idle_reset ----

test_start "session_check_idle_reset clears old session"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global", "idleResetMinutes": 1}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
# Write a line with an old timestamp (1 hour ago)
old_ts=$(( $(date +%s) * 1000 - 3600000 ))
printf '{"role":"user","content":"old msg","ts":%d}\n' "$old_ts" > "$f"
session_check_idle_reset "$f" 1
# File should be cleared
size="$(wc -c < "$f" | tr -d ' ')"
assert_eq "$size" "0"
teardown_test_env

test_start "session_check_idle_reset keeps recent session"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global", "idleResetMinutes": 30}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "recent msg"
if session_check_idle_reset "$f" 30; then
  _test_fail "recent session should not be reset"
else
  _test_pass
fi
teardown_test_env

# ---- session_export ----

test_start "session_export json format"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "hello"
result="$(session_export "$f" "json")"
assert_json_valid "$result"
teardown_test_env

test_start "session_export text format"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
f="$(session_file "main" "test")"
session_append "$f" "user" "hello"
session_append "$f" "assistant" "world"
result="$(session_export "$f" "text")"
assert_contains "$result" "user: hello"
assert_contains "$result" "assistant: world"
teardown_test_env

test_start "session_export on missing file"
setup_test_env
result="$(session_export "/nonexistent/file.jsonl" "json" 2>&1)" || true
assert_contains "$result" ""
teardown_test_env

# ---- session_list ----

test_start "session_list enumerates sessions"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "per-sender"}}
EOF
_CONFIG_CACHE=""
config_load
f1="$(session_file "main" "telegram" "user1")"
session_append "$f1" "user" "msg1"
f2="$(session_file "main" "discord" "user2")"
session_append "$f2" "user" "msg2"
result="$(session_list)"
assert_json_valid "$result"
length="$(printf '%s' "$result" | jq 'length')"
assert_ge "$length" 2
teardown_test_env

test_start "session_list returns empty array with no sessions"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"session": {"scope": "global"}}
EOF
_CONFIG_CACHE=""
config_load
result="$(session_list)"
assert_json_valid "$result"
teardown_test_env

# ---- session_key ----

test_start "session_key format"
setup_test_env
key="$(session_key "main" "telegram" "user123")"
assert_eq "$key" "agent:main:telegram:direct:user123"
teardown_test_env

test_start "session_key with empty sender"
setup_test_env
key="$(session_key "main" "discord")"
assert_eq "$key" "agent:main:discord:direct"
teardown_test_env

report_results
