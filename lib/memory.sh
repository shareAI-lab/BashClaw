#!/usr/bin/env bash
# Long-term memory module for bashclaw
# File-based key-value store with tags, sources, and access tracking
# Extended with workspace memory, daily logs, BM25-style search (Gap 2.5)

# Returns the memory storage directory
memory_dir() {
  local dir="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/memory"
  ensure_dir "$dir"
  printf '%s' "$dir"
}

# Sanitize a key for safe use as a filename
_memory_key_to_filename() {
  local key="$1"
  printf '%s' "$key" | tr -c '[:alnum:]._-' '_' | head -c 200
}

# ---- Workspace Memory (Gap 2.5) ----

# Ensure the agent workspace memory directory exists
memory_ensure_workspace() {
  local agent_id="${1:?agent_id required}"

  local workspace="${BASHCLAW_STATE_DIR:?}/agents/${agent_id}/memory"
  ensure_dir "$workspace"

  # Initialize MEMORY.md if absent
  local memory_md="${BASHCLAW_STATE_DIR}/agents/${agent_id}/MEMORY.md"
  if [[ ! -f "$memory_md" ]]; then
    printf '# Memory\n\nCurated memory for agent: %s\n' "$agent_id" > "$memory_md"
    log_debug "Initialized MEMORY.md for agent=$agent_id"
  fi

  printf '%s' "$workspace"
}

# Append content to today's daily log
memory_append_daily() {
  local agent_id="${1:?agent_id required}"
  local content="${2:?content required}"

  local workspace
  workspace="$(memory_ensure_workspace "$agent_id")"

  local today
  today="$(date -u '+%Y-%m-%d')"
  local daily_file="${workspace}/${today}.md"

  # Create header if new file
  if [[ ! -f "$daily_file" ]]; then
    printf '# Daily Log: %s\n\n' "$today" > "$daily_file"
  fi

  # Append with timestamp
  local now
  now="$(date -u '+%H:%M:%S')"
  printf '\n## %s\n\n%s\n' "$now" "$content" >> "$daily_file"

  log_debug "Memory daily append: agent=$agent_id date=$today"
}

# ---- KV Store ----

# Store a value with optional tags and source
# Usage: memory_store KEY VALUE [--tags tag1,tag2] [--source SOURCE]
memory_store() {
  local key="${1:?key required}"
  local value="${2:?value required}"
  shift 2

  local tags=""
  local source=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tags) tags="$2"; shift 2 ;;
      --source) source="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  require_command jq "memory_store requires jq"

  local dir
  dir="$(memory_dir)"
  local safe_key
  safe_key="$(_memory_key_to_filename "$key")"
  local file="${dir}/${safe_key}.json"
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  # Build tags JSON array from comma-separated string
  local tags_json="[]"
  if [[ -n "$tags" ]]; then
    tags_json="$(printf '%s' "$tags" | jq -Rs 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))')"
  fi

  # Check if entry already exists (update vs create)
  local created_at="$now"
  local access_count=0
  if [[ -f "$file" ]]; then
    created_at="$(jq -r '.created_at // empty' < "$file" 2>/dev/null)"
    access_count="$(jq -r '.access_count // 0' < "$file" 2>/dev/null)"
    created_at="${created_at:-$now}"
  fi

  jq -nc \
    --arg k "$key" \
    --arg v "$value" \
    --argjson tags "$tags_json" \
    --arg src "$source" \
    --arg ca "$created_at" \
    --arg ua "$now" \
    --argjson ac "$access_count" \
    '{key: $k, value: $v, tags: $tags, source: $src, created_at: $ca, updated_at: $ua, access_count: $ac}' \
    > "$file"

  chmod 600 "$file"
  log_debug "Memory stored: key=$key"
}

