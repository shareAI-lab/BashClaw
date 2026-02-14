#!/usr/bin/env bash
# Process/command queue module for bashclaw
# FIFO queue with concurrency control per agent

_QUEUE_DIR=""

# Initialize queue directory
_queue_dir() {
  if [[ -z "$_QUEUE_DIR" ]]; then
    _QUEUE_DIR="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/queue"
  fi
  ensure_dir "$_QUEUE_DIR"
  printf '%s' "$_QUEUE_DIR"
}

# Enqueue a command for an agent
# Creates a timestamped file in the queue directory for FIFO ordering
process_enqueue() {
  local agent_id="${1:?agent_id required}"
  local command="${2:?command required}"

  require_command jq "process_enqueue requires jq"

  local dir
  dir="$(_queue_dir)"
  local ts
  ts="$(timestamp_ms)"
  local id
  id="$(uuid_generate)"
  local safe_id
  safe_id="$(printf '%s' "${ts}_${id}" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${dir}/${safe_id}.json"
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  jq -nc \
    --arg id "$id" \
    --arg aid "$agent_id" \
    --arg cmd "$command" \
    --arg status "pending" \
    --arg ca "$now" \
    --argjson ts "$ts" \
    '{id: $id, agent_id: $aid, command: $cmd, status: $status, created_at: $ca, ts: $ts}' \
    > "$file"

  log_debug "Enqueued: id=$id agent=$agent_id"
  printf '%s' "$id"
}

# Dequeue the next pending item (oldest first by filename sort)
# Marks the item as "processing" and outputs it
process_dequeue() {
  require_command jq "process_dequeue requires jq"

  local dir
  dir="$(_queue_dir)"
  local f

  # Files are named with timestamp prefix, so sorted order = FIFO
  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue

    local status
    status="$(jq -r '.status // empty' < "$f" 2>/dev/null)"
    if [[ "$status" != "pending" ]]; then
      continue
    fi

    # Mark as processing
    local updated
    updated="$(jq '.status = "processing"' < "$f")"
    printf '%s\n' "$updated" > "$f"

    printf '%s' "$updated"
    return 0
  done

  return 1
}

# Background worker that continuously processes the queue
process_worker() {
  log_info "Queue worker starting..."

  while true; do
    local item
    item="$(process_dequeue 2>/dev/null)" || {
      sleep 2
      continue
    }

    local item_id agent_id command
    item_id="$(printf '%s' "$item" | jq -r '.id // empty')"
    agent_id="$(printf '%s' "$item" | jq -r '.agent_id // "main"')"
    command="$(printf '%s' "$item" | jq -r '.command // empty')"

    if [[ -z "$command" ]]; then
      log_warn "Queue item $item_id has no command, skipping"
      _queue_mark_done "$item_id" "error" "no command"
      continue
    fi

    # Check concurrency lane
    if ! process_lanes_check "$agent_id"; then
      log_debug "Agent $agent_id at max concurrency, re-queuing $item_id"
      _queue_mark_pending "$item_id"
      sleep 1
      continue
    fi

    log_info "Queue processing: id=$item_id agent=$agent_id"

    # Execute in subshell
    (
      _queue_lane_acquire "$agent_id"
      local result
      result="$(agent_run "$agent_id" "$command" "queue" "queue:${item_id}" 2>&1)" || true
      _queue_lane_release "$agent_id"
      _queue_mark_done "$item_id" "completed" "${result:0:500}"
    ) &

    sleep 0.5
  done
}

# Report queue status: depth, running count
process_status() {
  require_command jq "process_status requires jq"

  local dir
  dir="$(_queue_dir)"
  local pending=0
  local processing=0
  local completed=0
  local f

  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local status
    status="$(jq -r '.status // empty' < "$f" 2>/dev/null)"
    case "$status" in
      pending) pending=$((pending + 1)) ;;
      processing) processing=$((processing + 1)) ;;
      completed|error) completed=$((completed + 1)) ;;
    esac
  done

  jq -nc \
    --argjson p "$pending" \
    --argjson r "$processing" \
    --argjson c "$completed" \
    '{pending: $p, processing: $r, completed: $c}'
}

# Check if an agent has available concurrency lanes
# Returns 0 (true) if a lane is available, 1 (false) otherwise
process_lanes_check() {
  local agent_id="${1:?agent_id required}"

  local max_concurrent
  max_concurrent="$(config_agent_get "$agent_id" "maxConcurrent" "3")"

  local lane_dir="${BASHCLAW_STATE_DIR:?}/queue/lanes"
  ensure_dir "$lane_dir"

  local current=0
  local f
  for f in "${lane_dir}/${agent_id}"_*.lock; do
    [[ -f "$f" ]] || continue
    # Check if the PID in the lock file is still running
    local lock_pid
    lock_pid="$(cat "$f" 2>/dev/null)"
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
      current=$((current + 1))
    else
      rm -f "$f"
    fi
  done

  if (( current >= max_concurrent )); then
    return 1
  fi
  return 0
}

# Internal: acquire a lane lock for an agent
_queue_lane_acquire() {
  local agent_id="$1"
  local lane_dir="${BASHCLAW_STATE_DIR:?}/queue/lanes"
  ensure_dir "$lane_dir"
  printf '%s' "$$" > "${lane_dir}/${agent_id}_$$.lock"
}

# Internal: release a lane lock for an agent
_queue_lane_release() {
  local agent_id="$1"
  local lane_dir="${BASHCLAW_STATE_DIR:?}/queue/lanes"
  rm -f "${lane_dir}/${agent_id}_$$.lock"
}

# Internal: mark a queue item as done
_queue_mark_done() {
  local item_id="$1"
  local status="${2:-completed}"
  local detail="${3:-}"

  local dir
  dir="$(_queue_dir)"
  local f
  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local fid
    fid="$(jq -r '.id // empty' < "$f" 2>/dev/null)"
    if [[ "$fid" == "$item_id" ]]; then
      local updated
      updated="$(jq --arg s "$status" --arg d "$detail" \
        '.status = $s | .detail = $d | .completed_at = (now | todate)' < "$f")"
      printf '%s\n' "$updated" > "$f"
      return 0
    fi
  done
}

# Internal: re-mark a queue item as pending
_queue_mark_pending() {
  local item_id="$1"

  local dir
  dir="$(_queue_dir)"
  local f
  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local fid
    fid="$(jq -r '.id // empty' < "$f" 2>/dev/null)"
    if [[ "$fid" == "$item_id" ]]; then
      local updated
      updated="$(jq '.status = "pending"' < "$f")"
      printf '%s\n' "$updated" > "$f"
      return 0
    fi
  done
}
