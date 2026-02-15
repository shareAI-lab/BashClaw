# bashclaw

Pure Bash reimplementation of the [OpenClaw](https://github.com/openclaw/openclaw) AI assistant platform.

Same architecture, same module flow, same functionality -- zero Node.js, zero npm. Just Bash + jq + curl.

[English](README.md) | [Chinese](README_CN.md)

## Why

OpenClaw is a powerful personal AI assistant gateway written in TypeScript (~20k lines). It has:

- 52 npm dependencies including heavy ones (playwright, sharp, baileys)
- 40+ sequential initialization steps on startup
- 234 redundant `.strict()` Zod schema calls
- 6+ separate config validation passes
- Uncached avatar resolution doing synchronous file I/O per request
- Complex retry/fallback logic spanning 800+ lines

**bashclaw** strips all that away:

| Metric | OpenClaw (TS) | bashclaw |
|---|---|---|
| Lines of code | ~20,000+ | ~17,300 |
| Dependencies | 52 npm packages | jq, curl (socat optional) |
| Startup time | 2-5s (Node cold start) | <100ms |
| Memory usage | 200-400MB | <10MB |
| Config validation | 6 passes + Zod | Single jq parse |
| Runtime | Node.js 22+ | Bash 3.2+ |
| Test suites | unknown | 18 suites, 222 cases, 320 assertions |

## One-line Install

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

Or clone manually:

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw
chmod +x bashclaw
```

### Requirements

- **bash** 3.2+ (macOS default works, Linux, Termux on Android)
- **jq** - JSON processing (auto-installed by installer)
- **curl** - HTTP requests
- **socat** (optional) - gateway HTTP server

```sh
# macOS
brew install jq curl socat

# Ubuntu/Debian
apt install jq curl socat

# Android (Termux, no root needed)
pkg install jq curl
```

## Quick Start

```sh
# Interactive setup wizard
./bashclaw onboard

# Or manual: set API key
export ANTHROPIC_API_KEY="your-key"

# Interactive chat
./bashclaw agent -i

# Single message
./bashclaw agent -m "What is the capital of France?"

# Check system health
./bashclaw doctor

# Install as background daemon
./bashclaw daemon install --enable
```

## Architecture

```sh
bashclaw/
  bashclaw                # Main entry point and CLI router (472 lines)
  install.sh              # Standalone installer (cross-platform)
  lib/
    # -- Core --
    log.sh                # Logging subsystem (levels, color, file output)
    utils.sh              # General utilities (retry, port check, uuid, tmpfile, etc.)
    config.sh             # Configuration (jq-based, env var substitution)
    session.sh            # JSONL session persistence (per-sender/channel/global, compaction)
    agent.sh              # Agent runtime (Anthropic/OpenAI API, tool loop, bootstrap files)
    tools.sh              # Built-in tools (14 tools: web, shell, memory, cron, files, etc.)
    routing.sh            # 7-level priority message routing and dispatch
    memory.sh             # Long-term memory (file-based key-value store with tags)

    # -- Background Systems --
    heartbeat.sh          # Periodic autonomous agent check-ins with active-hours gating
    events.sh             # System events queue (FIFO, dedup, drain-on-next-turn)
    cron.sh               # Advanced cron (at/every/cron schedules, backoff, isolated sessions)
    process.sh            # Dual-layer command queue with typed lanes and concurrency control
    daemon.sh             # Daemon management (systemd/launchd/cron)

    # -- Extensions --
    plugin.sh             # Plugin system (discover, load, register tools/hooks/commands/providers)
    skills.sh             # Skills system (SKILL.md prompt-level capabilities per agent)
    dedup.sh              # Idempotency / deduplication cache (TTL-based, file-backed)
    hooks.sh              # 14-event hook/middleware pipeline (void/modifying/sync strategies)
    boot.sh               # Boot automation (BOOT.md parsing, agent workspace integration)
    autoreply.sh          # Pattern-based auto-reply rules
    security.sh           # 8-layer security (audit, pairing, rate limit, tool policy, elevated, RBAC)

    # -- CLI Commands --
    cmd_agent.sh          # CLI: agent command (interactive mode)
    cmd_gateway.sh        # CLI: gateway server (WebSocket/HTTP)
    cmd_config.sh         # CLI: config management
    cmd_session.sh        # CLI: session management
    cmd_message.sh        # CLI: send messages
    cmd_memory.sh         # CLI: memory management
    cmd_cron.sh           # CLI: cron job management
    cmd_hooks.sh          # CLI: hook management
    cmd_daemon.sh         # CLI: daemon management
    cmd_onboard.sh        # CLI: setup wizard

  channels/
    telegram.sh           # Telegram Bot API (long-poll)
    discord.sh            # Discord Bot API (HTTP poll)
    slack.sh              # Slack Bot API (conversations poll)
  gateway/
    http_handler.sh       # HTTP request handler for socat gateway
  tests/
    framework.sh          # Test framework (assertions, setup/teardown)
    test_*.sh             # 18 test suites, 222 test cases
    run_all.sh            # Test runner (unit, integration, compat modes)
  .github/workflows/
    ci.yml                # CI: unit + compat tests on push/PR
    integration.yml       # Integration tests (weekly + manual)
```

### Module Flow

```sh
Channel (Telegram/Discord/Slack/CLI)
  -> Dedup Check (idempotency cache, skip duplicate messages)
  -> Auto-Reply Check (pattern match -> immediate response)
  -> Hooks: pre_message (middleware pipeline)
  -> Routing (7-level priority: sender/guild/channel/team -> agent resolution)
    -> Security (8 layers: rate limit, pairing, tool policy, elevated, RBAC)
    -> Process Queue (dual-layer: typed lanes + concurrency control per agent)
    -> Events Injection (drain queued system events into message context)
    -> Agent Runtime (model selection, bootstrap files, API call, tool loop)
      -> Hooks: pre_tool / post_tool
      -> Tools (web_fetch, web_search, shell, memory, cron, files, message, ...)
      -> Plugin Tools (dynamically registered by loaded plugins)
    -> Session (JSONL append, prune, context compaction, idle reset)
  -> Hooks: post_message
  -> Delivery (format reply, split long messages, send)

Background Systems:
  Heartbeat Loop -> Active-hours gating -> HEARTBEAT.md prompt -> Agent turn
  Cron Service   -> Schedule check -> Isolated/main session -> Backoff on failure
  Events Queue   -> Enqueue from background -> Drain on next agent turn

Boot Automation:
  BOOT.md -> Parse code blocks -> Execute (shell / agent message) -> Status tracking

Plugin System:
  Discover (4 sources) -> Load -> Register (tools, hooks, commands, providers)

Skills:
  Agent workspace -> SKILL.md files -> Inject into system prompt -> On-demand load

Daemon:
  systemd (Linux) / launchd (macOS) / cron (fallback)
```

## Commands

```sh
bashclaw agent [-m MSG] [-i] [-a AGENT]   # Chat with agent
bashclaw gateway [-p PORT] [-d] [--stop]   # Start/stop gateway
bashclaw daemon [install|uninstall|status|logs|restart|stop]
bashclaw message send -c CH -t TO -m MSG   # Send to channel
bashclaw config [show|get|set|init|validate|edit|path]
bashclaw session [list|show|clear|delete|export]
bashclaw memory [list|get|set|delete|search|export|import|compact|stats]
bashclaw cron [list|add|remove|enable|disable|run|history]
bashclaw hooks [list|add|remove|enable|disable|test]
bashclaw boot [run|find|status|reset]      # Agent boot automation
bashclaw security [pair-generate|pair-verify|tool-check|elevated-check|audit]
bashclaw onboard                           # Interactive setup wizard
bashclaw status                            # System status
bashclaw doctor                            # Diagnose issues
bashclaw update                            # Update to latest
bashclaw completion [bash|zsh]             # Shell completions
bashclaw version                           # Version info
```

## Configuration

Config file: `~/.bashclaw/bashclaw.json`

```json
{
  "agents": {
    "defaults": {
      "model": "claude-sonnet-4-20250514",
      "maxTokens": 8192,
      "maxTurns": 50,
      "contextTokens": 200000,
      "systemPrompt": "You are a helpful personal AI assistant.",
      "temperature": 0.7,
      "tools": ["web_fetch", "web_search", "memory", "shell", "message", "cron"]
    },
    "list": []
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "$TELEGRAM_BOT_TOKEN"
    }
  },
  "gateway": {
    "port": 18789,
    "auth": { "token": "$BASHCLAW_GATEWAY_TOKEN" }
  },
  "session": {
    "scope": "per-sender",
    "maxHistory": 200,
    "idleResetMinutes": 30
  },
  "heartbeat": {
    "enabled": false
  },
  "cron": {
    "enabled": false,
    "maxConcurrentRuns": 1
  },
  "plugins": {
    "allow": [],
    "deny": [],
    "load": { "paths": [] }
  },
  "security": {
    "elevatedUsers": [],
    "commands": {},
    "userRoles": {}
  }
}
```

### Environment Variables

| Variable | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic Claude API key |
| `ANTHROPIC_BASE_URL` | Custom API base URL (for proxies/compatible APIs) |
| `MODEL_ID` | Override default model name |
| `OPENAI_API_KEY` | OpenAI API key |
| `BRAVE_SEARCH_API_KEY` | Brave Search API |
| `PERPLEXITY_API_KEY` | Perplexity API |
| `BASHCLAW_STATE_DIR` | State directory (default: ~/.bashclaw) |
| `BASHCLAW_CONFIG` | Config file path override |
| `LOG_LEVEL` | Log level: debug, info, warn, error, fatal, silent |
| `BASHCLAW_BOOTSTRAP_MAX_CHARS` | Max chars per bootstrap file in system prompt (default: 20000) |
| `TOOL_WEB_FETCH_MAX_CHARS` | Max response body size for web_fetch (default: 102400) |
| `TOOL_SHELL_TIMEOUT` | Shell command timeout in seconds (default: 30) |
| `TOOL_READ_FILE_MAX_LINES` | Max lines for read_file tool (default: 2000) |
| `TOOL_LIST_FILES_MAX` | Max entries for list_files tool (default: 500) |

### Custom API Endpoints

bashclaw supports any Anthropic-compatible API via `ANTHROPIC_BASE_URL`:

```sh
# Use with BigModel/GLM
export ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic
export MODEL_ID=glm-5

