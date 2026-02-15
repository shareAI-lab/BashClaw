<div align="center">

<img src="assets/logo.png" alt="BashClaw" width="600" />

**Bash is all you need.**

Pure-shell AI agent runtime. No Node.js, no Python, no compiled binaries.

<p>
  <img src="https://img.shields.io/badge/bash-3.2%2B_(2006)-4EAA25?logo=gnubash&logoColor=white" alt="Bash 3.2+" />
  <img src="https://img.shields.io/badge/deps-jq%20%2B%20curl-blue" alt="Dependencies" />
  <img src="https://img.shields.io/badge/tests-334%20pass-brightgreen" alt="Tests" />
  <img src="https://img.shields.io/badge/RAM-%3C%2010MB-purple" alt="Memory" />
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT" />
  </a>
</p>

<p>
  <a href="#install">Install</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#features">Features</a> &middot;
  <a href="#web-dashboard">Dashboard</a> &middot;
  <a href="#providers">Providers</a> &middot;
  <a href="#channels">Channels</a> &middot;
  <a href="#architecture">Architecture</a> &middot;
  <a href="README_CN.md">&#x4E2D;&#x6587;</a>
</p>
</div>

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

Or clone directly:

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw && ./bashclaw doctor
```

## Quick Start

```sh
export ANTHROPIC_API_KEY="sk-ant-..."   # or OPENAI_API_KEY, GOOGLE_API_KEY, etc.

bashclaw agent -m "What is the mass of the sun?"   # one-shot
bashclaw agent -i                                    # interactive REPL
bashclaw onboard                                     # guided setup wizard
bashclaw gateway                                     # web dashboard + channels
```

## Why BashClaw

```
+---------------------+------------------+------------------+
|                     |  OpenClaw (TS)   | BashClaw (Bash)  |
+---------------------+------------------+------------------+
| Runtime             | Node.js 22+      | Bash 3.2+        |
| Dependencies        | 52 npm packages  | jq + curl        |
| Memory              | 200-400 MB       | < 10 MB          |
| Cold start          | 2-5 seconds      | < 100 ms         |
| Install             | npm / Docker     | curl | bash      |
| macOS out-of-box    | No (needs Node)  | Yes              |
| Android Termux      | Complex          | pkg install jq   |
| Hot self-modify     | No (needs build) | Yes              |
| Tests               | Vitest           | 334 pass         |
+---------------------+------------------+------------------+
```

BashClaw is shell script -- the agent can **read, modify, and reload its own source code** at runtime. No compilation, no restart, instant self-bootstrapping.

### Bash 3.2: Universal Runtime

Bash 3.2 was released in **October 2006** as the last GPLv2-licensed version. Apple froze it on every Mac starting with macOS Leopard (2007) and has shipped 3.2 on every Mac since, because later versions (4.0+) switched to GPLv3 which conflicts with Apple's licensing policy.

BashClaw targets Bash 3.2 deliberately: no `declare -A`, no `mapfile`, no `|&`. This means it runs on:

- **macOS** -- every version since 2007, zero additional installs
- **Linux** -- any distribution (Ubuntu, Debian, Fedora, Alpine, Arch...)
- **Android Termux** -- no root required
- **Windows** -- WSL2, Git Bash, Cygwin
- **Embedded** -- Alpine containers, Raspberry Pi, CI runners, NAS boxes

## Features

- **Pure shell** -- Zero dependencies beyond bash 3.2, curl, jq. Already on your machine.
- **Self-modifying** -- Agent hot-patches its own source at runtime. No compilation step.
- **Multi-provider** -- 9 providers: Claude, GPT, Gemini, DeepSeek, Qwen, Zhipu GLM, Moonshot, MiniMax, OpenRouter.
- **Multi-channel** -- Telegram, Discord, Slack, Feishu/Lark. Each channel is one shell script.
- **Web dashboard** -- Built-in browser UI for chat, config, and monitoring. No external tools.
- **14 built-in tools** -- Web fetch, search, shell exec, memory, cron, file I/O, inter-agent messaging.
- **Plugin system** -- 4 discovery paths. Register tools, hooks, commands, providers.
- **8-layer security** -- SSRF protection, command filters, pairing codes, rate limiting, RBAC, audit.
- **Session management** -- 5 scope modes, JSONL persistence, idle reset, context compaction.
- **Cron scheduler** -- `at` / `every` / `cron` expressions, backoff, stuck job detection.
- **14 hook events** -- Pre/post message, tool, compaction, session lifecycle. Modifying + sync strategies.
- **Hot config reload** -- `kill -USR1` the gateway to reload without restart.
- **Daemon support** -- systemd, launchd, Termux boot, crontab fallback.
- **334 tests** -- Unit, compatibility (Bash 3.2 verification), integration. 473 assertions.

## Web Dashboard

Start the gateway and open `http://localhost:18789`:

