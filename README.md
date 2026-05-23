# claude-code-notify

> Desktop notifications for [Claude Code](https://claude.ai/code) — get alerted the moment a task finishes, with your original prompt shown as the notification body.

Language: English | [中文文档](README_CN.md)

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

`claude-code-notify` hooks into Claude Code's `Stop` (success) and `StopFailure` (failure) events. When Claude finishes a task (whether successful or failed), a system notification pops up showing the last user message (truncated to 200 chars) — so you know exactly which task completed, even if you've switched windows.

Success and failure notifications have distinct visual and audio cues:
- ✅ **Success**: Green checkmark title with positive notification sound
- ❌ **Failure**: Red cross title with error notification sound

| Platform | Mechanism |
|----------|-----------|
| Windows  | Toast notification via WinRT `ToastNotificationManager` (appears in Notification Center) |
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

> **Windows:** The installer also registers a registry key under `HKCU` (no admin rights required) so notifications appear as "Claude Code" in the Notification Center.

---

## Uninstall

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File windows\uninstall-claude-notify.ps1
```

### macOS

```bash
bash mac/uninstall-claude-notify.sh
```

The uninstaller prompts you to choose a scope:

- **[1] Current project only** — removes hook from `.claude/` in the working directory. The registry key is **not** removed (Windows only; it may still be needed by a global install).
- **[2] Global only** — removes hook from `~/.claude`. On Windows, also deletes the `ClaudeCode.Notify` registry key.
- **[3] Both** — removes all of the above

Only `cc-notify` hook entries are removed. All other hooks in `settings.json` are preserved.

---

## Other Configuration *(optional)*

### Sound

Sound plays automatically with each notification, with different defaults for success and failure states. This is optional — you can change the sound or disable it entirely.

#### Windows

Default sounds:
- Success: `ding.wav` (from `C:\Windows\Media\`)
- Failure: `Windows Error.wav` (from `C:\Windows\Media\`)

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

Default sounds:
- Success: `Funk` (built-in system sound)
- Failure: `Basso` (built-in system sound)

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
2. It patches `<target>/.claude/settings.json` to register two async hooks:
   - `Stop` hook: For successful task completion
   - `StopFailure` hook: For execution failures (API errors, permission denials, tool crashes, etc.)
3. On each event, the notify script reads the JSON payload from stdin:
   - Detects success/failure state (either via event type or `success` field in payload)
   - Reads `transcript_path` from the payload, walks the transcript backwards to find the last user message
   - Displays appropriate notification with status-specific title and sound
4. Falls back to status-specific default message if the transcript is unavailable

**The installer is idempotent** — re-running it updates the existing hook entry rather than duplicating it.

**Windows only:** The installer also writes a registry key `HKCU:\SOFTWARE\Classes\AppUserModelId\ClaudeCode.Notify` (`DisplayName = "Claude Code"`) so Toast notifications are attributed to "Claude Code" in the Notification Center. No admin rights required. To verify: `Get-ItemProperty "HKCU:\SOFTWARE\Classes\AppUserModelId\ClaudeCode.Notify"` — output should include `DisplayName : Claude Code`. The uninstaller removes this key when scope **[2] Global only** or **[3] Both** is chosen.

---

## Project Structure

```
windows/
├── notify.ps1                    # Notification script (invoked on Stop/StopFailure events)
├── install-claude-notify.ps1     # Interactive installer (registers both event hooks)
└── uninstall-claude-notify.ps1   # Interactive uninstaller (cleans up all hook entries)

mac/
├── notify.sh                     # Notification script (invoked on Stop/StopFailure events)
├── install-claude-notify.sh      # Interactive installer (registers both event hooks)
└── uninstall-claude-notify.sh    # Interactive uninstaller (cleans up all hook entries)
```

---

## License

[MIT](LICENSE)