# Use with any compatible proxy
export ANTHROPIC_BASE_URL=https://your-proxy.example.com
```

## Channel Setup

### Telegram

```sh
./bashclaw config set '.channels.telegram.botToken' '"YOUR_BOT_TOKEN"'
./bashclaw config set '.channels.telegram.enabled' 'true'
./bashclaw gateway  # starts Telegram long-poll listener
```

### Discord

```sh
./bashclaw config set '.channels.discord.botToken' '"YOUR_BOT_TOKEN"'
./bashclaw config set '.channels.discord.enabled' 'true'
./bashclaw gateway
```

### Slack

```sh
./bashclaw config set '.channels.slack.botToken' '"xoxb-YOUR-TOKEN"'
./bashclaw config set '.channels.slack.enabled' 'true'
./bashclaw gateway
```

## Built-in Tools

| Tool | Description |
|---|---|
| `web_fetch` | HTTP requests with SSRF protection |
| `web_search` | Web search (Brave/Perplexity) |
| `shell` | Execute commands (with security filters) |
| `memory` | Persistent key-value store with tags and search |
| `message` | Send messages to channels |
| `cron` | Schedule recurring tasks |
| `agents_list` | List available agents |
| `session_status` | Current session information |
| `sessions_list` | List all sessions |
| `agent_message` | Send a message to another agent |
| `read_file` | Read file contents (line-limited) |
| `write_file` | Write content to a file |
| `list_files` | List directory contents |
| `file_search` | Search for files by pattern |

## Heartbeat System

The heartbeat system enables periodic autonomous agent check-ins. An agent can perform scheduled self-directed actions (e.g., checking reminders, monitoring systems) without user prompts.

```sh
# Enable globally
./bashclaw config set '.heartbeat.enabled' 'true'

