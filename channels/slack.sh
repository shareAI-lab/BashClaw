#!/usr/bin/env bash
# Slack Bot API channel for bashclaw

SLACK_API="https://slack.com/api"
SLACK_MAX_MESSAGE_LENGTH=40000
SLACK_POLL_INTERVAL="${SLACK_POLL_INTERVAL:-3}"

# ---- API Helpers ----

_slack_token() {
  local token="${BASHCLAW_SLACK_TOKEN:-}"
  if [[ -z "$token" ]]; then
    token="$(config_channel_get "slack" "botToken" "")"
  fi
  if [[ -z "$token" ]]; then
    log_error "Slack bot token not configured (set BASHCLAW_SLACK_TOKEN or channels.slack.botToken)"
    return 1
  fi
  printf '%s' "$token"
}

_slack_webhook_url() {
  local url="${BASHCLAW_SLACK_WEBHOOK_URL:-}"
  if [[ -z "$url" ]]; then
    url="$(config_channel_get "slack" "webhookUrl" "")"
  fi
  printf '%s' "$url"
}

_slack_api() {
  local method="$1"
  local data="$2"

  local token
  token="$(_slack_token)" || return 1

  local url="${SLACK_API}/${method}"
  local response
  response="$(curl -sS --max-time 30 \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$data" \
    "$url" 2>/dev/null)"

  if [[ $? -ne 0 || -z "$response" ]]; then
    log_error "Slack API request failed: $method"
    return 1
  fi

  local ok
  ok="$(printf '%s' "$response" | jq -r '.ok // false')"
  if [[ "$ok" != "true" ]]; then
    local error
    error="$(printf '%s' "$response" | jq -r '.error // "unknown error"')"
    log_error "Slack API error ($method): $error"
    printf '%s' "$response"
    return 1
  fi

  printf '%s' "$response"
}

# ---- Public Functions ----

channel_slack_send() {
  local channel_id="$1"
  local text="$2"
  local thread_ts="${3:-}"

  if [[ -z "$channel_id" || -z "$text" ]]; then
    log_error "channel_slack_send: channel_id and text are required"
    return 1
  fi

  require_command jq "channel_slack_send requires jq"

  # Try webhook mode first if configured and no thread_ts
  if [[ -z "$thread_ts" ]]; then
    local webhook_url
    webhook_url="$(_slack_webhook_url)"
    if [[ -n "$webhook_url" ]]; then
      _slack_send_webhook "$webhook_url" "$channel_id" "$text"
      return $?
    fi
  fi

  # Bot token mode
  local data
  if [[ -n "$thread_ts" ]]; then
    data="$(jq -nc --arg ch "$channel_id" --arg txt "$text" --arg ts "$thread_ts" \
      '{channel: $ch, text: $txt, thread_ts: $ts}')"
  else
    data="$(jq -nc --arg ch "$channel_id" --arg txt "$text" \
      '{channel: $ch, text: $txt}')"
  fi

  local response
  response="$(_slack_api "chat.postMessage" "$data")" || return 1
  printf '%s' "$response" | jq -r '.ts // ""'
}

_slack_send_webhook() {
  local webhook_url="$1"
  local channel_id="$2"
  local text="$3"

  local data
  data="$(jq -nc --arg ch "$channel_id" --arg txt "$text" \
    '{channel: $ch, text: $txt}')"

  local response
  response="$(curl -sS --max-time 15 \
    -H "Content-Type: application/json" \
    -d "$data" \
    "$webhook_url" 2>/dev/null)"

  if [[ $? -ne 0 ]]; then
    log_error "Slack webhook send failed"
    return 1
  fi

  if [[ "$response" == "ok" ]]; then
    printf 'webhook'
    return 0
  fi

  log_warn "Slack webhook response: $response"
  printf 'webhook'
}

channel_slack_reply() {
  local channel_id="$1"
  local thread_ts="$2"
  local text="$3"

  channel_slack_send "$channel_id" "$text" "$thread_ts"
}

channel_slack_auth_test() {
  _slack_api "auth.test" "{}"
}

channel_slack_conversations_list() {
  local types="${1:-public_channel,private_channel}"
  local data
  data="$(jq -nc --arg t "$types" '{types: $t, limit: 200}')"
  _slack_api "conversations.list" "$data"
}

# ---- Polling Listener ----

# Tracks last seen timestamp per channel (file-based for bash 3.2 compat)
_SLACK_LAST_TS_DIR=""

