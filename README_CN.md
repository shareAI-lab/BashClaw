<div align="center">
<pre>
     _               _          _
    | |__   __ _ ___| |__   ___| | __ ___      __
    | '_ \ / _` / __| '_ \ / __| |/ _` \ \ /\ / /
    | |_) | (_| \__ \ | | | (__| | (_| |\ V  V /
    |_.__/ \__,_|___/_| |_|\___|_|\__,_| \_/\_/
</pre>

<h3>零依赖 AI 助手，Bash 在哪它就在哪。</h3>

<p>纯 Bash + curl + jq。不需要 Node.js、Python、任何二进制文件。<br>
与 <a href="https://github.com/openclaw/openclaw">OpenClaw</a> 同架构，99% 更轻量。</p>

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
  <a href="#一键安装">安装</a> &middot;
  <a href="#快速开始">快速开始</a> &middot;
  <a href="#架构">架构</a> &middot;
  <a href="#命令">命令</a> &middot;
  <a href="README.md">English</a>
</p>
</div>

---

## 为什么选择 bashclaw?

```sh
# OpenClaw 需要这些:
node >= 22, npm, 52 packages, playwright, sharp, 200-400MB RAM, 2-5s startup

# bashclaw 只需要:
bash >= 3.2, curl, jq
# 你的机器上已经有了。
```

|                  | OpenClaw (TS)   | nanobot (Python)  | bashclaw          |
|------------------|-----------------|-------------------|-------------------|
| 运行时           | Node.js 22+     | Python 3.11+      | **Bash 3.2+**     |
| 依赖             | 52 个 npm 包    | pip + 包          | **jq, curl**      |
| 内存             | 200-400 MB      | 80-150 MB         | **< 10 MB**       |
| 启动时间         | 2-5 秒          | 1-2 秒            | **< 100 ms**      |
| 代码行数         | ~20,000+        | ~4,000            | **~17,300**       |
| 安装             | npm/Docker      | pip/Docker        | **curl \| bash**  |
| macOS 开箱即用   | 否 (需要 Node)  | 否 (需要 Python)  | **是**            |
| Android Termux   | 复杂            | 复杂              | **pkg install jq** |
| 测试覆盖         | 未知            | 未知              | **334 个测试**    |

### Bash 3.2: 为什么重要

```
2006-10  Bash 3.2 发布 (Chet Ramey, Case Western Reserve University)
2007-10  macOS Leopard 搭载 Bash 3.2 -- 此后每台 Mac 都有
2009-02  Bash 4.0 发布 (新增关联数组、mapfile、|& 等特性)
2019-06  macOS Catalina 将默认 shell 切换为 zsh
2019-    Apple 将 /bin/bash 永久冻结在 3.2.57 (拒绝 GPLv3)
2025     每台 Mac、每个 Linux、Android Termux -- 都有 Bash 3.2+
```

bashclaw 有意只用 3.2 特性: 不用 `declare -A`、不用 `mapfile`、不用 `|&`。
这意味着它可以在**自 2007 年以来出货的每台 Mac** 上运行而无需 Homebrew，
也可以在任何 Linux 发行版、Android Termux (无需 root)、Windows WSL、
Alpine 容器和树莓派上运行。零编译。零二进制下载。

## 一键安装

```sh
curl -fsSL https://raw.githubusercontent.com/shareAI-lab/bashclaw/main/install.sh | bash
```

或者克隆后直接运行 (零安装):

```sh
git clone https://github.com/shareAI-lab/bashclaw.git
cd bashclaw && ./bashclaw doctor
```

### 平台支持

| 平台                  | 方式                 | 状态                |
|-----------------------|----------------------|---------------------|
| macOS (Intel/Apple)   | curl 安装或 git      | 开箱即用            |
| Ubuntu / Debian       | curl 安装或 git      | 开箱即用            |
| Fedora / RHEL / Arch  | curl 安装或 git      | 开箱即用            |
| Alpine Linux          | apk add bash jq curl | 可用                |
| Windows (WSL2)        | curl 安装或 git      | 可用                |
| Android (Termux)      | pkg install jq curl  | 可用, 无需 root     |
| Raspberry Pi          | curl 安装或 git      | 可用 (< 10MB RAM)   |
| Docker / CI           | git clone            | 可用                |

## 快速开始

```sh
# 第 1 步: 设置 API 密钥
export ANTHROPIC_API_KEY="sk-ant-..."

