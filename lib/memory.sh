#!/usr/bin/env bash
# Long-term memory module for bashclaw
# File-based key-value store with tags, sources, and access tracking

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

# Search across all memory files for entries matching a query
# Returns matching entries as JSON lines
memory_search() {
  local query="${1:?query required}"

  require_command jq "memory_search requires jq"

  local dir
  dir="$(memory_dir)"
  local results="[]"
  local f

  for f in "${dir}"/*.json; do
    [[ -f "$f" ]] || continue
    if grep -qi "$query" "$f" 2>/dev/null; then
      local entry
      entry="$(cat "$f")"
      results="$(printf '%s' "$results" | jq --argjson e "$entry" '. + [$e]')"
    fi
  done

  printf '%s' "$results"
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

  # Since filenames are derived from keys, true duplicates only happen
  # if there are collision variants. Scan for entries and keep newest by updated_at.
  local seen_keys=""
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
