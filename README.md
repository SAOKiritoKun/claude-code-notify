# claude-code-notify

> Desktop notifications for [Claude Code](https://claude.ai/code) — get alerted the moment a task finishes, with your original prompt shown as the notification body.

Language: English | [中文文档](README_CN.md)

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

`claude-code-notify` hooks into Claude Code's `Stop` event. When Claude finishes a turn, a system notification pops up showing the last user message (truncated to 200 chars) — so you know exactly which task completed, even if you've switched windows.

| Platform | Mechanism |
|----------|-----------|
| Windows  | Balloon tip via `System.Windows.Forms.NotifyIcon` |
| macOS    | Native notification via `osascript` |

---

## Requirements

| Platform | Requirement |
|----------|-------------|
| Windows  | PowerShell 5+, .NET (pre-installed on Windows 10+) |
| macOS    | Python 3, `osascript` (pre-installed on macOS) |

---

## Installation

### Windows

Double-click `windows/install.bat`, or run in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File windows\install-claude-notify.ps1
```

### macOS

```bash
bash mac/install-claude-notify.sh
```

Both installers prompt you to choose an install scope:

- **Global** — applies to all projects (`~/.claude`)
- **Project-local** — applies only to the current project (`.claude/` in the working directory)

After installation, restart Claude Code or reload `/hooks` to activate.

---

## Other Configuration *(optional)*

### Sound

Sound plays automatically with each notification. This is optional — you can change the sound or disable it entirely.

#### Windows

Default sound: `ding.wav` (from `C:\Windows\Media\`).

Customize via the `-Sound` parameter in the hook command in `settings.json`:

```json
"command": "powershell -ExecutionPolicy Bypass -NonInteractive -File \"...notify.ps1\" -Sound chord.wav"
```

Common built-in sounds: `ding.wav`, `chimes.wav`, `chord.wav`, `notify.wav`, `tada.wav`, `Windows Exclamation.wav`, `Windows Notify.wav`

Use a full path for a custom file (`.wav` only):

```json
"command": "powershell ... -Sound \"C:\\path\\to\\sound.wav\""
```

Disable sound:

```json
"command": "powershell ... -Sound \"\""
```

Alternatively, set the `CC_NOTIFY_SOUND` environment variable in your PowerShell profile as a fallback when `-Sound` is not specified:

```powershell
$env:CC_NOTIFY_SOUND = "chord.wav"
```

#### macOS

Default sound: `Funk` (built-in system sound).

Customize via the `CC_NOTIFY_SOUND` environment variable in `.zshrc` or `.bash_profile`:

```bash
export CC_NOTIFY_SOUND="Ping"
```

Available built-in sounds (from `/System/Library/Sounds/`):
`Basso`, `Blow`, `Bottle`, `Frog`, `Funk`, `Glass`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`

Use a full path for a custom file (`.mp3`, `.wav`, `.aiff`, `.m4a`, `.caf`, etc.):

```bash
export CC_NOTIFY_SOUND="/path/to/sound.mp3"
```

Disable sound:

```bash
export CC_NOTIFY_SOUND=""
```

Or set it inline in the hook command in `settings.json`:

```json
"command": "CC_NOTIFY_SOUND=\"Ping\" ~/.claude/hooks/cc-notify/notify.sh"
```

---

## How It Works

1. The installer copies the notify script into `<target>/.claude/hooks/cc-notify/`
2. It patches `<target>/.claude/settings.json` to register an async `Stop` hook
3. On each `Stop` event, the notify script reads `transcript_path` from the JSON payload, walks the transcript backwards to find the last user message, and displays it as the notification body
4. Falls back to `"Task completed"` if the transcript is unavailable

**The installer is idempotent** — re-running it updates the existing hook entry rather than duplicating it. `settings.json` is backed up before every modification (`settings.json.<timestamp>.bak`).

---

## Project Structure

```
windows/
├── notify.ps1                  # Notification script (invoked on Stop)
├── install-claude-notify.ps1   # Interactive installer
└── install.bat                 # Launcher wrapper for the installer

mac/
├── notify.sh                   # Notification script (invoked on Stop)
└── install-claude-notify.sh    # Interactive installer
```

---

## License

[MIT](LICENSE)
