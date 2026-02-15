<div align="center">

```
 ____            _      ____ _
| __ )  __ _ ___| |__  / ___| | __ ___      __
|  _ \ / _` / __| '_ \| |   | |/ _` \ \ /\ / /
| |_) | (_| \__ \ | | | |___| | (_| |\ V  V /
|____/ \__,_|___/_| |_|\____|_|\__,_| \_/\_/
```

<h3>Bash is all you need.</h3>

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
  <a href="#install">Install</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#llm-providers">Providers</a> &middot;
  <a href="#channels">Channels</a> &middot;
  <a href="#architecture">Architecture</a> &middot;
  <a href="README_CN.md">Chinese</a>
</p>
</div>

---

BashClaw is a pure-shell AI agent runtime. No Node.js, no Python, no compiled binaries -- just `bash`, `curl`, and `jq`. It implements the same multi-channel agent architecture as OpenClaw, but runs anywhere a shell exists.

Because BashClaw is shell script, the agent can hot-modify its own source code at runtime -- no compilation, no restart, instant self-bootstrapping.

## Why BashClaw

```sh
# OpenClaw needs:
node >= 22, npm, 52 packages, 200-400MB RAM, 2-5s cold start

# BashClaw needs:
bash >= 3.2, curl, jq
# Already on your machine.
```

|                  | OpenClaw (TS)   | BashClaw (Bash)   |
|------------------|-----------------|-------------------|
| Runtime          | Node.js 22+     | **Bash 3.2+**     |
| Dependencies     | 52 npm packages | **jq, curl**      |
| Memory           | 200-400 MB      | **< 10 MB**       |
| Cold start       | 2-5 seconds     | **< 100 ms**      |
| Source lines     | ~20,000+        | **~14,000**       |
| Install          | npm / Docker    | **curl \| bash**  |
| macOS out-of-box | No (needs Node) | **Yes**           |
| Android Termux   | Complex         | **pkg install jq** |
| Hot self-modify  | No (needs build)| **Yes**           |
| Tests            | Vitest          | **334 tests**     |

### Hot Self-Bootstrapping

BashClaw runs on the shell -- the environment that AI agents already understand best. The agent can read, modify, and reload its own source code at runtime without any compilation step. This makes BashClaw uniquely suited for self-evolving agent workflows.

### Runs Everywhere

BashClaw targets Bash 3.2 (the version Apple froze on every Mac since 2007). No `declare -A`, no `mapfile`, no `|&`. This means it works on:

- macOS (every version since 2007, no Homebrew needed)
- Linux (any distro)
- Android Termux (no root)
- Windows (WSL2 / Git Bash)
- Alpine containers, Raspberry Pi, embedded systems

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
# Set API key (pick any provider)
export ANTHROPIC_API_KEY="sk-ant-..."    # or OPENAI_API_KEY, GOOGLE_API_KEY, etc.

# Chat
./bashclaw agent -m "What is the mass of the sun?"

# Interactive mode
./bashclaw agent -i

# Guided setup
./bashclaw onboard
```

## LLM Providers

BashClaw supports 9 providers with data-driven routing. Adding a provider is a single JSON entry -- no code changes needed.

### International Providers

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

### Chinese Providers

All Chinese providers use OpenAI-compatible APIs. Set the env var and go.

```sh
# DeepSeek
export DEEPSEEK_API_KEY="sk-..."
MODEL_ID=deepseek-chat bashclaw agent -m "hello"

# Qwen (Alibaba DashScope)
export QWEN_API_KEY="sk-..."
MODEL_ID=qwen-max bashclaw agent -m "hello"

# Zhipu GLM
export ZHIPU_API_KEY="..."
MODEL_ID=glm-4.7-flash bashclaw agent -m "hello"

# Moonshot Kimi
export MOONSHOT_API_KEY="sk-..."
MODEL_ID=kimi-k2.5 bashclaw agent -m "hello"

# MiniMax
export MINIMAX_API_KEY="..."
MODEL_ID=MiniMax-M2.5 bashclaw agent -m "hello"
```

### Free Tier Models

| Model | Provider | Free Quota |
|-------|----------|------------|
| glm-4.7-flash | Zhipu | Free |
| glm-4.5-flash | Zhipu | Free |
| deepseek-chat | DeepSeek | 5M tokens (30-day for new accounts) |
| qwen-turbo | Qwen | Free quota (90-day for new accounts) |

### Model Aliases

```sh
MODEL_ID=fast      # -> gemini-2.0-flash
MODEL_ID=smart     # -> claude-opus-4
MODEL_ID=balanced  # -> claude-sonnet-4
MODEL_ID=cheap     # -> gpt-4o-mini
MODEL_ID=free      # -> glm-4.7-flash
MODEL_ID=deepseek  # -> deepseek-chat
MODEL_ID=qwen      # -> qwen-max
MODEL_ID=kimi      # -> kimi-k2.5
```

## Channels

BashClaw supports multiple messaging platforms. Each channel is a standalone shell script under `channels/`.

| Channel | Status | Mode |
|---------|--------|------|
| Telegram | Stable | Long-poll listener |
| Discord | Stable | WebSocket gateway |
| Slack | Stable | Socket Mode / webhook |
| Feishu / Lark | Stable | Webhook + App Bot polling |
| QQ (via OneBot v11) | Planned | NapCat / LLOneBot bridge |

### Telegram

```sh
bashclaw config set '.channels.telegram.botToken' '"BOT_TOKEN"'
bashclaw config set '.channels.telegram.enabled' 'true'
bashclaw gateway
```

### Discord

```sh
bashclaw config set '.channels.discord.botToken' '"BOT_TOKEN"'
bashclaw config set '.channels.discord.enabled' 'true'
bashclaw gateway
```

### Feishu / Lark

Two modes: **Webhook** (outbound only, zero config) and **App Bot** (full bidirectional).

```sh
# Webhook mode (simple)
bashclaw config set '.channels.feishu.webhookUrl' '"https://open.feishu.cn/open-apis/bot/v2/hook/xxx"'

# App Bot mode (full features)
bashclaw config set '.channels.feishu.appId' '"cli_xxx"'
bashclaw config set '.channels.feishu.appSecret' '"secret"'
bashclaw config set '.channels.feishu.monitorChats' '["oc_xxx"]'

# International (Lark)
bashclaw config set '.channels.feishu.region' '"intl"'

bashclaw gateway
```

### Slack

```sh
bashclaw config set '.channels.slack.botToken' '"xoxb-YOUR-TOKEN"'
bashclaw config set '.channels.slack.enabled' 'true'
bashclaw gateway
```

## Architecture

```
                        +------------------+
                        |    CLI / User    |
                        +--------+---------+
                                 |
                  +--------------+--------------+
                  |       BashClaw (main)        |
                  |    472 lines, CLI router     |
                  +--------------+--------------+
                                 |
        +------------------------+------------------------+
        |                        |                        |
+-------+-------+      +--------+--------+      +--------+--------+
|    Channels    |      |   Core Engine   |      | Background Sys  |
+-------+-------+      +--------+--------+      +--------+--------+
| telegram.sh   |      | agent.sh         |      | heartbeat.sh    |
| discord.sh    |      | routing.sh       |      | cron.sh         |
| slack.sh      |      | session.sh       |      | events.sh       |
| feishu.sh     |      | tools.sh (14)    |      | process.sh      |
| (plugin: any) |      | memory.sh        |      | daemon.sh       |
+---------------+      | config.sh        |      +-----------------+
                        +------------------+
                                 |
        +------------------------+------------------------+
        |                        |                        |
+-------+-------+      +--------+--------+      +--------+--------+
|   Extensions   |      |    Security      |      |    CLI Cmds     |
+-------+-------+      +--------+--------+      +--------+--------+
| plugin.sh      |      | 8-layer model    |      | cmd_agent.sh    |
| skills.sh      |      | SSRF protection  |      | cmd_config.sh   |
| hooks.sh (14)  |      | rate limiting    |      | cmd_session.sh  |
| autoreply.sh   |      | RBAC + audit     |      | cmd_cron.sh     |
| boot.sh        |      | pairing codes    |      | cmd_daemon.sh   |
| dedup.sh       |      | tool policies    |      | cmd_gateway.sh  |
+----------------+      +-----------------+      | cmd_memory.sh   |
                                                  | cmd_hooks.sh    |
                                                  | cmd_onboard.sh  |
                                                  | cmd_message.sh  |
                                                  +-----------------+
```

### Message Flow

```
User Message --> Dedup --> Auto-Reply --> Hook: pre_message
  |
  v
Routing (7-level priority: peer > parent > guild > channel > team > account > default)
  |
  v
Security Gate (rate limit, pairing, tool policy, RBAC)
  |
  v
Process Queue (main: 4, cron: 1, subagent: 8 concurrent)
  |
  v
Agent Runtime
  1. Resolve model + provider (data-driven from models.json)
  2. Load workspace (SOUL.md, MEMORY.md, BOOT.md)
  3. Build system prompt (10 segments)
  4. API call (Anthropic / OpenAI / Google / OpenRouter / DeepSeek / Qwen / Zhipu / Moonshot / MiniMax)
  5. Tool loop (max 10 iterations)
  6. Overflow degradation (reduce history -> compact -> model fallback -> reset)
  |
  v
Session Persist (JSONL) --> Hook: post_message --> Delivery
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

## Plugin System

```
Plugin Discovery (4 sources):
  1. ${BASHCLAW_ROOT}/extensions/     # bundled
  2. ~/.bashclaw/extensions/          # global user
  3. .bashclaw/extensions/            # workspace-local
  4. config: plugins.load.paths       # custom paths
```

Each plugin has a `bashclaw.plugin.json` manifest:

```sh
plugin_register_tool "my_tool" "Does something" '{"input":{"type":"string"}}' "$PWD/handler.sh"
plugin_register_hook "pre_message" "$PWD/filter.sh" 50
plugin_register_command "my_cmd" "Custom command" "$PWD/cmd.sh"
plugin_register_provider "my_llm" "My LLM" '["model-a"]' '{"envKey":"MY_KEY"}'
```

## Hook System (14 Events)

```
Event                Strategy     When
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
    "telegram": { "enabled": true, "botToken": "$TELEGRAM_BOT_TOKEN" },
    "feishu": { "appId": "$FEISHU_APP_ID", "appSecret": "$FEISHU_APP_SECRET" }
  },
  "gateway": { "port": 18789 },
  "session": { "scope": "per-sender", "idleResetMinutes": 30 }
}
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Anthropic Claude |
| `OPENAI_API_KEY` | OpenAI |
| `GOOGLE_API_KEY` | Google Gemini |
| `OPENROUTER_API_KEY` | OpenRouter |
| `DEEPSEEK_API_KEY` | DeepSeek |
| `QWEN_API_KEY` | Qwen (Alibaba DashScope) |
| `ZHIPU_API_KEY` | Zhipu GLM |
| `MOONSHOT_API_KEY` | Moonshot Kimi |
| `MINIMAX_API_KEY` | MiniMax |
| `MODEL_ID` | Override default model |
| `BASHCLAW_STATE_DIR` | State directory (default: ~/.bashclaw) |
| `LOG_LEVEL` | debug \| info \| warn \| error \| silent |

## Testing

```sh
# Run all (334 tests, 473 assertions)
bash tests/run_all.sh

# By category
bash tests/run_all.sh --unit
bash tests/run_all.sh --compat
bash tests/run_all.sh --integration

# Single suite
bash tests/test_agent.sh
```

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
| test_heartbeat | 18 | Guard chain, active hours, events |
| test_events | 12 | FIFO queue, drain, dedup |
| test_cron_advanced | 17 | Schedule types, backoff, stuck jobs |
| test_plugin | 14 | Discover, load, register, enable |
| test_skills | 11 | Skill discovery, loading |
| test_dedup | 13 | TTL cache, expiry, cleanup |
| test_integration | 11 | Live API, multi-turn |
| test_compat | 10 | Bash 3.2 verification |

## License

MIT
