# claude-code-notify

> Desktop notifications for [Claude Code](https://claude.ai/code) — get alerted the moment a task finishes, with your original prompt shown as the notification body.

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
bash mac/install.sh
```

Both installers prompt you to choose an install scope:

- **Global** — applies to all projects (`~/.claude`)
- **Project-local** — applies only to the current project (`.claude/` in the working directory)

After installation, restart Claude Code or reload `/hooks` to activate.

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
├── install-claude-notify.sh    # Interactive installer
└── install.sh                  # Launcher wrapper for the installer
```

---

## License

[MIT](LICENSE)
