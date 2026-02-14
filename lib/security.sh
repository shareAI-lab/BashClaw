#!/usr/bin/env bash
# Security module for bashclaw
# Audit logging, pairing codes, rate limiting, exec approval

# Append an audit event to the audit log (JSONL format)
security_audit_log() {
  local event="${1:?event required}"
  local details="${2:-}"

  require_command jq "security_audit_log requires jq"

  local log_dir="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/logs"
  ensure_dir "$log_dir"
  local audit_file="${log_dir}/audit.jsonl"
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  local line
  line="$(jq -nc \
    --arg ev "$event" \
    --arg dt "$details" \
    --arg ts "$now" \
    --arg pid "$$" \
    '{event: $ev, details: $dt, timestamp: $ts, pid: ($pid | tonumber)}')"

  printf '%s\n' "$line" >> "$audit_file"
}

# Generate a 6-digit pairing code for a channel+sender combination
# Saves the code with an expiry (default 5 minutes)
security_pairing_code_generate() {
  local channel="${1:?channel required}"
  local sender="${2:?sender required}"

  require_command jq "security_pairing_code_generate requires jq"

  local pair_dir="${BASHCLAW_STATE_DIR:?}/pairing"
  ensure_dir "$pair_dir"

  # Generate 6-digit numeric code
  local code
  code="$(printf '%06d' "$((RANDOM * RANDOM % 1000000))")"
  local now
  now="$(date +%s)"
  local expiry=$((now + 300))

  local safe_key
  safe_key="$(printf '%s_%s' "$channel" "$sender" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${pair_dir}/${safe_key}.json"

  jq -nc \
    --arg ch "$channel" \
    --arg snd "$sender" \
    --arg code "$code" \
    --argjson exp "$expiry" \
    --argjson ts "$now" \
    '{channel: $ch, sender: $snd, code: $code, expires_at: $exp, created_at: $ts}' \
    > "$file"

  chmod 600 "$file"
  security_audit_log "pairing_code_generated" "channel=$channel sender=$sender"

  printf '%s' "$code"
}

# Verify a pairing code for a channel+sender combination
# Returns 0 on success, 1 on failure
security_pairing_code_verify() {
  local channel="${1:?channel required}"
  local sender="${2:?sender required}"
  local code="${3:?code required}"

  require_command jq "security_pairing_code_verify requires jq"

  local pair_dir="${BASHCLAW_STATE_DIR:?}/pairing"
  local safe_key
  safe_key="$(printf '%s_%s' "$channel" "$sender" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${pair_dir}/${safe_key}.json"

  if [[ ! -f "$file" ]]; then
    security_audit_log "pairing_code_verify_failed" "channel=$channel sender=$sender reason=no_code"
    return 1
  fi

  local stored_code expiry
  stored_code="$(jq -r '.code // empty' < "$file")"
  expiry="$(jq -r '.expires_at // 0' < "$file")"

  local now
  now="$(date +%s)"

  # Check expiry
  if (( now > expiry )); then
    rm -f "$file"
    security_audit_log "pairing_code_verify_failed" "channel=$channel sender=$sender reason=expired"
    return 1
  fi

  # Check code match
  if [[ "$code" != "$stored_code" ]]; then
    security_audit_log "pairing_code_verify_failed" "channel=$channel sender=$sender reason=mismatch"
    return 1
  fi

  # Code is valid, remove it (single use)
  rm -f "$file"
  security_audit_log "pairing_code_verified" "channel=$channel sender=$sender"
  return 0
}

# Token bucket rate limiter using files
# Returns 0 if request is allowed, 1 if rate limited
security_rate_limit() {
  local sender="${1:?sender required}"
  local max_per_min="${2:-30}"

  local rl_dir="${BASHCLAW_STATE_DIR:?}/ratelimit"
  ensure_dir "$rl_dir"

  local safe_sender
  safe_sender="$(printf '%s' "$sender" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${rl_dir}/${safe_sender}.dat"

  local now
  now="$(date +%s)"
  local window_start=$((now - 60))

  # Read existing timestamps, filter to current window
  local count=0
  if [[ -f "$file" ]]; then
    local tmp
    tmp="$(mktemp -t bashclaw_rl.XXXXXX 2>/dev/null || mktemp /tmp/bashclaw_rl.XXXXXX)"
    while IFS= read -r ts; do
      if (( ts > window_start )); then
        printf '%s\n' "$ts" >> "$tmp"
        count=$((count + 1))
      fi
    done < "$file"
    mv "$tmp" "$file"
  fi

  if (( count >= max_per_min )); then
    security_audit_log "rate_limited" "sender=$sender count=$count max=$max_per_min"
    return 1
  fi

  # Record this request
  printf '%s\n' "$now" >> "$file"
  return 0
}

# Check if a command needs execution approval
# Returns "approved" for safe commands, "needs_approval" for dangerous ones
security_exec_approval() {
  local cmd="${1:?command required}"

  # Check against dangerous patterns
  case "$cmd" in
    *"rm -rf"*|*"mkfs"*|*"dd if="*|*"chmod -R 777 /"*|*":(){:"*)
      security_audit_log "exec_blocked" "command=$cmd"
      printf 'blocked'
      return 1
      ;;
    *sudo*|*"> /dev/"*|*"curl "*"|"*sh*|*"wget "*"|"*sh*)
      security_audit_log "exec_needs_approval" "command=$cmd"
      printf 'needs_approval'
      return 0
      ;;
    *)
      printf 'approved'
      return 0
      ;;
  esac
}