# Per-agent heartbeat config
./bashclaw config set '.agents.list[0].heartbeat.enabled' 'true'
./bashclaw config set '.agents.list[0].heartbeat.interval' '"30m"'
./bashclaw config set '.agents.list[0].heartbeat.activeHours.start' '"08:00"'
./bashclaw config set '.agents.list[0].heartbeat.activeHours.end' '"22:00"'
./bashclaw config set '.agents.list[0].heartbeat.timezone' '"local"'
```

Guard chain (6 checks before a heartbeat runs):

1. Global heartbeat enabled
2. Agent-level heartbeat not disabled
3. Interval is valid (> 0)
4. Current time within active hours (supports cross-midnight windows)
5. No active processing (no lane locks held)
6. HEARTBEAT.md file exists and has content

The heartbeat prompt instructs the agent to read HEARTBEAT.md and follow it. If nothing needs attention, the agent replies with `HEARTBEAT_OK` and the response is silently discarded. Meaningful responses are deduplicated (24h window) and enqueued as system events for the main session.

## Plugin System

Plugins extend bashclaw with custom tools, hooks, commands, and LLM providers. Plugins are discovered from 4 source directories:

1. **Bundled**: `${BASHCLAW_ROOT}/extensions/`
2. **Global**: `~/.bashclaw/extensions/`
3. **Workspace**: `.bashclaw/extensions/` (relative to cwd)
4. **Config**: `plugins.load.paths` (custom paths array)

Each plugin directory contains a `bashclaw.plugin.json` manifest and an entry script (`init.sh` or `<id>.sh`). Entry scripts register components using:

```sh
# Register a custom tool
plugin_register_tool "my_tool" "Description" '{"param1":{"type":"string"}}' "/path/to/handler.sh"

