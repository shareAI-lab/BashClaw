#!/usr/bin/env bash
# Tool system for bashclaw
# Compatible with bash 3.2+ (no associative arrays)

TOOL_WEB_FETCH_MAX_CHARS="${TOOL_WEB_FETCH_MAX_CHARS:-102400}"
TOOL_SHELL_TIMEOUT="${TOOL_SHELL_TIMEOUT:-30}"

# ---- Tool Registry (function-based for bash 3.2 compat) ----

_tool_handler() {
  case "$1" in
    web_fetch)      echo "tool_web_fetch" ;;
    web_search)     echo "tool_web_search" ;;
    shell)          echo "tool_shell" ;;
    memory)         echo "tool_memory" ;;
    cron)           echo "tool_cron" ;;
    message)        echo "tool_message" ;;
    agents_list)    echo "tool_agents_list" ;;
    session_status) echo "tool_session_status" ;;
    sessions_list)  echo "tool_sessions_list" ;;
    agent_message)  echo "tool_agent_message" ;;
    *)              echo "" ;;
  esac
}

_tool_list() {
  echo "web_fetch web_search shell memory cron message agents_list session_status sessions_list agent_message"
}

# ---- SSRF private IP patterns ----

_ssrf_is_private_pattern() {
  local addr="$1"
  case "$addr" in
    10.*)            return 0 ;;
    172.1[6-9].*)    return 0 ;;
    172.2[0-9].*)    return 0 ;;
    172.3[01].*)     return 0 ;;
    192.168.*)       return 0 ;;
    127.*)           return 0 ;;
    0.*)             return 0 ;;
    169.254.*)       return 0 ;;
    localhost)       return 0 ;;
    metadata.google.internal) return 0 ;;
    ::1)             return 0 ;;
    fe80:*)          return 0 ;;
    fc*)             return 0 ;;
    fd*)             return 0 ;;
    *)               return 1 ;;
  esac
}

# ---- Dangerous shell patterns ----

_shell_is_dangerous() {
  local cmd="$1"
  case "$cmd" in
    *"rm -rf /"*)       return 0 ;;
    *"rm -rf /*"*)      return 0 ;;
    *"mkfs"*)           return 0 ;;
    *"dd if="*)         return 0 ;;
    *"> /dev/sd"*)      return 0 ;;
    *"chmod -R 777 /"*) return 0 ;;
    *":(){:|:&};:"*)    return 0 ;;
    *)                  return 1 ;;
  esac
}

# ---- Tool Dispatch ----

tool_execute() {
  local tool_name="$1"
  local tool_input="$2"

  local handler
  handler="$(_tool_handler "$tool_name")"
  if [[ -z "$handler" ]]; then
    log_error "Unknown tool: $tool_name"
    printf '{"error": "unknown tool: %s"}' "$tool_name"
    return 1
  fi

  log_debug "Executing tool: $tool_name"
  "$handler" "$tool_input"
}

# ---- Tool Descriptions ----

tools_describe_all() {
  cat <<'TOOLDESC'
Available tools:

1. web_fetch - Fetch and extract readable content from a URL.
   Parameters: url (string, required), maxChars (number, optional)

2. web_search - Search the web using Brave Search or Perplexity.
   Parameters: query (string, required), count (number, optional, 1-10)

3. shell - Execute a shell command with timeout and safety checks.
   Parameters: command (string, required), timeout (number, optional)

4. memory - File-based key-value store for persistent memory.
   Parameters: action (get|set|delete|list|search, required), key (string), value (string), query (string)

5. cron - Manage scheduled jobs.
   Parameters: action (add|remove|list, required), id (string), schedule (string), command (string)

6. message - Send a message via the configured channel handler.
   Parameters: action (send, required), channel (string), target (string), message (string, required)

7. agents_list - List all configured agents with their settings.
   Parameters: none

8. session_status - Query session info for the current agent.
   Parameters: agent_id (string), channel (string), sender (string)

9. sessions_list - List all active sessions across all agents.
   Parameters: none

10. agent_message - Send a message to another agent.
    Parameters: target_agent (string, required), message (string, required), from_agent (string, optional)
TOOLDESC
}

# ---- Tool Spec Builder (Anthropic format) ----

