# 🐱🎀 Neko Desktop

> 猫娘人格化 Linux 桌面环境 —— 不是主题，不是插件，而是给电脑注入人格的一层。

Neko Desktop 在 KDE Plasma 之上增加一个「人格化桌面层」，让电脑不再是工具，而是一个会回应、会变化、有状态、有生命感的计算环境。

```
Linux Kernel
    ↓
KDE Plasma
    ↓
Neko Desktop Layer（人格引擎）
    ↓
用户
```

---

## 设计原则

1. **全系统一致性** — 登录界面 → 桌面 → 任务栏 → 窗口 → 通知 → 文件管理器 → 终端 → 系统状态，处处是 Neko 风格。
2. **不固定文字** — 欢迎语/反馈永远动态，根据时间、日期、系统状态、当前应用、工作状态变化。
3. **中文优先 + English** — 双语显示，禁止日文。

---

## 架构

```
                Neko Core
                   |
        -----------+-----------
        |          |          |
     Hardware    Apps      Time
        |          |          |
        +----------+----------+
                   |
            Personality Engine
                   |
                   ↓
            Desktop Reaction
```

---

## 目录结构

```
neko-desktop/
├── core/            # Neko Core 配置
├── daemon/          # 后台守护进程 (状态采集/环境判断/反馈生成)
├── personality/     # 人格引擎 (morning/work/night/deep-night/coding/ai/gaming/random)
├── fish/            # Fish Shell 猫娘终端
├── kitty/           # Kitty 玻璃终端
├── kwin/            # KWin 玻璃效果脚本
├── plasmoid/        # 桌面 HUD Widget (CPU/GPU/RAM/模式/时间)
├── sddm/            # SDDM 登录界面主题 (粒子+猫耳+系统检查动画)
├── scripts/         # 模式检测/状态/壁纸生成
├── services/        # systemd user service
└── installer/       # 一键安装器 (检测→备份→安装→测试→恢复)
```

---

## 功能总览

| 模块 | 说明 |
|------|------|
| **Neko Core** | 状态收集、环境判断、反馈生成、桌面表现控制 |
| **Personality Engine** | 7 个人格 JSON，每条消息随机组合「称呼+状态+鼓励+系统信息」 |
| **时间系统** | 06-12 清晨(亮粉) / 12-18 工作(稳定清晰) / 18-24 夜晚(深色安静) / 00-06 深夜(黑紫低亮度) |
| **应用感知** | 检测 VS Code/JetBrains/Blender/Steam/VRChat/Ollama/vLLM/Python/CUDA → Coding / AI / Gaming 模式 |
| **硬件监控** | CPU(型号/温度/频率/使用率) + GPU(NVIDIA RTX/Tesla、AMD) + VRAM |
| **桌面 HUD** | Plasma Widget，顶部覆盖显示状态，可隐藏/移动/调透明度 |
| **玻璃效果** | 透明 + 黑色遮罩 + 模糊，非纯透明 |
| **Kitty 终端** | 猫娘 Prompt，启动随机欢迎，命令成功/失败反馈(不污染 stderr) |
| **Fish Shell** | 欢迎语 + 系统状态 + 随机消息 |
| **SDDM 登录** | 黑色背景 → 粒子 → 猫耳图标 → 文字 → 系统检查动画 |
| **动态壁纸** | 按时间/模式切换 (AI实验室/游戏房/月光房) |
| **通知系统** | 下载完成 / 错误通知 猫娘化 |
| **多机器迁移** | 支持 Arch / Garuda / CachyOS，自动检测 KDE/Wayland/NVIDIA/Python |
| **安全安装** | 检测→备份→安装→测试→恢复，备份到 ~/.config/neko-backup-日期 |

---

## 安装

### 一键安装 (用户级)

```bash
cd neko-desktop
./installer/install.sh
```

安装内容：Theme / Widget / KWin / SDDM / Kitty / Fish / Service。

### 含 SDDM 登录主题 (需 root)

```bash
sudo ./installer/install.sh
```

装完后在 `系统设置 → 启动与关机 → 登录屏幕(SDDM)` 里选择 **Neko Sakura**。

### 手动启用核心服务

```bash
systemctl --user enable --now neko-core.service
systemctl --user status neko-core.service
# 查看状态
~/.config/neko-desktop/scripts/neko-status.sh
```

---

## 使用