# 第 2 步: 聊天
./bashclaw agent -m "太阳的质量是多少?"

# 第 3 步: 交互模式
./bashclaw agent -i
```

三条命令搞定。无需配置文件、无需向导、无需注册。

如需引导式设置 (含频道配置):

```sh
./bashclaw onboard
```

## 架构

```
                          +------------------+
                          |    CLI / 用户    |
                          +--------+---------+
                                   |
                    +--------------+--------------+
                    |        bashclaw (main)       |
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
  | (插件: 任意)  |      | tools.sh (14)    |      | process.sh      |
  +---------------+      | memory.sh        |      | daemon.sh       |
                          | config.sh        |      +-----------------+
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
  +-----------------+      +-----------------+      | cmd_memory.sh   |
                                                    | cmd_hooks.sh    |
                                                    | cmd_onboard.sh  |
                                                    | cmd_message.sh  |
                                                    +-----------------+
```

### 消息处理流程

```
用户消息
  |
  v
去重检查 ---------> [重复?] --> 丢弃
  |
  v
自动回复检查 -----> [模式匹配?] --> 即时回复
  |
  v
钩子: pre_message (修改型管道)
  |
  v
路由 (7 级优先级解析)
  |  L1: 精确 peer 绑定
  |  L2: 父级 peer (线程继承)
  |  L3: guild 绑定
  |  L4: channel 绑定
  |  L5: team 绑定
  |  L6: account 绑定
  |  L7: 默认 agent
  v
安全门控
  |  频率限制 --> [超限?] --> 节流
  |  配对验证 --> [需要?] --> 挑战
  |  工具策略 --> [拒绝?] --> 阻止
  |  RBAC    --> [无角色?] --> 拒绝
  v
处理队列 (双层, 类型化通道)
  |  main:     最大 4 个并发
  |  cron:     最大 1 个并发
  |  subagent: 最大 8 个并发
  v
事件注入 (排空排队的系统事件)
  |
  v
Agent 运行时
  |  1. 解析模型 + 提供者
  |  2. 加载工作空间文件 (SOUL.md, MEMORY.md, ...)
  |  3. 构建系统提示 (10 个段)
  |  4. 从 JSONL 会话构建消息
  |  5. API 调用 (Anthropic/OpenAI/Google/OpenRouter)
  |  6. 工具循环 (最大 10 次迭代)
  |  7. 5 级溢出降级:
  |     L1: 减少历史
  |     L2: 自动压缩 (3 次重试)
  |     L3: 模型降级链
  |     L4: 会话重置
  v
会话持久化 (JSONL 追加 + 修剪)
  |
  v
钩子: post_message
  |
  v
投递 (格式化, 拆分长消息, 发送)
```

### 后台系统

```
心跳循环 (可配置间隔)
  |
  +--> 活跃时段门控 (默认 08:00 - 22:00)
  +--> 无活跃处理检查
  +--> HEARTBEAT.md 提示注入
  +--> 有意义的回复? --> 作为系统事件入队
  +--> HEARTBEAT_OK?  --> 静默丢弃

定时服务
  |
  +--> 调度类型: at (一次性) | every (间隔) | cron (5 字段)
  +--> 失败时指数退避 (30s -> 60s -> 5m -> 15m -> 60m)
  +--> 卡死任务检测 (2 小时阈值, 自动释放)
  +--> 隔离会话 (避免污染主对话)

