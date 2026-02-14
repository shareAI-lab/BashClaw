#!/usr/bin/env bash
# Telegram Bot API channel for bashclaw

TELEGRAM_API="https://api.telegram.org/bot"
TELEGRAM_MAX_MESSAGE_LENGTH=4096
TELEGRAM_POLL_TIMEOUT="${TELEGRAM_POLL_TIMEOUT:-30}"
TELEGRAM_POLL_OFFSET=""

# ---- API Helpers ----

_telegram_token() {
  local token="${BASHCLAW_TELEGRAM_TOKEN:-}"
  if [[ -z "$token" ]]; then
    token="$(config_channel_get "telegram" "botToken" "")"
  fi
  if [[ -z "$token" ]]; then
    log_error "Telegram bot token not configured (set BASHCLAW_TELEGRAM_TOKEN or channels.telegram.botToken)"
    return 1
  fi
  printf '%s' "$token"
}

_telegram_api() {
  local method="$1"
  shift
  local token
  token="$(_telegram_token)" || return 1

  local url="${TELEGRAM_API}${token}/${method}"
  local response
  response="$(curl -sS --max-time 60 "$@" "$url" 2>/dev/null)"
  if [[ $? -ne 0 || -z "$response" ]]; then
    log_error "Telegram API request failed: $method"
    return 1
  fi

  local ok
  ok="$(printf '%s' "$response" | jq -r '.ok // false')"
  if [[ "$ok" != "true" ]]; then
    local desc
    desc="$(printf '%s' "$response" | jq -r '.description // "unknown error"')"
    log_error "Telegram API error ($method): $desc"
    printf '%s' "$response"
    return 1
  fi

  printf '%s' "$response"
}

_telegram_api_post() {
  local method="$1"
  local data="$2"
  _telegram_api "$method" \
    -H "Content-Type: application/json" \
    -d "$data"
}

# ---- Public Functions ----

channel_telegram_get_me() {
  local response
  response="$(_telegram_api "getMe")" || return 1
  printf '%s' "$response" | jq '.result'
}

channel_telegram_set_webhook() {
  local url="$1"
  local secret="${2:-}"

  require_command jq "channel_telegram_set_webhook requires jq"

  local data
  if [[ -n "$secret" ]]; then
    data="$(jq -nc --arg url "$url" --arg secret "$secret" \
      '{url: $url, secret_token: $secret}')"
  else
    data="$(jq -nc --arg url "$url" '{url: $url}')"
  fi

  local response
  response="$(_telegram_api_post "setWebhook" "$data")" || return 1
  log_info "Telegram webhook set: $url"
  printf '%s' "$response"
}

channel_telegram_delete_webhook() {
  local data='{"drop_pending_updates": false}'
  local response
  response="$(_telegram_api_post "deleteWebhook" "$data")" || return 1
  log_info "Telegram webhook deleted"
  printf '%s' "$response"
}

