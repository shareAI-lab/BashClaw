#!/usr/bin/env bash
# Message routing for bashclaw
# Compatible with bash 3.2+ (no associative arrays)

# ---- Channel-specific message length limits ----

_channel_max_length() {
  case "$1" in
    telegram)  echo 4096 ;;
    discord)   echo 2000 ;;
    slack)     echo 40000 ;;
    whatsapp)  echo 4096 ;;
    imessage)  echo 20000 ;;
    line)      echo 5000 ;;
    signal)    echo 4096 ;;
    web)       echo 100000 ;;
    *)         echo 4096 ;;
  esac
}

# ---- Agent Resolution ----

routing_resolve_agent() {
  local channel="${1:-default}"
  local sender="${2:-}"

  local channel_agent
  channel_agent="$(config_channel_get "$channel" "agentId" "")"
  if [[ -n "$channel_agent" ]]; then
    printf '%s' "$channel_agent"
    return
  fi

  local bindings
  bindings="$(config_get_raw '.bindings // []')"
  if [[ "$bindings" != "null" && "$bindings" != "[]" ]]; then
    local matched
    matched="$(printf '%s' "$bindings" | jq -r \
      --arg ch "$channel" --arg sender "$sender" '
      [.[] |
        select(.match.channel == $ch) |
        if .match.peer then
          select(.match.peer.id == $sender)
        else
          .
        end
      ] | .[0].agentId // empty
    ' 2>/dev/null)"
    if [[ -n "$matched" ]]; then
      printf '%s' "$matched"
      return
    fi
  fi

  local default_agent
  default_agent="$(config_get '.agents.defaultId' 'main')"
  printf '%s' "$default_agent"
}

# ---- Allowlist Check ----

routing_check_allowlist() {
  local channel="$1"
  local sender="$2"

  local allowlist
  allowlist="$(config_get_raw ".channels.${channel}.allowFrom // null" 2>/dev/null)"

  if [[ "$allowlist" == "null" || -z "$allowlist" ]]; then
    return 0
  fi

  local is_allowed
  is_allowed="$(printf '%s' "$allowlist" | jq --arg s "$sender" \
    'if type == "array" then any(. == $s or . == ($s | tonumber? // "")) else true end' 2>/dev/null)"

  if [[ "$is_allowed" == "true" ]]; then
    return 0
  fi

  log_warn "Sender not in allowlist: channel=$channel sender=$sender"
  return 1
}

# ---- Mention Gating ----

routing_check_mention_gating() {
  local channel="$1"
  local message="$2"
  local is_group="${3:-false}"

  if [[ "$is_group" != "true" ]]; then
    return 0
  fi

  local require_mention
  require_mention="$(config_channel_get "$channel" "requireMention" "true")"

  if [[ "$require_mention" != "true" ]]; then
    return 0
  fi

  local bot_name
  bot_name="$(config_channel_get "$channel" "botName" "")"
  if [[ -z "$bot_name" ]]; then
    bot_name="$(config_get '.agents.defaults.name' 'bashclaw')"
  fi

  local lower_msg lower_name
  lower_msg="$(printf '%s' "$message" | tr '[:upper:]' '[:lower:]')"
  lower_name="$(printf '%s' "$bot_name" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lower_msg" == *"@${lower_name}"* ]]; then
    return 0
  fi

  if [[ "$lower_msg" == *"${lower_name}"* ]]; then
    return 0
  fi

  log_debug "Mention gating: bot=$bot_name not mentioned in group message"
  return 1
}

# ---- Reply Formatting ----

routing_format_reply() {
  local channel="$1"
  local text="$2"

  local max_len
  max_len="$(_channel_max_length "$channel")"

  if [ "${#text}" -le "$max_len" ]; then
    printf '%s' "$text"
    return
  fi

  local truncated="${text:0:$((max_len - 20))}

[message truncated]"
  printf '%s' "$truncated"
}

# ---- Long Message Splitting ----

routing_split_long_message() {
  local text="$1"
  local max_len="${2:-4096}"

  if [ "${#text}" -le "$max_len" ]; then
    printf '%s\n' "$text"
    return
  fi

  local remaining="$text"

  while [ "${#remaining}" -gt 0 ]; do
    if [ "${#remaining}" -le "$max_len" ]; then
      printf '%s\n' "$remaining"
      break
    fi

    local chunk="${remaining:0:$max_len}"
    local split_pos=-1

    # Try to split at a paragraph boundary (double newline)
    local last_para
    last_para="$(printf '%s' "$chunk" | grep -bn '^$' | tail -1 | cut -d: -f1)"
    if [[ -n "$last_para" && "$last_para" -gt 0 ]]; then
      # grep -bn returns line number; we need char offset
      # Use a different approach: find last double newline position
      local tmp_chunk="$chunk"
      local found_pos=""
      local search_from=0
      while true; do
        local idx="${tmp_chunk%%

*}"
        if [[ "$idx" == "$tmp_chunk" ]]; then
          break
        fi
        local idx_len="${#idx}"
        search_from=$((search_from + idx_len))
        found_pos="$search_from"
        tmp_chunk="${tmp_chunk:$((idx_len + 2))}"
        search_from=$((search_from + 2))
      done
      if [[ -n "$found_pos" ]]; then
        split_pos="$found_pos"
      fi
    fi

    # Fall back to last newline
    if [ "$split_pos" -lt 0 ] 2>/dev/null; then
      local nl_chunk="${chunk%
