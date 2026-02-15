#!/usr/bin/env bash
# Configuration management for bashclaw (jq-based)
# Extended with heartbeat, dmScope, tools policy, channel policies (Gaps 12.1, 12.2)

_CONFIG_CACHE=""
_CONFIG_PATH=""

config_path() {
  if [[ -n "${BASHCLAW_CONFIG:-}" ]]; then
    printf '%s' "$BASHCLAW_CONFIG"
    return
  fi
  printf '%s/bashclaw.json' "${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}"
}

config_set_path() {
  _CONFIG_PATH="$1"
}

config_load() {
  local path
  path="$(_config_resolve_path)"
  if [[ ! -f "$path" ]]; then
    _CONFIG_CACHE="{}"
    return 0
  fi
  _CONFIG_CACHE="$(cat "$path")"
  if ! printf '%s' "$_CONFIG_CACHE" | jq empty 2>/dev/null; then
    log_error "Invalid JSON in config: $path"
    _CONFIG_CACHE="{}"
    return 1
  fi
}

config_env_substitute() {
  local input="$1"
  local result="$input"
  local var_pattern='\$\{([A-Za-z_][A-Za-z_0-9]*)\}'
  while [[ "$result" =~ $var_pattern ]]; do
    local var_name="${BASH_REMATCH[1]}"
    local var_value="${!var_name:-}"
    result="${result/\$\{${var_name}\}/${var_value}}"
  done
  printf '%s' "$result"
}

config_get() {
  local filter="$1"
  local default="${2:-}"
  _config_ensure_loaded
  local value
  value="$(printf '%s' "$_CONFIG_CACHE" | jq -r "$filter // empty" 2>/dev/null)"
  if [[ -z "$value" ]]; then
    printf '%s' "$default"
  else
    printf '%s' "$(config_env_substitute "$value")"
  fi
}

config_get_raw() {
  local filter="$1"
  _config_ensure_loaded
  printf '%s' "$_CONFIG_CACHE" | jq "$filter" 2>/dev/null
}

config_set() {
  local filter="$1"
  local value="$2"
  _config_ensure_loaded
  local path
  path="$(_config_resolve_path)"
  _CONFIG_CACHE="$(printf '%s' "$_CONFIG_CACHE" | jq "$filter = $value")"
  ensure_dir "$(dirname "$path")"
  printf '%s\n' "$_CONFIG_CACHE" > "$path"
  chmod 600 "$path"
}

config_validate() {
  local path
  path="$(_config_resolve_path)"
  if [[ ! -f "$path" ]]; then
    log_warn "Config file not found: $path"
    return 1
  fi

  local content
  content="$(cat "$path")"
  if ! printf '%s' "$content" | jq empty 2>/dev/null; then
    log_error "Config is not valid JSON: $path"
    return 1
  fi

  local port
  port="$(printf '%s' "$content" | jq -r '.gateway.port // empty' 2>/dev/null)"
  if [[ -n "$port" ]]; then
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
      log_error "Invalid gateway port: $port (must be 1-65535)"
      return 1
    fi
  fi

  local agents_type
  agents_type="$(printf '%s' "$content" | jq -r '.agents | type' 2>/dev/null)"
  if [[ "$agents_type" == "object" ]]; then
    local list_type
    list_type="$(printf '%s' "$content" | jq -r '.agents.list | type' 2>/dev/null)"
    if [[ "$list_type" != "null" && "$list_type" != "array" ]]; then
      log_error "agents.list must be an array"
      return 1
    fi
  fi

  local channels_type
  channels_type="$(printf '%s' "$content" | jq -r '.channels | type' 2>/dev/null)"
  if [[ "$channels_type" != "null" && "$channels_type" != "object" ]]; then
    log_error "channels must be an object"
    return 1
  fi

  log_debug "Config validation passed: $path"
  return 0
}

