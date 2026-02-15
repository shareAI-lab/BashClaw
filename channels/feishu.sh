#!/usr/bin/env bash
# Feishu/Lark Bot channel for BashClaw
# Supports both Feishu (feishu.cn) and Lark (larksuite.com)
# Uses webhook mode for simplicity (no SDK dependency)

FEISHU_MAX_MESSAGE_LENGTH=30000
FEISHU_POLL_INTERVAL="${FEISHU_POLL_INTERVAL:-3}"

# ---- API Helpers ----

_feishu_app_id() {
  local id="${BASHCLAW_FEISHU_APP_ID:-}"
  if [[ -z "$id" ]]; then
    id="$(config_channel_get "feishu" "appId" "")"
  fi
  printf '%s' "$id"
}

_feishu_app_secret() {
  local secret="${BASHCLAW_FEISHU_APP_SECRET:-}"
  if [[ -z "$secret" ]]; then
    secret="$(config_channel_get "feishu" "appSecret" "")"
  fi
  printf '%s' "$secret"
}

_feishu_webhook_url() {
  local url="${BASHCLAW_FEISHU_WEBHOOK:-}"
  if [[ -z "$url" ]]; then
    url="$(config_channel_get "feishu" "webhookUrl" "")"
  fi
  printf '%s' "$url"
}

# Determine base API URL (feishu.cn vs larksuite.com)
_feishu_api_base() {
  local region
  region="$(config_channel_get "feishu" "region" "cn")"
  case "$region" in
    intl|lark) printf 'https://open.larksuite.com/open-apis' ;;
    *)         printf 'https://open.feishu.cn/open-apis' ;;
  esac
}

# Get tenant access token (for App Bot mode)
_FEISHU_TOKEN_CACHE=""
_FEISHU_TOKEN_EXPIRES=0

_feishu_get_token() {
  local now
  now="$(date +%s)"

  if [[ -n "$_FEISHU_TOKEN_CACHE" ]] && (( now < _FEISHU_TOKEN_EXPIRES )); then
    printf '%s' "$_FEISHU_TOKEN_CACHE"
    return
  fi

  local app_id app_secret
  app_id="$(_feishu_app_id)"
  app_secret="$(_feishu_app_secret)"

  if [[ -z "$app_id" || -z "$app_secret" ]]; then
    log_error "Feishu App ID and App Secret required for App Bot mode"
    return 1
  fi

  local base
  base="$(_feishu_api_base)"
  local body
  body="$(jq -nc --arg id "$app_id" --arg secret "$app_secret" \
    '{"app_id": $id, "app_secret": $secret}')"

  local response
  response="$(curl -sS --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${base}/auth/v3/tenant_access_token/internal" 2>/dev/null)"

  if [[ $? -ne 0 || -z "$response" ]]; then
    log_error "Feishu token request failed"
    return 1
  fi

  local code
  code="$(printf '%s' "$response" | jq -r '.code // -1')"
  if [[ "$code" != "0" ]]; then
    local msg
    msg="$(printf '%s' "$response" | jq -r '.msg // "unknown"')"
    log_error "Feishu token error: $msg (code=$code)"
    return 1
  fi

  _FEISHU_TOKEN_CACHE="$(printf '%s' "$response" | jq -r '.tenant_access_token')"
  local expire
  expire="$(printf '%s' "$response" | jq -r '.expire // 7200')"
  _FEISHU_TOKEN_EXPIRES=$((now + expire - 300))

  printf '%s' "$_FEISHU_TOKEN_CACHE"
}

_feishu_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  local base
  base="$(_feishu_api_base)"
  local token
  token="$(_feishu_get_token)" || return 1

  local response
  if [[ "$method" == "GET" ]]; then
    response="$(curl -sS --max-time 60 \
      -H "Authorization: Bearer ${token}" \
      "${base}${path}" 2>/dev/null)"
  else
    response="$(curl -sS --max-time 60 \
      -X "$method" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "${base}${path}" 2>/dev/null)"
  fi

  if [[ $? -ne 0 || -z "$response" ]]; then
    log_error "Feishu API request failed: $path"
    return 1
  fi

  local code
  code="$(printf '%s' "$response" | jq -r '.code // -1')"
  if [[ "$code" != "0" ]]; then
    local msg
    msg="$(printf '%s' "$response" | jq -r '.msg // "unknown"')"
    log_error "Feishu API error ($path): $msg"
    printf '%s' "$response"
    return 1
  fi

  printf '%s' "$response"
}

