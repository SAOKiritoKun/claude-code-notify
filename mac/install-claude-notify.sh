#!/bin/bash
# Claude Code Turn Notification - One-click installer (macOS)

set +e  # Disable exit on error to make script more robust

CLAUDE_DIR_GLOBAL="$HOME/.claude"
CLAUDE_DIR_PROJECT="$(pwd)/.claude"

echo "=== Claude Code Turn Notification Installer ==="
echo ""
echo "This will install a desktop notification hook that fires when Claude Code finishes a task."
echo ""
echo "Install location:"
echo "  [1] Global (applies to all projects)  -> $CLAUDE_DIR_GLOBAL"
echo "  [2] Current project only              -> $CLAUDE_DIR_PROJECT"
echo ""

while true; do
    read -rp "Enter 1 or 2: " CHOICE
    case "$CHOICE" in
        1) CLAUDE_DIR="$CLAUDE_DIR_GLOBAL"; echo ""; echo "[Target] Global: $CLAUDE_DIR"; break ;;
        2) CLAUDE_DIR="$CLAUDE_DIR_PROJECT"; echo ""; echo "[Target] Project: $CLAUDE_DIR"; break ;;
        *) echo "Please enter 1 or 2" ;;
    esac
done

HOOKS_DIR="$CLAUDE_DIR/hooks/cc-notify"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
NOTIFY_DEST="$HOOKS_DIR/notify.sh"
SCRIPT_DIR="$(dirname "$0")"

# 1. Install notify script
echo "[INFO] Installing notification scripts..."
if ! mkdir -p "$HOOKS_DIR"; then
    echo "[ERROR] Failed to create directory $HOOKS_DIR (permission denied)"
    exit 1
fi

if ! cp "$SCRIPT_DIR/notify.sh" "$NOTIFY_DEST"; then
    echo "[ERROR] Failed to copy notify.sh to $NOTIFY_DEST"
    exit 1
fi

if ! chmod +x "$NOTIFY_DEST"; then
    echo "[WARNING] Failed to make $NOTIFY_DEST executable"
else
    echo "[OK] Installed notify.sh -> $NOTIFY_DEST"
fi

# 2. Patch settings.json
echo "[INFO] Configuring hooks in settings.json..."

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] python3 not found. Please install Python 3 first."
    exit 1
fi

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
    if echo '{}' > "$SETTINGS_FILE"; then
        echo "[OK] Created new settings.json file"
    else
        echo "[ERROR] Failed to create $SETTINGS_FILE (permission denied)"
        exit 1
    fi
fi

# Check if file is readable and writable
if [ ! -r "$SETTINGS_FILE" ]; then
    echo "[ERROR] $SETTINGS_FILE is not readable"
    exit 1
fi

if [ ! -w "$SETTINGS_FILE" ]; then
    echo "[ERROR] $SETTINGS_FILE is not writable"
    exit 1
fi

# Patch using python3 with error handling
python3 - "$SETTINGS_FILE" "$NOTIFY_DEST" <<'EOF'
import sys, json, copy

