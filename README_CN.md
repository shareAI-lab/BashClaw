<div align="center">

<img src="assets/logo.png" alt="BashClaw" width="600" />

**Bash is all you need.**

纯 Shell AI 智能体运行时。不需要 Node.js、Python 或编译二进制。

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
  <a href="#安装">安装</a> &middot;
  <a href="#快速开始">快速开始</a> &middot;
  <a href="#特性">特性</a> &middot;
  <a href="#web-控制台">控制台</a> &middot;
  <a href="#模型提供者">提供者</a> &middot;
  <a href="#消息频道">频道</a> &middot;
  <a href="#架构">架构</a> &middot;
  <a href="README.md">English</a>
</p>
</div>

---

## 安装

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

或直接克隆:

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw && ./bashclaw doctor
```

## 快速开始

```sh
export ANTHROPIC_API_KEY="sk-ant-..."   # 或 OPENAI_API_KEY, GOOGLE_API_KEY 等

bashclaw agent -m "太阳的质量是多少?"    # 单次问答
bashclaw agent -i                        # 交互式 REPL
bashclaw onboard                         # 引导式安装向导
bashclaw gateway                         # Web 控制台 + 频道
```

## 为什么选 BashClaw

```
+---------------------+------------------+------------------+
|                     |  OpenClaw (TS)   | BashClaw (Bash)  |
+---------------------+------------------+------------------+
| 运行时              | Node.js 22+      | Bash 3.2+        |
| 依赖                | 52 npm packages  | jq + curl        |
| 内存                | 200-400 MB       | < 10 MB          |
| 冷启动              | 2-5 秒           | < 100 ms         |
| 安装                | npm / Docker     | curl | bash      |
| macOS 开箱即用      | 否 (需要 Node)   | 是               |
| Android Termux      | 复杂             | pkg install jq   |
| 运行时自修改        | 否 (需要构建)    | 是               |
| 测试                | Vitest           | 334 通过         |
+---------------------+------------------+------------------+
```

BashClaw 是 Shell 脚本 -- 智能体可以在运行时**读取、修改并重新加载自己的源代码**。无需编译、无需重启,即时自举。

### Bash 3.2: 通用运行时

Bash 3.2 于 **2006 年 10 月**发布,是最后一个 GPLv2 许可证版本。Apple 从 macOS Leopard (2007) 开始在每台 Mac 上固定使用 3.2,因为后续版本 (4.0+) 改用 GPLv3 与 Apple 许可策略冲突。

BashClaw 刻意以 Bash 3.2 为目标: 不用 `declare -A`、不用 `mapfile`、不用 `|&`。这意味着可以运行在:

- **macOS** -- 2007 年至今的所有版本,零额外安装
- **Linux** -- 任何发行版 (Ubuntu, Debian, Fedora, Alpine, Arch...)
- **Android Termux** -- 无需 root
- **Windows** -- WSL2, Git Bash, Cygwin
- **嵌入式** -- Alpine 容器、树莓派、CI 运行器、NAS

## 特性

- **纯 Shell** -- 仅依赖 bash 3.2, curl, jq。你的机器上已经有了。
- **自修改** -- 智能体在运行时热修改自身源代码。无编译步骤。
- **多提供者** -- 9 个提供者: Claude, GPT, Gemini, DeepSeek, 通义千问, 智谱 GLM, Moonshot, MiniMax, OpenRouter。
- **多频道** -- Telegram, Discord, Slack, 飞书/Lark。每个频道是一个 Shell 脚本。
- **Web 控制台** -- 内置浏览器界面,用于聊天、配置和监控。无需外部工具。
- **14 个内置工具** -- Web 抓取、搜索、Shell 执行、记忆、定时任务、文件 I/O、智能体间通信。
- **插件系统** -- 4 个发现路径。可注册工具、钩子、命令、提供者。
- **8 层安全模型** -- SSRF 防护、命令过滤、配对码、限流、RBAC、审计。
- **会话管理** -- 5 种作用域模式、JSONL 持久化、空闲重置、上下文压缩。
- **定时调度** -- `at` / `every` / `cron` 表达式、退避、卡住任务检测。
- **14 个钩子事件** -- 消息、工具、压缩、会话生命周期的前/后钩子。
- **热配置重载** -- `kill -USR1` 网关进程即可重载配置。
- **守护进程** -- systemd, launchd, Termux 开机启动, crontab 回退。
- **334 个测试** -- 单元测试、兼容性 (Bash 3.2 验证)、集成测试。473 个断言。

## Web 控制台

启动网关并在浏览器中打开 `http://localhost:18789`:

