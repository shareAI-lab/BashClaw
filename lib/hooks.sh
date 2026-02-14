#!/usr/bin/env bash
# Hook/middleware system for bashclaw
# Supports event-driven hook registration and execution

# Hook events
# pre_message - before message is processed
# post_message - after message is processed
# pre_tool - before tool execution
# post_tool - after tool execution
# on_error - when an error occurs
# on_session_reset - when a session is reset

_HOOKS_DIR=""

# Initialize hooks directory
_hooks_dir() {
  if [[ -z "$_HOOKS_DIR" ]]; then
    _HOOKS_DIR="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/hooks"
  fi
  ensure_dir "$_HOOKS_DIR"
  printf '%s' "$_HOOKS_DIR"
}

# Register a hook for an event
# Usage: hooks_register NAME EVENT SCRIPT_PATH
hooks_register() {
  local name="${1:?name required}"
  local event="${2:?event required}"
  local script_path="${3:?script_path required}"

  require_command jq "hooks_register requires jq"

  if [[ ! -f "$script_path" ]]; then
    log_error "Hook script not found: $script_path"
    return 1
  fi

  # Validate event name
  case "$event" in
    pre_message|post_message|pre_tool|post_tool|on_error|on_session_reset)
      ;;
    *)
      log_error "Invalid hook event: $event"
      return 1
      ;;
  esac

  local dir
  dir="$(_hooks_dir)"
  local safe_name
  safe_name="$(printf '%s' "$name" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${dir}/${safe_name}.json"
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  jq -nc \
    --arg name "$name" \
    --arg event "$event" \
    --arg script "$script_path" \
    --arg ca "$now" \
    '{name: $name, event: $event, script: $script, enabled: true, created_at: $ca}' \
    > "$file"

  chmod 600 "$file"
  log_info "Hook registered: name=$name event=$event"
}

# Run all enabled hooks matching an event, piping JSON through each script
# Usage: hooks_run EVENT INPUT_JSON
hooks_run() {
  local event="${1:?event required}"
  local input_json="${2:-{\}}"

  local dir
  dir="$(_hooks_dir)"
  local current="$input_json"
  local f

  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue

    local hook_event hook_enabled hook_script
    hook_event="$(jq -r '.event // empty' < "$f" 2>/dev/null)"
    hook_enabled="$(jq -r '.enabled // false' < "$f" 2>/dev/null)"
    hook_script="$(jq -r '.script // empty' < "$f" 2>/dev/null)"

    if [[ "$hook_event" != "$event" ]]; then
      continue
    fi

    if [[ "$hook_enabled" != "true" ]]; then
      continue
    fi

    if [[ ! -x "$hook_script" && ! -f "$hook_script" ]]; then
      log_warn "Hook script missing: $hook_script"
      continue
    fi

    log_debug "Running hook: $(jq -r '.name // "unknown"' < "$f") for event=$event"

    local result
    result="$(printf '%s' "$current" | bash "$hook_script" 2>/dev/null)" || {
      log_warn "Hook script failed: $hook_script"
      continue
    }

    if [[ -n "$result" ]]; then
      current="$result"
    fi
  done

  printf '%s' "$current"
}

# Scan a directory for *.sh hook scripts and register them
# Files should contain a comment header: # hook:EVENT_NAME
hooks_load_dir() {
  local search_dir="${1:?directory required}"

  if [[ ! -d "$search_dir" ]]; then
    log_warn "Hooks directory not found: $search_dir"
    return 1
  fi

  local f count=0
  for f in "${search_dir}"/*.sh; do
    [[ -f "$f" ]] || continue

    # Extract event from comment header
    local event_line
    event_line="$(grep -m1 '^# hook:' "$f" 2>/dev/null || true)"
    if [[ -z "$event_line" ]]; then
      continue
    fi

    local event="${event_line#\# hook:}"
    event="$(printf '%s' "$event" | tr -d '[:space:]')"
    local name
    name="$(basename "$f" .sh)"

    hooks_register "$name" "$event" "$f" && count=$((count + 1))
  done

  log_info "Loaded $count hooks from $search_dir"
}

# List all registered hooks with their status
hooks_list() {
  require_command jq "hooks_list requires jq"

  local dir
  dir="$(_hooks_dir)"
  local result="[]"
  local f

  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local entry
    entry="$(cat "$f")"
    result="$(printf '%s' "$result" | jq --argjson e "$entry" '. + [$e]')"
  done

  printf '%s' "$result"
}

# Enable a hook by name
hooks_enable() {
  local name="${1:?name required}"

  require_command jq "hooks_enable requires jq"

  local dir
  dir="$(_hooks_dir)"
  local safe_name
  safe_name="$(printf '%s' "$name" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${dir}/${safe_name}.json"

  if [[ ! -f "$file" ]]; then
    log_error "Hook not found: $name"
    return 1
  fi

  local updated
  updated="$(jq '.enabled = true' < "$file")"
  printf '%s\n' "$updated" > "$file"
  log_info "Hook enabled: $name"
}

# Disable a hook by name
hooks_disable() {
  local name="${1:?name required}"

  require_command jq "hooks_disable requires jq"

  local dir
  dir="$(_hooks_dir)"
  local safe_name
  safe_name="$(printf '%s' "$name" | tr -c '[:alnum:]._-' '_' | head -c 200)"
  local file="${dir}/${safe_name}.json"

  if [[ ! -f "$file" ]]; then
    log_error "Hook not found: $name"
    return 1
  fi

  local updated
  updated="$(jq '.enabled = false' < "$file")"
  printf '%s\n' "$updated" > "$file"
  log_info "Hook disabled: $name"
}