tools_build_spec() {
  require_command jq "tools_build_spec requires jq"

  local specs="[]"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "web_fetch",
    "description": "Fetch and extract readable content from a URL. Use for lightweight page access.",
    "input_schema": {
      "type": "object",
      "properties": {
        "url": {"type": "string", "description": "HTTP or HTTPS URL to fetch."},
        "maxChars": {"type": "number", "description": "Maximum characters to return."}
      },
      "required": ["url"]
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "web_search",
    "description": "Search the web. Returns titles, URLs, and snippets.",
    "input_schema": {
      "type": "object",
      "properties": {
        "query": {"type": "string", "description": "Search query string."},
        "count": {"type": "number", "description": "Number of results to return (1-10)."}
      },
      "required": ["query"]
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "shell",
    "description": "Execute a shell command with timeout and safety checks.",
    "input_schema": {
      "type": "object",
      "properties": {
        "command": {"type": "string", "description": "The shell command to execute."},
        "timeout": {"type": "number", "description": "Timeout in seconds (default 30)."}
      },
      "required": ["command"]
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "memory",
    "description": "File-based key-value store for persistent agent memory. Supports get, set, delete, list, and search actions.",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {"type": "string", "enum": ["get", "set", "delete", "list", "search"], "description": "The memory operation to perform."},
        "key": {"type": "string", "description": "The key to get, set, or delete."},
        "value": {"type": "string", "description": "The value to store (for set action)."},
        "query": {"type": "string", "description": "Search query (for search action)."}
      },
      "required": ["action"]
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "cron",
    "description": "Manage scheduled cron jobs. Supports add, remove, and list actions.",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {"type": "string", "enum": ["add", "remove", "list"], "description": "The cron operation to perform."},
        "id": {"type": "string", "description": "Job ID (for remove)."},
        "schedule": {"type": "string", "description": "Cron schedule expression (for add)."},
        "command": {"type": "string", "description": "Command to execute (for add)."},
        "agent_id": {"type": "string", "description": "Agent ID for the job."}
      },
      "required": ["action"]
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "message",
    "description": "Send a message via channel handler.",
    "input_schema": {
      "type": "object",
      "properties": {
        "action": {"type": "string", "enum": ["send"], "description": "Message action."},
        "channel": {"type": "string", "description": "Target channel (telegram, discord, slack, etc)."},
        "target": {"type": "string", "description": "Target chat/user ID."},
        "message": {"type": "string", "description": "The message text to send."}
      },
      "required": ["action", "message"]
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "agents_list",
    "description": "List all configured agents with their settings.",
    "input_schema": {
      "type": "object",
      "properties": {},
      "required": []
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "session_status",
    "description": "Query session info for a specific agent, channel, and sender.",
    "input_schema": {
      "type": "object",
      "properties": {
        "agent_id": {"type": "string", "description": "Agent ID to query."},
        "channel": {"type": "string", "description": "Channel name."},
        "sender": {"type": "string", "description": "Sender identifier."}
      },
      "required": []
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "sessions_list",
    "description": "List all active sessions across all agents.",
    "input_schema": {
      "type": "object",
      "properties": {},
      "required": []
    }
  }]')"

  specs="$(printf '%s' "$specs" | jq '. + [{
    "name": "agent_message",
    "description": "Send a message to another agent and get their response.",
    "input_schema": {
      "type": "object",
      "properties": {
        "target_agent": {"type": "string", "description": "The agent ID to send the message to."},
        "message": {"type": "string", "description": "The message to send."},
        "from_agent": {"type": "string", "description": "The sending agent ID (optional)."}
      },
      "required": ["target_agent", "message"]
    }
  }]')"

  printf '%s' "$specs"
}

# ---- Tool: web_fetch ----