config_init_default() {
  local path
  path="$(_config_resolve_path)"
  if [[ -f "$path" ]]; then
    log_warn "Config already exists: $path"
    return 1
  fi

  local model="${MODEL_ID:-claude-sonnet-4-20250514}"
  ensure_dir "$(dirname "$path")"

  cat > "$path" <<ENDJSON
{
  "agents": {
    "defaultId": "main",
    "defaults": {
      "model": "${model}",
      "maxTurns": 50,
      "contextTokens": 200000,
      "dmScope": "per-channel-peer",
      "queueMode": "followup",
      "queueDebounceMs": 0,
      "fallbackModels": [],
      "tools": {
        "allow": [],
        "deny": []
      },
      "heartbeat": {
        "enabled": false,
        "interval": "30m",
        "activeHours": {
          "start": "08:00",
          "end": "22:00"
        },
        "timezone": "local",
        "showAlerts": true
      }
    },
    "list": []
  },
  "channels": {
    "defaults": {
      "dmPolicy": {
        "policy": "open",
        "allowFrom": []
      },
      "groupPolicy": {
        "policy": "open"
      },
      "debounceMs": 0,
      "threadAware": false,
      "capabilities": {
        "polls": false,
        "reactions": false,
        "edit": false
      },
      "outbound": {
        "textChunkLimit": 4096
      }
    }
  },
  "bindings": [],
  "identityLinks": [],
  "gateway": {
    "port": 18789,
    "auth": {}
  },
  "session": {
    "dmScope": "per-channel-peer",
    "idleResetMinutes": 30,
    "maxHistory": 200
  },
  "security": {
    "elevatedUsers": [],
    "commands": {},
    "userRoles": {}
  },
  "meta": {
    "lastTouchedVersion": "${BASHCLAW_VERSION:-1.0.0}",
    "lastTouchedAt": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  }
}
ENDJSON

  chmod 600 "$path"
  log_info "Created default config: $path"
}

config_backup() {
  local path
  path="$(_config_resolve_path)"
  if [[ ! -f "$path" ]]; then
    return 0
  fi

  local dir
  dir="$(dirname "$path")"
  local base
  base="$(basename "$path")"

  local i
  for i in 4 3 2 1; do
    local src="${dir}/${base}.bak.${i}"
    local dst="${dir}/${base}.bak.$((i + 1))"
    [[ -f "$src" ]] && mv "$src" "$dst"
  done

  cp "$path" "${dir}/${base}.bak.1"
  log_debug "Config backup created"
}

config_agent_get() {
  local agent_id="$1"
  local field="$2"
  local default="${3:-}"
  _config_ensure_loaded

  local value
  value="$(printf '%s' "$_CONFIG_CACHE" | jq -r \
    --arg id "$agent_id" --arg f "$field" \
    '(.agents.list // [] | map(select(.id == $id)) | .[0] | .[$f] // empty) // (.agents.defaults[$f] // empty)' \
    2>/dev/null)"

  if [[ -z "$value" ]]; then
    printf '%s' "$default"
  else
    printf '%s' "$(config_env_substitute "$value")"
  fi
}

# Get a nested agent config field using a jq path expression
config_agent_get_raw() {
  local agent_id="$1"
  local jq_path="$2"
  _config_ensure_loaded

  local value
  value="$(printf '%s' "$_CONFIG_CACHE" | jq -r \
    --arg id "$agent_id" \
    "(.agents.list // [] | map(select(.id == \$id)) | .[0] | ${jq_path} // null) // (.agents.defaults | ${jq_path} // null)" \
    2>/dev/null)"

  printf '%s' "$value"
}

config_channel_get() {
  local channel_id="$1"
  local field="$2"
  local default="${3:-}"
  _config_ensure_loaded

  local value
  value="$(printf '%s' "$_CONFIG_CACHE" | jq -r \
    --arg ch "$channel_id" --arg f "$field" \
    '.channels[$ch][$f] // .channels.defaults[$f] // empty' \
    2>/dev/null)"

  if [[ -z "$value" ]]; then
    printf '%s' "$default"
  else
    printf '%s' "$(config_env_substitute "$value")"
  fi
}

# Get raw channel config (for nested objects)
config_channel_get_raw() {
  local channel_id="$1"
  local jq_path="$2"
  _config_ensure_loaded

  local value
  value="$(printf '%s' "$_CONFIG_CACHE" | jq \
    --arg ch "$channel_id" \
    ".channels[\$ch] | ${jq_path} // (.channels.defaults | ${jq_path} // null)" \
    2>/dev/null)"

  printf '%s' "$value"
}

config_reload() {
  _CONFIG_CACHE=""
  config_load
}

# -- internal helpers --

_config_resolve_path() {
  if [[ -n "$_CONFIG_PATH" ]]; then
    printf '%s' "$_CONFIG_PATH"
  else
    config_path
  fi
}

_config_ensure_loaded() {
  if [[ -z "$_CONFIG_CACHE" ]]; then
    config_load
  fi
}
