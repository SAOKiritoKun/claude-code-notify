# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`claude-code-notify` is a cross-platform hook installer that fires a desktop notification whenever Claude Code finishes a task (the `Stop` event). It has no build system, no dependencies, and no tests — it is pure shell/PowerShell scripts.

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
2. It patches `settings.json` to register a `Stop` hook that calls the notify script asynchronously (`async: true`, `timeout: 10`).
3. On each Claude Code `Stop` event, the notify script reads `transcript_path` from stdin JSON, walks the transcript backwards to find the last user message, and shows it as the notification body.
   - Windows: P/Invoke `Shell_NotifyIcon` with `NIIF_NOSOUND` flag to suppress the default balloon sound, then plays a custom sound via `System.Media.SoundPlayer`. Accepts `-Sound` parameter (filename under `C:\Windows\Media\` or full path; empty string to disable).
   - macOS: `osascript display notification`. Sound controlled via `CC_NOTIFY_SOUND` env var (built-in sound name or file path; empty string to disable).

## Key Constraints

- The installer is idempotent: re-running it updates the existing `cc-notify` hook entry rather than duplicating it (detected by `"cc-notify"` in the command string).
- `settings.json` is backed up before modification only when it already exists — a freshly created file is not backed up.
- Project-local install targets the current working directory (`$PWD` / `$(pwd)`), not the script's own directory.
- Notification message is capped at 200 characters.
- Windows installer uses a custom `Format-Json` function for pretty-printing (PowerShell's `ConvertTo-Json` output is not always well-formatted).
- macOS installer uses Python 3 for both JSON patching and transcript parsing; Windows uses native PowerShell JSON cmdlets.
