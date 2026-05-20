#!/bin/bash
# Claude Code Turn Notification - One-click installer (macOS)

set -e

CLAUDE_DIR_GLOBAL="$HOME/.claude"
CLAUDE_DIR_PROJECT="$(pwd)/.claude"

echo "=== Claude Code Turn Notification Installer ==="
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

# 1. Always overwrite notify script
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/notify.sh" "$NOTIFY_DEST"
chmod +x "$NOTIFY_DEST"
echo "[OK] Installed notify.sh -> $NOTIFY_DEST"

# 2. Patch settings.json
SETTINGS_EXISTED=false
[ -f "$SETTINGS_FILE" ] && SETTINGS_EXISTED=true

if [ "$SETTINGS_EXISTED" = false ]; then
    echo '{}' > "$SETTINGS_FILE"
    echo "[OK] Created $SETTINGS_FILE"
fi

if [ "$SETTINGS_EXISTED" = true ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$SETTINGS_FILE.$TIMESTAMP.bak"
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    echo "[OK] Backup -> $BACKUP_FILE"
fi

# Patch using python3
python3 - "$SETTINGS_FILE" "$NOTIFY_DEST" <<'EOF'
import sys, json, copy

settings_file = sys.argv[1]
notify_dest   = sys.argv[2]

with open(settings_file, "r", encoding="utf-8") as f:
    data = json.load(f)

if "hooks" not in data:
    data["hooks"] = {}

hook_entry = {
    "type":    "command",
    "command": f"bash \"{notify_dest}\"",
    "timeout": 10,
    "async":   True
}
stop_block = {"hooks": [hook_entry]}

stop_hooks = data["hooks"].get("Stop", [])

# Find existing cc-notify entry index
existing_index = -1
for i, block in enumerate(stop_hooks):
    for h in block.get("hooks", []):
        if "cc-notify" in h.get("command", ""):
            existing_index = i
            break

if existing_index >= 0:
    stop_hooks[existing_index] = stop_block
    print("[OK] Updated existing Stop hook in settings.json")
elif stop_hooks:
    stop_hooks.append(stop_block)
    print("[OK] Appended Stop hook to settings.json")
else:
    data["hooks"]["Stop"] = [stop_block]
    print("[OK] Added Stop hook to settings.json")

with open(settings_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)
    f.write("\n")
EOF

echo ""
echo "Installation complete."
echo "Restart Claude Code (or open /hooks) to activate notifications."