tool_web_fetch() {
  local input="$1"
  require_command curl "web_fetch requires curl"
  require_command jq "web_fetch requires jq"

  local url max_chars
  url="$(printf '%s' "$input" | jq -r '.url // empty')"
  max_chars="$(printf '%s' "$input" | jq -r '.maxChars // empty')"
  max_chars="${max_chars:-$TOOL_WEB_FETCH_MAX_CHARS}"

  if [[ -z "$url" ]]; then
    printf '{"error": "url parameter is required"}'
    return 1
  fi

  if [[ "$url" != http://* && "$url" != https://* ]]; then
    printf '{"error": "URL must use http or https protocol"}'
    return 1
  fi

  # SSRF protection: extract hostname
  local hostname
  hostname="$(printf '%s' "$url" | sed -E 's|^https?://||' | sed -E 's|[:/].*||' | tr '[:upper:]' '[:lower:]')"

  if _ssrf_is_blocked "$hostname"; then
    printf '{"error": "SSRF blocked: request to private/internal address denied"}'
    return 1
  fi

  local response_file
  response_file="$(tmpfile "web_fetch")"

  local http_code
  http_code="$(curl -sS -L --max-redirs 5 --max-time 30 \
    -o "$response_file" -w '%{http_code}' \
    -H 'Accept: text/markdown, text/html;q=0.9, */*;q=0.1' \
    -H 'User-Agent: Mozilla/5.0 (compatible; bashclaw/1.0)' \
    "$url" 2>/dev/null)" || {
    printf '{"error": "fetch failed", "url": "%s"}' "$url"
    return 1
  }

  if [[ "$http_code" -ge 400 ]]; then
    local error_body
    error_body="$(head -c 4000 "$response_file" 2>/dev/null || true)"
    jq -nc --arg url "$url" --arg code "$http_code" --arg body "$error_body" \
      '{error: "HTTP error", status: ($code | tonumber), url: $url, detail: $body}'
    return 1
  fi

  local body
  body="$(head -c "$max_chars" "$response_file" 2>/dev/null || true)"
  local body_len
  body_len="$(file_size_bytes "$response_file")"
  local truncated="false"
  if [ "$body_len" -gt "$max_chars" ]; then
    truncated="true"
  fi

  jq -nc \
    --arg url "$url" \
    --arg status "$http_code" \
    --arg text "$body" \
    --arg trunc "$truncated" \
    --arg len "$body_len" \
    '{url: $url, status: ($status | tonumber), text: $text, truncated: ($trunc == "true"), length: ($len | tonumber)}'
}

# ---- Tool: web_search ----

tool_web_search() {
  local input="$1"
  require_command curl "web_search requires curl"
  require_command jq "web_search requires jq"

  local query count
  query="$(printf '%s' "$input" | jq -r '.query // empty')"
  count="$(printf '%s' "$input" | jq -r '.count // empty')"
  count="${count:-5}"

  if [[ -z "$query" ]]; then
    printf '{"error": "query parameter is required"}'
    return 1
  fi

  if [ "$count" -lt 1 ] 2>/dev/null; then count=1; fi
  if [ "$count" -gt 10 ] 2>/dev/null; then count=10; fi

  local api_key="${BRAVE_SEARCH_API_KEY:-}"
  if [[ -n "$api_key" ]]; then
    _web_search_brave "$query" "$count" "$api_key"
    return $?
  fi

  local perplexity_key="${PERPLEXITY_API_KEY:-}"
  if [[ -n "$perplexity_key" ]]; then
    _web_search_perplexity "$query" "$perplexity_key"
    return $?
  fi

  printf '{"error": "No search API key configured. Set BRAVE_SEARCH_API_KEY or PERPLEXITY_API_KEY."}'
  return 1
}

_web_search_brave() {
  local query="$1"
  local count="$2"
  local api_key="$3"

  local encoded_query
  encoded_query="$(url_encode "$query")"

  local response
  response="$(curl -sS --max-time 15 \
    -H "Accept: application/json" \
    -H "X-Subscription-Token: ${api_key}" \
    "https://api.search.brave.com/res/v1/web/search?q=${encoded_query}&count=${count}" 2>/dev/null)"

  if [[ $? -ne 0 || -z "$response" ]]; then
    printf '{"error": "Brave Search API request failed"}'
    return 1
  fi

  printf '%s' "$response" | jq '{
    query: .query.original,
    provider: "brave",
    results: [(.web.results // [])[:10][] | {
      title: .title,
      url: .url,
      description: .description,
      published: .age
    }]
  }'
}

_web_search_perplexity() {
  local query="$1"
  local api_key="$2"

  local base_url="${PERPLEXITY_BASE_URL:-https://api.perplexity.ai}"
  local model="${PERPLEXITY_MODEL:-sonar-pro}"

  local body
  body="$(jq -nc --arg q "$query" --arg m "$model" '{
    model: $m,
    messages: [{role: "user", content: $q}]
  }')"

  local response
  response="$(curl -sS --max-time 30 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${api_key}" \
    -d "$body" \
    "${base_url}/chat/completions" 2>/dev/null)"

  if [[ $? -ne 0 || -z "$response" ]]; then
    printf '{"error": "Perplexity API request failed"}'
    return 1
  fi

  local safe_query
  safe_query="$(printf '%s' "$query" | jq -Rs '.')"
  printf '%s' "$response" | jq --arg q "$query" '{
    query: $q,
    provider: "perplexity",
    content: (.choices[0].message.content // "No response"),
    citations: (.citations // [])
  }'
}

