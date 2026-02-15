#!/usr/bin/env bash
# HTTP handler for socat-based gateway
# This script is executed per-connection by socat

# Source the main bashclaw if not already loaded
if ! declare -f log_info &>/dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/lib/log.sh"
  source "${SCRIPT_DIR}/lib/utils.sh"
  source "${SCRIPT_DIR}/lib/config.sh"
  source "${SCRIPT_DIR}/lib/session.sh"
  source "${SCRIPT_DIR}/lib/tools.sh"
  source "${SCRIPT_DIR}/lib/agent.sh"
  source "${SCRIPT_DIR}/lib/routing.sh"

  # Load .env if present
  env_file="${BASHCLAW_STATE_DIR:?}/.env"
  if [[ -f "$env_file" ]]; then
    set -a
    source "$env_file"
    set +a
  fi
fi

# ---- HTTP Request Parser ----

_http_read_request() {
  local line
  IFS= read -r line
  line="${line%%$'\r'}"

  HTTP_METHOD=""
  HTTP_PATH=""
  HTTP_VERSION=""
  HTTP_BODY=""
  HTTP_CONTENT_LENGTH=0

  # Parse request line
  IFS=' ' read -r HTTP_METHOD HTTP_PATH HTTP_VERSION <<< "$line"

  # Read headers
  while IFS= read -r line; do
    line="${line%%$'\r'}"
    [[ -z "$line" ]] && break

    local lower_line
    lower_line="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_line" == content-length:* ]]; then
      HTTP_CONTENT_LENGTH="${line#*: }"
      HTTP_CONTENT_LENGTH="${HTTP_CONTENT_LENGTH%%$'\r'}"
    fi
  done

  # Read body if present
  if (( HTTP_CONTENT_LENGTH > 0 )); then
    HTTP_BODY="$(head -c "$HTTP_CONTENT_LENGTH")"
  fi
}

# ---- HTTP Response Writer ----

_http_respond() {
  local status="$1"
  local content_type="${2:-application/json}"
  local body="$3"

  local status_text
  case "$status" in
    200) status_text="OK" ;;
    400) status_text="Bad Request" ;;
    401) status_text="Unauthorized" ;;
    404) status_text="Not Found" ;;
    405) status_text="Method Not Allowed" ;;
    500) status_text="Internal Server Error" ;;
    *) status_text="Unknown" ;;
  esac

  local body_length="${#body}"

  printf 'HTTP/1.1 %s %s\r\n' "$status" "$status_text"
  printf 'Content-Type: %s\r\n' "$content_type"
  printf 'Content-Length: %d\r\n' "$body_length"
  printf 'Connection: close\r\n'
  printf 'Access-Control-Allow-Origin: *\r\n'
  printf 'Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n'
  printf 'Access-Control-Allow-Headers: Content-Type, Authorization\r\n'
  printf '\r\n'
  printf '%s' "$body"
}

_http_respond_json() {
  local status="$1"
  local json="$2"
  _http_respond "$status" "application/json" "$json"
}

# ---- Auth Check ----

_http_check_auth() {
  local auth_token
  auth_token="$(config_get '.gateway.auth.token' '')"

  # No token configured = no auth required
  if [[ -z "$auth_token" ]]; then
    return 0
  fi

  # Check Authorization header from request headers
  # In socat mode, we need to extract it during header parsing
  # For now, skip auth in the minimal handler
  return 0
}

# ---- Route Handler ----

handle_request() {
  _http_read_request

  # Handle CORS preflight
  if [[ "$HTTP_METHOD" == "OPTIONS" ]]; then
    _http_respond 200 "text/plain" ""
    return
  fi

  log_debug "HTTP request: $HTTP_METHOD $HTTP_PATH"

  case "$HTTP_METHOD:$HTTP_PATH" in
    GET:/status|GET:/health|GET:/healthz)
      _handle_status
      ;;
    POST:/chat)
      _handle_chat
      ;;
    POST:/session/clear)
      _handle_session_clear
      ;;
    POST:/message/send)
      _handle_message_send
      ;;
    GET:/)
      _http_respond_json 200 '{"name":"bashclaw","status":"running"}'
      ;;
    *)
      _http_respond_json 404 '{"error":"not found"}'
      ;;
  esac
}

# ---- Route Implementations ----