```sh
bashclaw gateway
```

```
+-------------------------------------------------------+
|  BashClaw Dashboard          [Chat] [Settings] [Status]|
+-------------------------------------------------------+
|                                                        |
|  You: What's the weather in Tokyo?                     |
|                                                        |
|  Agent: Let me check that for you...                   |
|  [tool: web_search] ...                                |
|  Currently 12C and partly cloudy in Tokyo.             |
|                                                        |
|  [____________________________________] [Send]         |
+-------------------------------------------------------+
```

**Chat** -- Talk to the agent from the browser. No channel setup needed.
**Settings** -- API keys, model selection, channel status. Keys stored server-side only.
**Status** -- Gateway state, active sessions, provider info.
**First-run** -- If no API key is set, shows a setup overlay on first visit.

### Web + CLI Dual Mode

Both modes share the same config, sessions, and state. Changes in the dashboard take effect in CLI immediately, and vice versa.

| Mode | Best For | Command |
|------|----------|---------|
| Web | First-time setup, visual config, casual chat | `bashclaw gateway` |
| CLI | Automation, scripting, SSH, power users | `bashclaw agent -i` |

### REST API

```
GET  /api/status        System status
GET  /api/config        Read config (secrets masked)
PUT  /api/config        Update config (partial merge)
GET  /api/models        List models, aliases, providers
GET  /api/sessions      List active sessions
POST /api/sessions/clear  Clear a session
POST /api/chat          Send message to agent
GET  /api/channels      List channels
GET  /api/env           Check which API keys are set
PUT  /api/env           Save API keys
```

<details>
<summary><strong>Platform access notes</strong></summary>

| Platform | Access | Notes |
|----------|--------|-------|
| macOS / Linux | `localhost:18789` | Full browser experience |
| Android Termux | `localhost:18789` in phone browser | Responsive touch UI |
| Cloud server | `ssh -L 18789:localhost:18789 server` | Port forward |
| Windows WSL2 | `localhost:18789` in Windows browser | Auto port forward |
| Headless / CI | CLI only | `bashclaw agent -m "..."` |

</details>

## Providers

BashClaw supports 9 providers with data-driven routing. Adding a provider is a JSON entry -- no code changes.

```sh
# Anthropic (default)
export ANTHROPIC_API_KEY="sk-ant-..."
bashclaw agent -m "hello"

# OpenAI
export OPENAI_API_KEY="sk-..."
MODEL_ID=gpt-4o bashclaw agent -m "hello"

# Google Gemini
export GOOGLE_API_KEY="..."
MODEL_ID=gemini-2.0-flash bashclaw agent -m "hello"

# OpenRouter (any model)
export OPENROUTER_API_KEY="sk-or-..."
MODEL_ID=anthropic/claude-sonnet-4 bashclaw agent -m "hello"
```

<details>
<summary><strong>Chinese providers</strong></summary>

All Chinese providers use OpenAI-compatible APIs:

```sh
# DeepSeek
export DEEPSEEK_API_KEY="sk-..."
MODEL_ID=deepseek-chat bashclaw agent -m "hello"

# Qwen (Alibaba DashScope)
export QWEN_API_KEY="sk-..."
MODEL_ID=qwen-max bashclaw agent -m "hello"

# Zhipu GLM
export ZHIPU_API_KEY="..."
MODEL_ID=glm-5 bashclaw agent -m "hello"

# Moonshot Kimi
export MOONSHOT_API_KEY="sk-..."
MODEL_ID=kimi-2.5 bashclaw agent -m "hello"

# MiniMax
export MINIMAX_API_KEY="..."
MODEL_ID=minimax-2.5 bashclaw agent -m "hello"
```

</details>

<details>
<summary><strong>Model aliases</strong></summary>

```sh
MODEL_ID=fast       # -> gemini-2.0-flash
MODEL_ID=smart      # -> claude-opus-4
MODEL_ID=balanced   # -> claude-sonnet-4
MODEL_ID=cheap      # -> gpt-4o-mini
MODEL_ID=deepseek   # -> deepseek-chat
MODEL_ID=qwen       # -> qwen-max
MODEL_ID=glm        # -> glm-5
MODEL_ID=kimi       # -> kimi-2.5
MODEL_ID=minimax    # -> minimax-2.5
```