# ---- Tool: shell ----

tool_shell() {
  local input="$1"
  require_command jq "shell tool requires jq"

  local cmd timeout_val
  cmd="$(printf '%s' "$input" | jq -r '.command // empty')"
  timeout_val="$(printf '%s' "$input" | jq -r '.timeout // empty')"
  timeout_val="${timeout_val:-$TOOL_SHELL_TIMEOUT}"

  if [[ -z "$cmd" ]]; then
    printf '{"error": "command parameter is required"}'
    return 1
  fi

  if _shell_is_dangerous "$cmd"; then
    log_warn "Shell tool blocked dangerous command: $cmd"
    printf '{"error": "blocked", "reason": "dangerous command pattern detected"}'
    return 1
  fi

  local output exit_code
  if is_command_available timeout; then
    output="$(timeout "$timeout_val" bash -c "$cmd" 2>&1)" || true
  elif is_command_available gtimeout; then
    output="$(gtimeout "$timeout_val" bash -c "$cmd" 2>&1)" || true
  else
    # Pure-bash timeout fallback (macOS/Termux)
    local _tmpout
    _tmpout="$(mktemp -t bashclaw_sh.XXXXXX 2>/dev/null || mktemp /tmp/bashclaw_sh.XXXXXX)"
    bash -c "$cmd" > "$_tmpout" 2>&1 &
    local _pid=$!
    local _waited=0
    while kill -0 "$_pid" 2>/dev/null && (( _waited < timeout_val )); do
      sleep 1
      _waited=$((_waited + 1))
    done
    if kill -0 "$_pid" 2>/dev/null; then
      kill -9 "$_pid" 2>/dev/null
      wait "$_pid" 2>/dev/null || true
      output="[command timed out after ${timeout_val}s]"
    else
      wait "$_pid" 2>/dev/null || true
      output="$(cat "$_tmpout")"
    fi
    rm -f "$_tmpout"
  fi
  exit_code=$?

  # Truncate output to 100KB
  if [ "${#output}" -gt 102400 ]; then
    output="${output:0:102400}... [truncated]"
  fi

  jq -nc --arg out "$output" --arg code "$exit_code" \
    '{output: $out, exitCode: ($code | tonumber)}'
}

# ---- Tool: memory ----