# Retrieve a value by key and increment access_count
memory_get() {
  local key="${1:?key required}"

  require_command jq "memory_get requires jq"

  local dir
  dir="$(memory_dir)"
  local safe_key
  safe_key="$(_memory_key_to_filename "$key")"
  local file="${dir}/${safe_key}.json"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Increment access_count in place
  local content
  content="$(cat "$file")"
  local updated
  updated="$(printf '%s' "$content" | jq '.access_count = (.access_count + 1)')"
  printf '%s\n' "$updated" > "$file"

  # Output the value
  printf '%s' "$content" | jq -r '.value'
}

# ---- BM25-Style Search (Gap 2.5) ----

# Search across all memory files with relevance scoring
# Returns matching entries as JSON with scores
memory_search() {
  local query="${1:?query required}"
  local max_results="${2:-10}"

  require_command jq "memory_search requires jq"

  local dir
  dir="$(memory_dir)"
  local results="[]"

  # Split query into terms for BM25-style scoring
  local query_lower
  query_lower="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"

  # Search JSON KV files
  local f
  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    if grep -qi "$query" "$f" 2>/dev/null; then
      local entry
      entry="$(cat "$f")"
      local score
      score="$(_memory_score_entry "$entry" "$query_lower")"
      results="$(printf '%s' "$results" | jq --argjson e "$entry" --argjson s "$score" \
        '. + [$e + {score: $s}]')"
    fi
  done

  # Search markdown memory files (agent workspaces)
  local agents_dir="${BASHCLAW_STATE_DIR:?}/agents"
  if [[ -d "$agents_dir" ]]; then
    local agent_dir
    for agent_dir in "${agents_dir}"/*/; do
      [[ -d "$agent_dir" ]] || continue
      local agent_id
      agent_id="$(basename "$agent_dir")"

      # Search MEMORY.md
      local memory_md="${agent_dir}MEMORY.md"
      if [[ -f "$memory_md" ]] && grep -qi "$query" "$memory_md" 2>/dev/null; then
        local snippet
        snippet="$(grep -i "$query" "$memory_md" 2>/dev/null | head -5)"
        local md_score
        md_score="$(_memory_score_text "$snippet" "$query_lower")"
        results="$(printf '%s' "$results" | jq \
          --arg k "md:${agent_id}:MEMORY" \
          --arg v "$snippet" \
          --arg src "$memory_md" \
          --argjson s "$md_score" \
          '. + [{key: $k, value: $v, source: $src, score: $s, tags: ["markdown","curated"]}]')"
      fi

      # Search daily log files
      local md_file
      for md_file in "${agent_dir}memory/"*.md; do
        [[ -f "$md_file" ]] || continue
        if grep -qi "$query" "$md_file" 2>/dev/null; then
          local md_snippet
          md_snippet="$(grep -i "$query" "$md_file" 2>/dev/null | head -5)"
          local daily_score
          daily_score="$(_memory_score_text "$md_snippet" "$query_lower")"
          local md_basename
          md_basename="$(basename "$md_file")"
          results="$(printf '%s' "$results" | jq \
            --arg k "md:${agent_id}:${md_basename}" \
            --arg v "$md_snippet" \
            --arg src "$md_file" \
            --argjson s "$daily_score" \
            '. + [{key: $k, value: $v, source: $src, score: $s, tags: ["markdown","daily"]}]')"
        fi
      done
    done
  fi

  # Sort by score descending and limit results
  printf '%s' "$results" | jq --argjson limit "$max_results" \
    'sort_by(-.score) | .[:$limit]'
}

# BM25-style relevance scoring for a JSON entry
_memory_score_entry() {
  local entry="$1"
  local query_lower="$2"

  local text
  text="$(printf '%s' "$entry" | jq -r '(.key // "") + " " + (.value // "")' 2>/dev/null)"
  _memory_score_text "$text" "$query_lower"
}

# BM25-inspired term frequency scoring
_memory_score_text() {
  local text="$1"
  local query_lower="$2"

  local text_lower
  text_lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"

  local score=0
  local term
  for term in $query_lower; do
    [[ -z "$term" ]] && continue
    # Count occurrences (term frequency)
    local count=0
    local tmp="$text_lower"
    while [[ "$tmp" == *"$term"* ]]; do
      count=$((count + 1))
      tmp="${tmp#*"$term"}"
    done

    if [[ "$count" -gt 0 ]]; then
      # BM25-style saturation: tf / (tf + k1), k1=1.2
      # Using integer arithmetic: score += (count * 100) / (count + 1)
      local tf_score=$(( (count * 100) / (count + 1) ))
      score=$((score + tf_score))
    fi
  done

  # Bonus for exact phrase match
  if [[ "$text_lower" == *"$query_lower"* ]]; then
    score=$((score + 50))
  fi

  printf '%s' "$score"
}

# List memory entries with optional pagination
# Usage: memory_list [--limit N] [--offset O]
memory_list() {
  local limit=50
  local offset=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit) limit="$2"; shift 2 ;;
      --offset) offset="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  require_command jq "memory_list requires jq"

  local dir
  dir="$(memory_dir)"
  local all="[]"
  local f

  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local entry
    entry="$(cat "$f")"
    all="$(printf '%s' "$all" | jq --argjson e "$entry" '. + [$e]')"
  done

  printf '%s' "$all" | jq --argjson off "$offset" --argjson lim "$limit" \
    '.[$off:$off + $lim]'
}

# Delete a memory entry by key
memory_delete() {
  local key="${1:?key required}"

  local dir
  dir="$(memory_dir)"
  local safe_key
  safe_key="$(_memory_key_to_filename "$key")"
  local file="${dir}/${safe_key}.json"

  if [[ -f "$file" ]]; then
    rm -f "$file"
    log_debug "Memory deleted: key=$key"
    return 0
  fi
  return 1
}

# Export all memory entries as a JSON array
memory_export() {
  require_command jq "memory_export requires jq"

  local dir
  dir="$(memory_dir)"
  local all="[]"
  local f

  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local entry
    entry="$(cat "$f")"
    all="$(printf '%s' "$all" | jq --argjson e "$entry" '. + [$e]')"
  done

  printf '%s' "$all"
}

# Import memory entries from a JSON array file
memory_import() {
  local file="${1:?file path required}"

  if [[ ! -f "$file" ]]; then
    log_error "Import file not found: $file"
    return 1
  fi

  require_command jq "memory_import requires jq"

  local count
  count="$(jq 'length' < "$file")"
  local i=0

  while (( i < count )); do
    local entry
    entry="$(jq -c ".[$i]" < "$file")"
    local key value tags source
    key="$(printf '%s' "$entry" | jq -r '.key // empty')"
    value="$(printf '%s' "$entry" | jq -r '.value // empty')"
    tags="$(printf '%s' "$entry" | jq -r '.tags // [] | join(",")')"
    source="$(printf '%s' "$entry" | jq -r '.source // empty')"

    if [[ -n "$key" ]]; then
      local args=("$key" "$value")
      if [[ -n "$tags" ]]; then
        args+=(--tags "$tags")
      fi
      if [[ -n "$source" ]]; then
        args+=(--source "$source")
      fi
      memory_store "${args[@]}"
    fi
    i=$((i + 1))
  done

  log_info "Imported $count memory entries from $file"
}

# Deduplicate entries with the same key, keeping the newest
memory_compact() {
  require_command jq "memory_compact requires jq"

  local dir
  dir="$(memory_dir)"
  local removed=0

  local f
  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    local key
    key="$(jq -r '.key // empty' < "$f" 2>/dev/null)" || true
    if [[ -z "$key" ]]; then
      rm -f "$f"
      removed=$((removed + 1))
      continue
    fi

    # Validate JSON structure
    if ! jq empty < "$f" 2>/dev/null; then
      rm -f "$f"
      removed=$((removed + 1))
      continue
    fi
  done

  log_info "Memory compact: removed $removed invalid entries"
}