启动自动化
  |
  +--> Agent 工作空间中的 BOOT.md
  +--> 解析代码围栏块
  +--> 执行: shell 命令或 agent 消息
  +--> 每个块状态跟踪
```

## LLM 提供者

bashclaw 支持 4 种提供者，自动检测和模型别名:

```sh
# Anthropic (默认)
export ANTHROPIC_API_KEY="sk-ant-..."
bashclaw agent -m "你好"                            # 使用 claude-sonnet-4

# OpenAI
export OPENAI_API_KEY="sk-..."
MODEL_ID=gpt-4o bashclaw agent -m "你好"

# Google Gemini
export GOOGLE_API_KEY="..."
MODEL_ID=gemini-2.0-flash bashclaw agent -m "你好"

# OpenRouter (任意模型)
export OPENROUTER_API_KEY="sk-or-..."
MODEL_ID=anthropic/claude-sonnet-4 bashclaw agent -m "你好"

# 自定义 API 兼容端点
export ANTHROPIC_BASE_URL=https://your-proxy.example.com
bashclaw agent -m "你好"
```

模型别名快速切换:

```sh
MODEL_ID=fast     # -> gemini-2.0-flash
MODEL_ID=smart    # -> claude-opus-4
MODEL_ID=balanced # -> claude-sonnet-4
MODEL_ID=cheap    # -> gpt-4o-mini
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

Agent 在对话中可以使用以下工具:

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

```sh
# 生成配对码
bashclaw security pair-generate telegram user123

# 检查工具访问
bashclaw security tool-check main shell main

# 查看审计记录
bashclaw security audit
```

## 频道设置

### Telegram

```sh
bashclaw config set '.channels.telegram.botToken' '"YOUR_BOT_TOKEN"'
bashclaw config set '.channels.telegram.enabled' 'true'
bashclaw gateway    # 启动 Telegram 长轮询监听
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

## 插件系统

通过自定义工具、钩子、命令和 LLM 提供者扩展 bashclaw。

```
插件发现 (4 个来源):
  1. ${BASHCLAW_ROOT}/extensions/     # 内置
  2. ~/.bashclaw/extensions/          # 全局用户
  3. .bashclaw/extensions/            # 工作空间本地
  4. config: plugins.load.paths       # 自定义路径
```

每个插件有一个 `bashclaw.plugin.json` 清单和一个入口脚本:

```sh
# my-plugin/bashclaw.plugin.json
{ "id": "my-plugin", "version": "1.0.0", "description": "My custom tool" }

# my-plugin/init.sh
plugin_register_tool "my_tool" "Does something" '{"input":{"type":"string"}}' "$PWD/handler.sh"
plugin_register_hook "pre_message" "$PWD/filter.sh" 50
plugin_register_command "my_cmd" "Custom command" "$PWD/cmd.sh"
plugin_register_provider "my_llm" "My LLM" '["model-a"]' '{"envKey":"MY_KEY"}'
```

## 钩子系统 (14 个事件)

```
事件                  策略          触发时机
-----                --------     ----
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

策略说明:
  void      -- 即发即忘, 忽略返回值
  modifying -- 串行管道, 每个钩子变换数据
  sync      -- 阻塞直到完成