| 场景 | 表现 |
|------|------|
| 打开终端 | 🐱🎀 猫娘提示符 + 动态问候 + 系统检查 |
| 命令成功 | 🐱 完成啦 Command finished. |
| 命令失败 | 😿 出现问题 Error detected. 让我们修复它。(不污染 stderr) |
| 打开 VS Code | 🐱 Coding Mode，主人正在创造 |
| 运行 ollama/vllm/cuda | 🤖 AI Laboratory，模型运行中，GPU 计算核心在线 |
| 打开 Steam | 🎮 Gaming Mode，娱乐时间开始 |
| 深夜 | 🖤 深夜模式，黑紫低亮度 |

---

## 硬件状态示例

```
🐱 System Status

CPU  Ryzen 7 9800X3D   42%
RTX 2060 SUPER         GPU: 50%  VRAM: 5GB/8GB
Tesla P40              VRAM: 18GB/24GB
```

---

## 环境要求

- Arch / Garuda / CachyOS
- KDE Plasma 6 + Wayland
- Python 3
- (可选) NVIDIA GPU / AMD GPU

---

## Roadmap

- v1-v3 基础美化：Kitty / Fish / Theme
- v4-v6 工程化：Core / Service / Config
- v7-v8 KDE 集成：Widget / KWin / SDDM
- v9 AI：本地模型 / 智能反馈
- v10 完整 Neko Desktop：一键安装 / 多机器迁移 / AI 人格系统

---

## License

MIT

---

## Rust 核心 (v10.1)

Neko Core 已用 Rust 重写（`rust/` 目录），二进制更小更快：

```bash
cd rust && cargo build --release
# 产出: neko-core (守护) / neko-notify (猫娘通知CLI) / neko-notifyd (通知监听层)
cargo run --release --bin neko-core -- --once
```

三个二进制已由安装器放入 `~/.config/neko-desktop/bin/`，systemd 服务自动使用：
- `neko-core.service` — 状态采集/环境判断/反馈生成
- `neko-notifyd.service` — 监听 DBus 通知，把「下载完成/错误/包管理」事件猫娘化播报

## 登录界面 (Plasma 6.7 plasmalogin)

Plasma 6.7 的登录管理器为 **plasmalogin**（内置 QML，不再读 SDDM 主题目录）。Neko 采用安全策略：
- 登录界面强调色 → 写入 `AccentColor=255,140,198`（粉色）
- 登录壁纸 → 生成的 `login.png`，在「系统设置 → 登录屏幕 → 更换壁纸」里选中即可

> 不硬改编译进 greeter 的 QML，避免破坏登录。

## 通知猫娘化

`neko-notifyd` 监听会话总线通知调用，命中关键词时补发猫娘播报：
- 下载完成 → 🐱 文件完成啦
- 包错误 → 😿 Neko 发现问题 / Package Error
- 通用错误 → 😿 Neko 发现问题 / Error detected

`neko-notify` 提供 CLI 给脚本/其它程序直接发猫娘通知：
```bash
neko-notify "文件完成啦" "模型下载完成 12GB"
```

---

## 悬浮置顶窗 + 任务栏组件 (v10.2)

- `overlay/main.qml` — 屏幕最顶层悬浮窗：猫娘头像气泡 + CPU/GPU/RAM/网络/模式/人格台词。用 `qml6` + XWayland(xcb) override-redirect 实现「置顶覆盖全屏」，鼠标拖动即可挪位置，位置自动记住（`state/overlay.conf`）。
- `plasmoid/org.neko.status` — 任务栏组件：一句话「问候语 + 模式」，点击展开完整状态面板（双 GPU 遍历、网络、人格台词）。
- `services/neko-overlay.service` — 悬浮窗 systemd 用户服务，随核心一起启动。
- 数据统一来自 `neko-core` 写出的 `state/status.json`，两个组件开销≈0。

---

## 猫娘大脑 (v10.3 — 聊天/记忆/指令)

- `rust/src/bin/neko-brain.rs` — 猫娘大脑 HTTP 微服务（127.0.0.1:7799）：对接本地小模型聊天、JSON 长期记忆、指令白名单（打开应用/换壁纸/锁屏/查时间/查状态）。
- `rust/src/dynamic.rs` — 动态人格引擎：状态语言、时间/场景/互动感、每日心情变化（按日期种子）。
- `overlay/main.qml` — 悬浮窗改造为「猫娘对话气泡」：顶部问候 + 聊天区 + 输入框。
- `services/neko-llm.service` — Qwen2.5-1.5B 小模型（纯 CPU，不抢 GPU 显存），下载后启动即可聊天。
- 小模型：`~/.config/neko-desktop/models/qwen2.5-1.5b-instruct-q4_k_m.gguf`（~1GB）。
