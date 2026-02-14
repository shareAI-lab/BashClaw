#!/usr/bin/env bash
# Agent runtime for bashclaw
# Compatible with bash 3.2+ (no associative arrays)

# ---- Model Catalog (function-based) ----

_model_provider() {
  case "$1" in
    claude-opus-4-20250918)   echo "anthropic" ;;
    claude-sonnet-4-20250514) echo "anthropic" ;;
    claude-haiku-3-20250307)  echo "anthropic" ;;
    glm-5)                    echo "anthropic" ;;
    gpt-4o)                   echo "openai" ;;
    gpt-4o-mini)              echo "openai" ;;
    gpt-4-turbo)              echo "openai" ;;
    o1)                       echo "openai" ;;
    o1-mini)                  echo "openai" ;;
    o3-mini)                  echo "openai" ;;
    *)                        echo "" ;;
  esac
}

_model_max_tokens() {
  case "$1" in
    claude-opus-4-20250918)   echo 4096 ;;
    claude-sonnet-4-20250514) echo 8192 ;;
    claude-haiku-3-20250307)  echo 4096 ;;
    glm-5)                    echo 4096 ;;
    gpt-4o)                   echo 4096 ;;
    gpt-4o-mini)              echo 4096 ;;
    gpt-4-turbo)              echo 4096 ;;
    o1)                       echo 4096 ;;
    o1-mini)                  echo 4096 ;;
    o3-mini)                  echo 4096 ;;
    *)                        echo 4096 ;;
  esac
}

AGENT_MAX_TOOL_ITERATIONS="${AGENT_MAX_TOOL_ITERATIONS:-10}"
AGENT_DEFAULT_TEMPERATURE="${AGENT_DEFAULT_TEMPERATURE:-0.7}"

# ---- Model Resolution ----

agent_resolve_model() {
  local agent_id="${1:-main}"

  local model
  model="$(config_agent_get "$agent_id" "model" "")"
  if [[ -n "$model" ]]; then
    printf '%s' "$model"
    return
  fi

  model="${MODEL_ID:-claude-sonnet-4-20250514}"
  printf '%s' "$model"
}

agent_resolve_provider() {
  local model="$1"

  local provider
  provider="$(_model_provider "$model")"
  if [[ -n "$provider" ]]; then
    printf '%s' "$provider"
    return
  fi

  printf 'anthropic'
}

agent_resolve_api_key() {
  local provider="$1"

  case "$provider" in
    anthropic)
      local key="${ANTHROPIC_API_KEY:-}"
      if [[ -z "$key" ]]; then
        log_fatal "ANTHROPIC_API_KEY is required for Anthropic provider"
      fi
      printf '%s' "$key"
      ;;
    openai)
      local key="${OPENAI_API_KEY:-}"
      if [[ -z "$key" ]]; then
        log_fatal "OPENAI_API_KEY is required for OpenAI provider"
      fi
      printf '%s' "$key"
      ;;
    *)
      log_fatal "Unknown provider: $provider"
      ;;
  esac
}

# ---- System Prompt ----

agent_build_system_prompt() {
  local agent_id="${1:-main}"

  local identity
  identity="$(config_agent_get "$agent_id" "identity" "")"
  local system_prompt
  system_prompt="$(config_agent_get "$agent_id" "systemPrompt" "")"

  local prompt=""

  if [[ -n "$identity" ]]; then
    prompt="You are ${identity}."
  else
    prompt="You are a helpful AI assistant."
  fi

  if [[ -n "$system_prompt" ]]; then
    prompt="${prompt}

${system_prompt}"
  fi

  local tool_desc
  tool_desc="$(tools_describe_all)"
  if [[ -n "$tool_desc" ]]; then
    prompt="${prompt}

${tool_desc}"
  fi

  printf '%s' "$prompt"
}

# ---- Message Building ----

