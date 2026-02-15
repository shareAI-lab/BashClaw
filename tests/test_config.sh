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

begin_test_file "test_config"

# ---- config_init_default ----

test_start "config_init_default creates valid JSON file"
setup_test_env
config_init_default >/dev/null 2>&1
assert_file_exists "$BASHCLAW_CONFIG"
content="$(cat "$BASHCLAW_CONFIG")"
assert_json_valid "$content"
teardown_test_env

test_start "config_init_default contains required keys"
setup_test_env
config_init_default >/dev/null 2>&1
content="$(cat "$BASHCLAW_CONFIG")"
assert_contains "$content" '"agents"'
assert_contains "$content" '"channels"'
assert_contains "$content" '"gateway"'
assert_contains "$content" '"session"'
teardown_test_env

test_start "config_init_default fails if already exists"
setup_test_env
config_init_default >/dev/null 2>&1
result="$(config_init_default 2>&1)" || true
# Second call should warn but not crash
assert_file_exists "$BASHCLAW_CONFIG"
teardown_test_env

# ---- config_load ----

test_start "config_load reads the file"
setup_test_env
config_init_default >/dev/null 2>&1
_CONFIG_CACHE=""
config_load
val="$(config_get '.agents.defaults.maxTurns')"
assert_eq "$val" "50"
teardown_test_env

test_start "config_load handles missing file"
setup_test_env
_CONFIG_CACHE=""
config_load
assert_eq "$_CONFIG_CACHE" "{}"
teardown_test_env

test_start "config_load handles invalid JSON"
setup_test_env
printf 'not json at all' > "$BASHCLAW_CONFIG"
_CONFIG_CACHE=""
config_load 2>/dev/null || true
assert_eq "$_CONFIG_CACHE" "{}"
teardown_test_env

# ---- config_get ----

test_start "config_get with various jq paths"
setup_test_env
config_init_default >/dev/null 2>&1
_CONFIG_CACHE=""
config_load

val="$(config_get '.gateway.port')"
assert_eq "$val" "18789"

val="$(config_get '.session.dmScope')"
assert_eq "$val" "per-channel-peer"

val="$(config_get '.session.idleResetMinutes')"
assert_eq "$val" "30"
teardown_test_env

test_start "config_get returns default for missing key"
setup_test_env
config_init_default >/dev/null 2>&1
_CONFIG_CACHE=""
config_load
val="$(config_get '.nonexistent.key' 'fallback_value')"
assert_eq "$val" "fallback_value"
teardown_test_env

# ---- config_set ----

test_start "config_set updates values"
setup_test_env
config_init_default >/dev/null 2>&1
_CONFIG_CACHE=""
config_load
config_set '.gateway.port' '9999'
val="$(config_get '.gateway.port')"
assert_eq "$val" "9999"
teardown_test_env

test_start "config_set persists to disk"
setup_test_env
config_init_default >/dev/null 2>&1
_CONFIG_CACHE=""
config_load
config_set '.custom.field' '"hello"'
# Reload from disk
_CONFIG_CACHE=""
config_load
val="$(config_get '.custom.field')"
assert_eq "$val" "hello"
teardown_test_env

# ---- config_env_substitute ----

test_start "config_env_substitute replaces \${VAR}"
setup_test_env
export MY_TEST_VAR="injected_value"
result="$(config_env_substitute 'prefix-${MY_TEST_VAR}-suffix')"
assert_eq "$result" "prefix-injected_value-suffix"
unset MY_TEST_VAR
teardown_test_env

test_start "config_env_substitute handles missing vars"
setup_test_env
unset NONEXISTENT_VAR 2>/dev/null || true
result="$(config_env_substitute 'before-${NONEXISTENT_VAR}-after')"
assert_eq "$result" "before--after"
teardown_test_env

test_start "config_env_substitute handles multiple vars"
setup_test_env
export VAR_A="alpha"
export VAR_B="beta"
result="$(config_env_substitute '${VAR_A}:${VAR_B}')"
assert_eq "$result" "alpha:beta"
unset VAR_A VAR_B
teardown_test_env

# ---- config_validate ----

test_start "config_validate on valid config"
setup_test_env
config_init_default >/dev/null 2>&1
if config_validate 2>/dev/null; then
  _test_pass
else
  _test_fail "valid config should pass validation"
fi
teardown_test_env

test_start "config_validate on invalid JSON"
setup_test_env
printf 'this is not json' > "$BASHCLAW_CONFIG"
if config_validate 2>/dev/null; then
  _test_fail "invalid JSON should fail validation"
else
  _test_pass
fi
teardown_test_env

test_start "config_validate on missing file"
setup_test_env
if config_validate 2>/dev/null; then
  _test_fail "missing config should fail validation"
else
  _test_pass
fi
teardown_test_env

test_start "config_validate on invalid port"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"gateway": {"port": 99999}}
EOF
if config_validate 2>/dev/null; then
  _test_fail "invalid port should fail validation"
else
  _test_pass
fi
teardown_test_env

# ---- config_agent_get ----

test_start "config_agent_get with agent-specific value"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"model": "default-model", "maxTurns": 50},
    "list": [
      {"id": "research", "model": "special-model"}
    ]
  }
}
EOF
_CONFIG_CACHE=""
config_load
val="$(config_agent_get "research" "model")"
assert_eq "$val" "special-model"
teardown_test_env

test_start "config_agent_get falls back to defaults"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"model": "default-model", "maxTurns": 50},
    "list": [
      {"id": "research", "identity": "researcher"}
    ]
  }
}
EOF
_CONFIG_CACHE=""
config_load
val="$(config_agent_get "research" "model")"
assert_eq "$val" "default-model"
teardown_test_env

test_start "config_agent_get returns default arg for unknown agent/field"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {"defaults": {}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
val="$(config_agent_get "unknown" "model" "fallback")"
assert_eq "$val" "fallback"
teardown_test_env

# ---- config_channel_get ----

test_start "config_channel_get reads channel-specific values"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {
    "telegram": {"botToken": "tg-token-123"},
    "defaults": {"botToken": "default-token"}
  }
}
EOF
_CONFIG_CACHE=""
config_load
val="$(config_channel_get "telegram" "botToken")"
assert_eq "$val" "tg-token-123"
teardown_test_env

test_start "config_channel_get falls back to defaults"
setup_test_env
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "channels": {
    "telegram": {},
    "defaults": {"maxMessages": "100"}
  }
}
EOF
_CONFIG_CACHE=""
config_load
val="$(config_channel_get "telegram" "maxMessages")"
assert_eq "$val" "100"
teardown_test_env

# ---- config_backup ----

test_start "config_backup creates backup files"
setup_test_env
config_init_default >/dev/null 2>&1
config_backup
assert_file_exists "${BASHCLAW_CONFIG}.bak.1"
teardown_test_env

test_start "config_backup rotates backups"
setup_test_env
config_init_default >/dev/null 2>&1
config_backup
config_backup
assert_file_exists "${BASHCLAW_CONFIG}.bak.1"
assert_file_exists "${BASHCLAW_CONFIG}.bak.2"
teardown_test_env

# ---- config_reload ----

test_start "config_reload clears cache and reloads"
setup_test_env
config_init_default >/dev/null 2>&1
_CONFIG_CACHE=""
config_load
old_val="$(config_get '.gateway.port')"
assert_eq "$old_val" "18789"

# Modify file on disk directly
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"gateway": {"port": 12345}}
EOF
config_reload
new_val="$(config_get '.gateway.port')"
assert_eq "$new_val" "12345"
teardown_test_env

report_results
