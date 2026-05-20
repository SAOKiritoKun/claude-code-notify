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
bash mac/install-claude-notify.sh
```

Both installers prompt you to choose an install scope:

- **Global** — applies to all projects (`~/.claude`)
- **Project-local** — applies only to the current project (`.claude/` in the working directory)

After installation, restart Claude Code or reload `/hooks` to activate.

---

## Configuration

### macOS Sound Customization

The notification uses the built-in `Funk` sound by default. You can customize or disable it by setting the `CC_NOTIFY_SOUND` environment variable in your shell configuration (`.zshrc`, `.bash_profile`, etc.) or directly in the hook command.

#### Option 1: Use built-in system sounds (recommended)
Uses native notification playback for perfect synchronization. Available built-in sounds (located in `/System/Library/Sounds/`):
`Basso`, `Blow`, `Bottle`, `Frog`, `Funk`, `Glass`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`

```bash
# Add to ~/.zshrc to change default sound
export CC_NOTIFY_SOUND="Ping"
```

#### Option 2: Use custom sound files
Uses `afplay` for playback, supports **all common audio formats**: `.mp3`, `.wav`, `.aiff`, `.m4a`, `.caf`, etc. No encoding or duration limits.

```bash
# Add to ~/.zshrc
export CC_NOTIFY_SOUND="/path/to/your/custom/sound.mp3"
```

#### Option 0: Disable sound
```bash
# Add to ~/.zshrc to turn off notification sound
export CC_NOTIFY_SOUND=""
```

#### Option 3: Modify the hook command directly
Edit the `Stop` hook entry in your `settings.json` to include the sound variable:
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
