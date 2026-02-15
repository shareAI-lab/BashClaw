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
  <a href="#安装">安装</a> &middot;
  <a href="#快速开始">快速开始</a> &middot;
  <a href="#llm-提供者">提供者</a> &middot;
  <a href="#消息频道">频道</a> &middot;
  <a href="#架构">架构</a> &middot;
  <a href="README.md">English</a>
</p>
</div>

---

BashClaw 是纯 Shell 实现的 AI Agent 运行时。不需要 Node.js、Python、任何编译二进制 -- 只需 `bash`、`curl`、`jq`。它实现了与 OpenClaw 相同的多频道 Agent 架构，但可以在任何有 Shell 的地方运行。

因为 BashClaw 本身就是 Shell 脚本，Agent 可以在运行时热修改自身的源代码 -- 无需编译、无需重启、即时热自举。命令行 Shell 是 AI Agent 最擅长的心智模式，BashClaw 让 Agent 随时可以修改自己的程序。

## 为什么选择 BashClaw

```sh
# OpenClaw 需要:
node >= 22, npm, 52 packages, 200-400MB RAM, 2-5s 冷启动

# BashClaw 只需要:
bash >= 3.2, curl, jq
# 你的机器上已经有了。
```

|                  | OpenClaw (TS)   | BashClaw (Bash)   |
|------------------|-----------------|-------------------|
| 运行时           | Node.js 22+     | **Bash 3.2+**     |
| 依赖             | 52 个 npm 包    | **jq, curl**      |
| 内存             | 200-400 MB      | **< 10 MB**       |
| 冷启动           | 2-5 秒          | **< 100 ms**      |
| 代码行数         | ~20,000+        | **~14,000**       |
| 安装             | npm / Docker    | **curl \| bash**  |
| macOS 开箱即用   | 否 (需要 Node)  | **是**            |
| Android Termux   | 复杂            | **pkg install jq** |
| 热自修改         | 否 (需要构建)   | **是**            |
| 测试             | Vitest          | **334 个测试**    |

### 热自举

BashClaw 运行在 Shell 上 -- AI Agent 最擅长操作的环境。Agent 可以在运行时读取、修改、重载自身源代码，无需任何编译步骤。这使得 BashClaw 天然适合自演化的 Agent 工作流。

### 全平台运行

BashClaw 以 Bash 3.2 为目标 (Apple 自 2007 年以来冻结在每台 Mac 上的版本)。不用 `declare -A`、不用 `mapfile`、不用 `|&`。支持:

- macOS (2007 年以来的每个版本, 无需 Homebrew)
- Linux (任何发行版)
- Android Termux (无需 root)
- Windows (WSL2 / Git Bash)
- Alpine 容器、树莓派、嵌入式系统
- 国产信创系统 (任何支持 bash 的环境)

## 安装

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

或者克隆后直接运行:

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw && ./bashclaw doctor
```

## 快速开始

```sh
# 设置 API 密钥 (任选一个提供者)
export ANTHROPIC_API_KEY="sk-ant-..."    # 或 OPENAI_API_KEY, GOOGLE_API_KEY 等

# 聊天
./bashclaw agent -m "太阳的质量是多少?"

# 交互模式
./bashclaw agent -i

# 引导式设置
./bashclaw onboard
```

## LLM 提供者

BashClaw 支持 9 个提供者，数据驱动路由。添加新提供者只需一条 JSON -- 无需改代码。

### 国际提供者

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

### 国产提供者

全部使用 OpenAI 兼容 API。设置环境变量即可使用。

```sh
# DeepSeek
export DEEPSEEK_API_KEY="sk-..."
MODEL_ID=deepseek-chat bashclaw agent -m "hello"

# 通义千问 (阿里 DashScope)
export QWEN_API_KEY="sk-..."
MODEL_ID=qwen-max bashclaw agent -m "hello"

# 智谱 GLM
export ZHIPU_API_KEY="..."
MODEL_ID=glm-4.7-flash bashclaw agent -m "hello"

# Moonshot Kimi
export MOONSHOT_API_KEY="sk-..."
MODEL_ID=kimi-k2.5 bashclaw agent -m "hello"