```sh
bashclaw gateway
```

```
+-------------------------------------------------------+
|  BashClaw 控制台          [聊天] [设置] [状态]          |
+-------------------------------------------------------+
|                                                        |
|  你: 东京现在天气怎么样?                                |
|                                                        |
|  智能体: 让我查一下...                                  |
|  [tool: web_search] ...                                |
|  东京目前 12 度,多云。                                  |
|                                                        |
|  [____________________________________] [发送]         |
+-------------------------------------------------------+
```

**聊天** -- 直接在浏览器中与智能体对话。无需配置任何频道。
**设置** -- API 密钥、模型选择、频道状态。密钥仅存储在服务端。
**状态** -- 网关状态、活跃会话、提供者信息。
**首次引导** -- 如果没有配置 API 密钥,首次访问会显示配置引导。

### Web + CLI 双模式

两种模式共享相同的配置、会话和状态。控制台中的更改立即在 CLI 中生效,反之亦然。

| 模式 | 适用场景 | 命令 |
|------|----------|------|
| Web | 首次配置、可视化管理、日常聊天 | `bashclaw gateway` |
| CLI | 自动化、脚本、SSH 会话、高级用户 | `bashclaw agent -i` |

### REST API

```
GET  /api/status        系统状态
GET  /api/config        读取配置 (敏感值已遮蔽)
PUT  /api/config        更新配置 (部分合并)
GET  /api/models        列出模型、别名、提供者
GET  /api/sessions      列出活跃会话
POST /api/sessions/clear  清除会话
POST /api/chat          向智能体发送消息
GET  /api/channels      列出频道
GET  /api/env           检查已设置的 API 密钥
PUT  /api/env           保存 API 密钥
```

<details>
<summary><strong>各平台访问方式</strong></summary>

| 平台 | 访问方式 | 备注 |
|------|----------|------|
| macOS / Linux | `localhost:18789` | 完整浏览器体验 |
| Android Termux | 手机浏览器打开 `localhost:18789` | 响应式触屏 UI |
| 云服务器 | `ssh -L 18789:localhost:18789 server` | 端口转发 |
| Windows WSL2 | Windows 浏览器打开 `localhost:18789` | 自动端口转发 |
| 无头 / CI | 仅 CLI | `bashclaw agent -m "..."` |

</details>

## 模型提供者

BashClaw 支持 9 个提供者,基于数据驱动路由。添加提供者只需一个 JSON 条目,无需修改代码。

```sh
# Anthropic (默认)
export ANTHROPIC_API_KEY="sk-ant-..."
bashclaw agent -m "hello"

# OpenAI
export OPENAI_API_KEY="sk-..."
MODEL_ID=gpt-4o bashclaw agent -m "hello"

# Google Gemini
export GOOGLE_API_KEY="..."
MODEL_ID=gemini-2.0-flash bashclaw agent -m "hello"

# OpenRouter (任意模型)
export OPENROUTER_API_KEY="sk-or-..."
MODEL_ID=anthropic/claude-sonnet-4 bashclaw agent -m "hello"
```

<details>
<summary><strong>国内提供者</strong></summary>

所有国内提供者使用 OpenAI 兼容 API:

```sh
# DeepSeek
export DEEPSEEK_API_KEY="sk-..."
MODEL_ID=deepseek-chat bashclaw agent -m "hello"

# 通义千问 (阿里 DashScope)
export QWEN_API_KEY="sk-..."
MODEL_ID=qwen-max bashclaw agent -m "hello"

# 智谱 GLM
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
<summary><strong>模型别名</strong></summary>

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

## 消息频道

每个频道是 `channels/` 下的独立 Shell 脚本。

| 频道 | 状态 | 模式 |
|------|------|------|
| Telegram | 稳定 | Bot API 长轮询 |
| Discord | 稳定 | REST API + 打字状态 |
| Slack | 稳定 | Socket Mode / Webhook |
| 飞书 / Lark | 稳定 | Webhook + 应用机器人 |

<details>
<summary><strong>频道配置</strong></summary>

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

**飞书 / Lark** (两种模式)
```sh
# Webhook 模式 (仅发送)
bashclaw config set '.channels.feishu.webhookUrl' '"https://open.feishu.cn/..."'

# 应用机器人模式 (完整双向)
bashclaw config set '.channels.feishu.appId' '"cli_xxx"'
bashclaw config set '.channels.feishu.appSecret' '"secret"'
bashclaw config set '.channels.feishu.monitorChats' '["oc_xxx"]'