try:
    settings_file = sys.argv[1]
    notify_dest   = sys.argv[2]

    with open(settings_file, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            print("[ERROR] settings.json is not valid JSON. Please fix the file first.")
            sys.exit(1)

    # Ensure data is a dict
    if not isinstance(data, dict):
        print("[ERROR] settings.json root is not an object. Please fix the file first.")
        sys.exit(1)

    if "hooks" not in data or not isinstance(data["hooks"], dict):
        data["hooks"] = {}

    # Create hook entries for Stop (success), StopFailure (failed), and PermissionRequest events
    hook_entry_success = {
        "type":    "command",
        "command": f"bash \"{notify_dest}\"",
        "timeout": 10,
        "async":   True
    }
    hook_entry_failed = {
        "type":    "command",
        "command": f"bash \"{notify_dest}\" --failed",
        "timeout": 10,
        "async":   True
    }
    hook_entry_permission = {
        "type":    "command",
        "command": f"bash \"{notify_dest}\" --permission",
        "timeout": 10,
        "async":   True  # 权限通知是异步的，不阻塞审批流程
    }
    stop_block = {"hooks": [hook_entry_success]}
    stop_failure_block = {"hooks": [hook_entry_failed]}
    permission_block = {"hooks": [hook_entry_permission]}

    # Process Stop event
    stop_hooks = data["hooks"].get("Stop", [])
    if not isinstance(stop_hooks, list):
        stop_hooks = []

    # Find existing cc-notify entry index in Stop
    existing_index = -1
    for i, block in enumerate(stop_hooks):
        if isinstance(block, dict) and "hooks" in block and isinstance(block["hooks"], list):
            for h in block["hooks"]:
                if isinstance(h, dict) and "command" in h and "cc-notify" in h["command"]:
                    existing_index = i
                    break

    if existing_index >= 0:
        stop_hooks[existing_index] = stop_block
        print("[OK] Updated existing cc-notify Stop hook")
    elif stop_hooks:
        stop_hooks.append(stop_block)
        print("[OK] Added cc-notify Stop hook to existing hooks")
    else:
        data["hooks"]["Stop"] = [stop_block]
        print("[OK] Created new Stop hook configuration")

    # Process StopFailure event
    stop_failure_hooks = data["hooks"].get("StopFailure", [])
    if not isinstance(stop_failure_hooks, list):
        stop_failure_hooks = []

    # Find existing cc-notify entry index in StopFailure
    existing_index_failure = -1
    for i, block in enumerate(stop_failure_hooks):
        if isinstance(block, dict) and "hooks" in block and isinstance(block["hooks"], list):
            for h in block["hooks"]:
                if isinstance(h, dict) and "command" in h and "cc-notify" in h["command"]:
                    existing_index_failure = i
                    break

    if existing_index_failure >= 0:
        stop_failure_hooks[existing_index_failure] = stop_failure_block
        print("[OK] Updated existing cc-notify StopFailure hook")
    elif stop_failure_hooks:
        stop_failure_hooks.append(stop_failure_block)
        print("[OK] Added cc-notify StopFailure hook to existing hooks")
    else:
        data["hooks"]["StopFailure"] = [stop_failure_block]
        print("[OK] Created new StopFailure hook configuration")

    # Process PermissionRequest event
    permission_hooks = data["hooks"].get("PermissionRequest", [])
    if not isinstance(permission_hooks, list):
        permission_hooks = []

    # Find existing cc-notify entry index in PermissionRequest
    existing_index_permission = -1
    for i, block in enumerate(permission_hooks):
        if isinstance(block, dict) and "hooks" in block and isinstance(block["hooks"], list):
            for h in block["hooks"]:
                if isinstance(h, dict) and "command" in h and "cc-notify" in h["command"]:
                    existing_index_permission = i
                    break

    if existing_index_permission >= 0:
        permission_hooks[existing_index_permission] = permission_block
        print("[OK] Updated existing cc-notify PermissionRequest hook")
    elif permission_hooks:
        permission_hooks.append(permission_block)
        print("[OK] Added cc-notify PermissionRequest hook to existing hooks")
    else:
        data["hooks"]["PermissionRequest"] = [permission_block]
        print("[OK] Created new PermissionRequest hook configuration")

    # Write back the modified settings
    with open(settings_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write("\n")

except Exception as e:
    print(f"[ERROR] Failed to update settings.json: {str(e)}")
    sys.exit(1)
EOF

# Check if python command succeeded
if [ $? -ne 0 ]; then
    echo ""
    echo "Installation failed. Please fix the above errors and try again."
    exit 1
fi

echo ""
echo "Installation complete."
echo "Restart Claude Code (or open /hooks) to activate notifications."
echo ""
echo "=== Configuration ==="
echo "To customize notification sound:"
echo "  1. Edit $NOTIFY_DEST"
echo "  2. Modify the SOUND variable at the top of the file:"
echo "     - Use built-in sound names: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink"
echo "     - Or provide full path to custom audio file (aiff, wav, caf formats supported)"
echo "     - Set to empty string \"\" to disable sound entirely"
echo ""
echo "To uninstall, run the uninstall-claude-notify.sh script in the same directory."