# MiniMax
export MINIMAX_API_KEY="..."
MODEL_ID=MiniMax-M2.5 bashclaw agent -m "hello"
```

### 免费模型

| 模型 | 提供者 | 免费额度 |
|------|--------|----------|
| glm-4.7-flash | 智谱 | 免费 |
| glm-4.5-flash | 智谱 | 免费 |
| deepseek-chat | DeepSeek | 500 万 token (新用户 30 天) |
| qwen-turbo | 通义千问 | 免费额度 (新用户 90 天) |

### 模型别名

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

## 消息频道

BashClaw 支持多个消息平台。每个频道是 `channels/` 下的独立 Shell 脚本，持续扩充中。

| 频道 | 状态 | 模式 |
|------|------|------|
| Telegram | 稳定 | 长轮询监听 |
| Discord | 稳定 | WebSocket 网关 |
| Slack | 稳定 | Socket Mode / webhook |
| 飞书 / Lark | 稳定 | Webhook + App Bot 轮询 |
| QQ (OneBot v11) | 规划中 | NapCat / LLOneBot 桥接 |

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

### 飞书 / Lark

两种模式: **Webhook** (仅出站, 零配置) 和 **App Bot** (完整双向通信)。

```sh
# Webhook 模式 (简单)
bashclaw config set '.channels.feishu.webhookUrl' '"https://open.feishu.cn/open-apis/bot/v2/hook/xxx"'

# App Bot 模式 (完整功能)
bashclaw config set '.channels.feishu.appId' '"cli_xxx"'
bashclaw config set '.channels.feishu.appSecret' '"secret"'
bashclaw config set '.channels.feishu.monitorChats' '["oc_xxx"]'

# 国际版 (Lark)
bashclaw config set '.channels.feishu.region' '"intl"'

bashclaw gateway
```

### Slack

```sh
bashclaw config set '.channels.slack.botToken' '"xoxb-YOUR-TOKEN"'
bashclaw config set '.channels.slack.enabled' 'true'
bashclaw gateway
```

## 架构

```
                        +------------------+
                        |    CLI / 用户    |
                        +--------+---------+
                                 |
                  +--------------+--------------+
                  |       BashClaw (main)        |
                  |    472 行, CLI 路由器        |
                  +--------------+--------------+
                                 |
        +------------------------+------------------------+
        |                        |                        |
+-------+-------+      +--------+--------+      +--------+--------+
|    频道模块    |      |    核心引擎      |      |   后台系统       |
+-------+-------+      +--------+--------+      +--------+--------+
| telegram.sh   |      | agent.sh         |      | heartbeat.sh    |
| discord.sh    |      | routing.sh       |      | cron.sh         |
| slack.sh      |      | session.sh       |      | events.sh       |
| feishu.sh     |      | tools.sh (14)    |      | process.sh      |
| (插件: 任意)  |      | memory.sh        |      | daemon.sh       |
+---------------+      | config.sh        |      +-----------------+
                        +------------------+
                                 |
        +------------------------+------------------------+
        |                        |                        |
+-------+-------+      +--------+--------+      +--------+--------+
|   扩展系统     |      |    安全模块      |      |   CLI 命令       |
+-------+-------+      +--------+--------+      +--------+--------+
| plugin.sh      |      | 8 层安全模型     |      | cmd_agent.sh    |
| skills.sh      |      | SSRF 防护       |      | cmd_config.sh   |
| hooks.sh (14)  |      | 频率限制        |      | cmd_session.sh  |
| autoreply.sh   |      | RBAC + 审计     |      | cmd_cron.sh     |
| boot.sh        |      | 配对码          |      | cmd_daemon.sh   |
| dedup.sh       |      | 工具策略        |      | cmd_gateway.sh  |
+----------------+      +-----------------+      | cmd_memory.sh   |
                                                  | cmd_hooks.sh    |
                                                  | cmd_onboard.sh  |
                                                  | cmd_message.sh  |
                                                  +-----------------+
```

### 消息流程

```
用户消息 --> 去重 --> 自动回复 --> 钩子: pre_message
  |
  v
