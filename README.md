<div align="center">
<pre>
     _               _          _
    | |__   __ _ ___| |__   ___| | __ ___      __
    | '_ \ / _` / __| '_ \ / __| |/ _` \ \ /\ / /
    | |_) | (_| \__ \ | | | (__| | (_| |\ V  V /
    |_.__/ \__,_|___/_| |_|\___|_|\__,_| \_/\_/
</pre>

<h3>The zero-dependency AI assistant that works everywhere Bash does.</h3>

<p>Pure Bash + curl + jq. No Node.js. No Python. No binaries.<br>
Same architecture as <a href="https://github.com/openclaw/openclaw">OpenClaw</a>, 99% less weight.</p>

<p>
  <img src="https://img.shields.io/badge/bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white" alt="Bash 3.2+" />
  <img src="https://img.shields.io/badge/dependencies-jq%20%2B%20curl-blue" alt="Dependencies" />
  <img src="https://img.shields.io/badge/tests-334%20passed-brightgreen" alt="Tests" />
  <img src="https://img.shields.io/badge/memory-%3C%2010MB-purple" alt="Memory" />
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License" />
  </a>
</p>

<p>
  <a href="#one-line-install">Install</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#architecture">Architecture</a> &middot;
  <a href="#commands">Commands</a> &middot;
  <a href="README_CN.md">Chinese</a>
</p>
</div>

---

## Why bashclaw?

```sh
# OpenClaw needs this:
node >= 22, npm, 52 packages, playwright, sharp, 200-400MB RAM, 2-5s startup

# bashclaw needs this:
bash >= 3.2, curl, jq
# That's it. Already on your machine.
```

|                  | OpenClaw (TS)   | nanobot (Python)  | bashclaw          |
|------------------|-----------------|-------------------|-------------------|
| Runtime          | Node.js 22+     | Python 3.11+      | **Bash 3.2+**     |
| Dependencies     | 52 npm packages | pip + packages    | **jq, curl**      |
| Memory           | 200-400 MB      | 80-150 MB         | **< 10 MB**       |
| Startup          | 2-5 seconds     | 1-2 seconds       | **< 100 ms**      |
| Lines of code    | ~20,000+        | ~4,000            | **~17,300**       |
| Install          | npm/Docker      | pip/Docker        | **curl \| bash**  |
| macOS out-of-box | No (needs Node) | No (needs Python) | **Yes**           |
| Android Termux   | Complex         | Complex           | **pkg install jq** |
| Test coverage    | Unknown         | Unknown           | **334 tests**     |

### Bash 3.2: Why It Matters

```
2006-10  Bash 3.2 released (Chet Ramey, Case Western Reserve)
2007-10  macOS Leopard ships Bash 3.2 -- every Mac since then has it
2009-02  Bash 4.0 released (adds associative arrays, mapfile, |&)
2019-06  macOS Catalina switches default shell to zsh
2019-    Apple FREEZES /bin/bash at 3.2.57 forever (refuses GPLv3)
2025     Every Mac, every Linux, Android Termux -- all have Bash 3.2+
```

bashclaw targets 3.2 deliberately: no `declare -A`, no `mapfile`, no `|&`.
This means it runs on **every Mac ever shipped since 2007** without Homebrew,
every Linux distro, Android Termux (no root), Windows WSL, Alpine containers,
and Raspberry Pi. Zero compilation. Zero binary downloads.

## One-line Install

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

Or clone and run directly (zero install):

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw && ./bashclaw doctor
```

### Platform Support

| Platform              | Method               | Status              |
|-----------------------|----------------------|---------------------|
| macOS (Intel/Apple)   | curl install or git  | Works out of box    |
| Ubuntu / Debian       | curl install or git  | Works out of box    |
| Fedora / RHEL / Arch  | curl install or git  | Works out of box    |
| Alpine Linux          | apk add bash jq curl | Works               |
| Windows (WSL2)        | curl install or git  | Works               |
| Android (Termux)      | pkg install jq curl  | Works, no root      |
| Raspberry Pi          | curl install or git  | Works (< 10MB RAM)  |
| Docker / CI           | git clone            | Works               |