```

## 守护进程支持

bashclaw 自动检测你的 init 系统:

```
平台            Init 系统       命令
--------        -----------     -------
Linux           systemd         bashclaw daemon install --enable
macOS           launchd         bashclaw daemon install --enable
Android/其他    cron            bashclaw daemon install --enable
```

```sh
bashclaw daemon install --enable   # 安装 + 启动
bashclaw daemon status             # 检查运行状态
bashclaw daemon logs               # 查看服务日志
bashclaw daemon uninstall          # 停止 + 移除
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
    "telegram": { "enabled": true, "botToken": "$TELEGRAM_BOT_TOKEN" }
  },
  "gateway": { "port": 18789 },
  "session": { "scope": "per-sender", "idleResetMinutes": 30 },
  "heartbeat": { "enabled": false },
  "cron": { "enabled": false }
}
```

环境变量覆盖配置:

| 变量 | 用途 |
|------|------|
| `ANTHROPIC_API_KEY` | Anthropic Claude API 密钥 |
| `OPENAI_API_KEY` | OpenAI API 密钥 |
| `GOOGLE_API_KEY` | Google Gemini API 密钥 |
| `OPENROUTER_API_KEY` | OpenRouter API 密钥 |
| `ANTHROPIC_BASE_URL` | 自定义 API 端点 (代理) |
| `MODEL_ID` | 覆盖默认模型 |
| `BASHCLAW_STATE_DIR` | 状态目录 (默认: ~/.bashclaw) |
| `LOG_LEVEL` | debug \| info \| warn \| error \| silent |

## 测试

```sh
# 运行所有测试 (334 个用例, 473 个断言)
bash tests/run_all.sh

# 按类别
bash tests/run_all.sh --unit          # 仅单元测试
bash tests/run_all.sh --compat        # Bash 3.2 兼容性
bash tests/run_all.sh --integration   # 实时 API 测试 (需要密钥)

# 单个套件
bash tests/test_memory.sh
bash tests/test_security.sh
bash tests/test_hooks.sh
```

| 套件 | 测试数 | 覆盖内容 |
|------|--------|----------|
| test_utils | 25 | UUID, 哈希, 重试, 时间戳 |
| test_config | 25 | 加载, 获取, 设置, 验证 |
| test_session | 26 | JSONL, 修剪, 空闲重置, 导出 |
| test_tools | 28 | 14 个工具, SSRF, 分发 |
| test_routing | 17 | 7 级解析, 白名单 |
| test_agent | 15 | 模型, 消息, 引导文件 |
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

## Bash 3.2 兼容性

所有代码运行在每台自 2006 年以来的 Mac 自带的 Bash 上:

- 不用 `declare -A` (关联数组) -- 使用基于文件的存储
- 不用 `declare -g` (全局声明) -- 使用模块级变量
- 不用 `mapfile` / `readarray` -- 使用 while-read 循环
- 不用 `&>>` 重定向 -- 使用 `>> file 2>&1`
- 不用 `|&` 管道简写 -- 使用 `2>&1 |`

这意味着 bashclaw 可以运行在:
- 每个曾出货的 macOS 版本 (不需要 Homebrew)
- 任何安装了 bash 的 Linux
- Android Termux (不需要 root)
- Windows WSL
- 最小容器 (Alpine + bash)
- 树莓派, 嵌入式系统

## 设计决策

### 从 OpenClaw 中移除的部分

1. **配置验证**: 6 次 Zod 验证 + 234 个 `.strict()` 调用 -> 单次 `jq empty`
2. **会话管理**: 复杂的合并/缓存层 -> 直接 JSONL 文件操作
3. **头像解析**: 每次请求 Base64 图片编码 -> 完全消除
4. **日志**: 10,000+ 行 tslog + 每日志颜色哈希 -> `printf` + 级别检查
5. **工具加载**: 延迟加载模块注册表 -> 直接函数分发
6. **频道路由**: 8 种适配器多态接口 -> 简单的 case/函数
7. **启动**: 40+ 个异步初始化步骤 -> 即时 `source` (< 100ms)

### 从 OpenClaw 中保留的精华

- 7 级消息路由和绑定
- 多频道网关架构
- JSONL 会话持久化和压缩
- 工作空间文件 (SOUL.md, MEMORY.md, BOOT.md)
- 心跳系统和活跃时段
- 插件系统 (4 个发现来源)
- 技能系统 (每 Agent 的 SKILL.md)
- 高级定时任务 (at/every/cron + 退避)
- 8 层安全模型
- 类型化通道处理队列

## 许可证

MIT
