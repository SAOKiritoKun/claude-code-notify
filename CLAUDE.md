# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`claude-code-notify` is a cross-platform hook installer that fires a desktop notification whenever Claude Code finishes a task. It supports both successful completion (`Stop` event) and execution failure (`StopFailure` event) notifications, with distinct visual and audio cues for each state. It has no build system, no dependencies, and no tests — it is pure shell/PowerShell scripts.

## Structure

```
windows/
  notify.ps1                 # The actual notification script (runs on Stop)
  install-claude-notify.ps1  # Interactive installer — patches settings.json
  install.bat                # Thin wrapper: runs install-claude-notify.ps1 via PowerShell

mac/
  notify.sh                  # The actual notification script (runs on Stop)
  install-claude-notify.sh   # Interactive installer — patches settings.json
```

## How It Works

1. The installer copies `notify.ps1` / `notify.sh` into `~/.claude/hooks/cc-notify/` (global) or `.claude/hooks/cc-notify/` (project-local).
2. It patches `settings.json` to register two async hooks (`async: true`, `timeout: 10`):
   - `Stop` hook: Triggered when a task completes successfully, calls the notify script normally
   - `StopFailure` hook: Triggered when a task execution fails, calls the notify script with `--failed` flag
3. On each event, the notify script reads the JSON payload from stdin:
   - For success events: Shows ✅ "Claude Code Task Done" title with success-themed sound
   - For failure events: Shows ❌ "Claude Code Task Failed" title with error-themed sound
   - Reads `transcript_path` from the payload, walks the transcript backwards to find the last user message, and shows it as the notification body
   - Windows: Uses WinRT `ToastNotificationManager` for toasts, plays sound via `System.Media.SoundPlayer`. Accepts `-Sound` parameter (filename under `C:\Windows\Media\` or full path; empty string to disable). Defaults to `ding.wav` for success, `Windows Error.wav` for failure.
   - macOS: `osascript display notification`. Sound controlled via `CC_NOTIFY_SOUND` env var (built-in sound name or file path; empty string to disable). Defaults to `Funk` for success, `Basso` for failure.

## Key Constraints

- The installer is idempotent: re-running it updates the existing `cc-notify` hook entry rather than duplicating it (detected by `"cc-notify"` in the command string).
- `settings.json` is backed up before modification only when it already exists — a freshly created file is not backed up.
- Project-local install targets the current working directory (`$PWD` / `$(pwd)`), not the script's own directory.
- Notification message is capped at 200 characters.
- Windows installer uses a custom `Format-Json` function for pretty-printing (PowerShell's `ConvertTo-Json` output is not always well-formatted).
- macOS installer uses Python 3 for both JSON patching and transcript parsing; Windows uses native PowerShell JSON cmdlets.