# 国际版 (Lark)
bashclaw config set '.channels.feishu.region' '"intl"'
bashclaw gateway
```

</details>

## 架构

```
                       +------------------+
                       |  CLI / 浏览器    |
                       +--------+---------+
                                |
                 +--------------+--------------+
                 |       bashclaw (主入口)      |
                 |      CLI 路由 + 模块加载     |
                 +--------------+--------------+
                                |
       +------------------------+------------------------+
       |                        |                        |
+------+------+        +-------+-------+        +-------+-------+
|    频道     |        |   核心引擎    |        |   后台服务    |
+------+------+        +-------+-------+        +-------+-------+
| telegram.sh |        | agent.sh      |        | heartbeat.sh  |
| discord.sh  |        | routing.sh    |        | cron.sh       |
| slack.sh    |        | session.sh    |        | events.sh     |
| feishu.sh   |        | tools.sh (14) |        | process.sh    |
| (插件)      |        | memory.sh     |        | daemon.sh     |
+-------------+        | config.sh     |        +---------------+
                       +---------------+
                                |
       +------------------------+------------------------+
       |                        |                        |
+------+------+        +-------+-------+        +-------+-------+
| Web / API   |        |    安全层     |        |    扩展      |
+------+------+        +-------+-------+        +-------+-------+
| http_handler |       | SSRF 过滤     |        | plugin.sh     |
| ui/index.html|       | 限流          |        | skills.sh     |
| ui/style.css |       | 配对码        |        | hooks.sh (14) |
| ui/app.js    |       | 工具策略      |        | autoreply.sh  |
| REST API (9) |       | RBAC + 审计   |        | boot.sh       |
+--------------+       +---------------+        | dedup.sh      |
                                                +---------------+
```

### 消息流

```
用户消息 --> 去重 --> 自动回复检查 --> 钩子: pre_message
  |
  v
路由 (7 级: peer > parent > guild > channel > team > account > default)
  |
  v
安全门 (限流 -> 配对 -> 工具策略 -> RBAC)
  |
  v
处理队列 (主: 4, 定时: 1, 子智能体: 8 并发通道)
  |
  v
智能体运行时
  1. 解析模型 + 提供者 (数据驱动, models.json)
  2. 加载工作区 (SOUL.md, MEMORY.md, BOOT.md, IDENTITY.md)
  3. 构建系统提示词 (10 个段落)
  4. API 调用 (Anthropic / OpenAI / Google / ...)
  5. 工具循环 (最多 10 次迭代)
  6. 溢出处理: 缩减历史 -> 压缩 -> 模型降级 -> 重置
  |
  v
会话持久化 (JSONL) --> 钩子: post_message --> 投递
```

### 目录结构

```
bashclaw/
  bashclaw              # 主入口 (CLI 路由)
  install.sh            # 独立安装脚本
  lib/
    agent.sh            # 智能体运行时、模型/提供者调度
    config.sh           # JSON 配置 (基于 jq)
    session.sh          # JSONL 会话持久化
    routing.sh          # 7 级消息路由
    tools.sh            # 14 个内置工具 + 调度
    memory.sh           # KV 存储 + BM25 搜索
    security.sh         # 8 层安全模型
    process.sh          # 双层队列 + 类型化通道
    cron.sh             # 调度器 (at/every/cron)
    hooks.sh            # 14 个事件类型, 3 种策略
    plugin.sh           # 4 源插件发现
    skills.sh           # 技能加载器
    heartbeat.sh        # 自主心跳
    events.sh           # FIFO 事件队列
    boot.sh             # BOOT.md 解析器
    autoreply.sh        # 基于模式的自动回复
    dedup.sh            # TTL 去重缓存
    log.sh              # 结构化日志
    utils.sh            # UUID, 哈希, 重试, 时间戳
    cmd_*.sh            # CLI 子命令处理器
  channels/
    telegram.sh         # Telegram Bot API
    discord.sh          # Discord REST + 打字状态
    slack.sh            # Slack Socket Mode + Webhook
    feishu.sh           # 飞书/Lark Webhook + 应用机器人
  gateway/
    http_handler.sh     # HTTP 请求处理器 + REST API
  ui/
    index.html          # 控制台页面
    style.css           # 深色/浅色主题, 响应式
    app.js              # 原生 JS 单页应用
  tools/                # 外部工具脚本
  tests/
    framework.sh        # 测试框架
    test_*.sh           # 23 个测试套件, 334 个测试
