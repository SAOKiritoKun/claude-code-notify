# claude-code-notify

> [Claude Code](https://claude.ai/code) 任务完成桌面通知 —— 任务结束时立即弹出系统通知，并显示你的原始提示词作为通知内容。

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 简介

`claude-code-notify` 挂载到 Claude Code 的 `Stop` 事件。每当 Claude 完成一轮对话，系统会弹出通知，显示最后一条用户消息（最多 200 字符）——即使你已切换到其他窗口，也能第一时间知道哪个任务完成了。

| 平台    | 通知方式 |
|---------|---------|
| Windows | 通过 `System.Windows.Forms.NotifyIcon` 显示气泡通知 |
| macOS   | 通过 `osascript` 显示原生系统通知 |

---

## 环境要求

| 平台    | 要求 |
|---------|------|
| Windows | PowerShell 5+，.NET（Windows 10+ 已预装） |
| macOS   | Python 3，`osascript`（macOS 已预装） |

---

## 安装方法

### Windows

双击 `windows/install.bat`，或在 PowerShell 中运行：

```powershell
powershell -ExecutionPolicy Bypass -File windows\install-claude-notify.ps1
```

### macOS

```bash
bash mac/install.sh
```

两个安装脚本都会提示你选择安装范围：

- **全局** —— 适用于所有项目（`~/.claude`）
- **仅当前项目** —— 适用于当前工作目录（`.claude/`）

安装完成后，重启 Claude Code 或重新加载 `/hooks` 即可生效。

---

## 配置说明

### macOS 通知音效自定义

通知默认使用系统内置的 `Funk` 音效。你可以通过在 shell 配置文件（`.zshrc`、`.bash_profile` 等）中设置 `CC_NOTIFY_SOUND` 环境变量，或直接修改钩子命令来自定义或禁用音效。

#### 选项1：使用系统内置音效（推荐）
使用原生通知播放，与弹窗完全同步。可用的内置音效（位于 `/System/Library/Sounds/` 目录）：
`Basso`、`Blow`、`Bottle`、`Frog`、`Funk`、`Glass`、`Hero`、`Morse`、`Ping`、`Pop`、`Purr`、`Sosumi`、`Submarine`、`Tink`

```bash
# 添加到 ~/.zshrc 文件修改默认音效
export CC_NOTIFY_SOUND="Ping"
```

#### 选项2：使用自定义音效文件
使用 `afplay` 播放，**支持所有常见音频格式**：`.mp3`、`.wav`、`.aiff`、`.m4a`、`.caf` 等，无编码或时长限制。

```bash
# 添加到 ~/.zshrc 文件
export CC_NOTIFY_SOUND="/path/to/your/custom/sound.mp3"
```

#### 选项0：禁用音效
```bash
# 添加到 ~/.zshrc 文件关闭通知音效
export CC_NOTIFY_SOUND=""
```

#### 选项3：直接修改钩子命令
编辑 `settings.json` 中的 `Stop` 钩子条目，直接包含音效变量：
```json
{
  "hooks": {
    "Stop": [
      {
        "command": "CC_NOTIFY_SOUND=\"Funk\" ~/.claude/hooks/cc-notify/notify.sh",
        "async": true,
        "timeout": 10
      }
    ]
  }
}
```

---

## 工作原理

1. 安装脚本将通知脚本复制到 `<目标>/.claude/hooks/cc-notify/`
2. 修改 `<目标>/.claude/settings.json`，注册异步 `Stop` 钩子
3. 每次触发 `Stop` 事件时，通知脚本从 JSON 载荷中读取 `transcript_path`，从后往前遍历对话记录，找到最后一条用户消息作为通知内容
4. 若无法读取对话记录，则回退显示 `"Task completed"`

**安装脚本是幂等的** —— 重复运行只会更新已有的钩子条目，不会重复添加。`settings.json` 在每次修改前会自动备份（`settings.json.<时间戳>.bak`）。

---

## 项目结构

```
windows/
├── notify.ps1                  # 通知脚本（Stop 事件时调用）
├── install-claude-notify.ps1   # 交互式安装脚本
└── install.bat                 # 安装脚本的启动入口

mac/
├── notify.sh                   # 通知脚本（Stop 事件时调用）
├── install-claude-notify.sh    # 交互式安装脚本
└── install.sh                  # 安装脚本的启动入口
```

---

## 许可证

[MIT](LICENSE)