</details>

## Channels

Each channel is a standalone shell script under `channels/`.

| Channel | Status | Mode |
|---------|--------|------|
| Telegram | Stable | Bot API long-poll |
| Discord | Stable | REST API + typing |
| Slack | Stable | Socket Mode / Webhook |
| Feishu / Lark | Stable | Webhook + App Bot |

<details>
<summary><strong>Channel setup</strong></summary>

**Telegram**
```sh
bashclaw config set '.channels.telegram.botToken' '"BOT_TOKEN"'
bashclaw config set '.channels.telegram.enabled' 'true'
bashclaw gateway
```

**Discord**
```sh
bashclaw config set '.channels.discord.botToken' '"BOT_TOKEN"'
bashclaw config set '.channels.discord.enabled' 'true'
bashclaw gateway
```

**Slack**
```sh
bashclaw config set '.channels.slack.botToken' '"xoxb-YOUR-TOKEN"'
bashclaw config set '.channels.slack.enabled' 'true'
bashclaw gateway
```

**Feishu / Lark** (two modes)
```sh
# Webhook (outbound only)
bashclaw config set '.channels.feishu.webhookUrl' '"https://open.feishu.cn/..."'

# App Bot (full bidirectional)
bashclaw config set '.channels.feishu.appId' '"cli_xxx"'
bashclaw config set '.channels.feishu.appSecret' '"secret"'
bashclaw config set '.channels.feishu.monitorChats' '["oc_xxx"]'

# International (Lark)
bashclaw config set '.channels.feishu.region' '"intl"'
bashclaw gateway
```

</details>

## Architecture

```
                       +------------------+
                       |   CLI / Browser  |
                       +--------+---------+
                                |
                 +--------------+--------------+
                 |       bashclaw (main)       |
                 |     CLI router + loader     |
                 +--------------+--------------+
                                |
       +------------------------+------------------------+
       |                        |                        |
+------+------+        +-------+-------+        +-------+-------+
|   Channels  |        |  Core Engine  |        |  Background   |
+------+------+        +-------+-------+        +-------+-------+
| telegram.sh |        | agent.sh      |        | heartbeat.sh  |
| discord.sh  |        | routing.sh    |        | cron.sh       |
| slack.sh    |        | session.sh    |        | events.sh     |
| feishu.sh   |        | tools.sh (14) |        | process.sh    |
| (plugins)   |        | memory.sh     |        | daemon.sh     |
+-------------+        | config.sh     |        +---------------+
                       +---------------+
                                |
       +------------------------+------------------------+
       |                        |                        |
+------+------+        +-------+-------+        +-------+-------+
|  Web / API  |        |   Security    |        |  Extensions   |
+------+------+        +-------+-------+        +-------+-------+
| http_handler |       | SSRF filter   |        | plugin.sh     |
| ui/index.html|       | rate limiting |        | skills.sh     |
| ui/style.css |       | pairing codes |        | hooks.sh (14) |
| ui/app.js    |       | tool policies |        | autoreply.sh  |
| REST API (9) |       | RBAC + audit  |        | boot.sh       |
+--------------+       +---------------+        | dedup.sh      |
                                                +---------------+
```

### Message Flow

```
User Message --> Dedup --> Auto-Reply Check --> Hook: pre_message
  |
  v
Routing (7-level: peer > parent > guild > channel > team > account > default)
  |
  v
Security Gate (rate limit -> pairing -> tool policy -> RBAC)
  |
  v
Process Queue (main: 4, cron: 1, subagent: 8 concurrent lanes)
  |
  v
Agent Runtime
  1. Resolve model + provider (data-driven, models.json)
  2. Load workspace (SOUL.md, MEMORY.md, BOOT.md, IDENTITY.md)
  3. Build system prompt (10 segments)
  4. API call (Anthropic / OpenAI / Google / ...)
  5. Tool loop (max 10 iterations)
  6. Overflow: reduce history -> compact -> model fallback -> reset
  |
  v
Session Persist (JSONL) --> Hook: post_message --> Delivery
```

### Directory Structure