_handle_status() {
  require_command jq "status handler requires jq"

  local uptime_info=""
  if [[ -f "${BASHCLAW_STATE_DIR}/gateway.pid" ]]; then
    local pid
    pid="$(cat "${BASHCLAW_STATE_DIR}/gateway.pid" 2>/dev/null)"
    uptime_info="$(jq -nc --arg pid "$pid" '{pid: $pid, running: true}')"
  else
    uptime_info='{"running": false}'
  fi

  local session_count=0
  if [[ -d "${BASHCLAW_STATE_DIR}/sessions" ]]; then
    session_count="$(find "${BASHCLAW_STATE_DIR}/sessions" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
  fi

  local response
  response="$(jq -nc \
    --arg status "ok" \
    --argjson sessions "$session_count" \
    --argjson gateway "$uptime_info" \
    '{status: $status, sessions: $sessions, gateway: $gateway}')"

  _http_respond_json 200 "$response"
}

_handle_chat() {
  require_command jq "chat handler requires jq"

  if [[ -z "$HTTP_BODY" ]]; then
    _http_respond_json 400 '{"error":"request body required"}'
    return
  fi

  # Parse all fields from body in a single jq call
  local parsed
  parsed="$(printf '%s' "$HTTP_BODY" | jq -r '[
    (.message // ""),
    (.agent // "main"),
    (.channel // "web"),
    (.sender // "http")
  ] | join("\n")' 2>/dev/null)"

  local message agent_id channel sender
  {
    IFS= read -r message
    IFS= read -r agent_id
    IFS= read -r channel
    IFS= read -r sender
  } <<< "$parsed"

  if [[ -z "$message" ]]; then
    _http_respond_json 400 '{"error":"message field is required"}'
    return
  fi

  local response
  response="$(agent_run "$agent_id" "$message" "$channel" "$sender" 2>/dev/null)"

  if [[ -n "$response" ]]; then
    local json
    json="$(jq -nc --arg r "$response" --arg a "$agent_id" \
      '{response: $r, agent: $a}')"
    _http_respond_json 200 "$json"
  else
    _http_respond_json 500 '{"error":"agent returned empty response"}'
  fi
}

_handle_session_clear() {
  require_command jq "session clear handler requires jq"

  local agent_id="main"
  local channel="web"
  local sender="http"

  if [[ -n "$HTTP_BODY" ]]; then
    local parsed
    parsed="$(printf '%s' "$HTTP_BODY" | jq -r '[
      (.agent // "main"),
      (.channel // "web"),
      (.sender // "http")
    ] | join("\n")' 2>/dev/null)"

    {
      IFS= read -r agent_id
      IFS= read -r channel
      IFS= read -r sender
    } <<< "$parsed"
  fi

  local sess_file
  sess_file="$(session_file "$agent_id" "$channel" "$sender")"
  session_clear "$sess_file"

  _http_respond_json 200 '{"cleared": true}'
}

_handle_message_send() {
  require_command jq "message send handler requires jq"

  if [[ -z "$HTTP_BODY" ]]; then
    _http_respond_json 400 '{"error":"request body required"}'
    return
  fi

  local parsed
  parsed="$(printf '%s' "$HTTP_BODY" | jq -r '[
    (.channel // ""),
    (.target // ""),
    (.message // "")
  ] | join("\n")' 2>/dev/null)"

  local ch target text
  {
    IFS= read -r ch
    IFS= read -r target
    IFS= read -r text
  } <<< "$parsed"

  if [[ -z "$ch" || -z "$target" || -z "$text" ]]; then
    _http_respond_json 400 '{"error":"channel, target, and message are required"}'
    return
  fi

  local send_func="channel_${ch}_send"
  if ! declare -f "$send_func" &>/dev/null; then
    # Try to load channel
    local ch_script
    ch_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/channels/${ch}.sh"
    if [[ -f "$ch_script" ]]; then
      source "$ch_script"
    fi
  fi

  if declare -f "$send_func" &>/dev/null; then
    local result
    result="$("$send_func" "$target" "$text" 2>/dev/null)"
    _http_respond_json 200 "$(jq -nc --arg ch "$ch" --arg r "$result" \
      '{sent: true, channel: $ch, result: $r}')"
  else
    _http_respond_json 400 "$(jq -nc --arg ch "$ch" \
      '{error: "unknown channel", channel: $ch}')"
  fi
}

# If executed directly (by socat), run the handler
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  handle_request
fi
