#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASHCLAW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/framework.sh"

begin_test_file "test_plugin"

_source_libs() {
  export LOG_LEVEL="silent"
  for _lib in "${BASHCLAW_ROOT}"/lib/*.sh; do
    [[ -f "$_lib" ]] && source "$_lib"
  done
  unset _lib
}

# ---- _plugin_registry_dir creates directory structure ----

test_start "_plugin_registry_dir creates directory structure"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
dir="$(_plugin_registry_dir)"
if [[ -d "${dir}/registry" && -d "${dir}/tools" && -d "${dir}/hooks" && -d "${dir}/commands" && -d "${dir}/providers" ]]; then
  _test_pass
else
  _test_fail "expected plugin subdirectories to exist"
fi
teardown_test_env

# ---- plugin_is_enabled returns 0 by default (no deny/allow lists) ----

test_start "plugin_is_enabled returns 0 by default"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "plugins": {}
}
EOF
_CONFIG_CACHE=""
config_load
if plugin_is_enabled "some_plugin"; then
  _test_pass
else
  _test_fail "plugin should be enabled by default"
fi
teardown_test_env

# ---- plugin_is_enabled returns 1 when in deny list ----

test_start "plugin_is_enabled returns 1 when in deny list"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "plugins": {
    "deny": ["blocked_plugin"]
  }
}
EOF
_CONFIG_CACHE=""
config_load
set +e
plugin_is_enabled "blocked_plugin" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- plugin_is_enabled returns 1 when allow list is set and plugin is not in it ----

test_start "plugin_is_enabled returns 1 when not in allow list"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "plugins": {
    "allow": ["allowed_plugin"]
  }
}
EOF
_CONFIG_CACHE=""
config_load
set +e
plugin_is_enabled "other_plugin" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- plugin_is_enabled returns 0 when in allow list ----

test_start "plugin_is_enabled returns 0 when in allow list"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{
  "plugins": {
    "allow": ["good_plugin"]
  }
}
EOF
_CONFIG_CACHE=""
config_load
if plugin_is_enabled "good_plugin"; then
  _test_pass
else
  _test_fail "plugin in allow list should be enabled"
fi
teardown_test_env

# ---- plugin_load with valid manifest and entry script ----

test_start "plugin_load with valid manifest and entry script"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
# Create a mock plugin
plugin_dir="${BASHCLAW_STATE_DIR}/mock_plugin"
mkdir -p "$plugin_dir"
cat > "${plugin_dir}/bashclaw.plugin.json" <<'PEOF'
{"id": "mock_test", "name": "Mock Plugin", "version": "1.0.0"}
PEOF
cat > "${plugin_dir}/init.sh" <<'SEOF'
#!/usr/bin/env bash
# Plugin init - register nothing, just exist
:
SEOF
chmod +x "${plugin_dir}/init.sh"
plugin_load "$plugin_dir"
# Verify registration
reg_dir="$(_plugin_registry_dir)/registry"
assert_file_exists "${reg_dir}/mock_test.json"
teardown_test_env

# ---- plugin_load fails with missing manifest ----

test_start "plugin_load fails with missing manifest"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
empty_dir="${BASHCLAW_STATE_DIR}/no_manifest"
mkdir -p "$empty_dir"
set +e
plugin_load "$empty_dir" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- plugin_load fails with missing id in manifest ----

test_start "plugin_load fails with missing id in manifest"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
plugin_dir="${BASHCLAW_STATE_DIR}/bad_plugin"
mkdir -p "$plugin_dir"
cat > "${plugin_dir}/bashclaw.plugin.json" <<'PEOF'
{"name": "No ID Plugin"}
PEOF
set +e
plugin_load "$plugin_dir" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- plugin_register stores registration entry ----

test_start "plugin_register stores registration entry"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
# Create a mock plugin and load it
plugin_dir="${BASHCLAW_STATE_DIR}/reg_plugin"
mkdir -p "$plugin_dir"
cat > "${plugin_dir}/bashclaw.plugin.json" <<'PEOF'
{"id": "reg_test", "name": "Reg Plugin", "version": "1.0.0"}
PEOF
cat > "${plugin_dir}/init.sh" <<'SEOF'
#!/usr/bin/env bash
:
SEOF
chmod +x "${plugin_dir}/init.sh"
plugin_load "$plugin_dir"
plugin_register "reg_test" "tool" "/fake/handler.sh"
reg_dir="$(_plugin_registry_dir)/registry"
reg_file="${reg_dir}/reg_test.json"
regs="$(jq '.registrations | length' < "$reg_file")"
assert_ge "$regs" 1
teardown_test_env

# ---- plugin_register rejects invalid types ----

test_start "plugin_register rejects invalid type"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
set +e
plugin_register "test" "invalid_type" "/handler.sh" 2>/dev/null
rc=$?
set -e
assert_ne "$rc" "0"
teardown_test_env

# ---- plugin_register_tool creates tool file ----

test_start "plugin_register_tool creates tool file"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
# Create and load a plugin first
plugin_dir="${BASHCLAW_STATE_DIR}/tool_plugin"
mkdir -p "$plugin_dir"
cat > "${plugin_dir}/bashclaw.plugin.json" <<'PEOF'
{"id": "tool_test", "name": "Tool Plugin", "version": "1.0.0"}
PEOF
cat > "${plugin_dir}/init.sh" <<'SEOF'
#!/usr/bin/env bash
plugin_register_tool "custom_tool" "A custom tool" '{"type":"object","properties":{}}' "/path/to/handler.sh"
SEOF
chmod +x "${plugin_dir}/init.sh"
plugin_load "$plugin_dir"
tools_dir="$(_plugin_registry_dir)/tools"
assert_file_exists "${tools_dir}/custom_tool.json"
teardown_test_env

# ---- plugin_tool_handler retrieves handler path ----

test_start "plugin_tool_handler retrieves handler path"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
plugin_dir="${BASHCLAW_STATE_DIR}/handler_plugin"
mkdir -p "$plugin_dir"
cat > "${plugin_dir}/bashclaw.plugin.json" <<'PEOF'
{"id": "handler_test", "name": "Handler Plugin", "version": "1.0.0"}
PEOF
cat > "${plugin_dir}/init.sh" <<'SEOF'
#!/usr/bin/env bash
plugin_register_tool "lookup_tool" "A tool" '{}' "/my/handler.sh"
SEOF
chmod +x "${plugin_dir}/init.sh"
plugin_load "$plugin_dir"
handler="$(plugin_tool_handler "lookup_tool")"
assert_eq "$handler" "/my/handler.sh"
teardown_test_env

# ---- plugin_list returns JSON array ----

test_start "plugin_list returns JSON array"
setup_test_env
_source_libs
_PLUGIN_REGISTRY_DIR=""
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
plugin_dir="${BASHCLAW_STATE_DIR}/list_plugin"
mkdir -p "$plugin_dir"
cat > "${plugin_dir}/bashclaw.plugin.json" <<'PEOF'
{"id": "list_test", "name": "List Plugin", "version": "1.0.0"}
PEOF
cat > "${plugin_dir}/init.sh" <<'SEOF'
#!/usr/bin/env bash
:
SEOF
chmod +x "${plugin_dir}/init.sh"
plugin_load "$plugin_dir"
result="$(plugin_list)"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_ge "$count" 1
teardown_test_env

# ---- plugin_discover returns empty array when no plugins exist ----

test_start "plugin_discover returns empty array when no plugins exist"
setup_test_env
_source_libs
cat > "$BASHCLAW_CONFIG" <<'EOF'
{"plugins": {}}
EOF
_CONFIG_CACHE=""
config_load
result="$(plugin_discover)"
assert_json_valid "$result"
count="$(printf '%s' "$result" | jq 'length')"
assert_eq "$count" "0"
teardown_test_env

report_results