agent_build_messages() {
  local session_file="$1"
  local user_message="$2"
  local max_history="${3:-50}"

  require_command jq "agent_build_messages requires jq"

  local history
  history="$(session_load "$session_file" "$max_history")"

  local messages
  messages="$(printf '%s' "$history" | jq '[
    .[] |
    if .type == "tool_call" then
      {
        role: "assistant",
        content: [{
          type: "tool_use",
          id: .tool_id,
          name: .tool_name,
          input: (if (.tool_input | type) == "string" then (.tool_input | fromjson? // {}) else (.tool_input // {}) end)
        }]
      }
    elif .type == "tool_result" then
      {
        role: "user",
        content: [{
          type: "tool_result",
          tool_use_id: .tool_id,
          content: .content,
          is_error: (.is_error // false)
        }]
      }
    else
      {role: .role, content: .content}
    end
  ]')"

  if [[ -n "$user_message" ]]; then
    messages="$(printf '%s' "$messages" | jq --arg msg "$user_message" '. + [{role: "user", content: $msg}]')"
  fi

  printf '%s' "$messages"
}

# ---- Tool Spec ----

agent_build_tools_spec() {
  local agent_id="${1:-main}"

  local enabled_tools
  enabled_tools="$(config_agent_get "$agent_id" "tools" "")"

  if [[ -z "$enabled_tools" || "$enabled_tools" == "null" ]]; then
    tools_build_spec
    return
  fi

  require_command jq "agent_build_tools_spec requires jq"
  local all_specs
  all_specs="$(tools_build_spec)"

  printf '%s' "$all_specs" | jq --argjson enabled "$enabled_tools" \
    '[.[] | select(.name as $n | $enabled | index($n))]'
}

# ---- API Callers ----

agent_call_anthropic() {
  local model="$1"
  local system_prompt="$2"
  local messages="$3"
  local max_tokens="${4:-4096}"
  local temperature="${5:-$AGENT_DEFAULT_TEMPERATURE}"
  local tools_json="${6:-}"

  require_command curl "agent_call_anthropic requires curl"
  require_command jq "agent_call_anthropic requires jq"

  local api_key
  api_key="$(agent_resolve_api_key "anthropic")"

  local api_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages"

  local body
  if [[ -n "$tools_json" && "$tools_json" != "[]" ]]; then
    body="$(jq -nc \
      --arg model "$model" \
      --arg system "$system_prompt" \
      --argjson messages "$messages" \
      --argjson max_tokens "$max_tokens" \
      --argjson temp "$temperature" \
      --argjson tools "$tools_json" \
      '{
        model: $model,
        system: $system,
        messages: $messages,
        max_tokens: $max_tokens,
        temperature: $temp,
        tools: $tools
      }')"
  else
    body="$(jq -nc \
      --arg model "$model" \
      --arg system "$system_prompt" \
      --argjson messages "$messages" \
      --argjson max_tokens "$max_tokens" \
      --argjson temp "$temperature" \
      '{
        model: $model,
        system: $system,
        messages: $messages,
        max_tokens: $max_tokens,
        temperature: $temp
      }')"
  fi

  log_debug "Anthropic API call: model=$model url=$api_url"

  local response http_code
  local response_file
  response_file="$(tmpfile "anthropic_resp")"

  # Retry with backoff on transient HTTP errors (429/500/502/503)
  local attempt=0
  local max_attempts=3
  while (( attempt < max_attempts )); do
    attempt=$((attempt + 1))

    http_code="$(curl -sS --max-time 120 \
      -o "$response_file" -w '%{http_code}' \
      -H "x-api-key: ${api_key}" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d "$body" \
      "$api_url" 2>/dev/null)" || true

    response="$(cat "$response_file" 2>/dev/null)"

    case "$http_code" in
      429|500|502|503)
        if (( attempt < max_attempts )); then
          local delay=$((2 * (1 << (attempt - 1)) + RANDOM % 3))
          log_warn "Anthropic API HTTP $http_code, retry ${attempt}/${max_attempts} in ${delay}s"
          sleep "$delay"
          continue
        fi
        ;;
    esac
    break
  done

  rm -f "$response_file"

  if [[ -z "$response" ]]; then
    log_error "Anthropic API request failed (HTTP $http_code)"
    printf '{"error": "API request failed"}'
    return 1
  fi

  local error_msg
  error_msg="$(printf '%s' "$response" | jq -r '.error.message // empty' 2>/dev/null)"
  if [[ -n "$error_msg" ]]; then
    log_error "Anthropic API error: $error_msg"
    printf '%s' "$response"
    return 1
  fi

  printf '%s' "$response"
}

