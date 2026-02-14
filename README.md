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
| Lines of code | ~20,000+ | ~10,400 |
| Dependencies | 52 npm packages | jq, curl (socat optional) |
| Startup time | 2-5s (Node cold start) | <100ms |
| Memory usage | 200-400MB | <10MB |
| Config validation | 6 passes + Zod | Single jq parse |
| Runtime | Node.js 22+ | Bash 3.2+ |
| Test cases | unknown | 222 (320 assertions) |

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
  bashclaw                # Main entry point and CLI router (362 lines)
  install.sh              # Standalone installer (cross-platform)
  lib/
    log.sh                # Logging subsystem (levels, color, file output)
    utils.sh              # General utilities (retry, port check, uuid, etc.)
    config.sh             # Configuration (jq-based, env var substitution)
    session.sh            # JSONL session persistence (per-sender/channel/global)
    agent.sh              # Agent runtime (Anthropic/OpenAI API, tool loop)
    tools.sh              # Built-in tools (web_fetch, shell, memory, cron, etc.)
    routing.sh            # Message routing and dispatch
    memory.sh             # Long-term memory (file-based key-value store)
    hooks.sh              # Event-driven hook/middleware pipeline
    boot.sh               # Boot automation (parse BOOT.md, execute blocks)
    autoreply.sh          # Pattern-based auto-reply rules
    process.sh            # Command queue with concurrency lanes
    security.sh           # Audit logging, pairing codes, rate limiting
    daemon.sh             # Daemon management (systemd/launchd/cron)
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
  -> Auto-Reply Check (pattern match -> immediate response)
  -> Hooks: pre_message (middleware pipeline)
  -> Routing (allowlist, mention-gating, agent resolution)
    -> Security (rate limit, pairing code, exec approval)
    -> Process Queue (concurrency lanes per agent)
    -> Agent Runtime (model selection, API call, tool loop)
      -> Hooks: pre_tool / post_tool
      -> Tools (web_fetch, shell, memory, cron, message)
    -> Session (JSONL append, prune, idle reset)
  -> Hooks: post_message
  -> Delivery (format reply, split long messages, send)

Boot Automation:
  BOOT.md -> Parse code blocks -> Execute (shell / agent message)

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
      "systemPrompt": "You are a helpful personal AI assistant.",
      "temperature": 0.7,
      "tools": ["web_fetch", "web_search", "memory", "shell", "message", "cron"]
    },
    "main": {}
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
    "maxHistory": 100,
    "idleResetMinutes": 0
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
| test_tools | 28 | Tool dispatch, web_fetch, shell, memory, cron |
| test_routing | 17 | Agent resolution, allowlist, mention-gating, reply format |
| test_agent | 15 | Model resolution, message building, tool spec |
| test_channels | 11 | Channel source, max length, message truncation |
| test_cli | 13 | CLI argument parsing, subcommand routing |
| test_memory | 10 | Store, get, search, list, delete, import/export |
| test_hooks | 7 | Register, run, chain, enable/disable, transform |
| test_security | 8 | Pairing codes, rate limit, audit log, exec approval |
| test_process | 3 | Queue FIFO, dequeue, status |
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
- Per-sender rate limiting
- Audit logging (JSONL) for all security events
- Config file permissions (chmod 600)

## License

MIT