*}"
      if [[ "$nl_chunk" != "$chunk" && -n "$nl_chunk" ]]; then
        split_pos="${#nl_chunk}"
      fi
    fi

    # Fall back to last space
    if [ "$split_pos" -lt 0 ] 2>/dev/null; then
      local sp_chunk="${chunk% *}"
      if [[ "$sp_chunk" != "$chunk" && -n "$sp_chunk" ]]; then
        split_pos="${#sp_chunk}"
      fi
    fi

    # Hard cut if no boundary found
    if [ "$split_pos" -lt 0 ] 2>/dev/null; then
      split_pos=$max_len
    fi

    printf '%s\n' "${remaining:0:$split_pos}"
    remaining="${remaining:$split_pos}"
    # Trim leading whitespace from remaining
    remaining="${remaining#"${remaining%%[![:space:]]*}"}"
  done
}

# ---- Main Dispatch Pipeline ----

routing_dispatch() {
  local channel="${1:-default}"
  local sender="${2:-}"
  local message="$3"
  local is_group="${4:-false}"

  if [[ -z "$message" ]]; then
    log_warn "routing_dispatch: empty message"
    printf ''
    return 1
  fi

  # Security: audit log incoming message
  security_audit_log "message_received" "channel=$channel sender=$sender"

  # Security: rate limit check
  if ! security_rate_limit "$sender" 2>/dev/null; then
    log_info "Message rate-limited: sender=$sender"
    printf ''
    return 1
  fi

  if ! routing_check_allowlist "$channel" "$sender"; then
    log_info "Message blocked by allowlist: channel=$channel sender=$sender"
    printf ''
    return 1
  fi

  if ! routing_check_mention_gating "$channel" "$message" "$is_group"; then
    log_debug "Message skipped (no mention in group): channel=$channel"
    printf ''
    return 0
  fi

  # Auto-reply check before agent dispatch
  local auto_response
  auto_response="$(autoreply_check "$message" "$channel" 2>/dev/null)" || true
  if [[ -n "$auto_response" ]]; then
    log_info "Auto-reply matched: channel=$channel sender=$sender"
    security_audit_log "autoreply_matched" "channel=$channel sender=$sender"
    local formatted
    formatted="$(routing_format_reply "$channel" "$auto_response")"
    printf '%s' "$formatted"
    return 0
  fi

  local agent_id
  agent_id="$(routing_resolve_agent "$channel" "$sender")"
  log_info "Routing: channel=$channel sender=$sender agent=$agent_id"

  # Run pre_message hooks
  local hook_input
  hook_input="$(jq -nc \
    --arg ch "$channel" \
    --arg snd "$sender" \
    --arg msg "$message" \
    --arg aid "$agent_id" \
    '{channel: $ch, sender: $snd, message: $msg, agent_id: $aid}' 2>/dev/null)"

  local hooked_input
  hooked_input="$(hooks_run "pre_message" "$hook_input" 2>/dev/null)" || true
  if [[ -n "$hooked_input" ]]; then
    local hooked_msg
    hooked_msg="$(printf '%s' "$hooked_input" | jq -r '.message // empty' 2>/dev/null)"
    if [[ -n "$hooked_msg" ]]; then
      message="$hooked_msg"
    fi
  fi

  local response
  response="$(agent_run "$agent_id" "$message" "$channel" "$sender")"

  if [[ -z "$response" ]]; then
    log_warn "Agent returned empty response"
    printf ''
    return 1
  fi

  # Run post_message hooks
  local post_hook_input
  post_hook_input="$(jq -nc \
    --arg ch "$channel" \
    --arg snd "$sender" \
    --arg msg "$message" \
    --arg resp "$response" \
    --arg aid "$agent_id" \
    '{channel: $ch, sender: $snd, message: $msg, response: $resp, agent_id: $aid}' 2>/dev/null)"
  hooks_run "post_message" "$post_hook_input" >/dev/null 2>&1 || true

  # Security: audit log response
  security_audit_log "message_responded" "channel=$channel sender=$sender agent=$agent_id"

  local formatted
  formatted="$(routing_format_reply "$channel" "$response")"

  printf '%s' "$formatted"
}