agent_call_openai() {
  local model="$1"
  local system_prompt="$2"
  local messages="$3"
  local max_tokens="${4:-4096}"
  local temperature="${5:-$AGENT_DEFAULT_TEMPERATURE}"
  local tools_json="${6:-}"

  require_command curl "agent_call_openai requires curl"
  require_command jq "agent_call_openai requires jq"

  local api_key
  api_key="$(agent_resolve_api_key "openai")"

  local api_url="${OPENAI_BASE_URL:-https://api.openai.com}/v1/chat/completions"

  local oai_messages
  oai_messages="$(printf '%s' "$messages" | jq --arg sys "$system_prompt" \
    '[{role: "system", content: $sys}] + .')"

  local oai_tools=""
  if [[ -n "$tools_json" && "$tools_json" != "[]" ]]; then
    oai_tools="$(printf '%s' "$tools_json" | jq '[.[] | {
      type: "function",
      function: {
        name: .name,
        description: .description,
        parameters: .input_schema
      }
    }]')"
  fi

  local body
  if [[ -n "$oai_tools" && "$oai_tools" != "[]" ]]; then
    body="$(jq -nc \
      --arg model "$model" \
      --argjson messages "$oai_messages" \
      --argjson max_tokens "$max_tokens" \
      --argjson temp "$temperature" \
      --argjson tools "$oai_tools" \
      '{
        model: $model,
        messages: $messages,
        max_tokens: $max_tokens,
        temperature: $temp,
        tools: $tools
      }')"
  else
    body="$(jq -nc \
      --arg model "$model" \
      --argjson messages "$oai_messages" \
      --argjson max_tokens "$max_tokens" \
      --argjson temp "$temperature" \
      '{
        model: $model,
        messages: $messages,
        max_tokens: $max_tokens,
        temperature: $temp
      }')"
  fi

  log_debug "OpenAI API call: model=$model"

  local response http_code
  local response_file
  response_file="$(tmpfile "openai_resp")"

  # Retry with backoff on transient HTTP errors (429/500/502/503)
  local attempt=0
  local max_attempts=3
  while (( attempt < max_attempts )); do
    attempt=$((attempt + 1))

    http_code="$(curl -sS --max-time 120 \
      -o "$response_file" -w '%{http_code}' \
      -H "Authorization: Bearer ${api_key}" \
      -H "Content-Type: application/json" \
      -d "$body" \
      "$api_url" 2>/dev/null)" || true

    response="$(cat "$response_file" 2>/dev/null)"

    case "$http_code" in
      429|500|502|503)
        if (( attempt < max_attempts )); then
          local delay=$((2 * (1 << (attempt - 1)) + RANDOM % 3))
          log_warn "OpenAI API HTTP $http_code, retry ${attempt}/${max_attempts} in ${delay}s"
          sleep "$delay"
          continue
        fi
        ;;
    esac
    break
  done

  rm -f "$response_file"

  if [[ -z "$response" ]]; then
    log_error "OpenAI API request failed (HTTP $http_code)"
    printf '{"error": "API request failed"}'
    return 1
  fi

  local error_msg
  error_msg="$(printf '%s' "$response" | jq -r '.error.message // empty' 2>/dev/null)"
  if [[ -n "$error_msg" ]]; then
    log_error "OpenAI API error: $error_msg"
    printf '%s' "$response"
    return 1
  fi

  _openai_normalize_response "$response"
}