## Quick Start

```sh
# Step 1: Set your API key
export ANTHROPIC_API_KEY="sk-ant-..."

# Step 2: Chat
./bashclaw agent -m "What is the mass of the sun?"

# Step 3: Interactive mode
./bashclaw agent -i
```

That's it. Three commands. No config files, no wizards, no signup.

For a guided setup with channel configuration:

```sh
./bashclaw onboard
```

## Architecture

```
                          +------------------+
                          |    CLI / User    |
                          +--------+---------+
                                   |
                    +--------------+--------------+
                    |        bashclaw (main)       |
                    |    472 lines, CLI router     |
                    +--------------+--------------+
                                   |
          +------------------------+------------------------+
          |                        |                        |
  +-------+-------+      +--------+--------+      +--------+--------+
  |    Channels    |      |    Core Engine   |      | Background Sys  |
  +-------+-------+      +--------+--------+      +--------+--------+
  | telegram.sh   |      | agent.sh         |      | heartbeat.sh    |
  | discord.sh    |      | routing.sh       |      | cron.sh         |
  | slack.sh      |      | session.sh       |      | events.sh       |
  | (plugin: any) |      | tools.sh (14)    |      | process.sh      |
  +---------------+      | memory.sh        |      | daemon.sh       |
                          | config.sh        |      +-----------------+
                          +------------------+
                                   |
          +------------------------+------------------------+
          |                        |                        |
  +-------+-------+      +--------+--------+      +--------+--------+
  |   Extensions   |      |    Security      |      |     CLI Cmds    |
  +-------+-------+      +--------+--------+      +--------+--------+
  | plugin.sh      |      | 8-layer model    |      | cmd_agent.sh    |
  | skills.sh      |      | SSRF protection  |      | cmd_config.sh   |
  | hooks.sh (14)  |      | rate limiting    |      | cmd_session.sh  |
  | autoreply.sh   |      | RBAC + audit     |      | cmd_cron.sh     |
  | boot.sh        |      | pairing codes    |      | cmd_daemon.sh   |
  | dedup.sh       |      | tool policies    |      | cmd_gateway.sh  |
  +-----------------+      +-----------------+      | cmd_memory.sh   |
                                                    | cmd_hooks.sh    |
                                                    | cmd_onboard.sh  |
                                                    | cmd_message.sh  |
                                                    +-----------------+
```

### Message Flow

```
User Message
  |
  v
Dedup Check ------> [seen before?] --> discard
  |
  v
Auto-Reply Check -> [pattern match?] --> immediate reply
  |
  v
Hook: pre_message (modifying pipeline)
  |
  v
Routing (7-level priority resolution)
  |  L1: exact peer binding
  |  L2: parent peer (thread inheritance)
  |  L3: guild binding
  |  L4: channel binding
  |  L5: team binding
  |  L6: account binding
  |  L7: default agent
  v
Security Gate
  |  Rate limit --> [exceeded?] --> throttle
  |  Pairing   --> [required?] --> challenge
  |  Tool policy -> [denied?]  --> block
  |  RBAC      --> [no role?]  --> deny
  v
Process Queue (dual-layer, typed lanes)
  |  main:     max 4 concurrent
  |  cron:     max 1 concurrent
  |  subagent: max 8 concurrent
  v
Events Injection (drain queued system events)
  |
  v
Agent Runtime
  |  1. Resolve model + provider
  |  2. Load workspace files (SOUL.md, MEMORY.md, ...)
  |  3. Build system prompt (10 segments)
  |  4. Build messages from JSONL session
  |  5. API call (Anthropic/OpenAI/Google/OpenRouter)
  |  6. Tool loop (max 10 iterations)
  |  7. 5-level overflow degradation:
  |     L1: reduce history
  |     L2: auto-compaction (3 retries)
  |     L3: model fallback chain
  |     L4: session reset
  v
Session Persist (JSONL append + prune)
  |
  v
Hook: post_message
  |
  v
Delivery (format, split long messages, send)
```

### Background Systems