```

## 命令

| 命令 | 子命令 | 说明 |
|------|--------|------|
| `agent` | `-m MSG`, `-i`, `-a AGENT` | 与智能体对话 |
| `gateway` | `-p PORT`, `-d`, `--stop` | HTTP 网关 + 频道 |
| `daemon` | `install`, `uninstall`, `status`, `logs`, `restart`, `stop` | 系统服务 |
| `config` | `show`, `get`, `set`, `init`, `validate`, `edit`, `path` | 配置管理 |
| `session` | `list`, `show`, `clear`, `delete`, `export` | 会话管理 |
| `memory` | `list`, `get`, `set`, `delete`, `search`, `export`, `import`, `compact`, `stats` | KV 存储 |
| `cron` | `list`, `add`, `remove`, `enable`, `disable`, `run`, `history` | 定时任务 |
| `hooks` | `list`, `add`, `remove`, `enable`, `disable`, `test` | 事件钩子 |
| `boot` | `run`, `find`, `status`, `reset` | 启动序列 |
| `security` | `pair-generate`, `pair-verify`, `tool-check`, `audit` | 安全管理 |
| `onboard` | | 安装向导 |
| `doctor` | | 诊断检查 |
| `status` | | 系统状态 |
| `update` | | 更新到最新版本 |
| `completion` | `bash`, `zsh` | Shell 补全 |

## 内置工具

| 工具 | 说明 | 权限 |
|------|------|------|
| `web_fetch` | HTTP GET/POST (SSRF 防护) | 普通 |
| `web_search` | Web 搜索 (Brave / Perplexity) | 普通 |
| `shell` | 执行命令 (安全过滤) | 提升 |
| `memory` | 持久化 KV 存储 + 标签 | 普通 |
| `cron` | 定时任务调度 | 普通 |
| `message` | 向频道发送消息 | 普通 |
| `agents_list` | 列出可用智能体 | 普通 |
| `session_status` | 当前会话信息 | 普通 |
| `sessions_list` | 列出所有会话 | 普通 |
| `agent_message` | 智能体间通信 | 普通 |
| `read_file` | 读取文件 | 普通 |
| `write_file` | 写入文件 | 提升 |
| `list_files` | 列出目录 | 普通 |
| `file_search` | 按模式搜索文件 | 普通 |

## 安全模型

```
第 1 层: SSRF 防护       -- 在 web_fetch 中阻止私有/内部 IP
第 2 层: 命令过滤        -- 阻止 rm -rf /, fork 炸弹等
第 3 层: 配对码          -- 6 位限时频道认证
第 4 层: 限流            -- 令牌桶, 每发送者独立
第 5 层: 工具策略        -- 每个智能体的允许/拒绝列表
第 6 层: 提升策略        -- 危险工具的授权
第 7 层: RBAC            -- 基于角色的命令授权
第 8 层: 审计日志        -- 所有安全事件的 JSONL 记录
```

## 插件系统

```
插件发现 (4 个来源):
  ${BASHCLAW_ROOT}/extensions/      # 内置
  ~/.bashclaw/extensions/           # 全局用户
  .bashclaw/extensions/             # 工作区本地
  config: plugins.load.paths        # 自定义路径
