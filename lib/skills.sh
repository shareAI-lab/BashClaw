#!/usr/bin/env bash
# Skills system for bashclaw
# Skills are prompt-level capabilities: directories containing SKILL.md and skill.json.
# Compatible with bash 3.2+ (no declare -A, no declare -g, no mapfile)

# Discover available skills for an agent.
# Scans ${BASHCLAW_STATE_DIR}/agents/${agent_id}/skills/ for skill directories.
# Each valid skill directory contains at least a SKILL.md file.
# Returns JSON array of skill metadata.
skills_discover() {
  local agent_id="${1:?agent_id required}"

  require_command jq "skills_discover requires jq"

  local skills_dir="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/agents/${agent_id}/skills"
  local results="[]"

  if [[ ! -d "$skills_dir" ]]; then
    printf '%s' "$results"
    return 0
  fi

  local d
  for d in "${skills_dir}"/*/; do
    [[ -d "$d" ]] || continue

    local skill_md="${d}SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
      continue
    fi

    local skill_name
    skill_name="$(basename "$d")"

    local meta="{}"
    local skill_json="${d}skill.json"
    if [[ -f "$skill_json" ]] && jq empty < "$skill_json" 2>/dev/null; then
      meta="$(jq '.' < "$skill_json")"
    fi

    results="$(printf '%s' "$results" | jq \
      --arg name "$skill_name" \
      --arg dir "$d" \
      --argjson meta "$meta" \
      '. + [{name: $name, dir: $dir, meta: $meta}]')"
  done

  printf '%s' "$results"
}

# List metadata for all available skills.
# Returns JSON array with name, description, and tags for each skill.
skills_list() {
  local agent_id="${1:?agent_id required}"

  require_command jq "skills_list requires jq"

  local discovered
  discovered="$(skills_discover "$agent_id")"

  local count
  count="$(printf '%s' "$discovered" | jq 'length')"
  if [[ "$count" -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  local result="[]"
  local idx=0
  while [ "$idx" -lt "$count" ]; do
    local name desc tags
    name="$(printf '%s' "$discovered" | jq -r ".[$idx].name")"
    desc="$(printf '%s' "$discovered" | jq -r ".[$idx].meta.description // \"No description\"")"
    tags="$(printf '%s' "$discovered" | jq ".[$idx].meta.tags // []")"

    result="$(printf '%s' "$result" | jq \
      --arg n "$name" \
      --arg d "$desc" \
      --argjson t "$tags" \
      '. + [{name: $n, description: $d, tags: $t}]')"
    idx=$((idx + 1))
  done

  printf '%s' "$result"
}

# Load the SKILL.md content for a specific skill.
# Returns the raw markdown text.
skills_load() {
  local agent_id="${1:?agent_id required}"
  local skill_name="${2:?skill_name required}"

  local safe_name
  safe_name="$(printf '%s' "$skill_name" | tr -c '[:alnum:]._-' '_' | head -c 200)"

  local skill_md="${BASHCLAW_STATE_DIR:?BASHCLAW_STATE_DIR not set}/agents/${agent_id}/skills/${safe_name}/SKILL.md"

  if [[ ! -f "$skill_md" ]]; then
    log_error "Skill not found: $skill_name for agent $agent_id"
    return 1
  fi

  cat "$skill_md"
}

# Generate a skills availability section for injection into the system prompt.
# Lists available skills so the agent knows what it can request.
# Returns a formatted text block, or empty string if no skills exist.
skills_inject_prompt() {
  local agent_id="${1:?agent_id required}"

  require_command jq "skills_inject_prompt requires jq"

  local skills_json
  skills_json="$(skills_list "$agent_id")"

  local count
  count="$(printf '%s' "$skills_json" | jq 'length')"
  if [[ "$count" -eq 0 ]]; then
    return 0
  fi

  printf '## Available Skills\n'
  printf 'You have access to the following skills. To use a skill, read its SKILL.md for detailed instructions.\n\n'

  local idx=0
  while [ "$idx" -lt "$count" ]; do
    local name desc
    name="$(printf '%s' "$skills_json" | jq -r ".[$idx].name")"
    desc="$(printf '%s' "$skills_json" | jq -r ".[$idx].description")"
    printf -- '- **%s**: %s\n' "$name" "$desc"
    idx=$((idx + 1))
  done

  printf '\nTo load a skill, use: skills_load("%s", "<skill_name>")\n' "$agent_id"
}
