#!/usr/bin/env bash
# Heartbeat system for bashclaw
# Periodic autonomous agent check-ins with active-hours gating.
# Compatible with bash 3.2+ (no declare -A, no declare -g, no mapfile)

DEFAULT_HEARTBEAT_INTERVAL=1800
HEARTBEAT_OK_TOKEN="HEARTBEAT_OK"
HEARTBEAT_OK_MAX_CHARS=300

# 6-step guard chain: determine if a heartbeat should run now
# Returns 0 if heartbeat should run, 1 otherwise
heartbeat_should_run() {
  local agent_id="${1:?agent_id required}"

  # Step 1: global heartbeat enabled
  local global_enabled
  global_enabled="$(config_get '.heartbeat.enabled' 'false')"
  if [[ "$global_enabled" != "true" ]]; then
    log_debug "heartbeat: globally disabled"
    return 1
  fi

  # Step 2: agent heartbeat config exists
  local agent_hb_enabled
  agent_hb_enabled="$(config_agent_get "$agent_id" "heartbeat.enabled" "")"
  # If agent-level config is explicitly false, skip
  if [[ "$agent_hb_enabled" == "false" ]]; then
    log_debug "heartbeat: disabled for agent $agent_id"
    return 1
  fi

  # Step 3: interval is valid (> 0)
  local interval
  interval="$(_heartbeat_interval "$agent_id")"
  if (( interval <= 0 )); then
    log_debug "heartbeat: invalid interval for agent $agent_id"
    return 1
  fi

  # Step 4: within active hours
  if ! heartbeat_in_active_hours "$agent_id"; then
    log_debug "heartbeat: outside active hours for agent $agent_id"
    return 1
  fi

  # Step 5: no active processing (check for active lane locks)
  local lane_dir="${BASHCLAW_STATE_DIR:?}/queue/lanes"
  if [[ -d "$lane_dir" ]]; then
    local f
    for f in "${lane_dir}/${agent_id}"_*.lock; do
      [[ -f "$f" ]] || continue
      local lock_pid
      lock_pid="$(cat "$f" 2>/dev/null)"
      if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
        log_debug "heartbeat: agent $agent_id is busy (active lane lock)"
        return 1
      fi
    done
  fi

  # Step 6: HEARTBEAT.md has actual content
  local hb_file="${BASHCLAW_STATE_DIR:?}/agents/${agent_id}/HEARTBEAT.md"
  if [[ ! -f "$hb_file" ]]; then
    log_debug "heartbeat: no HEARTBEAT.md for agent $agent_id"
    return 1
  fi
  # Check for non-empty content (ignore whitespace and empty markdown headers)
  local content
  content="$(sed '/^[[:space:]]*$/d; /^#*[[:space:]]*$/d' "$hb_file" 2>/dev/null)"
  if [[ -z "$content" ]]; then
    log_debug "heartbeat: HEARTBEAT.md is empty for agent $agent_id"
    return 1
  fi

  # Check last heartbeat time against interval
  local last_run_file="${BASHCLAW_STATE_DIR:?}/heartbeat/${agent_id}.last"
  if [[ -f "$last_run_file" ]]; then
    local last_ts now_s diff_s
    last_ts="$(cat "$last_run_file" 2>/dev/null)"
    now_s="$(timestamp_s)"
    diff_s=$((now_s - last_ts))
    if (( diff_s < interval )); then
      log_debug "heartbeat: too soon for agent $agent_id (${diff_s}s < ${interval}s)"
      return 1
    fi
  fi

  return 0
}

# Check if current time is within agent's active hours.
# Supports cross-midnight windows (e.g., 22:00-06:00).
heartbeat_in_active_hours() {
  local agent_id="${1:?agent_id required}"

  local start_str end_str tz
  start_str="$(config_agent_get "$agent_id" "heartbeat.activeHours.start" "00:00")"
  end_str="$(config_agent_get "$agent_id" "heartbeat.activeHours.end" "23:59")"
  tz="$(config_agent_get "$agent_id" "heartbeat.timezone" "local")"

  # Parse HH:MM to minutes since midnight
  local start_min end_min
  start_min="$(_heartbeat_hhmm_to_min "$start_str")"
  end_min="$(_heartbeat_hhmm_to_min "$end_str")"

  # Get current time in specified timezone
  local current_min
  if [[ "$tz" == "local" || -z "$tz" ]]; then
    current_min="$(date '+%H * 60 + %M' | bc 2>/dev/null || _heartbeat_current_min_fallback)"
  else
    current_min="$(TZ="$tz" date '+%H * 60 + %M' | bc 2>/dev/null || TZ="$tz" _heartbeat_current_min_fallback)"
  fi

  if (( start_min <= end_min )); then
    # Normal window (e.g., 08:00-22:00)
    if (( current_min >= start_min && current_min <= end_min )); then
      return 0
    fi
  else
    # Cross-midnight window (e.g., 22:00-06:00)
    if (( current_min >= start_min || current_min <= end_min )); then
      return 0
    fi
  fi

  return 1
}