```
Heartbeat Loop (configurable interval)
  |
  +--> Active hours gate (08:00 - 22:00 default)
  +--> No active processing check
  +--> HEARTBEAT.md prompt injection
  +--> Meaningful reply? --> enqueue as system event
  +--> HEARTBEAT_OK?    --> discard silently

Cron Service
  |
  +--> Schedule types: at (one-shot) | every (interval) | cron (5-field)
  +--> Exponential backoff on failure (30s -> 60s -> 5m -> 15m -> 60m)
  +--> Stuck job detection (2h threshold, auto-release)
  +--> Isolated sessions (avoid polluting main conversation)

Boot Automation
  |
  +--> BOOT.md in agent workspace
  +--> Parse fenced code blocks
  +--> Execute: shell commands or agent messages
  +--> Status tracking per block
```

## LLM Providers

bashclaw supports 4 providers with automatic detection and model aliasing:

```sh
# Anthropic (default)
export ANTHROPIC_API_KEY="sk-ant-..."
bashclaw agent -m "hello"                           # uses claude-sonnet-4

# OpenAI
export OPENAI_API_KEY="sk-..."
MODEL_ID=gpt-4o bashclaw agent -m "hello"

# Google Gemini
export GOOGLE_API_KEY="..."
MODEL_ID=gemini-2.0-flash bashclaw agent -m "hello"

# OpenRouter (any model)
export OPENROUTER_API_KEY="sk-or-..."
MODEL_ID=anthropic/claude-sonnet-4 bashclaw agent -m "hello"

# Custom API-compatible endpoint
export ANTHROPIC_BASE_URL=https://your-proxy.example.com
bashclaw agent -m "hello"
```

Model aliases for quick switching:

```sh
MODEL_ID=fast    # -> gemini-2.0-flash
MODEL_ID=smart   # -> claude-opus-4
MODEL_ID=balanced # -> claude-sonnet-4
MODEL_ID=cheap   # -> gpt-4o-mini
```

## Commands

```sh
bashclaw agent    [-m MSG] [-i] [-a AGENT]   # Chat with agent
bashclaw gateway  [-p PORT] [-d] [--stop]    # Start/stop gateway
bashclaw daemon   [install|uninstall|status|logs|restart|stop]
bashclaw message  send -c CH -t TO -m MSG    # Send to channel
bashclaw config   [show|get|set|init|validate|edit|path]
bashclaw session  [list|show|clear|delete|export]
bashclaw memory   [list|get|set|delete|search|export|import|compact|stats]
bashclaw cron     [list|add|remove|enable|disable|run|history]
bashclaw hooks    [list|add|remove|enable|disable|test]
bashclaw boot     [run|find|status|reset]
bashclaw security [pair-generate|pair-verify|tool-check|elevated-check|audit]
bashclaw onboard                             # Interactive setup wizard
bashclaw status                              # System status
bashclaw doctor                              # Diagnose issues
bashclaw update                              # Update to latest
bashclaw completion [bash|zsh]               # Shell completions
```

## Built-in Tools (14)

The agent has access to these tools during conversation:

| Tool | Description | Elevation |
|------|-------------|-----------|
| `web_fetch` | HTTP GET/POST with SSRF protection | none |
| `web_search` | Web search via Brave / Perplexity | none |
| `shell` | Execute commands (security filtered) | elevated |
| `memory` | Persistent key-value store with tags | none |
| `cron` | Schedule recurring tasks | none |
| `message` | Send messages to channels | none |
| `agents_list` | List available agents | none |
| `session_status` | Current session info | none |
| `sessions_list` | List all sessions | none |
| `agent_message` | Send message to another agent | none |
| `read_file` | Read file contents (line-limited) | none |
| `write_file` | Write content to file | elevated |
| `list_files` | List directory contents | none |
| `file_search` | Search for files by pattern | none |

## Security Model (8 Layers)

```
Layer 1: SSRF Protection     -- blocks private/internal IPs in web_fetch
Layer 2: Command Filters     -- blocks rm -rf /, fork bombs, etc.
Layer 3: Pairing Codes       -- 6-digit time-limited channel auth
Layer 4: Rate Limiting       -- token-bucket per-sender (configurable)
Layer 5: Tool Policy         -- per-agent allow/deny lists
Layer 6: Elevated Policy     -- authorization for dangerous tools
Layer 7: RBAC                -- role-based command authorization
Layer 8: Audit Logging       -- JSONL trail for all security events
```