_slack_last_ts_init() {
  if [[ -z "$_SLACK_LAST_TS_DIR" ]]; then
    _SLACK_LAST_TS_DIR="$(mktemp -d -t bashclaw_slack.XXXXXX 2>/dev/null || mktemp -d /tmp/bashclaw_slack.XXXXXX)"
  fi
}

_slack_last_ts_get() {
  _slack_last_ts_init
  local ch_id="$1"
  local f="$_SLACK_LAST_TS_DIR/$ch_id"
  if [[ -f "$f" ]]; then cat "$f"; else echo ""; fi
}

_slack_last_ts_set() {
  _slack_last_ts_init
  local ch_id="$1" ts="$2"
  printf '%s' "$ts" > "$_SLACK_LAST_TS_DIR/$ch_id"
}

channel_slack_start() {
  log_info "Slack poll listener starting..."

  local auth
  auth="$(channel_slack_auth_test)" || {
    log_error "Failed to verify Slack bot identity"
    return 1
  }
  local bot_id bot_name
  bot_id="$(printf '%s' "$auth" | jq -r '.bot_id // .user_id // ""')"
  bot_name="$(printf '%s' "$auth" | jq -r '.user // "unknown"')"
  log_info "Slack bot: ${bot_name} (${bot_id})"

  # Read configured channels to monitor
  local channels_json
  channels_json="$(config_get_raw '.channels.slack.monitorChannels // []')"
  local num_channels
  num_channels="$(printf '%s' "$channels_json" | jq 'length')"

  if (( num_channels == 0 )); then
    log_warn "No Slack channels configured to monitor (set channels.slack.monitorChannels)"
    return 1
  fi

  log_info "Monitoring $num_channels Slack channels"

  while true; do
    local c=0
    while (( c < num_channels )); do
      local chan_id
      chan_id="$(printf '%s' "$channels_json" | jq -r ".[$c]")"

      local oldest
      oldest="$(_slack_last_ts_get "$chan_id")"
      local data
      if [[ -n "$oldest" ]]; then
        data="$(jq -nc --arg ch "$chan_id" --arg old "$oldest" \
          '{channel: $ch, oldest: $old, limit: 50}')"
      else
        data="$(jq -nc --arg ch "$chan_id" '{channel: $ch, limit: 1}')"
      fi

      local response
      response="$(_slack_api "conversations.history" "$data" 2>/dev/null)"
      if [[ $? -ne 0 || -z "$response" ]]; then
        c=$((c + 1))
        continue
      fi

      local messages
      messages="$(printf '%s' "$response" | jq -c '.messages // []')"
      local msg_count
      msg_count="$(printf '%s' "$messages" | jq 'length')"

      if (( msg_count == 0 )); then
        c=$((c + 1))
        continue
      fi

      # Process messages in chronological order (Slack returns newest first)
      local m=$((msg_count - 1))
      while (( m >= 0 )); do
        local msg
        msg="$(printf '%s' "$messages" | jq -c ".[$m]")"
        local ts user subtype text
        ts="$(printf '%s' "$msg" | jq -r '.ts // ""')"
        user="$(printf '%s' "$msg" | jq -r '.user // ""')"
        subtype="$(printf '%s' "$msg" | jq -r '.subtype // ""')"
        text="$(printf '%s' "$msg" | jq -r '.text // ""')"

        # Update last seen timestamp
        _slack_last_ts_set "$chan_id" "$ts"

        # Skip bot messages and subtypes
        if [[ -n "$subtype" || "$user" == "$bot_id" ]]; then
          m=$((m - 1))
          continue
        fi

        if [[ -z "$text" ]]; then
          m=$((m - 1))
          continue
        fi

        log_info "Slack message: channel=$chan_id user=$user"
        log_debug "Slack text: ${text:0:100}"

        # Dispatch through routing pipeline
        local reply
        reply="$(routing_dispatch "slack" "$user" "$text" "true")"
        if [[ -n "$reply" ]]; then
          channel_slack_reply "$chan_id" "$ts" "$reply" || true
        fi

        m=$((m - 1))
      done

      c=$((c + 1))
    done

    sleep "$SLACK_POLL_INTERVAL"
  done
}

# Register channel send function for tool_message
_channel_send_slack() {
  local target="$1"
  local message="$2"
  local msg_ts
  msg_ts="$(channel_slack_send "$target" "$message")" || {
    jq -nc --arg ch "slack" --arg err "send failed" \
      '{"sent": false, "channel": $ch, "error": $err}'
    return 1
  }
  jq -nc --arg ch "slack" --arg ts "$msg_ts" --arg tgt "$target" \
    '{"sent": true, "channel": $ch, "messageTs": $ts, "target": $tgt}'
}
