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

begin_test_file "test_routing"

# ---- routing_resolve_agent ----

test_start "routing_resolve_agent returns channel-specific agent"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {
    "telegram": {"agentId": "telegram-agent"}
  },
  "agents": {"defaultId": "main"}
}
EOF
_CONFIG_CACHE=""
config_load
result="$(routing_resolve_agent "telegram" "user1")"
assert_eq "$result" "telegram-agent"
teardown_test_env

test_start "routing_resolve_agent returns default when no channel binding"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {},
  "agents": {"defaultId": "main"}
}
EOF
_CONFIG_CACHE=""
config_load
result="$(routing_resolve_agent "telegram" "user1")"
assert_eq "$result" "main"
teardown_test_env

test_start "routing_resolve_agent returns main when no config"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{}
EOF
_CONFIG_CACHE=""
config_load
result="$(routing_resolve_agent "discord" "user1")"
assert_eq "$result" "main"
teardown_test_env

# ---- routing_check_allowlist ----

test_start "routing_check_allowlist with empty list allows all"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {
    "telegram": {}
  }
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_allowlist "telegram" "anyone"; then
  _test_pass
else
  _test_fail "empty allowlist should allow all"
fi
teardown_test_env

test_start "routing_check_allowlist with no channel config allows all"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"channels": {}}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_allowlist "telegram" "anyone"; then
  _test_pass
else
  _test_fail "no channel config should allow all"
fi
teardown_test_env

test_start "routing_check_allowlist with populated list allows listed sender"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {
    "telegram": {"allowFrom": ["user1", "user2"]}
  }
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_allowlist "telegram" "user1"; then
  _test_pass
else
  _test_fail "listed sender should be allowed"
fi
teardown_test_env

test_start "routing_check_allowlist rejects unlisted sender"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {
    "telegram": {
      "dmPolicy": {"policy": "allowlist", "allowFrom": ["user1", "user2"]},
      "allowFrom": ["user1", "user2"]
    }
  }
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_allowlist "telegram" "hacker" "true"; then
  _test_fail "unlisted sender should be rejected"
else
  _test_pass
fi
teardown_test_env

# ---- routing_check_mention_gating ----

test_start "routing_check_mention_gating passes in direct chat"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {"telegram": {"requireMention": "true", "botName": "mybot"}},
  "agents": {"defaults": {"name": "mybot"}}
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_mention_gating "telegram" "hello there" "false"; then
  _test_pass
else
  _test_fail "direct chat should always pass mention gating"
fi
teardown_test_env

test_start "routing_check_mention_gating passes in group with mention"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {"telegram": {"requireMention": "true", "botName": "mybot"}},
  "agents": {"defaults": {"name": "mybot"}}
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_mention_gating "telegram" "hey @mybot what's up" "true"; then
  _test_pass
else
  _test_fail "group message with @mention should pass"
fi
teardown_test_env

test_start "routing_check_mention_gating blocks in group without mention"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {"telegram": {"requireMention": "true", "botName": "mybot"}},
  "agents": {"defaults": {"name": "mybot"}}
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_mention_gating "telegram" "hello everyone" "true"; then
  _test_fail "group message without mention should be blocked"
else
  _test_pass
fi
teardown_test_env

test_start "routing_check_mention_gating case insensitive"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {"telegram": {"requireMention": "true", "botName": "MyBot"}},
  "agents": {"defaults": {"name": "MyBot"}}
}
EOF
_CONFIG_CACHE=""
config_load
if routing_check_mention_gating "telegram" "hey @MYBOT help" "true"; then
  _test_pass
else
  _test_fail "mention matching should be case insensitive"
fi
teardown_test_env

# ---- routing_format_reply ----

test_start "routing_format_reply short message passes through"
setup_test_env
result="$(routing_format_reply "telegram" "short message")"
assert_eq "$result" "short message"
teardown_test_env

test_start "routing_format_reply truncates for telegram limit"
setup_test_env
long_msg="$(python3 -c "print('x' * 5000)")"
result="$(routing_format_reply "telegram" "$long_msg")"
len="${#result}"
# Allow small margin (truncation adds newline + truncation indicator)
assert_ge 4200 "$len" "result should be approximately at most 4096 chars"
assert_contains "$result" "[message truncated]"
teardown_test_env

test_start "routing_format_reply truncates for discord limit"
setup_test_env
long_msg="$(python3 -c "print('x' * 3000)")"
result="$(routing_format_reply "discord" "$long_msg")"
len="${#result}"
assert_ge 2100 "$len" "result should be approximately at most 2000 chars"
assert_contains "$result" "[message truncated]"
teardown_test_env

# ---- routing_split_long_message ----

test_start "routing_split_long_message short message single part"
setup_test_env
result="$(routing_split_long_message "short message" 100)"
# Short message should come through as-is
assert_eq "$result" "short message"
teardown_test_env

test_start "routing_split_long_message splits at boundaries"
setup_test_env
# Build a message with known newline positions
msg="$(printf 'aaaa\nbbbb\ncccc\ndddd')"
result="$(routing_split_long_message "$msg" 10)"
# Each part should be <= 10 chars (roughly)
first_line="$(printf '%s\n' "$result" | head -1)"
len="${#first_line}"
assert_ge 10 "$len" "first chunk should be <= max_len"
teardown_test_env

test_start "routing_split_long_message produces multiple parts for long input"
setup_test_env
long_msg="$(python3 -c "print('word ' * 200)")"
result="$(routing_split_long_message "$long_msg" 50)"
lines="$(printf '%s' "$result" | wc -l | tr -d ' ')"
assert_gt "$lines" 1
teardown_test_env

report_results