路由 (7 级优先级: peer > parent > guild > channel > team > account > default)
  |
  v
安全门控 (频率限制, 配对验证, 工具策略, RBAC)
  |
  v
处理队列 (main: 4, cron: 1, subagent: 8 并发)
  |
  v
Agent 运行时
  1. 解析模型 + 提供者 (数据驱动, 来自 models.json)
  2. 加载工作空间 (SOUL.md, MEMORY.md, BOOT.md)
  3. 构建系统提示 (10 个段)
  4. API 调用 (Anthropic / OpenAI / Google / OpenRouter / DeepSeek / Qwen / Zhipu / Moonshot / MiniMax)
  5. 工具循环 (最大 10 次)
  6. 溢出降级 (减少历史 -> 压缩 -> 模型降级 -> 重置)
  |
  v
会话持久化 (JSONL) --> 钩子: post_message --> 投递
```

## 命令

```sh
bashclaw agent    [-m MSG] [-i] [-a AGENT]   # 与 Agent 聊天
bashclaw gateway  [-p PORT] [-d] [--stop]    # 启动/停止网关
bashclaw daemon   [install|uninstall|status|logs|restart|stop]
bashclaw message  send -c CH -t TO -m MSG    # 发送到频道
bashclaw config   [show|get|set|init|validate|edit|path]
bashclaw session  [list|show|clear|delete|export]
bashclaw memory   [list|get|set|delete|search|export|import|compact|stats]
bashclaw cron     [list|add|remove|enable|disable|run|history]
bashclaw hooks    [list|add|remove|enable|disable|test]
bashclaw boot     [run|find|status|reset]
bashclaw security [pair-generate|pair-verify|tool-check|elevated-check|audit]
bashclaw onboard                             # 交互式设置向导
bashclaw status                              # 系统状态
bashclaw doctor                              # 诊断问题
bashclaw update                              # 更新到最新版本
bashclaw completion [bash|zsh]               # Shell 补全
```

## 内置工具 (14 个)

| 工具 | 描述 | 权限等级 |
|------|------|----------|
| `web_fetch` | HTTP GET/POST, 带 SSRF 防护 | 无 |
| `web_search` | 网页搜索 (Brave / Perplexity) | 无 |
| `shell` | 执行命令 (安全过滤) | 需提权 |
| `memory` | 持久化键值存储, 支持标签 | 无 |
| `cron` | 调度定期任务 | 无 |
| `message` | 发送消息到频道 | 无 |
| `agents_list` | 列出可用 Agent | 无 |
| `session_status` | 当前会话信息 | 无 |
| `sessions_list` | 列出所有会话 | 无 |
| `agent_message` | 发送消息给其他 Agent | 无 |
| `read_file` | 读取文件内容 (行数限制) | 无 |
| `write_file` | 写入内容到文件 | 需提权 |
| `list_files` | 列出目录内容 | 无 |
| `file_search` | 按模式搜索文件 | 无 |

## 安全模型 (8 层)

```
Layer 1: SSRF 防护       -- web_fetch 阻止私有/内部 IP
Layer 2: 命令过滤        -- 阻止 rm -rf /, fork 炸弹等
Layer 3: 配对码          -- 6 位限时频道认证
Layer 4: 频率限制        -- 每用户令牌桶 (可配置)
Layer 5: 工具策略        -- 每 Agent 允许/拒绝列表
Layer 6: 提权策略        -- 危险工具需要授权
Layer 7: RBAC            -- 基于角色的命令授权
Layer 8: 审计日志        -- 所有安全事件的 JSONL 记录
```

## 插件系统

```
插件发现 (4 个来源):
  1. ${BASHCLAW_ROOT}/extensions/     # 内置
  2. ~/.bashclaw/extensions/          # 全局用户
  3. .bashclaw/extensions/            # 工作空间本地
  4. config: plugins.load.paths       # 自定义路径
