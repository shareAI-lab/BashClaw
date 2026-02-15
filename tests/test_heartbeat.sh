#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_heartbeat"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- _heartbeat_interval parses seconds ----

test_start "_heartbeat_interval parses plain seconds"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"heartbeat.interval": "120"},
    "list": [{"id": "test_agent", "heartbeat.interval": "120"}]
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(_heartbeat_interval "test_agent")"
assert_eq "$result" "120"
teardown_test_env

# ---- _heartbeat_interval parses minutes ----

test_start "_heartbeat_interval parses minutes suffix"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"heartbeat.interval": "30m"},
    "list": []
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(_heartbeat_interval "main")"
assert_eq "$result" "1800"
teardown_test_env

# ---- _heartbeat_interval parses hours ----

test_start "_heartbeat_interval parses hours suffix"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "agents": {
    "defaults": {"heartbeat.interval": "2h"},
    "list": []
  }
}
EOF
_CONFIG_CACHE=""
config_load
result="$(_heartbeat_interval "main")"
assert_eq "$result" "7200"
teardown_test_env

# ---- _heartbeat_hhmm_to_min conversion ----

test_start "_heartbeat_hhmm_to_min converts 08:30 to 510"
setup_test_env
_source_libs
result="$(_heartbeat_hhmm_to_min "08:30")"
assert_eq "$result" "510"
teardown_test_env

test_start "_heartbeat_hhmm_to_min converts 00:00 to 0"
setup_test_env
_source_libs
result="$(_heartbeat_hhmm_to_min "00:00")"
assert_eq "$result" "0"
teardown_test_env

test_start "_heartbeat_hhmm_to_min converts 23:59 to 1439"
setup_test_env
_source_libs
result="$(_heartbeat_hhmm_to_min "23:59")"
assert_eq "$result" "1439"
teardown_test_env

# ---- heartbeat_should_run fails when globally disabled ----

test_start "heartbeat_should_run fails when globally disabled"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "heartbeat": {"enabled": false},
  "agents": {"defaults": {}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
set +e
heartbeat_should_run "main" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- heartbeat_should_run fails when agent disabled ----

test_start "heartbeat_should_run fails when agent heartbeat disabled"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "heartbeat": {"enabled": true},
  "agents": {
    "defaults": {},
    "list": [{"id": "test_agent", "heartbeat.enabled": "false"}]
  }
}
EOF
_CONFIG_CACHE=""
config_load
set +e
heartbeat_should_run "test_agent" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- heartbeat_should_run fails without HEARTBEAT.md ----

test_start "heartbeat_should_run fails without HEARTBEAT.md"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "heartbeat": {"enabled": true},
  "agents": {"defaults": {"heartbeat.interval": "30"}, "list": []}
}
EOF
_CONFIG_CACHE=""
config_load
set +e
heartbeat_should_run "main" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- heartbeat_process_result detects HEARTBEAT_OK ----

test_start "heartbeat_process_result detects HEARTBEAT_OK token"
setup_test_env
_source_libs
result="$(heartbeat_process_result "Everything is fine. HEARTBEAT_OK")"
assert_eq "$result" "ok-token"
teardown_test_env

# ---- heartbeat_process_result empty response ----

test_start "heartbeat_process_result empty response returns ok-empty"
setup_test_env
_source_libs
result="$(heartbeat_process_result "")"
assert_eq "$result" "ok-empty"
teardown_test_env

# ---- heartbeat_process_result trivial response ----

test_start "heartbeat_process_result trivial response returns ok-empty"
setup_test_env
_source_libs
result="$(heartbeat_process_result "OK")"
assert_eq "$result" "ok-empty"
teardown_test_env

# ---- heartbeat_process_result meaningful content ----

test_start "heartbeat_process_result meaningful content returns has-content"
setup_test_env
_source_libs
result="$(heartbeat_process_result "I found an issue with the server: disk is running low on space and needs immediate attention.")"
assert_eq "$result" "has-content"
teardown_test_env

# ---- heartbeat_build_prompt returns correct text per reason ----

test_start "heartbeat_build_prompt default reason"
setup_test_env
_source_libs
result="$(heartbeat_build_prompt "default")"
assert_contains "$result" "HEARTBEAT.md"
teardown_test_env

test_start "heartbeat_build_prompt exec-event reason"
setup_test_env
_source_libs
result="$(heartbeat_build_prompt "exec-event")"
assert_contains "$result" "async command"
teardown_test_env

test_start "heartbeat_build_prompt cron-event reason"
setup_test_env
_source_libs
result="$(heartbeat_build_prompt "cron-event")"
assert_contains "$result" "scheduled reminder"
teardown_test_env

# ---- heartbeat_dedup returns 1 for unique text ----

test_start "heartbeat_dedup returns 1 for unique text"
setup_test_env
_source_libs
ensure_dir "${BASHCLAW_STATE_DIR}/heartbeat/dedup"
set +e
heartbeat_dedup "first alert message" "main" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "1"
teardown_test_env

# ---- heartbeat_dedup returns 0 for duplicate text within 24h ----

test_start "heartbeat_dedup returns 0 for duplicate text"
setup_test_env
_source_libs
ensure_dir "${BASHCLAW_STATE_DIR}/heartbeat/dedup"
heartbeat_dedup "same alert message" "main" 2>/dev/null || true
set +e
heartbeat_dedup "same alert message" "main" 2>/dev/null
rc=$?
set -e
assert_eq "$rc" "0"
teardown_test_env

report_results