# Run a heartbeat for an agent
heartbeat_run() {
  local agent_id="${1:?agent_id required}"
  local reason="${2:-default}"

  log_info "heartbeat: running for agent $agent_id (reason=$reason)"

  # Record heartbeat time
  local hb_dir="${BASHCLAW_STATE_DIR:?}/heartbeat"
  ensure_dir "$hb_dir"
  timestamp_s > "${hb_dir}/${agent_id}.last"

  # Save session updatedAt before heartbeat so we can restore it
  local sess_file
  sess_file="$(session_file "$agent_id" "heartbeat" "system")"

  # Build prompt
  local prompt
  prompt="$(heartbeat_build_prompt "$reason")"

  # Run agent turn
  local result
  result="$(agent_run "$agent_id" "$prompt" "heartbeat" "system" 2>&1)" || true

  # Process result
  local outcome
  outcome="$(heartbeat_process_result "$result")"

  case "$outcome" in
    ok-token|ok-empty)
      log_debug "heartbeat: agent $agent_id replied $outcome"
      ;;
    has-content)
      # Dedup check
      if heartbeat_dedup "$result" "$agent_id"; then
        log_debug "heartbeat: dedup skipped for agent $agent_id"
        return 0
      fi

      # Deliver heartbeat result as event to main session
      local session_key
      session_key="$(session_key "$agent_id" "default" "")"
      events_enqueue "$session_key" "Heartbeat: ${result}" "heartbeat"

      local show_alerts
      show_alerts="$(config_agent_get "$agent_id" "heartbeat.showAlerts" "true")"
      if [[ "$show_alerts" == "true" ]]; then
        log_info "heartbeat [$agent_id]: $result"
      fi
      ;;
  esac

  # Restore session updatedAt
  heartbeat_restore_updated_at "$sess_file"
}

# Process heartbeat result text.
# Returns: "ok-token" if HEARTBEAT_OK detected, "ok-empty" if response is trivially short,
# "has-content" if there is meaningful content.
heartbeat_process_result() {
  local text="$1"

  if [[ -z "$text" ]]; then
    printf 'ok-empty'
    return 0
  fi

  # Strip common wrappers (HTML tags, markdown formatting, whitespace)
  local stripped
  stripped="$(printf '%s' "$text" | sed 's/<[^>]*>//g' | sed 's/[*\`#]//g')"
  stripped="$(trim "$stripped")"

  # Check for HEARTBEAT_OK token
  case "$stripped" in
    *"$HEARTBEAT_OK_TOKEN"*)
      printf 'ok-token'
      return 0
      ;;
  esac

  # Check if response is trivially short
  if [ "${#stripped}" -le "$HEARTBEAT_OK_MAX_CHARS" ]; then
    # Heuristic: very short responses with no actionable content
    case "$stripped" in
      ""|"OK"|"ok"|"Ok"|"Nothing to report"|"nothing to report"|"All clear"|"all clear")
        printf 'ok-empty'
        return 0
        ;;
    esac
  fi

  printf 'has-content'
}

# Deduplicate heartbeat text: skip if same text was produced within 24 hours.
# Returns 0 if duplicate (should skip), 1 if unique.
heartbeat_dedup() {
  local text="${1:?text required}"
  local agent_id="${2:?agent_id required}"

  local dedup_dir="${BASHCLAW_STATE_DIR:?}/heartbeat/dedup"
  ensure_dir "$dedup_dir"

  local text_hash
  text_hash="$(hash_string "$text")"
  local dedup_file="${dedup_dir}/${agent_id}.last"

  if [[ -f "$dedup_file" ]]; then
    local stored_hash stored_ts now_s diff_s
    stored_hash="$(head -n 1 "$dedup_file" 2>/dev/null)"
    stored_ts="$(tail -n 1 "$dedup_file" 2>/dev/null)"
    now_s="$(timestamp_s)"
    diff_s=$((now_s - stored_ts))

    # 24 hours = 86400 seconds
    if [[ "$stored_hash" == "$text_hash" ]] && (( diff_s < 86400 )); then
      return 0
    fi
  fi

  # Store current hash and timestamp
  printf '%s\n%s\n' "$text_hash" "$(timestamp_s)" > "$dedup_file"
  return 1
}

