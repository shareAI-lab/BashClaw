# bashclaw

[OpenClaw](https://github.com/openclaw/openclaw) AI 助手平台的纯 Bash 重新实现。

相同的架构、相同的模块流程、相同的功能 -- 零 Node.js、零 npm。只需 Bash + jq + curl。

[English](README.md) | [Chinese](README_CN.md)

## 为什么

OpenClaw 是一个用 TypeScript 编写的个人 AI 助手网关（约 20k 行代码），存在以下问题：

- 52 个 npm 依赖（包括 playwright、sharp、baileys 等重型依赖）
- 启动时 40+ 个顺序初始化步骤
- 234 个冗余的 `.strict()` Zod schema 调用
- 6+ 次独立的配置验证
- 每次请求都进行未缓存的头像解析（同步文件 I/O）
- 跨越 800+ 行的复杂重试/回退逻辑

**bashclaw** 完全消除了这些冗余：

| 指标 | OpenClaw (TS) | bashclaw |
|---|---|---|
| 代码行数 | ~20,000+ | ~17,300 |
| 依赖 | 52 个 npm 包 | jq, curl (socat 可选) |
| 启动时间 | 2-5秒 (Node 冷启动) | <100毫秒 |
| 内存占用 | 200-400MB | <10MB |
| 配置验证 | 6 次 + Zod | 单次 jq 解析 |
| 运行时 | Node.js 22+ | Bash 3.2+ |
| 测试套件 | 未知 | 18 套件, 222 用例, 320 断言 |

## 一键安装

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

或手动克隆：

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw
chmod +x bashclaw
```

### 系统要求

- **bash** 3.2+（macOS 默认版本即可，Linux、Android Termux 均可）
- **jq** - JSON 处理（安装器会自动安装）
- **curl** - HTTP 请求
- **socat**（可选）- 网关 HTTP 服务器

```sh
# macOS
brew install jq curl socat

# Ubuntu/Debian
apt install jq curl socat

# Android (Termux, 无需 root)
pkg install jq curl
```

## 快速开始

```sh
# 交互式设置向导
./bashclaw onboard

# 或手动设置 API 密钥
export ANTHROPIC_API_KEY="your-key"

# 交互式聊天
./bashclaw agent -i

# 发送单条消息
./bashclaw agent -m "法国的首都是什么?"

# 检查系统健康状态
./bashclaw doctor

# 安装为后台守护进程
./bashclaw daemon install --enable
```

## 架构

```sh
bashclaw/
  bashclaw                # 主入口和 CLI 路由 (472 行)
  install.sh              # 独立安装器 (跨平台)
  lib/
    # -- 核心模块 --
    log.sh                # 日志子系统 (级别、颜色、文件输出)
    utils.sh              # 通用工具 (重试、端口检查、uuid、临时文件等)
    config.sh             # 配置管理 (基于 jq、环境变量替换)
    session.sh            # JSONL 会话持久化 (按发送者/频道/全局, 上下文压缩)
    agent.sh              # Agent 运行时 (Anthropic/OpenAI API、工具循环、引导文件)
    tools.sh              # 内置工具 (14 种: web、shell、memory、cron、文件等)
    routing.sh            # 7 级优先级消息路由和分发
    memory.sh             # 长期记忆 (基于文件的键值存储, 支持标签)

    # -- 后台系统 --
    heartbeat.sh          # 周期性自主 Agent 签到 (活跃时段门控)
    events.sh             # 系统事件队列 (FIFO, 去重, 下轮排空)
    cron.sh               # 高级定时任务 (at/every/cron 调度, 退避, 隔离会话)
    process.sh            # 双层命令队列 (类型化通道, 并发控制)
    daemon.sh             # 守护进程管理 (systemd/launchd/cron)

    # -- 扩展系统 --
    plugin.sh             # 插件系统 (发现、加载、注册工具/钩子/命令/提供者)
    skills.sh             # 技能系统 (SKILL.md 提示级能力, 按 Agent)
    dedup.sh              # 幂等性/去重缓存 (基于 TTL, 文件存储)
    hooks.sh              # 14 事件钩子/中间件管道 (void/modifying/sync 策略)
    boot.sh               # 启动自动化 (BOOT.md 解析, Agent 工作空间集成)
    autoreply.sh          # 基于模式匹配的自动回复规则
    security.sh           # 8 层安全 (审计、配对、限流、工具策略、提权、RBAC)

    # -- CLI 命令 --
    cmd_agent.sh          # CLI: agent 命令 (交互模式)
    cmd_gateway.sh        # CLI: 网关服务器 (WebSocket/HTTP)
    cmd_config.sh         # CLI: 配置管理
    cmd_session.sh        # CLI: 会话管理
    cmd_message.sh        # CLI: 发送消息
    cmd_memory.sh         # CLI: 记忆管理
    cmd_cron.sh           # CLI: 定时任务管理
    cmd_hooks.sh          # CLI: 钩子管理
    cmd_daemon.sh         # CLI: 守护进程管理
    cmd_onboard.sh        # CLI: 设置向导

  channels/
    telegram.sh           # Telegram Bot API (长轮询)
    discord.sh            # Discord Bot API (HTTP 轮询)
    slack.sh              # Slack Bot API (会话轮询)
  gateway/
    http_handler.sh       # socat 网关的 HTTP 请求处理
  tests/
    framework.sh          # 测试框架 (断言、环境设置/清理)
    test_*.sh             # 18 个测试套件, 222 个测试用例
    run_all.sh            # 测试运行器 (单元、集成、兼容性模式)
  .github/workflows/
    ci.yml                # CI: 推送/PR 时运行单元+兼容性测试
    integration.yml       # 集成测试 (每周+手动触发)
```

### 模块流程

```sh
频道 (Telegram/Discord/Slack/CLI)
  -> 去重检查 (幂等性缓存, 跳过重复消息)
  -> 自动回复检查 (模式匹配 -> 立即响应)
  -> 钩子: pre_message (中间件管道)
  -> 路由 (7 级优先级: 发送者/服务器/频道/团队 -> Agent 解析)
    -> 安全 (8 层: 限流、配对、工具策略、提权、RBAC)
    -> 处理队列 (双层: 类型化通道 + 每 Agent 并发控制)
    -> 事件注入 (将排队的系统事件排空到消息上下文)
    -> Agent 运行时 (模型选择、引导文件、API 调用、工具循环)
      -> 钩子: pre_tool / post_tool
      -> 工具 (web_fetch、web_search、shell、memory、cron、文件、message...)
      -> 插件工具 (由已加载插件动态注册)
    -> 会话 (JSONL 追加、修剪、上下文压缩、空闲重置)
  -> 钩子: post_message
  -> 投递 (格式化回复、拆分长消息、发送)

后台系统:
  心跳循环   -> 活跃时段门控 -> HEARTBEAT.md 提示 -> Agent 轮次
  定时服务   -> 调度检查 -> 隔离/主会话 -> 失败退避
  事件队列   -> 后台入队 -> 下一轮 Agent 排空

启动自动化:
  BOOT.md -> 解析代码块 -> 执行 (shell / agent 消息) -> 状态跟踪

插件系统:
  发现 (4 个来源) -> 加载 -> 注册 (工具、钩子、命令、提供者)

技能:
  Agent 工作空间 -> SKILL.md 文件 -> 注入系统提示 -> 按需加载

守护进程:
  systemd (Linux) / launchd (macOS) / cron (通用回退)
```

## 命令

```sh
bashclaw agent [-m MSG] [-i] [-a AGENT]   # 与 agent 聊天
bashclaw gateway [-p PORT] [-d] [--stop]   # 启动/停止网关
bashclaw daemon [install|uninstall|status|logs|restart|stop]
bashclaw message send -c CH -t TO -m MSG   # 发送到频道
bashclaw config [show|get|set|init|validate|edit|path]
bashclaw session [list|show|clear|delete|export]
bashclaw memory [list|get|set|delete|search|export|import|compact|stats]
bashclaw cron [list|add|remove|enable|disable|run|history]
bashclaw hooks [list|add|remove|enable|disable|test]
bashclaw boot [run|find|status|reset]      # Agent 启动自动化
bashclaw security [pair-generate|pair-verify|tool-check|elevated-check|audit]
bashclaw onboard                           # 交互式设置向导
bashclaw status                            # 系统状态
bashclaw doctor                            # 诊断问题
bashclaw update                            # 更新到最新版本
bashclaw completion [bash|zsh]             # Shell 补全
bashclaw version                           # 版本信息
```

## 配置

配置文件: `~/.bashclaw/bashclaw.json`

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

### 环境变量

| 变量 | 用途 |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic Claude API 密钥 |
| `ANTHROPIC_BASE_URL` | 自定义 API 基础 URL (代理/兼容 API) |
| `MODEL_ID` | 覆盖默认模型名称 |
| `OPENAI_API_KEY` | OpenAI API 密钥 |
| `BRAVE_SEARCH_API_KEY` | Brave 搜索 API |
| `PERPLEXITY_API_KEY` | Perplexity API |
| `BASHCLAW_STATE_DIR` | 状态目录 (默认: ~/.bashclaw) |
| `BASHCLAW_CONFIG` | 配置文件路径覆盖 |
| `LOG_LEVEL` | 日志级别: debug, info, warn, error, fatal, silent |
| `BASHCLAW_BOOTSTRAP_MAX_CHARS` | 系统提示中每个引导文件的最大字符数 (默认: 20000) |
| `TOOL_WEB_FETCH_MAX_CHARS` | web_fetch 最大响应体大小 (默认: 102400) |
| `TOOL_SHELL_TIMEOUT` | Shell 命令超时秒数 (默认: 30) |
| `TOOL_READ_FILE_MAX_LINES` | read_file 工具最大行数 (默认: 2000) |
| `TOOL_LIST_FILES_MAX` | list_files 工具最大条目数 (默认: 500) |

### 自定义 API 端点

bashclaw 支持任何 Anthropic 兼容 API：

```sh
# 使用 BigModel/GLM
export ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic
export MODEL_ID=glm-5

# 使用任意兼容代理
export ANTHROPIC_BASE_URL=https://your-proxy.example.com
```

## 频道设置

### Telegram

```sh
./bashclaw config set '.channels.telegram.botToken' '"YOUR_BOT_TOKEN"'
./bashclaw config set '.channels.telegram.enabled' 'true'
./bashclaw gateway  # 启动 Telegram 长轮询监听
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

## 内置工具

| 工具 | 描述 |
|---|---|
| `web_fetch` | HTTP 请求 (带 SSRF 保护) |
| `web_search` | 网页搜索 (Brave/Perplexity) |
| `shell` | 执行命令 (带安全过滤) |
| `memory` | 持久化键值存储 (带标签和搜索) |
| `message` | 发送消息到频道 |
| `cron` | 调度定期任务 |
| `agents_list` | 列出可用 Agent |
| `session_status` | 当前会话信息 |
| `sessions_list` | 列出所有会话 |
| `agent_message` | 向其他 Agent 发送消息 |
| `read_file` | 读取文件内容 (行数限制) |
| `write_file` | 写入文件内容 |
| `list_files` | 列出目录内容 |
| `file_search` | 按模式搜索文件 |

## 心跳系统

心跳系统支持周期性自主 Agent 签到。Agent 可以执行定期的自主操作（如检查提醒、监控系统），无需用户主动发起对话。

```sh
# 全局启用
./bashclaw config set '.heartbeat.enabled' 'true'

# 每个 Agent 的心跳配置
./bashclaw config set '.agents.list[0].heartbeat.enabled' 'true'
./bashclaw config set '.agents.list[0].heartbeat.interval' '"30m"'
./bashclaw config set '.agents.list[0].heartbeat.activeHours.start' '"08:00"'
./bashclaw config set '.agents.list[0].heartbeat.activeHours.end' '"22:00"'
./bashclaw config set '.agents.list[0].heartbeat.timezone' '"local"'
```

守卫链（心跳运行前的 6 项检查）：

1. 全局心跳已启用
2. Agent 级别心跳未禁用
3. 间隔有效（> 0）
4. 当前时间在活跃时段内（支持跨午夜窗口）
5. 无正在进行的处理（无通道锁被持有）
6. HEARTBEAT.md 文件存在且有内容

心跳提示指示 Agent 读取 HEARTBEAT.md 并遵循其中的指令。如果无需关注，Agent 回复 `HEARTBEAT_OK`，该响应会被静默丢弃。有意义的响应会被去重（24小时窗口）并作为系统事件入队到主会话。

## 插件系统

插件可以为 bashclaw 扩展自定义工具、钩子、命令和 LLM 提供者。插件从 4 个来源目录中发现：

1. **内置**: `${BASHCLAW_ROOT}/extensions/`
2. **全局**: `~/.bashclaw/extensions/`
3. **工作空间**: `.bashclaw/extensions/`（相对于当前目录）
4. **配置**: `plugins.load.paths`（自定义路径数组）

每个插件目录包含一个 `bashclaw.plugin.json` 清单文件和一个入口脚本（`init.sh` 或 `<id>.sh`）。入口脚本使用以下函数注册组件：

```sh
# 注册自定义工具
plugin_register_tool "my_tool" "描述" '{"param1":{"type":"string"}}' "/path/to/handler.sh"

# 注册钩子
plugin_register_hook "pre_message" "/path/to/hook.sh" 50

# 注册 CLI 命令
plugin_register_command "my_cmd" "描述" "/path/to/cmd.sh"

# 注册 LLM 提供者
plugin_register_provider "my_llm" "My LLM" '["model-a","model-b"]' '{"envKey":"MY_API_KEY"}'
```

插件允许/拒绝列表控制哪些插件被加载：

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

## 技能系统

技能是存储在 Agent 工作空间目录下的提示级能力。每个技能目录包含一个 `SKILL.md`（必需）和一个可选的 `skill.json` 元数据文件。

```sh
~/.bashclaw/agents/main/skills/
  code-review/
    SKILL.md          # Agent 的详细指令
    skill.json        # { "description": "代码审查", "tags": ["dev"] }
  summarize/
    SKILL.md
    skill.json
```

可用技能会自动列在 Agent 的系统提示中。Agent 可以按需加载特定技能的 SKILL.md 获取详细指令。

## 高级定时任务

定时任务系统支持三种调度类型：

| 类型 | 格式 | 示例 |
|---|---|---|
| `at` | 一次性 ISO 时间戳 | `{"kind":"at","at":"2025-12-01T09:00:00Z"}` |
| `every` | 间隔毫秒数 | `{"kind":"every","everyMs":3600000}` |
| `cron` | 带时区的 5 字段 cron 表达式 | `{"kind":"cron","expr":"0 9 * * 1","tz":"America/New_York"}` |

功能特性：

- **指数退避**: 失败的任务按 30秒、60秒、5分钟、15分钟、60分钟（上限）退避
- **卡死任务检测**: 超过卡死阈值（默认 2 小时）的运行会被自动释放
- **隔离会话**: 任务可在专用会话中运行，避免污染主对话
- **并发运行限制**: 可配置最大并发 cron 运行数（默认: 1）
- **会话回收**: 超过保留期的旧隔离 cron 会话会被自动清理
- **运行历史**: 所有任务执行记录在 `cron/history/runs.jsonl`

```sh
# 列出定时任务
./bashclaw cron list

# 添加任务
./bashclaw cron add --id daily-summary --schedule '{"kind":"cron","expr":"0 9 * * *"}' --prompt "总结今日"

# 查看运行历史
./bashclaw cron history

# 手动触发任务
./bashclaw cron run daily-summary
```

## 事件队列

后台进程（心跳、定时任务、异步命令）将系统事件入队。这些事件在下一次用户发起的轮次中被排空并注入到 Agent 的消息上下文中。

- 每个会话 FIFO 队列（最多 20 个事件）
- 连续相同事件会被去重
- 基于文件的锁文件并发控制
- 事件以 `[SYSTEM EVENT]` 前缀消息的形式出现在 Agent 上下文中

## 去重缓存

去重模块为消息处理提供基于 TTL 的幂等性检查：

- 基于文件的缓存存储在 `${BASHCLAW_STATE_DIR}/dedup/`
- 每次检查可配置 TTL（默认 300 秒）
- 从频道 + 发送者 + 内容哈希生成组合键
- 自动清理过期条目
- 防止频道轮询导致的重复消息处理

## 安全模型（8 层）

bashclaw 实现纵深防御安全策略：

| 层级 | 模块 | 描述 |
|---|---|---|
| 1. SSRF 防护 | `tools.sh` | 在 web_fetch 中阻止私有/内部 IP |
| 2. 命令过滤 | `security.sh` | 阻止危险的 shell 模式 (rm -rf /, fork 炸弹等) |
| 3. 配对码 | `security.sh` | 6 位限时验证码用于频道认证 |
| 4. 频率限制 | `security.sh` | 基于令牌桶的每用户限流（可配置每分钟上限） |
| 5. 工具策略 | `security.sh` | 每 Agent 的允许/拒绝列表，会话类型限制（子 Agent/cron） |
| 6. 提权策略 | `security.sh` | 危险工具的提权授权（shell、write_file） |
| 7. 命令授权 / RBAC | `security.sh` | 基于角色的命名命令访问控制 |
| 8. 审计日志 | `security.sh` | 所有安全相关事件的 JSONL 审计记录 |

```sh
# 生成配对码
./bashclaw security pair-generate telegram user123

# 验证配对码
./bashclaw security pair-verify telegram user123 482910

# 检查工具是否允许
./bashclaw security tool-check main shell main

# 检查提权授权
./bashclaw security elevated-check shell user123 telegram

# 查看审计日志（最近 20 条）
./bashclaw security audit
```

## 钩子系统

钩子系统提供 14 事件中间件管道，支持三种执行策略：

**事件列表：**

| 事件 | 策略 | 描述 |
|---|---|---|
| `pre_message` | modifying | 消息处理前（可修改输入） |
| `post_message` | void | 消息处理后 |
| `pre_tool` | modifying | 工具执行前（可修改参数） |
| `post_tool` | modifying | 工具执行后（可修改结果） |
| `on_error` | void | 发生错误时 |
| `on_session_reset` | void | 会话重置时 |
| `before_agent_start` | sync | Agent 开始处理前 |
| `agent_end` | void | Agent 处理完成后 |
| `before_compaction` | sync | 上下文压缩前 |
| `after_compaction` | void | 上下文压缩后 |
| `message_received` | modifying | 网关收到消息时 |
| `message_sending` | modifying | 回复发送前 |
| `message_sent` | void | 回复发送后 |
| `session_start` | void | 新会话创建时 |

**执行策略：**
- `void`: 并行即发即忘，忽略返回值
- `modifying`: 串行管道，每个钩子可修改输入 JSON
- `sync`: 同步热路径，阻塞直到完成

```sh
# 列出钩子
./bashclaw hooks list

# 添加钩子
./bashclaw hooks add --name log-messages --event pre_message --handler /path/to/script.sh

# 测试钩子
./bashclaw hooks test log-messages '{"text":"hello"}'

# 启用/禁用
./bashclaw hooks enable log-messages
./bashclaw hooks disable log-messages
```

## 处理队列

处理队列实现双层并发控制：

- **第 1 层**: 每 Agent 的原始 FIFO 队列（向后兼容）
- **第 2 层**: 带可配置并发限制的类型化通道
  - `main` 通道: 最大 4 个并发（可配置）
  - `cron` 通道: 最大 1 个并发
  - `subagent` 通道: 最大 8 个并发
- 基于文件的锁文件实现跨进程安全
- 队列模式支持: 按 Agent 和全局
- 中止机制用于取消排队命令

## 守护进程支持

bashclaw 可以作为系统服务运行，支持自动重启：

```sh
# 安装并启用 (自动检测 systemd/launchd/cron)
./bashclaw daemon install --enable

# 查看状态
./bashclaw daemon status

# 查看日志
./bashclaw daemon logs

# 停止并卸载
./bashclaw daemon uninstall
```

支持的初始化系统：
- **systemd** (Linux)
- **launchd** (macOS)
- **cron** (通用回退，包括 Android/Termux)

## 测试

```sh
# 运行所有测试 (222 个用例, 320 个断言)
bash tests/run_all.sh

# 仅运行单元测试
bash tests/run_all.sh --unit

# 仅运行兼容性测试
bash tests/run_all.sh --compat

# 运行集成测试 (需要 API 密钥)
bash tests/run_all.sh --integration

# 运行单个测试套件
bash tests/test_memory.sh
bash tests/test_hooks.sh
bash tests/test_security.sh

# 详细输出模式
bash tests/run_all.sh --verbose
```

### 测试覆盖

| 套件 | 用例数 | 覆盖内容 |
|---|---|---|
| test_utils | 25 | UUID、哈希、url_encode、重试、trim、时间戳 |
| test_config | 25 | 加载、获取、设置、验证、agent/频道配置 |
| test_session | 26 | JSONL 持久化、修剪、空闲重置、导出 |
| test_tools | 28 | 工具分发、web_fetch、shell、memory、cron、文件 |
| test_routing | 17 | 7 级 Agent 解析、白名单、提及门控、回复格式 |
| test_agent | 15 | 模型解析、消息构建、工具规范、引导文件 |
| test_channels | 11 | 频道加载、最大长度、消息截断 |
| test_cli | 13 | CLI 参数解析、子命令路由 |
| test_memory | 10 | 存储、获取、搜索、列表、删除、导入/导出 |
| test_hooks | 7 | 注册、运行、链式调用、启用/禁用、转换、14 事件 |
| test_security | 8 | 配对码、频率限制、审计日志、执行审批、工具策略 |
| test_process | 3 | 队列 FIFO、出队、状态、类型化通道 |
| test_boot | 2 | BOOT.md 解析、状态跟踪 |
| test_autoreply | 6 | 规则增删、模式匹配、频道过滤 |
| test_daemon | 3 | 安装、卸载、状态 |
| test_install | 2 | 安装器帮助、prefix 选项 |
| test_integration | 11 | 真实 API 调用、多轮对话、工具使用、并发 |
| test_compat | 10 | Bash 3.2 兼容性、无 declare -A/-g、关键函数 |

## 设计决策

### 消除 OpenClaw 中的冗余

1. **配置验证**: 单次 jq 解析取代 6 次 Zod 验证和 234 个 `.strict()` 调用
2. **会话管理**: 直接 JSONL 文件操作取代复杂的合并/缓存层
3. **头像解析**: 完全消除（不再每次请求进行 base64 图片编码）
4. **日志**: 简单的级别检查 + printf 取代 10,000+ 行的 tslog 子系统
5. **工具加载**: 直接函数分发取代延迟加载模块注册表
6. **频道路由**: 简单的 case/函数模式取代 8 种适配器类型多态接口
7. **启动**: 即时（source 脚本）取代 40+ 个顺序异步初始化步骤

### Bash 3.2 兼容性

所有代码均可在 macOS 默认 bash (3.2)、Linux 和 Android Termux（无需 root）上运行：

- 不使用关联数组 (`declare -A`)
- 不使用 `declare -g` (全局声明)
- 不使用 `mapfile` / `readarray`
- 不使用 `&>>` 重定向操作符
- 基于文件的状态跟踪取代内存映射
- 系统命令的跨平台回退链

### 安全

- `web_fetch` 的 SSRF 保护（阻止私有 IP）
- 命令执行安全过滤（阻止 `rm -rf /`、fork 炸弹等）
- 频道认证配对码
- 基于令牌桶的每用户频率限制
- 每 Agent 的工具允许/拒绝策略列表
- 危险工具的提权授权检查
- 基于角色的命令授权 (RBAC)
- 所有安全事件的审计日志（JSONL）
- 配置文件权限控制 (chmod 600)

## 许可证

MIT