```sh
# Generate a pairing code
bashclaw security pair-generate telegram user123

# Check tool access
bashclaw security tool-check main shell main

# View audit trail
bashclaw security audit
```

## Channel Setup

### Telegram

```sh
bashclaw config set '.channels.telegram.botToken' '"YOUR_BOT_TOKEN"'
bashclaw config set '.channels.telegram.enabled' 'true'
bashclaw gateway    # starts long-poll listener
```

### Discord

```sh
bashclaw config set '.channels.discord.botToken' '"YOUR_BOT_TOKEN"'
bashclaw config set '.channels.discord.enabled' 'true'
bashclaw gateway
```

### Slack

```sh
bashclaw config set '.channels.slack.botToken' '"xoxb-YOUR-TOKEN"'
bashclaw config set '.channels.slack.enabled' 'true'
bashclaw gateway
```

## Plugin System

Extend bashclaw with custom tools, hooks, commands, and LLM providers.

```
Plugin Discovery (4 sources):
  1. ${BASHCLAW_ROOT}/extensions/     # bundled
  2. ~/.bashclaw/extensions/          # global user
  3. .bashclaw/extensions/            # workspace-local
  4. config: plugins.load.paths       # custom paths
```

Each plugin has a `bashclaw.plugin.json` manifest and an entry script:

```sh
# my-plugin/bashclaw.plugin.json
{ "id": "my-plugin", "version": "1.0.0", "description": "My custom tool" }

# my-plugin/init.sh
plugin_register_tool "my_tool" "Does something" '{"input":{"type":"string"}}' "$PWD/handler.sh"
plugin_register_hook "pre_message" "$PWD/filter.sh" 50
plugin_register_command "my_cmd" "Custom command" "$PWD/cmd.sh"
plugin_register_provider "my_llm" "My LLM" '["model-a"]' '{"envKey":"MY_KEY"}'
```

## Hook System (14 Events)

```
Event                Strategy     When
-----                --------     ----
pre_message          modifying    Before message processing (can modify input)
post_message         void         After message processing
pre_tool             modifying    Before tool execution (can modify args)
post_tool            modifying    After tool execution (can modify result)
on_error             void         When an error occurs
on_session_reset     void         When a session is reset
before_agent_start   sync         Before agent begins processing
agent_end            void         After agent finishes
before_compaction    sync         Before context compaction
after_compaction     void         After context compaction
message_received     modifying    When message arrives at gateway
message_sending      modifying    Before reply is dispatched
message_sent         void         After reply is dispatched
session_start        void         When a new session is created

Strategies:
  void      -- fire-and-forget, return value ignored
  modifying -- serial pipeline, each hook transforms data
  sync      -- blocks until complete
```

## Daemon Support

bashclaw auto-detects your init system:

```
Platform        Init System     Command
--------        -----------     -------
Linux           systemd         bashclaw daemon install --enable
macOS           launchd         bashclaw daemon install --enable
Android/other   cron            bashclaw daemon install --enable
```

```sh
bashclaw daemon install --enable   # install + start
bashclaw daemon status             # check if running
bashclaw daemon logs               # view service logs
bashclaw daemon uninstall          # stop + remove
```

## Configuration

Config file: `~/.bashclaw/bashclaw.json`

```json
{
  "agents": {
    "defaults": {
      "model": "claude-sonnet-4-20250514",
      "maxTurns": 50,
      "contextTokens": 200000,
      "tools": ["web_fetch", "web_search", "memory", "shell"]
    }
  },
  "channels": {
    "telegram": { "enabled": true, "botToken": "$TELEGRAM_BOT_TOKEN" }
  },
  "gateway": { "port": 18789 },
  "session": { "scope": "per-sender", "idleResetMinutes": 30 },
  "heartbeat": { "enabled": false },
  "cron": { "enabled": false }
}
```