# ---- Public Functions ----

# Send via webhook (simple mode, group only)
channel_feishu_send_webhook() {
  local text="$1"

  local webhook_url
  webhook_url="$(_feishu_webhook_url)"
  if [[ -z "$webhook_url" ]]; then
    log_error "Feishu webhook URL not configured"
    return 1
  fi

  local body
  body="$(jq -nc --arg t "$text" '{"msg_type":"text","content":{"text":$t}}')"

  local response
  response="$(curl -sS --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$webhook_url" 2>/dev/null)"

  if [[ $? -ne 0 ]]; then
    log_error "Feishu webhook send failed"
    return 1
  fi

  local code
  code="$(printf '%s' "$response" | jq -r '.code // .StatusCode // -1')"
  if [[ "$code" != "0" ]]; then
    log_error "Feishu webhook error: $(printf '%s' "$response" | jq -r '.msg // .StatusMessage // "unknown"')"
    return 1
  fi

  printf 'ok'
}

# Send via App Bot API (full mode, supports DM and group)
channel_feishu_send() {
  local target="$1"
  local text="$2"

  if [[ -z "$target" || -z "$text" ]]; then
    log_error "channel_feishu_send: target and text required"
    return 1
  fi

  require_command jq "channel_feishu_send requires jq"

  # Truncate at limit
  if (( ${#text} > FEISHU_MAX_MESSAGE_LENGTH )); then
    text="${text:0:$FEISHU_MAX_MESSAGE_LENGTH}..."
  fi

  local body
  body="$(jq -nc \
    --arg id "$target" \
    --arg txt "$text" \
    '{receive_id: $id, msg_type: "text", content: ({text: $txt} | tojson)}')"

  local response
  response="$(_feishu_api "POST" "/im/v1/messages?receive_id_type=chat_id" "$body")" || return 1
  printf '%s' "$response" | jq -r '.data.message_id // ""'
}

channel_feishu_reply() {
  local message_id="$1"
  local text="$2"

  if [[ -z "$message_id" || -z "$text" ]]; then
    log_error "channel_feishu_reply: message_id and text required"
    return 1
  fi

  require_command jq "channel_feishu_reply requires jq"

  local body
  body="$(jq -nc --arg txt "$text" \
    '{msg_type: "text", content: ({text: $txt} | tojson)}')"

  local response
  response="$(_feishu_api "POST" "/im/v1/messages/${message_id}/reply" "$body")" || return 1
  printf '%s' "$response" | jq -r '.data.message_id // ""'
}

# ---- Polling Listener ----

# Track last processed event timestamp
_FEISHU_LAST_TS_FILE=""

_feishu_last_ts_file() {
  if [[ -z "$_FEISHU_LAST_TS_FILE" ]]; then
    _FEISHU_LAST_TS_FILE="${BASHCLAW_STATE_DIR:?}/channels/feishu_last_ts"
    ensure_dir "$(dirname "$_FEISHU_LAST_TS_FILE")"
  fi
  printf '%s' "$_FEISHU_LAST_TS_FILE"
}

_feishu_last_ts_get() {
  local f
  f="$(_feishu_last_ts_file)"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    printf '0'
  fi
}

_feishu_last_ts_set() {
  printf '%s' "$1" > "$(_feishu_last_ts_file)"
}

channel_feishu_start() {
  log_info "Feishu listener starting..."

  # Determine mode: webhook-only or app bot
  local app_id
  app_id="$(_feishu_app_id)"
  local webhook_url
  webhook_url="$(_feishu_webhook_url)"

  if [[ -z "$app_id" && -z "$webhook_url" ]]; then
    log_error "Feishu: either App ID + App Secret (for polling) or Webhook URL required"
    return 1
  fi

  # Webhook-only mode: no polling, only outbound
  if [[ -z "$app_id" ]]; then
    log_info "Feishu: webhook-only mode (outbound only, no message polling)"
    log_info "Feishu: configure appId + appSecret for bidirectional messaging"
    # Keep the process alive but don't poll
    while true; do
      sleep 60
    done
    return 0
  fi

  # App Bot mode: poll for messages
  local token
  token="$(_feishu_get_token)" || return 1
  log_info "Feishu App Bot authenticated"

  local last_ts
  last_ts="$(_feishu_last_ts_get)"

  while true; do
    # List recent messages from subscribed chats
    local chat_list
    chat_list="$(config_channel_get "feishu" "monitorChats" "[]")"
    if [[ "$chat_list" == "[]" || -z "$chat_list" ]]; then
      sleep "$FEISHU_POLL_INTERVAL"
      continue
    fi

    local chat_count
    chat_count="$(printf '%s' "$chat_list" | jq 'length' 2>/dev/null)" || chat_count=0

    local ci=0
    while (( ci < chat_count )); do
      local chat_id
      chat_id="$(printf '%s' "$chat_list" | jq -r ".[$ci]")"

      local messages_resp
      messages_resp="$(_feishu_api "GET" "/im/v1/messages?container_id_type=chat&container_id=${chat_id}&sort_type=ByCreateTimeDesc&page_size=10" 2>/dev/null)"

      if [[ $? -eq 0 && -n "$messages_resp" ]]; then
        local items
        items="$(printf '%s' "$messages_resp" | jq -c '.data.items // []')"
        local msg_count
        msg_count="$(printf '%s' "$items" | jq 'length')"

        local mi=0
        while (( mi < msg_count )); do
          local msg
          msg="$(printf '%s' "$items" | jq -c ".[$mi]")"
          local create_time
          create_time="$(printf '%s' "$msg" | jq -r '.create_time // "0"')"

          # Skip already processed messages
          if [[ "$create_time" -le "$last_ts" ]]; then
            mi=$((mi + 1))
            continue
          fi

          local sender_id msg_type content
          sender_id="$(printf '%s' "$msg" | jq -r '.sender.id // ""')"
          msg_type="$(printf '%s' "$msg" | jq -r '.msg_type // ""')"

          if [[ "$msg_type" != "text" ]]; then
            mi=$((mi + 1))
            continue
          fi

          content="$(printf '%s' "$msg" | jq -r '.body.content // ""' | jq -r '.text // ""' 2>/dev/null)"
          if [[ -z "$content" ]]; then
            mi=$((mi + 1))
            continue
          fi

          log_info "Feishu message: chat=$chat_id sender=$sender_id"

          local reply
          reply="$(routing_dispatch "feishu" "$sender_id" "$content" "true")"
          if [[ -n "$reply" ]]; then
            channel_feishu_send "$chat_id" "$reply" || true
          fi

          _feishu_last_ts_set "$create_time"
          last_ts="$create_time"

          mi=$((mi + 1))
        done
      fi

      ci=$((ci + 1))
    done

    sleep "$FEISHU_POLL_INTERVAL"
  done
}

# Register channel send function for tool_message
_channel_send_feishu() {
  local target="$1"
  local message="$2"

  # If no app credentials, try webhook
  local app_id
  app_id="$(_feishu_app_id)"
  if [[ -z "$app_id" ]]; then
    local result
    result="$(channel_feishu_send_webhook "$message")" || {
      jq -nc --arg ch "feishu" --arg err "send failed" \
        '{"sent": false, "channel": $ch, "error": $err}'
      return 1
    }
    jq -nc --arg ch "feishu" --arg tgt "$target" \
      '{"sent": true, "channel": $ch, "target": $tgt}'
    return
  fi

  local msg_id
  msg_id="$(channel_feishu_send "$target" "$message")" || {
    jq -nc --arg ch "feishu" --arg err "send failed" \
      '{"sent": false, "channel": $ch, "error": $err}'
    return 1
  }
  jq -nc --arg ch "feishu" --arg mid "$msg_id" --arg tgt "$target" \
    '{"sent": true, "channel": $ch, "messageId": $mid, "target": $tgt}'
}