_openai_normalize_response() {
  local response="$1"

  local stop_reason
  stop_reason="$(printf '%s' "$response" | jq -r '.choices[0].finish_reason // "stop"')"

  local mapped_reason="end_turn"
  case "$stop_reason" in
    tool_calls) mapped_reason="tool_use" ;;
    length)     mapped_reason="max_tokens" ;;
    *)          mapped_reason="end_turn" ;;
  esac

  local has_tool_calls
  has_tool_calls="$(printf '%s' "$response" | jq '.choices[0].message.tool_calls | length > 0')"

  if [[ "$has_tool_calls" == "true" ]]; then
    printf '%s' "$response" | jq --arg sr "$mapped_reason" '{
      stop_reason: $sr,
      content: [
        (if .choices[0].message.content then {type: "text", text: .choices[0].message.content} else empty end),
        (.choices[0].message.tool_calls[]? | {
          type: "tool_use",
          id: .id,
          name: .function.name,
          input: (.function.arguments | fromjson? // {})
        })
      ]
    }'
  else
    local text
    text="$(printf '%s' "$response" | jq -r '.choices[0].message.content // ""')"
    printf '%s' "$response" | jq --arg sr "$mapped_reason" --arg text "$text" '{
      stop_reason: $sr,
      content: [{type: "text", text: $text}]
    }'
  fi
}

# ---- Main Agent Loop ----

agent_run() {
  local agent_id="${1:-main}"
  local user_message="$2"
  local channel="${3:-default}"
  local sender="${4:-}"

  if [[ -z "$user_message" ]]; then
    log_error "agent_run: message is required"
    printf '{"error": "message is required"}'
    return 1
  fi

  require_command jq "agent_run requires jq"
  require_command curl "agent_run requires curl"

  # 1. Resolve model, provider
  local model provider
  model="$(agent_resolve_model "$agent_id")"
  provider="$(agent_resolve_provider "$model")"
  log_info "Agent run: agent=$agent_id model=$model provider=$provider"

  local max_tokens
  max_tokens="$(_model_max_tokens "$model")"

  # 2. Load/check session
  local sess_file
  sess_file="$(session_file "$agent_id" "$channel" "$sender")"

  session_check_idle_reset "$sess_file" || true

  # 3. Append user message to session
  session_append "$sess_file" "user" "$user_message"

  # 4. Build system prompt and tools spec
  local system_prompt
  system_prompt="$(agent_build_system_prompt "$agent_id")"

  local tools_json
  tools_json="$(agent_build_tools_spec "$agent_id")"

  # 5. Agent loop with tool execution
  local iteration=0
  local final_text=""

  while [ "$iteration" -lt "$AGENT_MAX_TOOL_ITERATIONS" ]; do
    iteration=$((iteration + 1))

    # Build messages from session (user message already appended)
    local max_history
    max_history="$(config_get '.session.maxHistory' '200')"
    local messages
    messages="$(agent_build_messages "$sess_file" "" "$max_history")"

    # Call API
    local response
    case "$provider" in
      anthropic)
        response="$(agent_call_anthropic "$model" "$system_prompt" "$messages" "$max_tokens" "$AGENT_DEFAULT_TEMPERATURE" "$tools_json")"
        ;;
      openai)
        response="$(agent_call_openai "$model" "$system_prompt" "$messages" "$max_tokens" "$AGENT_DEFAULT_TEMPERATURE" "$tools_json")"
        ;;
      *)
        log_error "Unsupported provider: $provider"
        printf '{"error": "unsupported provider: %s"}' "$provider"
        return 1
        ;;
    esac

    if [[ $? -ne 0 ]]; then
      log_error "API call failed on iteration $iteration"
      printf '%s' "$response"
      return 1
    fi

    # Check API error response
    local api_error
    api_error="$(printf '%s' "$response" | jq -r '.error // empty' 2>/dev/null)"
    if [[ -n "$api_error" && "$api_error" != "null" ]]; then
      log_error "API error: $api_error"
      printf '%s' "$response"
      return 1
    fi

    # Parse stop_reason and content
    local stop_reason
    stop_reason="$(printf '%s' "$response" | jq -r '.stop_reason // "end_turn"')"

    local text_content
    text_content="$(printf '%s' "$response" | jq -r '
      [.content[]? | select(.type == "text") | .text] | join("")
    ')"

    if [[ -n "$text_content" ]]; then
      final_text="$text_content"
    fi

    # If stop_reason is tool_use, execute tools and continue
    if [[ "$stop_reason" == "tool_use" ]]; then
      log_debug "Tool use requested on iteration $iteration"

      if [[ -n "$text_content" ]]; then
        session_append "$sess_file" "assistant" "$text_content"
      fi

      local tool_calls
      tool_calls="$(printf '%s' "$response" | jq -c '[.content[]? | select(.type == "tool_use")]')"
      local num_calls
      num_calls="$(printf '%s' "$tool_calls" | jq 'length')"

      local i=0
      while [ "$i" -lt "$num_calls" ]; do
        local tool_call
        tool_call="$(printf '%s' "$tool_calls" | jq -c ".[$i]")"
        local tool_name tool_id tool_input
        tool_name="$(printf '%s' "$tool_call" | jq -r '.name')"
        tool_id="$(printf '%s' "$tool_call" | jq -r '.id')"
        tool_input="$(printf '%s' "$tool_call" | jq -c '.input')"

        log_info "Tool call: $tool_name (id=$tool_id)"

        session_append_tool_call "$sess_file" "$tool_name" "$tool_input" "$tool_id"

        local tool_result
        tool_result="$(tool_execute "$tool_name" "$tool_input" 2>&1)" || true

        log_debug "Tool result ($tool_name): ${tool_result:0:200}"

        local is_error="false"
        if printf '%s' "$tool_result" | jq -e '.error' &>/dev/null; then
          is_error="true"
        fi

        session_append_tool_result "$sess_file" "$tool_id" "$tool_result" "$is_error"

        i=$((i + 1))
      done

      continue
    fi

    # stop_reason is end_turn or max_tokens
    if [[ -n "$text_content" ]]; then
      session_append "$sess_file" "assistant" "$text_content"
    fi

    break
  done

  if [ "$iteration" -ge "$AGENT_MAX_TOOL_ITERATIONS" ]; then
    log_warn "Agent reached max tool iterations ($AGENT_MAX_TOOL_ITERATIONS)"
  fi

  # Prune session
  local max_history_val
  max_history_val="$(config_get '.session.maxHistory' '200')"
  session_prune "$sess_file" "$max_history_val"

  printf '%s' "$final_text"
}