Environment variables override config:

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic Claude API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `GOOGLE_API_KEY` | Google Gemini API key |
| `OPENROUTER_API_KEY` | OpenRouter API key |
| `ANTHROPIC_BASE_URL` | Custom API endpoint (for proxies) |
| `MODEL_ID` | Override default model |
| `BASHCLAW_STATE_DIR` | State directory (default: ~/.bashclaw) |
| `LOG_LEVEL` | debug \| info \| warn \| error \| silent |

## Testing

```sh
# Run all tests (334 cases, 473 assertions)
bash tests/run_all.sh

# By category
bash tests/run_all.sh --unit          # unit tests only
bash tests/run_all.sh --compat        # bash 3.2 compatibility
bash tests/run_all.sh --integration   # live API tests (needs key)

# Single suite
bash tests/test_memory.sh
bash tests/test_security.sh
bash tests/test_hooks.sh
```

| Suite | Tests | Covers |
|-------|-------|--------|
| test_utils | 25 | UUID, hash, retry, timestamp |
| test_config | 25 | Load, get, set, validate |
| test_session | 26 | JSONL, prune, idle reset, export |
| test_tools | 28 | 14 tools, SSRF, dispatch |
| test_routing | 17 | 7-level resolution, allowlist |
| test_agent | 15 | Model, messages, bootstrap |
| test_channels | 11 | Source parsing, truncation |
| test_cli | 13 | Argument parsing, routing |
| test_memory | 10 | Store, search, import/export |
| test_hooks | 7 | Register, chain, transform |
| test_security | 8 | Pairing, rate limit, RBAC |
| test_process | 13 | Queue, lanes, concurrency |
| test_boot | 2 | BOOT.md parsing |
| test_autoreply | 6 | Pattern match, filters |
| test_daemon | 3 | Install, status |
| test_install | 2 | Installer verification |
| test_heartbeat | 18 | Guard chain, active hours, events |
| test_events | 12 | FIFO queue, drain, dedup |
| test_cron_advanced | 17 | Schedule types, backoff, stuck jobs |
| test_plugin | 14 | Discover, load, register, enable |
| test_skills | 11 | Skill discovery, loading |
| test_dedup | 13 | TTL cache, expiry, cleanup |
| test_integration | 11 | Live API, multi-turn |
| test_compat | 10 | Bash 3.2 verification |

## Bash 3.2 Compatibility

All code runs on the Bash that ships with every Mac since 2006:

- No `declare -A` (associative arrays) -- uses file-based storage
- No `declare -g` (global declarations) -- uses module-level vars
- No `mapfile` / `readarray` -- uses while-read loops
- No `&>>` redirect -- uses `>> file 2>&1`
- No `|&` pipe shorthand -- uses `2>&1 |`

This means bashclaw works on:
- Every macOS version ever shipped (no Homebrew required)
- Any Linux with bash installed
- Android Termux (no root required)
- Windows WSL
- Minimal containers (Alpine + bash)
- Raspberry Pi, embedded systems

## Design Decisions

### What was removed from OpenClaw

1. **Config validation**: 6 Zod passes with 234 `.strict()` calls -> single `jq empty`
2. **Session management**: Complex merge/cache layers -> direct JSONL file ops
3. **Avatar resolution**: Base64 image encoding per request -> eliminated
4. **Logging**: 10,000+ line tslog with per-log color hashing -> `printf` + level check
5. **Tool loading**: Lazy-loaded module registry -> direct function dispatch
6. **Channel routing**: 8-adapter polymorphic interfaces -> simple case/function
7. **Startup**: 40+ async initialization steps -> instant `source` (< 100ms)

### What was preserved from OpenClaw

All the things that make OpenClaw great:

- 7-level message routing with bindings
- Multi-channel gateway architecture
- JSONL session persistence with compaction
- Workspace files (SOUL.md, MEMORY.md, BOOT.md)
- Heartbeat system with active hours
- Plugin system (4 discovery sources)
- Skills system (SKILL.md per agent)
- Advanced cron (at/every/cron + backoff)
- 8-layer security model
- Process queue with typed lanes

## License

MIT
