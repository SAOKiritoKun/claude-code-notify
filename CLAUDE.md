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
2. It patches `settings.json` to register four async hooks (`async: true`):
   - `Stop` hook: Triggered when a task completes successfully, calls the notify script normally (timeout: 10s)
   - `StopFailure` hook: Triggered when a task execution fails, calls the notify script with `--failed` flag (timeout: 10s)
   - `PermissionRequest` hook: Triggered when Claude requests user permission to perform an operation, calls the notify script with `--permission` flag (timeout: 10s)
   - `SessionStart` hook: Triggered when a new session starts or an existing session resumes, calls the notify script with `--session-start` flag (timeout: 5s)
3. On each event, the notify script reads the JSON payload from stdin:
   - For success events: Shows "Claude Code Task Done" title with success-themed sound
   - For failure events: Shows "Claude Code Task Failed" title with error-themed sound, includes error details if available
   - For permission request events: Shows "Claude Code Permission Request" title with neutral notification sound, displays the requested operation type and details
   - For session start events: Shows "Claude Code Session Started" title with gentle notification sound, displays session type (new/resumed based on `source` field), project path (auto-simplified with `~`), and session ID
   - Success/failure events: Read `transcript_path` from the payload, walk the transcript backwards to find the last user message as the notification body
   - Permission events: Extract permission type and operation details, display user-friendly action descriptions with type prefixes ([Command] for commands, [Edit] for file edits, [Read] for file reads, [Network] for network requests)
   - Session events: Extract session type and workspace path, automatically simplify user directory path with `~`
   - Windows: Uses WinRT `ToastNotificationManager` for toasts, plays sound via `System.Media.SoundPlayer`. Defaults: success `ding.wav`, failure `Windows Error.wav`, permission `notify.wav`, session `notify.wav`.
   - macOS: `osascript display notification`. Sound controlled via `CC_NOTIFY_SOUND` env var (built-in sound name or file path; empty string to disable). Defaults: success `Funk`, failure `Basso`, permission `Glass`, session `Glass`.

## Key Constraints

- The installer is idempotent: re-running it updates the existing `cc-notify` hook entry rather than duplicating it (detected by `"cc-notify"` in the command string).
- `settings.json` is backed up before modification only when it already exists — a freshly created file is not backed up.
- Project-local install targets the current working directory (`$PWD` / `$(pwd)`), not the script's own directory.
- Notification message is capped at 200 characters.
- Windows installer uses a custom `Format-Json` function for pretty-printing (PowerShell's `ConvertTo-Json` output is not always well-formatted).
- macOS installer uses Python 3 for both JSON patching and transcript parsing; Windows uses native PowerShell JSON cmdlets.
- **Documentation synchronization**: Any modification, addition, or deletion of features MUST be accompanied by corresponding updates to `README.md` (English) and `README_CN.md` (Chinese) to keep documentation consistent with functionality.
- **Mandatory development workflow**:
  1. Complete code implementation and testing
  2. Update `CLAUDE.md` with technical design, constraints, and implementation details
  3. Update `README.md` with user-facing documentation (features, usage, configuration)
  4. Update `README_CN.md` with Chinese translation of all changes
  5. Verify all three documents are consistent with the implementation
  6. Feature is only considered complete when both code and documentation are fully updated
- **Documentation checklist**:
  - CLAUDE.md: Update technical implementation details, constraints, and working principles
  - README.md: Update feature descriptions, usage instructions, configuration options, and project structure
  - README_CN.md: Fully synchronize all changes from the English README
