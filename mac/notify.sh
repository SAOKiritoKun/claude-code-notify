#!/bin/bash
# Claude Code Turn Notification - macOS

TITLE_SUCCESS="✅ Claude Code Task Done"
TITLE_FAILED="❌ Claude Code Task Failed"
MESSAGE_SUCCESS="Task completed"
MESSAGE_FAILED="Task execution failed"
# 音效配置：可以是内置音效名或自定义音效文件路径
# 内置音效列表：Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
# 自定义音效支持格式：aiff, wav, caf
# 设置为空字符串 "" 可禁用音效
SOUND_SUCCESS="${CC_NOTIFY_SOUND:-Funk}"
SOUND_FAILED="${CC_NOTIFY_SOUND:-Basso}"  # 失败时默认使用不同的音效

# 解析命令行参数
IS_FAILED=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --failed)
            IS_FAILED="1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -t 0 ]; then
    # No stdin
    if [ -z "$IS_FAILED" ]; then
        TITLE="$TITLE_SUCCESS"
        MESSAGE="$MESSAGE_SUCCESS"
        SOUND="$SOUND_SUCCESS"
    else
        TITLE="$TITLE_FAILED"
        MESSAGE="$MESSAGE_FAILED"
        SOUND="$SOUND_FAILED"
    fi
else
    RAW=$(cat)

    # 检测事件是否成功
    if [ -z "$IS_FAILED" ]; then
        SUCCESS=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(str(d.get('success', True)).lower())
except:
    print('true')
" 2>/dev/null)
        if [ "$SUCCESS" = "false" ]; then
            IS_FAILED="1"
        fi
    fi

    # 设置标题和音效
    if [ -z "$IS_FAILED" ]; then
        TITLE="$TITLE_SUCCESS"
        SOUND="$SOUND_SUCCESS"
    else
        TITLE="$TITLE_FAILED"
        SOUND="$SOUND_FAILED"
    fi

    TRANSCRIPT_PATH=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except:
    print('')
" 2>/dev/null)

    # 提取错误信息（如果是失败事件）
    ERROR_INFO=""
    if [ -n "$IS_FAILED" ]; then
        ERROR_INFO=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    error = d.get('error', '')
    if isinstance(error, dict):
        # 处理错误对象，优先取message/reason字段
        error = error.get('message', error.get('reason', str(error)))
    print(str(error)[:100])  # 限制错误信息长度
except:
    print('')
" 2>/dev/null)
    fi

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
        else
            if [ -z "$IS_FAILED" ]; then
                MESSAGE="$MESSAGE_SUCCESS"
            else
                MESSAGE="$MESSAGE_FAILED"
            fi
        fi

        # 失败时添加错误信息
        if [ -n "$IS_FAILED" ] && [ -n "$ERROR_INFO" ]; then
            MESSAGE="$MESSAGE
⚠️ Error: $ERROR_INFO"
            # 总长度限制在300字符以内
            if [ ${#MESSAGE} -gt 300 ]; then
                MESSAGE="${MESSAGE:0:297}..."
            fi
        fi
    else
        if [ -z "$IS_FAILED" ]; then
            MESSAGE="$MESSAGE_SUCCESS"
        else
            MESSAGE="$MESSAGE_FAILED"
        fi
    fi
fi

# Escape for AppleScript
ESCAPED_TITLE=$(echo "$TITLE"   | sed "s/\"/\\\\\"/g" | sed "s/'/\\\\'/g")
ESCAPED_MSG=$(echo   "$MESSAGE" | sed "s/\"/\\\\\"/g" | sed "s/'/\\\\'/g")

# 构建通知命令
NOTIFY_CMD="display notification \"$ESCAPED_MSG\" with title \"$ESCAPED_TITLE\""

if [ -n "$SOUND" ]; then
    # 判断是否是内置音效名
    if [ ! -f "$SOUND" ] && [ -f "/System/Library/Sounds/$SOUND.aiff" ]; then
        # 内置音效：使用原生通知播放（同步性更好）
        NOTIFY_CMD="$NOTIFY_CMD sound name \"$SOUND\""
    elif [ -f "$SOUND" ]; then
        # 自定义音频文件：使用afplay播放（支持全格式）
        afplay "$SOUND" &
    fi
fi

osascript -e "$NOTIFY_CMD"