```
bashclaw/
  bashclaw              # main entry (CLI router)
  install.sh            # standalone installer
  lib/
    agent.sh            # agent runtime, model/provider dispatch
    config.sh           # JSON config (jq-based)
    session.sh          # JSONL session persistence
    routing.sh          # 7-level message routing
    tools.sh            # 14 built-in tools + dispatch
    memory.sh           # KV store + BM25 search
    security.sh         # 8-layer security model
    process.sh          # dual-layer queue + typed lanes
    cron.sh             # scheduler (at/every/cron)
    hooks.sh            # 14 event types, 3 strategies
    plugin.sh           # 4-source plugin discovery
    skills.sh           # skill loader
    heartbeat.sh        # autonomous heartbeat
    events.sh           # FIFO event queue
    boot.sh             # BOOT.md parser
    autoreply.sh        # pattern-based auto-reply
    dedup.sh            # TTL dedup cache
    log.sh              # structured logging
    utils.sh            # UUID, hash, retry, timestamp
    cmd_*.sh            # CLI subcommand handlers
  channels/
    telegram.sh         # Telegram Bot API
    discord.sh          # Discord REST + typing
    slack.sh            # Slack Socket Mode + webhook
    feishu.sh           # Feishu/Lark webhook + App Bot
  gateway/
    http_handler.sh     # HTTP request handler + REST API
  ui/
    index.html          # dashboard shell
    style.css           # dark/light theme, responsive
    app.js              # vanilla JS SPA
  tools/                # external tool scripts
  tests/
    framework.sh        # test runner
    test_*.sh           # 23 test suites, 334 tests
```

## Commands

| Command | Subcommands | Description |
|---------|-------------|-------------|
| `agent` | `-m MSG`, `-i`, `-a AGENT` | Chat with agent |
| `gateway` | `-p PORT`, `-d`, `--stop` | HTTP gateway + channels |
| `daemon` | `install`, `uninstall`, `status`, `logs`, `restart`, `stop` | System service |
| `config` | `show`, `get`, `set`, `init`, `validate`, `edit`, `path` | Configuration |
| `session` | `list`, `show`, `clear`, `delete`, `export` | Sessions |
| `memory` | `list`, `get`, `set`, `delete`, `search`, `export`, `import`, `compact`, `stats` | KV store |
| `cron` | `list`, `add`, `remove`, `enable`, `disable`, `run`, `history` | Scheduler |
| `hooks` | `list`, `add`, `remove`, `enable`, `disable`, `test` | Event hooks |
| `boot` | `run`, `find`, `status`, `reset` | Boot sequence |
| `security` | `pair-generate`, `pair-verify`, `tool-check`, `audit` | Security |
| `onboard` | | Setup wizard |
| `doctor` | | Diagnostics |
| `status` | | System status |
| `update` | | Update to latest |
| `completion` | `bash`, `zsh` | Shell completions |

## Built-in Tools

| Tool | Description | Elevation |
|------|-------------|-----------|
| `web_fetch` | HTTP GET/POST with SSRF protection | none |
| `web_search` | Web search (Brave / Perplexity) | none |
| `shell` | Execute commands (security filtered) | elevated |
| `memory` | Persistent KV store with tags | none |
| `cron` | Schedule recurring tasks | none |
| `message` | Send to channels | none |
| `agents_list` | List available agents | none |
| `session_status` | Current session info | none |
| `sessions_list` | List all sessions | none |
| `agent_message` | Inter-agent messaging | none |
| `read_file` | Read file contents | none |
| `write_file` | Write to file | elevated |
| `list_files` | List directory | none |
| `file_search` | Search files by pattern | none |

## Security

```
Layer 1: SSRF Protection      -- block private/internal IPs in web_fetch
Layer 2: Command Filters       -- block rm -rf /, fork bombs, etc.
Layer 3: Pairing Codes         -- 6-digit time-limited channel auth
Layer 4: Rate Limiting         -- token-bucket per-sender
Layer 5: Tool Policy           -- per-agent allow/deny lists
Layer 6: Elevated Policy       -- authorization for dangerous tools
Layer 7: RBAC                  -- role-based command authorization
Layer 8: Audit Logging         -- JSONL trail for all security events
```

## Plugin System

```
Plugin Discovery (4 sources):
  ${BASHCLAW_ROOT}/extensions/      # bundled
  ~/.bashclaw/extensions/           # global user
  .bashclaw/extensions/             # workspace-local
  config: plugins.load.paths        # custom paths
```

Plugins can register tools, hooks, commands, and providers:

```sh
plugin_register_tool "my_tool" "Description" '{"input":{"type":"string"}}' handler.sh
plugin_register_hook "pre_message" filter.sh 50
plugin_register_command "my_cmd" "Description" cmd.sh
plugin_register_provider "my_llm" "My LLM" '["model-a"]' '{"envKey":"MY_KEY"}'
```

## Hook System