# Background heartbeat loop for an agent.
# Runs continuously, checking and executing heartbeats at the configured interval.
heartbeat_loop() {
  local agent_id="${1:?agent_id required}"

  log_info "heartbeat_loop: starting for agent $agent_id"

  while true; do
    local interval
    interval="$(_heartbeat_interval "$agent_id")"
    if (( interval <= 0 )); then
      interval=$DEFAULT_HEARTBEAT_INTERVAL
    fi

    sleep "$interval"

    if heartbeat_should_run "$agent_id"; then
      heartbeat_run "$agent_id" "default"
    fi
  done
}

# Restore session updatedAt to pre-heartbeat value.
# Heartbeat should not extend session lifetime for idle-reset purposes.
heartbeat_restore_updated_at() {
  local session_file="$1"

  if [[ -z "$session_file" || ! -f "$session_file" ]]; then
    return 0
  fi

  local meta_file="${session_file%.jsonl}.meta.json"
  if [[ ! -f "$meta_file" ]]; then
    return 0
  fi

  local saved_ts_file="${BASHCLAW_STATE_DIR:?}/heartbeat/_saved_updated_at"
  if [[ -f "$saved_ts_file" ]]; then
    local saved_ts
    saved_ts="$(cat "$saved_ts_file")"
    if [[ -n "$saved_ts" ]]; then
      require_command jq "heartbeat_restore_updated_at requires jq"
      local updated
      updated="$(jq --arg ts "$saved_ts" '.updatedAt = $ts' < "$meta_file")"
      printf '%s\n' "$updated" > "$meta_file"
    fi
    rm -f "$saved_ts_file"
  fi
}

# Build the heartbeat prompt based on the reason.
# Three variants: default, exec-event, cron-event
heartbeat_build_prompt() {
  local reason="${1:-default}"

  case "$reason" in
    exec-event)
      printf '%s' "An async command you ran earlier has completed. Check the system events for details. If you need to take action based on the result, do so. If nothing needs attention, reply with $HEARTBEAT_OK_TOKEN."
      ;;
    cron-event)
      printf '%s' "A scheduled reminder has been triggered. Check the system events for the reminder details. Follow the instructions in the reminder. If nothing needs attention, reply with $HEARTBEAT_OK_TOKEN."
      ;;
    *)
      printf '%s' "Read HEARTBEAT.md if it exists. Follow it strictly. If nothing needs attention, reply with $HEARTBEAT_OK_TOKEN."
      ;;
  esac
}

# -- Internal helpers --

# Parse interval config and return seconds
_heartbeat_interval() {
  local agent_id="$1"

  local interval_str
  interval_str="$(config_agent_get "$agent_id" "heartbeat.interval" "30m")"

  # If purely numeric, treat as seconds
  if [[ "$interval_str" =~ ^[0-9]+$ ]]; then
    printf '%s' "$interval_str"
    return
  fi

  # Parse duration string (e.g., "30m", "1h", "90s")
  local num unit
  num="$(printf '%s' "$interval_str" | sed 's/[^0-9]//g')"
  unit="$(printf '%s' "$interval_str" | sed 's/[0-9]//g')"

  if [[ -z "$num" ]]; then
    printf '%s' "$DEFAULT_HEARTBEAT_INTERVAL"
    return
  fi

  case "$unit" in
    s) printf '%s' "$num" ;;
    m) printf '%s' "$((num * 60))" ;;
    h) printf '%s' "$((num * 3600))" ;;
    *)  printf '%s' "$num" ;;
  esac
}

# Convert HH:MM to minutes since midnight
_heartbeat_hhmm_to_min() {
  local hhmm="$1"
  local hh mm

  hh="$(printf '%s' "$hhmm" | cut -d: -f1 | sed 's/^0//')"
  mm="$(printf '%s' "$hhmm" | cut -d: -f2 | sed 's/^0//')"

  hh="${hh:-0}"
  mm="${mm:-0}"

  printf '%s' "$(( hh * 60 + mm ))"
}

# Fallback for getting current minutes since midnight without bc
_heartbeat_current_min_fallback() {
  local hh mm
  hh="$(date '+%H' | sed 's/^0//')"
  mm="$(date '+%M' | sed 's/^0//')"
  hh="${hh:-0}"
  mm="${mm:-0}"
  printf '%s' "$(( hh * 60 + mm ))"
}
