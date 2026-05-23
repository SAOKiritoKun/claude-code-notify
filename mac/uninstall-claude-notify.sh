#!/bin/bash
# Claude Code Turn Notification - Uninstaller (macOS)

set +e  # Disable exit on error to make script more robust

CLAUDE_DIR_GLOBAL="$HOME/.claude"
CLAUDE_DIR_PROJECT="$(pwd)/.claude"

echo "=== Claude Code Turn Notification Uninstaller ==="
echo ""
echo "Uninstall scope:"
echo "  [1] Current project only  -> $CLAUDE_DIR_PROJECT"
echo "  [2] Global only           -> $CLAUDE_DIR_GLOBAL"
echo "  [3] Both"
echo ""

while true; do
    read -rp "Enter 1, 2, or 3: " CHOICE
    case "$CHOICE" in
        1|2|3) break ;;
        *) echo "Please enter 1, 2, or 3" ;;
    esac
done

# Function to perform uninstall for a given directory
uninstall_from() {
    local claude_dir="$1"
    local hooks_dir="$claude_dir/hooks/cc-notify"
    local settings_file="$claude_dir/settings.json"

    echo ""
    echo "[Target] $claude_dir"

    # 1. Remove notify script directory
    if [ -d "$hooks_dir" ]; then
        if rm -rf "$hooks_dir"; then
            echo "[OK] Removed notification scripts: $hooks_dir"
        else
            echo "[WARNING] Failed to remove $hooks_dir (may require sudo or manual deletion)"
        fi
    else
        echo "[INFO] No notification scripts found at $hooks_dir"
    fi

    # 2. Remove hook from settings.json
    if [ -f "$settings_file" ]; then
        echo "[INFO] Found settings.json, checking for cc-notify hooks..."

        # Check if file is readable
        if [ ! -r "$settings_file" ]; then
            echo "[WARNING] settings.json is not readable, skipping hook removal"
            return
        fi

        # Check if python3 is available
        if ! command -v python3 &> /dev/null; then
            echo "[WARNING] python3 not found, cannot modify settings.json automatically"
            echo "[INFO] Please manually remove the cc-notify entry from $settings_file"
            return
        fi

        # Use python3 to patch settings.json with error handling
        python3 - "$settings_file" <<'EOF'
import sys, json, os

def remove_cc_notify_hooks(data, event_name):
    """Remove cc-notify hooks from a specific event, returns (modified_data, was_modified, found_count)"""
    modified = False
    found_count = 0

    if not isinstance(data, dict) or "hooks" not in data or not isinstance(data["hooks"], dict):
        return data, modified, found_count

    if event_name not in data["hooks"] or not isinstance(data["hooks"][event_name], list):
        return data, modified, found_count

    event_hooks = data["hooks"][event_name]
    new_event_hooks = []

    for block in event_hooks:
        if isinstance(block, dict) and "hooks" in block and isinstance(block["hooks"], list):
            block_hooks = block["hooks"]
            filtered_hooks = []
            cc_notify_found_in_block = False

            for h in block_hooks:
                if (isinstance(h, dict) and
                    "command" in h and
                    isinstance(h["command"], str) and
                    "cc-notify" in h["command"] and
                    h.get("type") == "command" and
                    h.get("timeout") == 10 and
                    h.get("async") == True):
                    cc_notify_found_in_block = True
                    found_count += 1
                else:
                    filtered_hooks.append(h)

            if filtered_hooks:
                new_block = block.copy()
                new_block["hooks"] = filtered_hooks
                new_event_hooks.append(new_block)
                if cc_notify_found_in_block:
                    modified = True
            elif cc_notify_found_in_block:
                modified = True
            else:
                new_event_hooks.append(block)
        else:
            new_event_hooks.append(block)

    if modified:
        if new_event_hooks:
            data["hooks"][event_name] = new_event_hooks
        else:
            del data["hooks"][event_name]

    return data, modified, found_count

try:
    settings_file = sys.argv[1]

    with open(settings_file, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            print("[WARNING] settings.json is not valid JSON, cannot modify automatically")
            sys.exit(0)

    total_modified = False
    total_found = 0

    # Process Stop, StopFailure and PermissionRequest events
    for event in ["Stop", "StopFailure", "PermissionRequest"]:
        data, modified, found = remove_cc_notify_hooks(data, event)
        if modified:
            total_modified = True
            total_found += found
            if found > 0:
                print(f"[OK] Removed {found} cc-notify hook(s) from {event} hooks")

    if total_modified:
        # If hooks is now empty, remove the hooks key entirely
        if "hooks" in data and not data["hooks"]:
            del data["hooks"]
            print("[OK] Removed empty hooks configuration")

        # Write back the modified settings
        try:
            with open(settings_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
                f.write("\n")
        except IOError:
            print("[WARNING] Failed to write to settings.json (permission denied)")
            print("[INFO] Please manually remove the cc-notify entries from $settings_file if needed")
    else:
        print("[INFO] No cc-notify hooks found in settings.json")
except Exception as e:
    print(f"[WARNING] An error occurred while processing settings.json: {str(e)}")
    print("[INFO] Please manually remove the cc-notify entries from $settings_file if needed")
EOF
    else
        echo "[INFO] No settings.json file found at $settings_file"
    fi
}

# Execute uninstall based on user choice
if [ "$CHOICE" = "1" ] || [ "$CHOICE" = "3" ]; then
    uninstall_from "$CLAUDE_DIR_PROJECT"
fi

if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "3" ]; then
    uninstall_from "$CLAUDE_DIR_GLOBAL"
fi

echo ""
echo "Uninstallation complete."
echo "Restart Claude Code for changes to take effect."