channel_telegram_send() {
  local chat_id="$1"
  local text="$2"

  if [[ -z "$chat_id" || -z "$text" ]]; then
    log_error "channel_telegram_send: chat_id and text are required"
    return 1
  fi

  require_command jq "channel_telegram_send requires jq"

  # Split long messages at the Telegram limit
  local parts=()
  local remaining="$text"
  while (( ${#remaining} > TELEGRAM_MAX_MESSAGE_LENGTH )); do
    local chunk="${remaining:0:$TELEGRAM_MAX_MESSAGE_LENGTH}"
    # Try to split at a newline boundary
    local split_pos=-1
    # Find last newline in chunk using bash string ops (portable)
    local _before="${chunk%$'\n'*}"
    if [[ "$_before" != "$chunk" ]]; then
      split_pos="${#_before}"
    fi
    if (( split_pos < 0 )); then
      split_pos=$TELEGRAM_MAX_MESSAGE_LENGTH
    fi
    parts+=("${remaining:0:$split_pos}")
    remaining="${remaining:$split_pos}"
    remaining="${remaining#$'\n'}"
  done
  if [[ -n "$remaining" ]]; then
    parts+=("$remaining")
  fi

  local last_msg_id=""
  local part
  for part in "${parts[@]}"; do
    local data
    data="$(jq -nc --arg cid "$chat_id" --arg txt "$part" \
      '{chat_id: $cid, text: $txt}')"

    local response
    response="$(_telegram_api_post "sendMessage" "$data")" || return 1
    last_msg_id="$(printf '%s' "$response" | jq -r '.result.message_id // ""')"
  done

  printf '%s' "$last_msg_id"
}

channel_telegram_reply() {
  local chat_id="$1"
  local reply_to_message_id="$2"
  local text="$3"

  if [[ -z "$chat_id" || -z "$reply_to_message_id" || -z "$text" ]]; then
    log_error "channel_telegram_reply: chat_id, reply_to_message_id, and text required"
    return 1
  fi

  require_command jq "channel_telegram_reply requires jq"

  local data
  data="$(jq -nc \
    --arg cid "$chat_id" \
    --arg txt "$text" \
    --argjson rid "$reply_to_message_id" \
    '{chat_id: $cid, text: $txt, reply_to_message_id: $rid}')"

  local response
  response="$(_telegram_api_post "sendMessage" "$data")" || return 1
  printf '%s' "$response" | jq -r '.result.message_id // ""'
}

# ---- Long-Poll Listener ----

channel_telegram_start() {
  log_info "Telegram long-poll listener starting..."

  local token
  token="$(_telegram_token)" || return 1

  # Verify bot identity
  local me
  me="$(channel_telegram_get_me)" || {
    log_error "Failed to verify Telegram bot identity"
    return 1
  }
  local bot_username
  bot_username="$(printf '%s' "$me" | jq -r '.username // "unknown"')"
  log_info "Telegram bot: @${bot_username}"

  TELEGRAM_POLL_OFFSET=""

  while true; do
    local params
    params="$(jq -nc \
      --argjson timeout "$TELEGRAM_POLL_TIMEOUT" \
      --arg offset "${TELEGRAM_POLL_OFFSET:-0}" \
      '{timeout: $timeout, offset: (if $offset == "" then 0 else ($offset | tonumber) end), allowed_updates: ["message"]}')"

    local response
    response="$(_telegram_api_post "getUpdates" "$params" 2>/dev/null)"
    if [[ $? -ne 0 || -z "$response" ]]; then
      log_warn "Telegram poll failed, retrying in 5s..."
      sleep 5
      continue
    fi

    local ok
    ok="$(printf '%s' "$response" | jq -r '.ok // false')"
    if [[ "$ok" != "true" ]]; then
      log_warn "Telegram poll returned error, retrying in 5s..."
      sleep 5
      continue
    fi

    local updates
    updates="$(printf '%s' "$response" | jq -c '.result // []')"
    local count
    count="$(printf '%s' "$updates" | jq 'length')"

    if (( count == 0 )); then
      continue
    fi

    local i=0
    while (( i < count )); do
      local update
      update="$(printf '%s' "$updates" | jq -c ".[$i]")"
      local update_id
      update_id="$(printf '%s' "$update" | jq -r '.update_id')"

      # Update offset to acknowledge this update
      TELEGRAM_POLL_OFFSET=$((update_id + 1))

      # Extract message data
      local msg
      msg="$(printf '%s' "$update" | jq -c '.message // empty')"
      if [[ -z "$msg" || "$msg" == "null" ]]; then
        i=$((i + 1))
        continue
      fi

      local chat_id sender_id text is_group
      chat_id="$(printf '%s' "$msg" | jq -r '.chat.id // ""')"
      sender_id="$(printf '%s' "$msg" | jq -r '.from.id // ""')"
      text="$(printf '%s' "$msg" | jq -r '.text // ""')"
      local chat_type
      chat_type="$(printf '%s' "$msg" | jq -r '.chat.type // "private"')"

      if [[ -z "$text" ]]; then
        i=$((i + 1))
        continue
      fi

      is_group="false"
      if [[ "$chat_type" == "group" || "$chat_type" == "supergroup" ]]; then
        is_group="true"
      fi

      log_info "Telegram message: chat=$chat_id sender=$sender_id group=$is_group"
      log_debug "Telegram text: ${text:0:100}"

      # Dispatch through routing pipeline
      local reply
      reply="$(routing_dispatch "telegram" "$sender_id" "$text" "$is_group")"
      if [[ -n "$reply" ]]; then
        channel_telegram_send "$chat_id" "$reply" || true
      fi

      i=$((i + 1))
    done
  done
}

# Register channel send function for tool_message
_channel_send_telegram() {
  local target="$1"
  local message="$2"
  local msg_id
  msg_id="$(channel_telegram_send "$target" "$message")" || {
    jq -nc --arg ch "telegram" --arg err "send failed" \
      '{"sent": false, "channel": $ch, "error": $err}'
    return 1
  }
  jq -nc --arg ch "telegram" --arg mid "$msg_id" --arg tgt "$target" \
    '{"sent": true, "channel": $ch, "messageId": $mid, "target": $tgt}'
}