# Register a hook
plugin_register_hook "pre_message" "/path/to/hook.sh" 50

# Register a CLI command
plugin_register_command "my_cmd" "Description" "/path/to/cmd.sh"

# Register an LLM provider
plugin_register_provider "my_llm" "My LLM" '["model-a","model-b"]' '{"envKey":"MY_API_KEY"}'
```

Plugin allow/deny lists control which plugins load:

```json
{
  "plugins": {
    "allow": ["plugin-a"],
    "deny": ["plugin-b"],
    "entries": {
      "plugin-c": { "enabled": false }
    }
  }
}
```

## Skills System

Skills are prompt-level capabilities stored as directories under an agent's workspace. Each skill directory contains a `SKILL.md` (required) and an optional `skill.json` metadata file.

```sh
~/.bashclaw/agents/main/skills/
  code-review/
    SKILL.md          # Detailed instructions for the agent
    skill.json        # { "description": "Review code", "tags": ["dev"] }
  summarize/
    SKILL.md
    skill.json
```

Available skills are automatically listed in the agent's system prompt. The agent can load a specific skill's SKILL.md on demand for detailed instructions.

## Advanced Cron

The cron system supports three schedule types:

| Type | Format | Example |
|---|---|---|
| `at` | One-shot ISO timestamp | `{"kind":"at","at":"2025-12-01T09:00:00Z"}` |
| `every` | Interval in milliseconds | `{"kind":"every","everyMs":3600000}` |
| `cron` | 5-field cron expression with timezone | `{"kind":"cron","expr":"0 9 * * 1","tz":"America/New_York"}` |

Features:

- **Exponential backoff**: Failed jobs back off at 30s, 60s, 5m, 15m, 60m (capped)
- **Stuck job detection**: Runs exceeding the stuck threshold (default 2h) are auto-released
- **Isolated sessions**: Jobs can run in dedicated sessions to avoid polluting the main conversation
- **Concurrent run limits**: Configurable max concurrent cron runs (default: 1)
- **Session reaping**: Old isolated cron sessions are cleaned up after the retention period
- **Run history**: All job executions are logged to `cron/history/runs.jsonl`

```sh
# List cron jobs
./bashclaw cron list

