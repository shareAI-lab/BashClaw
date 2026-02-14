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
| 代码行数 | ~20,000+ | ~10,400 |
| 依赖 | 52 个 npm 包 | jq, curl (socat 可选) |
| 启动时间 | 2-5秒 (Node 冷启动) | <100毫秒 |
| 内存占用 | 200-400MB | <10MB |
| 配置验证 | 6 次 + Zod | 单次 jq 解析 |
| 运行时 | Node.js 22+ | Bash 3.2+ |
| 测试用例 | 未知 | 222 个 (320 个断言) |

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
  bashclaw                # 主入口和 CLI 路由 (362 行)
  install.sh              # 独立安装器 (跨平台)
  lib/
    log.sh                # 日志子系统 (级别、颜色、文件输出)
    utils.sh              # 通用工具 (重试、端口检查、uuid 等)
    config.sh             # 配置管理 (基于 jq、环境变量替换)
    session.sh            # JSONL 会话持久化 (按发送者/频道/全局)
    agent.sh              # Agent 运行时 (Anthropic/OpenAI API、工具循环)
    tools.sh              # 内置工具 (web_fetch、shell、memory、cron 等)
    routing.sh            # 消息路由和分发
    memory.sh             # 长期记忆 (基于文件的键值存储)
    hooks.sh              # 事件驱动的钩子/中间件管道
    boot.sh               # 启动自动化 (解析 BOOT.md、执行代码块)
    autoreply.sh          # 基于模式匹配的自动回复规则
    process.sh            # 命令队列 (并发通道控制)
    security.sh           # 审计日志、配对码、频率限制
    daemon.sh             # 守护进程管理 (systemd/launchd/cron)
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
  -> 自动回复检查 (模式匹配 -> 立即响应)
  -> 钩子: pre_message (中间件管道)
  -> 路由 (白名单、提及门控、Agent 解析)
    -> 安全 (频率限制、配对码、执行审批)
    -> 处理队列 (每个 Agent 的并发通道)
    -> Agent 运行时 (模型选择、API 调用、工具循环)
      -> 钩子: pre_tool / post_tool
      -> 工具 (web_fetch、shell、memory、cron、message)
    -> 会话 (JSONL 追加、修剪、空闲重置)
  -> 钩子: post_message
  -> 投递 (格式化回复、拆分长消息、发送)

启动自动化:
  BOOT.md -> 解析代码块 -> 执行 (shell / agent 消息)

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

# 详细输出模式
bash tests/run_all.sh --verbose
```

### 测试覆盖

| 套件 | 用例数 | 覆盖内容 |
|---|---|---|
| test_utils | 25 | UUID、哈希、url_encode、重试、trim、时间戳 |
| test_config | 25 | 加载、获取、设置、验证、agent/频道配置 |
| test_session | 26 | JSONL 持久化、修剪、空闲重置、导出 |
| test_tools | 28 | 工具分发、web_fetch、shell、memory、cron |
| test_routing | 17 | Agent 解析、白名单、提及门控、回复格式 |
| test_agent | 15 | 模型解析、消息构建、工具规范 |
| test_channels | 11 | 频道加载、最大长度、消息截断 |
| test_cli | 13 | CLI 参数解析、子命令路由 |
| test_memory | 10 | 存储、获取、搜索、列表、删除、导入/导出 |
| test_hooks | 7 | 注册、运行、链式调用、启用/禁用、转换 |
| test_security | 8 | 配对码、频率限制、审计日志、执行审批 |
| test_process | 3 | 队列 FIFO、出队、状态 |
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
- 每用户频率限制
- 所有安全事件的审计日志（JSONL）
- 配置文件权限控制 (chmod 600)

## 许可证

MIT