tool_memory() {
  local input="$1"
  require_command jq "memory tool requires jq"

  local action key value query_str
  action="$(printf '%s' "$input" | jq -r '.action // empty')"
  key="$(printf '%s' "$input" | jq -r '.key // empty')"
  value="$(printf '%s' "$input" | jq -r '.value // empty')"
  query_str="$(printf '%s' "$input" | jq -r '.query // empty')"

  local mem_dir="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/memory"
  ensure_dir "$mem_dir"

  case "$action" in
    get)
      if [[ -z "$key" ]]; then
        printf '{"error": "key is required for get"}'
        return 1
      fi
      local safe_key
      safe_key="$(_memory_safe_key "$key")"
      local file="${mem_dir}/${safe_key}.json"
      if [[ ! -f "$file" ]]; then
        jq -nc --arg k "$key" '{"key": $k, "found": false}'
        return 0
      fi
      cat "$file"
      ;;
    set)
      if [[ -z "$key" ]]; then
        printf '{"error": "key is required for set"}'
        return 1
      fi
      local safe_key
      safe_key="$(_memory_safe_key "$key")"
      local file="${mem_dir}/${safe_key}.json"
      local ts
      ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      jq -nc --arg k "$key" --arg v "$value" --arg t "$ts" \
        '{"key": $k, "value": $v, "updated_at": $t}' > "$file"
      jq -nc --arg k "$key" '{"key": $k, "stored": true}'
      ;;
    delete)
      if [[ -z "$key" ]]; then
        printf '{"error": "key is required for delete"}'
        return 1
      fi
      local safe_key
      safe_key="$(_memory_safe_key "$key")"
      local file="${mem_dir}/${safe_key}.json"
      if [[ -f "$file" ]]; then
        rm -f "$file"
        jq -nc --arg k "$key" '{"key": $k, "deleted": true}'
      else
        jq -nc --arg k "$key" '{"key": $k, "deleted": false, "reason": "not found"}'
      fi
      ;;
    list)
      local keys="[]"
      local f
      for f in "${mem_dir}"/*.json; do
        [[ -f "$f" ]] || continue
        local k
        k="$(jq -r '.key // empty' < "$f" 2>/dev/null)"
        if [[ -n "$k" ]]; then
          keys="$(printf '%s' "$keys" | jq --arg k "$k" '. + [$k]')"
        fi
      done
      jq -nc --argjson ks "$keys" '{"keys": $ks, "count": ($ks | length)}'
      ;;
    search)
      if [[ -z "$query_str" ]]; then
        printf '{"error": "query is required for search"}'
        return 1
      fi
      local results="[]"
      local f
      for f in "${mem_dir}"/*.json; do
        [[ -f "$f" ]] || continue
        if grep -qi "$query_str" "$f" 2>/dev/null; then
          local entry
          entry="$(cat "$f")"
          results="$(printf '%s' "$results" | jq --argjson e "$entry" '. + [$e]')"
        fi
      done
      jq -nc --argjson r "$results" '{"results": $r, "count": ($r | length)}'
      ;;
    *)
      printf '{"error": "unknown memory action: %s. Use get, set, delete, list, or search"}' "$action"
      return 1
      ;;
  esac
}

_memory_safe_key() {
  local key="$1"
  printf '%s' "$key" | tr -c '[:alnum:]._-' '_' | head -c 200
}

# ---- Tool: cron ----

tool_cron() {
  local input="$1"
  require_command jq "cron tool requires jq"

  local action id schedule command agent_id
  action="$(printf '%s' "$input" | jq -r '.action // empty')"
  id="$(printf '%s' "$input" | jq -r '.id // empty')"
  schedule="$(printf '%s' "$input" | jq -r '.schedule // empty')"
  command="$(printf '%s' "$input" | jq -r '.command // empty')"
  agent_id="$(printf '%s' "$input" | jq -r '.agent_id // empty')"

  local cron_dir="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/cron"
  ensure_dir "$cron_dir"

  case "$action" in
    add)
      if [[ -z "$schedule" || -z "$command" ]]; then
        printf '{"error": "schedule and command are required for add"}'
        return 1
      fi
      if [[ -z "$id" ]]; then
        id="$(uuid_generate)"
      fi
      local ts
      ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      local safe_id
      safe_id="$(_memory_safe_key "$id")"
      jq -nc \
        --arg id "$id" \
        --arg sched "$schedule" \
        --arg cmd "$command" \
        --arg aid "$agent_id" \
        --arg ts "$ts" \
        '{id: $id, schedule: $sched, command: $cmd, agent_id: $aid, created_at: $ts, enabled: true}' \
        > "${cron_dir}/${safe_id}.json"
      jq -nc --arg id "$id" '{"id": $id, "created": true}'
      ;;
    remove)
      if [[ -z "$id" ]]; then
        printf '{"error": "id is required for remove"}'
        return 1
      fi
      local safe_id
      safe_id="$(_memory_safe_key "$id")"
      local file="${cron_dir}/${safe_id}.json"
      if [[ -f "$file" ]]; then
        rm -f "$file"
        jq -nc --arg id "$id" '{"id": $id, "removed": true}'
      else
        jq -nc --arg id "$id" '{"id": $id, "removed": false, "reason": "not found"}'
      fi
      ;;
    list)
      local jobs="[]"
      local f
      for f in "${cron_dir}"/*.json; do
        [[ -f "$f" ]] || continue
        local entry
        entry="$(cat "$f")"
        jobs="$(printf '%s' "$jobs" | jq --argjson e "$entry" '. + [$e]')"
      done
      jq -nc --argjson j "$jobs" '{"jobs": $j, "count": ($j | length)}'
      ;;
    *)
      printf '{"error": "unknown cron action: %s. Use add, remove, or list"}' "$action"
      return 1
      ;;
  esac
}

# ---- Tool: message ----

tool_message() {
  local input="$1"
  require_command jq "message tool requires jq"

  local action channel target message_text
  action="$(printf '%s' "$input" | jq -r '.action // empty')"
  channel="$(printf '%s' "$input" | jq -r '.channel // empty')"
  target="$(printf '%s' "$input" | jq -r '.target // empty')"
  message_text="$(printf '%s' "$input" | jq -r '.message // empty')"

  if [[ "$action" != "send" ]]; then
    printf '{"error": "only send action is supported"}'
    return 1
  fi

  if [[ -z "$message_text" ]]; then
    printf '{"error": "message parameter is required"}'
    return 1
  fi

  local handler_func="_channel_send_${channel}"
  if declare -f "$handler_func" &>/dev/null; then
    "$handler_func" "$target" "$message_text"
  else
    log_warn "No channel handler for: ${channel:-<none>}, message logged only"
    jq -nc --arg ch "$channel" --arg tgt "$target" --arg msg "$message_text" \
      '{"sent": false, "channel": $ch, "target": $tgt, "message": $msg, "reason": "no handler configured"}'
  fi
}

# ---- Tool: agents_list ----

# List all configured agents from the config
tool_agents_list() {
  require_command jq "agents_list tool requires jq"

  local agents_raw
  agents_raw="$(config_get_raw '.agents.list // []')"
  local defaults
  defaults="$(config_get_raw '.agents.defaults // {}')"

  jq -nc --argjson agents "$agents_raw" --argjson defaults "$defaults" \
    '{agents: $agents, defaults: $defaults, count: ($agents | length)}'
}

# ---- Tool: session_status ----

# Query session info for a specific agent/channel/sender
tool_session_status() {
  local input="$1"
  require_command jq "session_status tool requires jq"

  local agent_id channel sender
  agent_id="$(printf '%s' "$input" | jq -r '.agent_id // "main"')"
  channel="$(printf '%s' "$input" | jq -r '.channel // "default"')"
  sender="$(printf '%s' "$input" | jq -r '.sender // empty')"

  local sess_file
  sess_file="$(session_file "$agent_id" "$channel" "$sender")"

  local msg_count=0
  local last_role=""
  if [[ -f "$sess_file" ]]; then
    msg_count="$(session_count "$sess_file")"
    last_role="$(session_last_role "$sess_file")"
  fi

  local model
  model="$(agent_resolve_model "$agent_id")"
  local provider
  provider="$(agent_resolve_provider "$model")"

  jq -nc \
    --arg aid "$agent_id" \
    --arg ch "$channel" \
    --arg snd "$sender" \
    --arg sf "$sess_file" \
    --argjson mc "$msg_count" \
    --arg lr "$last_role" \
    --arg m "$model" \
    --arg p "$provider" \
    '{agent_id: $aid, channel: $ch, sender: $snd, session_file: $sf, message_count: $mc, last_role: $lr, model: $m, provider: $p}'
}

# ---- Tool: sessions_list ----

# List all active sessions across all agents
tool_sessions_list() {
  require_command jq "sessions_list tool requires jq"
  session_list
}

# ---- SSRF helper ----

_ssrf_is_blocked() {
  local hostname="$1"

  if _ssrf_is_private_pattern "$hostname"; then
    return 0
  fi

  # DNS resolution check
  if is_command_available dig; then
    local resolved
    resolved="$(dig +short "$hostname" 2>/dev/null | head -1)"
    if [[ -n "$resolved" ]] && _ssrf_is_private_pattern "$resolved"; then
      log_warn "SSRF blocked: $hostname resolves to private IP $resolved"
      return 0
    fi
  elif is_command_available host; then
    local resolved
    resolved="$(host "$hostname" 2>/dev/null | grep 'has address' | head -1 | awk '{print $NF}')"
    if [[ -n "$resolved" ]] && _ssrf_is_private_pattern "$resolved"; then
      log_warn "SSRF blocked: $hostname resolves to private IP $resolved"
      return 0
    fi
  fi

  return 1
}