# Add a job
./bashclaw cron add --id daily-summary --schedule '{"kind":"cron","expr":"0 9 * * *"}' --prompt "Summarize today"

# View run history
./bashclaw cron history

# Manually trigger a job
./bashclaw cron run daily-summary
```

## Events Queue

Background processes (heartbeat, cron, async commands) enqueue system events. These events are drained and injected into the agent's message context on the next user-initiated turn.

- FIFO queue per session (max 20 events)
- Consecutive identical events are deduplicated
- File-based with lockfile concurrency control
- Events appear as `[SYSTEM EVENT]` prefixed messages in the agent context

## Deduplication Cache

The dedup module provides TTL-based idempotency checking for message processing:

- File-backed cache in `${BASHCLAW_STATE_DIR}/dedup/`
- Configurable TTL per check (default 300 seconds)
- Generates composite keys from channel + sender + content hash
- Automatic cleanup of expired entries
- Prevents duplicate message processing from channel polling

## Security Model (8 Layers)

bashclaw implements defense-in-depth security:

| Layer | Module | Description |
|---|---|---|
| 1. SSRF Protection | `tools.sh` | Blocks private/internal IPs in web_fetch |
| 2. Command Filters | `security.sh` | Blocks dangerous shell patterns (rm -rf /, fork bombs, etc.) |
| 3. Pairing Codes | `security.sh` | 6-digit time-limited codes for channel authentication |
| 4. Rate Limiting | `security.sh` | Token-bucket per-sender rate limiter (configurable per-minute cap) |
| 5. Tool Policy | `security.sh` | Per-agent allow/deny lists, session-type restrictions (subagent/cron) |
| 6. Elevated Policy | `security.sh` | Elevated authorization for dangerous tools (shell, write_file) |
| 7. Command Auth / RBAC | `security.sh` | Role-based access control for named commands |
| 8. Audit Logging | `security.sh` | JSONL audit trail for all security-relevant events |

```sh
# Generate a pairing code
./bashclaw security pair-generate telegram user123

# Verify a pairing code
./bashclaw security pair-verify telegram user123 482910

# Check if a tool is allowed
./bashclaw security tool-check main shell main

# Check elevated authorization
./bashclaw security elevated-check shell user123 telegram

# View audit log (last 20 entries)
./bashclaw security audit
```

## Hook System

The hook system provides a 14-event middleware pipeline with three execution strategies:

**Events:**

| Event | Strategy | Description |
|---|---|---|
| `pre_message` | modifying | Before message is processed (can modify input) |
| `post_message` | void | After message is processed |
| `pre_tool` | modifying | Before tool execution (can modify args) |
| `post_tool` | modifying | After tool execution (can modify result) |
| `on_error` | void | When an error occurs |
| `on_session_reset` | void | When a session is reset |
| `before_agent_start` | sync | Before agent begins processing |
| `agent_end` | void | After agent finishes processing |
| `before_compaction` | sync | Before context compaction |
| `after_compaction` | void | After context compaction |
| `message_received` | modifying | When a message arrives at the gateway |
| `message_sending` | modifying | Before a reply is dispatched |
| `message_sent` | void | After a reply is dispatched |
| `session_start` | void | When a new session is created |

**Execution strategies:**
- `void`: Parallel fire-and-forget, return value ignored
- `modifying`: Serial pipeline, each hook can modify the input JSON
- `sync`: Synchronous hot-path, blocks until complete

```sh
# List hooks
./bashclaw hooks list

# Add a hook
./bashclaw hooks add --name log-messages --event pre_message --handler /path/to/script.sh

# Test a hook
./bashclaw hooks test log-messages '{"text":"hello"}'

# Enable/disable
./bashclaw hooks enable log-messages
./bashclaw hooks disable log-messages
```

## Process Queue

The process queue implements dual-layer concurrency control:

- **Layer 1**: Original FIFO queue per agent (backward compatible)
- **Layer 2**: Typed lanes with configurable concurrency limits
  - `main` lane: max 4 concurrent (configurable)
  - `cron` lane: max 1 concurrent
  - `subagent` lane: max 8 concurrent
- File-based lockfiles for cross-process safety
- Queue mode support: per-agent and global
- Abort mechanism for canceling queued commands

## Daemon Support

bashclaw can run as a system service with automatic restart:

```sh
# Install and enable (auto-detects systemd/launchd/cron)
./bashclaw daemon install --enable