# ---- Usage Tracking ----

# Save API usage data to the session directory
agent_track_usage() {
  local agent_id="$1"
  local model="$2"
  local input_tokens="${3:-0}"
  local output_tokens="${4:-0}"

  require_command jq "agent_track_usage requires jq"

  local usage_dir="${BASHCLAW_STATE_DIR:?}/usage"
  ensure_dir "$usage_dir"
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  local line
  line="$(jq -nc \
    --arg aid "$agent_id" \
    --arg m "$model" \
    --argjson it "$input_tokens" \
    --argjson ot "$output_tokens" \
    --arg ts "$now" \
    '{agent_id: $aid, model: $m, input_tokens: $it, output_tokens: $ot, timestamp: $ts}')"

  printf '%s\n' "$line" >> "${usage_dir}/usage.jsonl"
}

# ---- Agent-to-Agent Messaging ----

# Send a message from one agent to another via the routing system
tool_agent_message() {
  local input="$1"
  require_command jq "tool_agent_message requires jq"

  local target_agent message_text from_agent
  target_agent="$(printf '%s' "$input" | jq -r '.target_agent // empty')"
  message_text="$(printf '%s' "$input" | jq -r '.message // empty')"
  from_agent="$(printf '%s' "$input" | jq -r '.from_agent // "main"')"

  if [[ -z "$target_agent" ]]; then
    printf '{"error": "target_agent is required"}'
    return 1
  fi

  if [[ -z "$message_text" ]]; then
    printf '{"error": "message is required"}'
    return 1
  fi

  log_info "Agent message: from=$from_agent to=$target_agent"

  local response
  response="$(agent_run "$target_agent" "$message_text" "agent" "$from_agent" 2>&1)" || true

  jq -nc \
    --arg from "$from_agent" \
    --arg to "$target_agent" \
    --arg resp "$response" \
    '{from_agent: $from, target_agent: $to, response: $resp}'
}
