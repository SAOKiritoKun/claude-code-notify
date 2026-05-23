# claude-code-notify

> [Claude Code](https://claude.ai/code) 任务完成桌面通知 —— 任务结束时立即弹出系统通知，并显示你的原始提示词作为通知内容。

语言: [English](README.md) | 中文

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 简介

`claude-code-notify` 挂载到 Claude Code 的 `Stop`（成功）、`StopFailure`（失败）和 `PermissionRequest`（权限请求）事件。每当 Claude 需要你的关注时就会弹出系统通知，不用一直守在终端前等待：

不同场景的通知有明确的标题和音效区分：
- **成功**："Claude Code Task Done"标题和积极提示音，任务正常完成时触发
- **失败**："Claude Code Task Failed"标题和错误提示音，任务执行失败时触发（包含错误详情）
- **权限请求**："Claude Code Permission Request"标题和中性提示音，Claude需要你授权操作时触发（显示请求的具体操作内容）

| 平台    | 通知方式 |
|---------|---------|
| Windows | 通过 WinRT `ToastNotificationManager` 显示 Toast 通知（显示在通知中心） |
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

```powershell
powershell -ExecutionPolicy Bypass -File windows\install-claude-notify.ps1
```

### macOS

```bash
bash mac/install-claude-notify.sh
```

两个安装脚本都会提示你选择安装范围：

- **全局** —— 适用于所有项目（`~/.claude`）
- **仅当前项目** —— 适用于当前工作目录（`.claude/`）

安装完成后，重启 Claude Code 或重新加载 `/hooks` 即可生效。

---

## 卸载方法

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File windows\uninstall-claude-notify.ps1
```

### macOS

```bash
bash mac/uninstall-claude-notify.sh
```

卸载脚本会提示你选择卸载范围：

- **[1] 仅当前项目** —— 移除当前工作目录 `.claude/` 中的 hook，**不删除**注册表键（仅 Windows；全局安装可能仍需使用）
- **[2] 仅全局** —— 移除 `~/.claude` 中的 hook；Windows 下同时删除 `ClaudeCode.Notify` 注册表键
- **[3] 全部** —— 以上全部移除

卸载脚本只会移除含 `cc-notify` 标识的 hook 条目，`settings.json` 中的其他 hook 不受影响。

---

## 其他配置说明 *(可选)*

### 音效

每次通知时自动播放音效，成功和失败状态有不同的默认音效。此项为可选配置 —— 可以更换音效或完全禁用。

#### Windows

默认音效：
- 成功：`ding.wav`（来自 `C:\Windows\Media\`）
- 失败：`Windows Error.wav`（来自 `C:\Windows\Media\`）
- 权限请求：`notify.wav`（来自 `C:\Windows\Media\`）

通过 `settings.json` 钩子命令中的 `-Sound` 参数自定义：

```json
"command": "powershell -ExecutionPolicy Bypass -NonInteractive -File \"...notify.ps1\" -Sound chord.wav"
```

常用内置音效：`ding.wav`、`chimes.wav`、`chord.wav`、`notify.wav`、`tada.wav`、`Windows Exclamation.wav`、`Windows Notify.wav`

使用完整路径指定自定义文件（仅支持 `.wav`）：

```json
"command": "powershell ... -Sound \"C:\\path\\to\\sound.wav\""
```

禁用音效：

```json
"command": "powershell ... -Sound \"\""
```

也可以在 PowerShell profile 中设置 `CC_NOTIFY_SOUND` 环境变量作为备选（未指定 `-Sound` 时生效）：

```powershell
$env:CC_NOTIFY_SOUND = "chord.wav"
```

#### macOS

默认音效：
- 成功：`Funk`（系统内置音效）
- 失败：`Basso`（系统内置音效）
- 权限请求：`Glass`（系统内置音效）

通过 `.zshrc` 或 `.bash_profile` 中的 `CC_NOTIFY_SOUND` 环境变量自定义：

```bash
export CC_NOTIFY_SOUND="Ping"
```

可用内置音效（来自 `/System/Library/Sounds/`）：
`Basso`、`Blow`、`Bottle`、`Frog`、`Funk`、`Glass`、`Hero`、`Morse`、`Ping`、`Pop`、`Purr`、`Sosumi`、`Submarine`、`Tink`

使用完整路径指定自定义文件（支持 `.mp3`、`.wav`、`.aiff`、`.m4a`、`.caf` 等）：

```bash
export CC_NOTIFY_SOUND="/path/to/sound.mp3"
```

禁用音效：

```bash
export CC_NOTIFY_SOUND=""
```

也可以直接在 `settings.json` 的钩子命令中内联设置：

```json
"command": "CC_NOTIFY_SOUND=\"Ping\" ~/.claude/hooks/cc-notify/notify.sh"
```

---

## 工作原理

1. 安装脚本将通知脚本复制到 `<目标>/.claude/hooks/cc-notify/`
2. 修改 `<目标>/.claude/settings.json`，注册三个异步钩子：
   - `Stop` 钩子：任务成功完成时触发
   - `StopFailure` 钩子：任务执行失败时触发（API错误、权限被拒、工具崩溃等）
   - `PermissionRequest` 钩子：Claude需要用户授权执行操作时触发
3. 每次事件触发时，通知脚本读取stdin中的JSON载荷：
   - **成功/失败事件**：识别任务状态，读取对话记录中的最后一条用户消息，显示任务上下文
   - **权限请求事件**：提取操作类型和详情，显示Claude请求执行的具体动作，使用类型前缀标识（[Command] 表示命令执行、[Edit] 表示文件修改、[Read] 表示文件读取、[Network] 表示外部请求）
   - 显示对应场景的通知标题、图标和音效
4. 若载荷解析失败，则回退显示场景对应的默认消息

**安装脚本是幂等的** —— 重复运行只会更新已有的钩子条目，不会重复添加。

**仅 Windows：** 安装脚本还会写入注册表键 `HKCU:\SOFTWARE\Classes\AppUserModelId\ClaudeCode.Notify`（`DisplayName = "Claude Code"`），使 Toast 通知在通知中心显示 "Claude Code" 作为应用名称，无需管理员权限。验证方式：`Get-ItemProperty "HKCU:\SOFTWARE\Classes\AppUserModelId\ClaudeCode.Notify"`，输出应包含 `DisplayName : Claude Code`。卸载时选择 **[2] 仅全局** 或 **[3] 全部** 会自动删除此键。

---

## 项目结构

```
windows/
├── notify.ps1                    # 通知脚本（Stop/StopFailure/PermissionRequest 事件时调用）
├── install-claude-notify.ps1     # 交互式安装脚本（同时注册三个事件钩子）
└── uninstall-claude-notify.ps1   # 交互式卸载脚本（清理所有相关钩子条目）

mac/
├── notify.sh                     # 通知脚本（Stop/StopFailure/PermissionRequest 事件时调用）
├── install-claude-notify.sh      # 交互式安装脚本（同时注册三个事件钩子）
└── uninstall-claude-notify.sh    # 交互式卸载脚本（清理所有相关钩子条目）
```

---

## 许可证

[MIT](LICENSE)