```

插件可以注册工具、钩子、命令和提供者:

```sh
plugin_register_tool "my_tool" "说明" '{"input":{"type":"string"}}' handler.sh
plugin_register_hook "pre_message" filter.sh 50
plugin_register_command "my_cmd" "说明" cmd.sh
plugin_register_provider "my_llm" "My LLM" '["model-a"]' '{"envKey":"MY_KEY"}'
```

## 钩子系统

| 事件 | 策略 | 触发时机 |
|------|------|----------|
| `pre_message` | modifying | 处理前 (可修改输入) |
| `post_message` | void | 处理后 |
| `pre_tool` | modifying | 工具执行前 (可修改参数) |
| `post_tool` | modifying | 工具执行后 (可修改结果) |
| `on_error` | void | 发生错误时 |
| `on_session_reset` | void | 会话重置时 |
| `before_agent_start` | sync | 智能体开始前 |
| `agent_end` | void | 智能体结束后 |
| `before_compaction` | sync | 上下文压缩前 |
| `after_compaction` | void | 上下文压缩后 |
| `message_received` | modifying | 消息到达网关 |
| `message_sending` | modifying | 回复发送前 |
| `message_sent` | void | 回复发送后 |
| `session_start` | void | 新会话创建 |

## 配置

配置文件: `~/.bashclaw/bashclaw.json`

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
<summary><strong>环境变量</strong></summary>

| 变量 | 用途 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic Claude |
| `OPENAI_API_KEY` | OpenAI |
| `GOOGLE_API_KEY` | Google Gemini |
| `OPENROUTER_API_KEY` | OpenRouter |
| `DEEPSEEK_API_KEY` | DeepSeek |
| `QWEN_API_KEY` | 通义千问 (DashScope) |
| `ZHIPU_API_KEY` | 智谱 GLM |
| `MOONSHOT_API_KEY` | Moonshot Kimi |
| `MINIMAX_API_KEY` | MiniMax |
| `MODEL_ID` | 覆盖默认模型 |
| `BASHCLAW_STATE_DIR` | 状态目录 (默认: `~/.bashclaw`) |
| `LOG_LEVEL` | `debug` / `info` / `warn` / `error` / `silent` |

</details>

## 使用场景

**Mac 上的个人助手**
```sh
export ANTHROPIC_API_KEY="sk-ant-..."
bashclaw agent -i
# 不需要 Python、Node、Docker。直接运行。
```

**无头服务器智能体**
```sh
# 在全新 Ubuntu 服务器上安装
curl -fsSL .../install.sh | bash
bashclaw daemon install --enable
# 智能体 7x24 运行,通过 Telegram 或 Web 控制台访问
```

**CI/CD 流水线智能体**
```sh
# 在 Dockerfile 或 CI 步骤中 (< 10MB 开销)
bashclaw agent -m "审查这个 diff 并提出改进建议" < diff.patch
```

**多频道团队机器人**
```sh
# 一个智能体,多个频道
bashclaw config set '.channels.telegram.enabled' 'true'
bashclaw config set '.channels.discord.enabled' 'true'
bashclaw config set '.channels.slack.enabled' 'true'
bashclaw gateway
# 所有平台的消息路由到同一个智能体
```

## 测试

```sh
bash tests/run_all.sh              # 全部 334 个测试
bash tests/run_all.sh --unit       # 仅单元测试
bash tests/run_all.sh --compat     # Bash 3.2 兼容性验证
bash tests/run_all.sh --integration  # 实时 API 测试
bash tests/test_agent.sh           # 单个测试套件
```

<details>
<summary><strong>测试套件 (23 个)</strong></summary>

| 套件 | 测试数 | 覆盖 |
|------|--------|------|
| test_utils | 25 | UUID, 哈希, 重试, 时间戳 |
| test_config | 25 | 加载, 获取, 设置, 验证 |
| test_session | 26 | JSONL, 修剪, 空闲重置, 导出 |
| test_tools | 28 | 14 个工具, SSRF, 调度 |
| test_routing | 17 | 7 级解析, 允许列表 |
| test_agent | 15 | 模型, 提供者路由, 引导 |
| test_channels | 11 | 源解析, 截断 |
| test_cli | 13 | 参数解析, 路由 |
| test_memory | 10 | 存储, 搜索, 导入/导出 |
| test_hooks | 7 | 注册, 链, 转换 |
| test_security | 8 | 配对, 限流, RBAC |
| test_process | 13 | 队列, 通道, 并发 |
| test_boot | 2 | BOOT.md 解析 |
| test_autoreply | 6 | 模式匹配, 过滤 |
| test_daemon | 3 | 安装, 状态 |
| test_install | 2 | 安装器验证 |
| test_heartbeat | 18 | 守卫链, 活跃时段 |
| test_events | 12 | FIFO 队列, 排空, 去重 |
| test_cron_advanced | 17 | 调度类型, 退避 |
| test_plugin | 14 | 发现, 加载, 注册 |
| test_skills | 11 | 技能发现, 加载 |
| test_dedup | 13 | TTL 缓存, 过期 |
| test_integration | 11 | 实时 API, 多轮 |
| test_compat | 10 | Bash 3.2 验证 |

</details>

## 故障排查

```sh
bashclaw doctor        # 检查依赖、配置、API 密钥
bashclaw status        # 网关状态、会话数
bashclaw config show   # 输出当前配置
LOG_LEVEL=debug bashclaw agent -m "test"  # 详细输出
```

**常见问题:**
- 安装后 `command not found` -- 运行 `source ~/.zshrc` (macOS) 或 `source ~/.bashrc` (Linux),或打开新终端
- `jq: command not found` -- 安装器会自动安装 jq;如果失败,运行 `brew install jq` (macOS) 或 `apt install jq` (Linux)
- 网关无法提供 HTTP -- 安装 `socat`: `brew install socat` (macOS) 或 `apt install socat` (Linux)

## 许可证

MIT