| Event | Strategy | When |
|-------|----------|------|
| `pre_message` | modifying | Before processing (can modify input) |
| `post_message` | void | After processing |
| `pre_tool` | modifying | Before tool exec (can modify args) |
| `post_tool` | modifying | After tool exec (can modify result) |
| `on_error` | void | On error |
| `on_session_reset` | void | Session reset |
| `before_agent_start` | sync | Before agent begins |
| `agent_end` | void | After agent finishes |
| `before_compaction` | sync | Before context compaction |
| `after_compaction` | void | After context compaction |
| `message_received` | modifying | Message arrives at gateway |
| `message_sending` | modifying | Before reply dispatch |
| `message_sent` | void | After reply dispatch |
| `session_start` | void | New session created |

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
  "session": { "scope": "per-sender", "idleResetMinutes": 30 }
}
```

<details>
<summary><strong>Environment variables</strong></summary>

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic Claude |
| `OPENAI_API_KEY` | OpenAI |
| `GOOGLE_API_KEY` | Google Gemini |
| `OPENROUTER_API_KEY` | OpenRouter |
| `DEEPSEEK_API_KEY` | DeepSeek |
| `QWEN_API_KEY` | Qwen (DashScope) |
| `ZHIPU_API_KEY` | Zhipu GLM |
| `MOONSHOT_API_KEY` | Moonshot Kimi |
| `MINIMAX_API_KEY` | MiniMax |
| `MODEL_ID` | Override default model |
| `BASHCLAW_STATE_DIR` | State dir (default: `~/.bashclaw`) |
| `LOG_LEVEL` | `debug` / `info` / `warn` / `error` / `silent` |

</details>

## Use Cases

**Personal assistant on a Mac**
```sh
export ANTHROPIC_API_KEY="sk-ant-..."
bashclaw agent -i
# No Python, no Node, no Docker. Just works.
```

**Headless server agent**
```sh
# Install on a fresh Ubuntu server
curl -fsSL .../install.sh | bash
bashclaw daemon install --enable
# Agent runs 24/7, accessible via Telegram or web dashboard
```

**CI/CD pipeline agent**
```sh
# In a Dockerfile or CI step (< 10MB overhead)
bashclaw agent -m "Review this diff and suggest improvements" < diff.patch
```

**Multi-channel team bot**
```sh
# One agent, multiple channels
bashclaw config set '.channels.telegram.enabled' 'true'
bashclaw config set '.channels.discord.enabled' 'true'
bashclaw config set '.channels.slack.enabled' 'true'
bashclaw gateway
# Messages from all platforms routed to the same agent
```

## Testing

```sh
bash tests/run_all.sh              # all 334 tests
bash tests/run_all.sh --unit       # unit tests only
bash tests/run_all.sh --compat     # Bash 3.2 verification
bash tests/run_all.sh --integration  # live API tests
bash tests/test_agent.sh           # single suite
```

<details>
<summary><strong>Test suites (23)</strong></summary>

| Suite | Tests | Covers |
|-------|-------|--------|
| test_utils | 25 | UUID, hash, retry, timestamp |
| test_config | 25 | Load, get, set, validate |
| test_session | 26 | JSONL, prune, idle reset, export |
| test_tools | 28 | 14 tools, SSRF, dispatch |
| test_routing | 17 | 7-level resolution, allowlist |
| test_agent | 15 | Model, provider routing, bootstrap |
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
| test_heartbeat | 18 | Guard chain, active hours |
| test_events | 12 | FIFO queue, drain, dedup |
| test_cron_advanced | 17 | Schedule types, backoff |
| test_plugin | 14 | Discover, load, register |
| test_skills | 11 | Skill discovery, loading |
| test_dedup | 13 | TTL cache, expiry |
| test_integration | 11 | Live API, multi-turn |
| test_compat | 10 | Bash 3.2 verification |

</details>

## Troubleshooting

```sh
bashclaw doctor        # check dependencies, config, API key
bashclaw status        # gateway state, session count
bashclaw config show   # dump current config
LOG_LEVEL=debug bashclaw agent -m "test"  # verbose output
```

**Common issues:**
- `command not found` after install -- run `source ~/.zshrc` (macOS) or `source ~/.bashrc` (Linux), or open a new terminal
- `jq: command not found` -- the installer auto-installs jq; if it failed, run `brew install jq` (macOS) or `apt install jq` (Linux)
- Gateway shows no HTTP -- install `socat` for full HTTP server: `brew install socat` (macOS) or `apt install socat` (Linux)

## License

MIT
