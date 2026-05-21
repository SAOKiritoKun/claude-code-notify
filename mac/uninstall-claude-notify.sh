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

try:
    settings_file = sys.argv[1]

    with open(settings_file, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            print("[WARNING] settings.json is not valid JSON, cannot modify automatically")
            sys.exit(0)

    modified = False

    if isinstance(data, dict) and "hooks" in data and isinstance(data["hooks"], dict):
        if "Stop" in data["hooks"] and isinstance(data["hooks"]["Stop"], list):
            stop_hooks = data["hooks"]["Stop"]
            new_stop_hooks = []

            # Only remove cc-notify hooks added by our installer
            for block in stop_hooks:
                if isinstance(block, dict) and "hooks" in block and isinstance(block["hooks"], list):
                    block_hooks = block["hooks"]
                    filtered_hooks = []
                    cc_notify_found_in_block = False

                    for h in block_hooks:
                        # Only remove hooks that match our exact installer signature
                        if (isinstance(h, dict) and
                            "command" in h and
                            isinstance(h["command"], str) and
                            "cc-notify" in h["command"] and
                            h.get("type") == "command" and
                            h.get("timeout") == 10 and
                            h.get("async") == True):
                            cc_notify_found_in_block = True
                            modified = True
                        else:
                            # Keep all other hooks untouched
                            filtered_hooks.append(h)

                    if filtered_hooks:
                        # Keep the block if there are other hooks left
                        new_block = block.copy()
                        new_block["hooks"] = filtered_hooks
                        new_stop_hooks.append(new_block)
                    elif cc_notify_found_in_block:
                        # Block only had our cc-notify hook, remove it entirely
                        modified = True
                    else:
                        # Block has no cc-notify hooks, keep it as is
                        new_stop_hooks.append(block)
                else:
                    # Not a hook block we recognize, keep it completely untouched
                    new_stop_hooks.append(block)

            if modified:
                if new_stop_hooks:
                    data["hooks"]["Stop"] = new_stop_hooks
                    print("[OK] Removed cc-notify hook from Stop hooks")
                else:
                    # No more Stop hooks, remove the Stop key
                    del data["hooks"]["Stop"]
                    print("[OK] Removed empty Stop hooks entry")

                # If hooks is now empty, remove the hooks key entirely
                if not data["hooks"]:
                    del data["hooks"]
                    print("[OK] Removed empty hooks configuration")

                # Write back the modified settings
                try:
                    with open(settings_file, "w", encoding="utf-8") as f:
                        json.dump(data, f, indent=4, ensure_ascii=False)
                        f.write("\n")
                except IOError:
                    print("[WARNING] Failed to write to settings.json (permission denied)")
                    print("[INFO] Please manually remove the cc-notify entry from $settings_file if needed")
            else:
                print("[INFO] No cc-notify hook found in settings.json")
        else:
            print("[INFO] No Stop hooks found in settings.json")
    else:
        print("[INFO] No hooks configuration found in settings.json")
except Exception as e:
    print(f"[WARNING] An error occurred while processing settings.json: {str(e)}")
    print("[INFO] Please manually remove the cc-notify entry from $settings_file if needed")
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