# Check status
./bashclaw daemon status

# View logs
./bashclaw daemon logs

# Stop and uninstall
./bashclaw daemon uninstall
```

Supported init systems:
- **systemd** (Linux)
- **launchd** (macOS)
- **cron** (universal fallback, including Android/Termux)

## Testing

```sh
# Run all tests (222 test cases, 320 assertions)
bash tests/run_all.sh

# Run only unit tests
bash tests/run_all.sh --unit

# Run only compatibility tests
bash tests/run_all.sh --compat

# Run integration tests (requires API key)
bash tests/run_all.sh --integration

# Run a single test suite
bash tests/test_memory.sh
bash tests/test_hooks.sh
bash tests/test_security.sh

# Run with verbose output
bash tests/run_all.sh --verbose
```

### Test Coverage

| Suite | Tests | What it covers |
|---|---|---|
| test_utils | 25 | UUID, hash, url_encode, retry, trim, timestamp |
| test_config | 25 | Load, get, set, validate, agent/channel config |
| test_session | 26 | JSONL persistence, prune, idle reset, export |
| test_tools | 28 | Tool dispatch, web_fetch, shell, memory, cron, files |
| test_routing | 17 | 7-level agent resolution, allowlist, mention-gating, reply format |
| test_agent | 15 | Model resolution, message building, tool spec, bootstrap |
| test_channels | 11 | Channel source, max length, message truncation |
| test_cli | 13 | CLI argument parsing, subcommand routing |
| test_memory | 10 | Store, get, search, list, delete, import/export |
| test_hooks | 7 | Register, run, chain, enable/disable, transform, 14 events |
| test_security | 8 | Pairing codes, rate limit, audit log, exec approval, tool policy |
| test_process | 3 | Queue FIFO, dequeue, status, typed lanes |
| test_boot | 2 | BOOT.md parsing, status tracking |
| test_autoreply | 6 | Rule add/remove, pattern match, channel filter |
| test_daemon | 3 | Install, uninstall, status |
| test_install | 2 | Installer help, prefix option |
| test_integration | 11 | Live API calls, multi-turn, tool use, concurrency |
| test_compat | 10 | Bash 3.2 compat, no declare -A/-g, key functions |

## Design Decisions

### Eliminated Redundancies from OpenClaw

1. **Config validation**: Single jq parse replaces 6 Zod validation passes with 234 `.strict()` calls
2. **Session management**: Direct JSONL file ops replace complex merging/caching layers
3. **Avatar resolution**: Eliminated entirely (no base64 encoding of images per request)
4. **Logging**: Simple level check + printf replaces 10,000+ line tslog subsystem with per-log color hashing
5. **Tool loading**: Direct function dispatch replaces lazy-loaded module registry
6. **Channel routing**: Simple case/function pattern replaces 8-adapter-type polymorphic interfaces
7. **Startup**: Instant (source scripts) replaces 40+ sequential async initialization steps

### Bash 3.2 Compatibility

All code works on macOS default bash (3.2), Linux, and Android Termux without root:

- No associative arrays (`declare -A`)
- No `declare -g` (global declarations)
- No `mapfile` / `readarray`
- No `&>>` redirect operator
- File-based state tracking replaces in-memory maps
- Cross-platform fallback chains for system commands

### Security

- SSRF protection on `web_fetch` (blocks private IPs)
- Command execution safety filters (blocks `rm -rf /`, fork bombs, etc.)
- Pairing codes for channel authentication
- Per-sender token-bucket rate limiting
- Per-agent tool allow/deny policy lists
- Elevated authorization checks for dangerous tools
- Role-based command authorization (RBAC)
- Audit logging (JSONL) for all security events
- Config file permissions (chmod 600)

## License

MIT
