#!/bin/bash
# Claude Code Turn Notification - macOS

TITLE="Claude Code Task Done"
MESSAGE="Task completed"

if [ -t 0 ]; then
    # No stdin
    MESSAGE="(no input)"
else
    RAW=$(cat)

    TRANSCRIPT_PATH=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except:
    print('')
" 2>/dev/null)

    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        USER_MSG=$(python3 - "$TRANSCRIPT_PATH" <<'EOF'
import sys, json

path = sys.argv[1]
user_msg = ""

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in reversed(lines):
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
        if entry.get("type") == "user" and entry.get("message"):
            content = entry["message"].get("content", "")
            if isinstance(content, str):
                user_msg = content
                break
            elif isinstance(content, list):
                texts = [b["text"] for b in content if b.get("type") == "text" and b.get("text")]
                if texts:
                    user_msg = " ".join(texts)
                    break
    except:
        continue

if len(user_msg) > 200:
    user_msg = user_msg[:197] + "..."

print(user_msg)
EOF
)
        if [ -n "$USER_MSG" ]; then
            MESSAGE="$USER_MSG"
        fi
    fi
fi

# Escape for AppleScript
ESCAPED_TITLE=$(echo "$TITLE"   | sed "s/\"/\\\\\"/g" | sed "s/'/\\\\'/g")
ESCAPED_MSG=$(echo   "$MESSAGE" | sed "s/\"/\\\\\"/g" | sed "s/'/\\\\'/g")

osascript -e "display notification \"$ESCAPED_MSG\" with title \"$ESCAPED_TITLE\""