```

每个插件有一个 `bashclaw.plugin.json` 清单:

```sh
plugin_register_tool "my_tool" "Does something" '{"input":{"type":"string"}}' "$PWD/handler.sh"
plugin_register_hook "pre_message" "$PWD/filter.sh" 50
plugin_register_command "my_cmd" "Custom command" "$PWD/cmd.sh"
plugin_register_provider "my_llm" "My LLM" '["model-a"]' '{"envKey":"MY_KEY"}'
```

## 钩子系统 (14 个事件)

```
事件                  策略          触发时机
pre_message          modifying    消息处理前 (可修改输入)
post_message         void         消息处理后
pre_tool             modifying    工具执行前 (可修改参数)
post_tool            modifying    工具执行后 (可修改结果)
on_error             void         发生错误时
on_session_reset     void         会话重置时
before_agent_start   sync         Agent 开始处理前
agent_end            void         Agent 处理完成后
before_compaction    sync         上下文压缩前
after_compaction     void         上下文压缩后
message_received     modifying    网关收到消息时
message_sending      modifying    回复发送前
message_sent         void         回复发送后
session_start        void         新会话创建时
```

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
    "telegram": { "enabled": true, "botToken": "$TELEGRAM_BOT_TOKEN" },
    "feishu": { "appId": "$FEISHU_APP_ID", "appSecret": "$FEISHU_APP_SECRET" }
  },
  "gateway": { "port": 18789 },
  "session": { "scope": "per-sender", "idleResetMinutes": 30 }
}
```

### 环境变量

| 变量 | 用途 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic Claude |
| `OPENAI_API_KEY` | OpenAI |
| `GOOGLE_API_KEY` | Google Gemini |
| `OPENROUTER_API_KEY` | OpenRouter |
| `DEEPSEEK_API_KEY` | DeepSeek |
| `QWEN_API_KEY` | 通义千问 (阿里 DashScope) |
| `ZHIPU_API_KEY` | 智谱 GLM |
| `MOONSHOT_API_KEY` | Moonshot Kimi |
| `MINIMAX_API_KEY` | MiniMax |
| `MODEL_ID` | 覆盖默认模型 |
| `BASHCLAW_STATE_DIR` | 状态目录 (默认: ~/.bashclaw) |
| `LOG_LEVEL` | debug \| info \| warn \| error \| silent |

## 测试

```sh
# 运行所有 (334 个测试, 473 个断言)
bash tests/run_all.sh

# 按类别
bash tests/run_all.sh --unit
bash tests/run_all.sh --compat
bash tests/run_all.sh --integration

# 单个套件
bash tests/test_agent.sh
```

| 套件 | 测试数 | 覆盖内容 |
|------|--------|----------|
| test_utils | 25 | UUID, 哈希, 重试, 时间戳 |
| test_config | 25 | 加载, 获取, 设置, 验证 |
| test_session | 26 | JSONL, 修剪, 空闲重置, 导出 |
| test_tools | 28 | 14 个工具, SSRF, 分发 |
| test_routing | 17 | 7 级解析, 白名单 |
| test_agent | 15 | 模型, 提供者路由, 引导文件 |
| test_channels | 11 | 源解析, 截断 |
| test_cli | 13 | 参数解析, 路由 |
| test_memory | 10 | 存储, 搜索, 导入/导出 |
| test_hooks | 7 | 注册, 链式, 变换 |
| test_security | 8 | 配对码, 频率限制, RBAC |
| test_process | 13 | 队列, 通道, 并发 |
| test_boot | 2 | BOOT.md 解析 |
| test_autoreply | 6 | 模式匹配, 过滤 |
| test_daemon | 3 | 安装, 状态 |
| test_install | 2 | 安装器验证 |
| test_heartbeat | 18 | 守卫链, 活跃时段, 事件 |
| test_events | 12 | FIFO 队列, 排空, 去重 |
| test_cron_advanced | 17 | 调度类型, 退避, 卡死任务 |
| test_plugin | 14 | 发现, 加载, 注册, 启用 |
| test_skills | 11 | 技能发现, 加载 |
| test_dedup | 13 | TTL 缓存, 过期, 清理 |
| test_integration | 11 | 实时 API, 多轮对话 |
| test_compat | 10 | Bash 3.2 验证 |

## 许可证

MIT
