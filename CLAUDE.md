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
  install.sh                 # Thin wrapper: runs install-claude-notify.sh
```

## How It Works

1. The installer copies `notify.ps1` / `notify.sh` into `~/.claude/hooks/cc-notify/` (global) or `.claude/hooks/cc-notify/` (project-local).
2. It patches `settings.json` to register a `Stop` hook that calls the notify script asynchronously (`async: true`, `timeout: 10`).
3. On each Claude Code `Stop` event, the notify script reads `transcript_path` from stdin JSON, walks the transcript backwards to find the last user message, and shows it as the notification body.
   - Windows: `System.Windows.Forms.NotifyIcon` balloon tip.
   - macOS: `osascript display notification`.

## Key Constraints

- The installer is idempotent: re-running it updates the existing `cc-notify` hook entry rather than duplicating it (detected by `"cc-notify"` in the command string).
- The installer always backs up `settings.json` before modifying it (`settings.json.<timestamp>.bak`).
- Notification message is capped at 200 characters.
- Both platforms require Python 3 only for JSON parsing inside the installer (macOS notify script also uses it for transcript parsing).
