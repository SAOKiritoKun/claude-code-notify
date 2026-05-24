#!/bin/bash
# Claude Code Turn Notification - macOS

TITLE_SUCCESS="Claude Code Task Done"
TITLE_FAILED="Claude Code Task Failed"
TITLE_PERMISSION="Claude Code Permission Request"
TITLE_SESSION="Claude Code Session Started"
MESSAGE_SUCCESS="Task completed"
MESSAGE_FAILED="Task execution failed"
MESSAGE_PERMISSION="Permission request requires your approval"
MESSAGE_SESSION_NEW="New session started at"
MESSAGE_SESSION_RESUMED="Session resumed at"
# 音效配置：可以是内置音效名或自定义音效文件路径
# 内置音效列表：Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
# 自定义音效支持格式：aiff, wav, caf
# 设置为空字符串 "" 可禁用音效
SOUND_SUCCESS="${CC_NOTIFY_SOUND:-Funk}"
SOUND_FAILED="${CC_NOTIFY_SOUND:-Basso}"  # 失败时默认使用不同的音效
SOUND_PERMISSION="${CC_NOTIFY_SOUND:-Glass}"  # 权限请求时使用中性提示音
SOUND_SESSION="${CC_NOTIFY_SOUND:-Glass}"   # 会话启动时使用温和的提示音

# 解析命令行参数
IS_FAILED=""
IS_PERMISSION=""
IS_SESSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --failed)
            IS_FAILED="1"
            shift
            ;;
        --permission)
            IS_PERMISSION="1"
            shift
            ;;
        --session-start)
            IS_SESSION="1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [ -t 0 ]; then
    # No stdin
    if [ -n "$IS_PERMISSION" ]; then
        TITLE="$TITLE_PERMISSION"
        MESSAGE="$MESSAGE_PERMISSION"
        SOUND="$SOUND_PERMISSION"
    elif [ -z "$IS_FAILED" ]; then
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

    # 检测事件类型
    if [ -z "$IS_PERMISSION" ] && [ -z "$IS_SESSION" ]; then
        EVENT_TYPE=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('event_type', ''))
except:
    print('')
" 2>/dev/null)
        if [ "$EVENT_TYPE" = "PermissionRequest" ]; then
            IS_PERMISSION="1"
        elif [ "$EVENT_TYPE" = "SessionStart" ]; then
            IS_SESSION="1"
        elif [ -z "$IS_FAILED" ]; then
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
    fi

    # 设置标题和音效
    if [ -n "$IS_SESSION" ]; then
        TITLE="$TITLE_SESSION"
        SOUND="$SOUND_SESSION"
    elif [ -n "$IS_PERMISSION" ]; then
        TITLE="$TITLE_PERMISSION"
        SOUND="$SOUND_PERMISSION"
    elif [ -z "$IS_FAILED" ]; then
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

    # 提取权限请求信息（如果是权限事件）
    PERMISSION_INFO=""
    if [ -n "$IS_PERMISSION" ]; then
        PERMISSION_INFO=$(echo "$RAW" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)

    # 权限类型映射
    type_map = {
        'bash_run': '[Command]',
        'file_edit': '[Edit]',
        'file_read': '[Read]',
        'network_access': '[Network]',
        'tool_call': '[Tool]'
    }

    perm_type = d.get('permission_type', '')
    operation = d.get('operation', {})

    # 优先获取操作描述
    if isinstance(operation, dict):
        desc = operation.get('description', '')
        if not desc:
            # 没有描述则尝试取工具+命令/路径
            tool = operation.get('tool', '')
            if tool == 'Bash' and operation.get('command'):
                desc = operation.get('command', '')
            elif (tool == 'Edit' or tool == 'Write') and operation.get('file_path'):
                desc = operation.get('file_path', '')
            elif (tool == 'Read') and operation.get('file_path'):
                desc = operation.get('file_path', '')

    # 组合显示内容
    if perm_type in type_map:
        prefix = type_map[perm_type]
    else:
        prefix = '[Operation]'

    if desc:
        result = f'{prefix} {desc}'
    else:
        result = 'Claude requires your authorization to proceed'

    print(result[:150])  # 限制长度
except:
    print('Claude requires your authorization to proceed')
" 2>/dev/null)
    fi

    # 提取会话启动信息（如果是会话事件）
    SESSION_INFO=""
    if [ -n "$IS_SESSION" ]; then
        SESSION_INFO=$(echo "$RAW" | python3 -c "
import sys, json, os
try:
    d = json.load(sys.stdin)
    # 先获取所有字段方便调试
    all_fields = list(d.keys())

    # 根据source字段区分会话类型
    source = d.get('source', d.get('event_source', '')).lower()
    # 获取工作区路径，兼容所有可能的字段
    workspace_path = ''
    for key in ['cwd', 'workspace_path', 'path', 'directory']:
        if key in d:
            workspace_path = d[key]
            break
    # 获取会话ID
    session_id = d.get('session_id', '')

    # 简化路径显示，用~代替用户目录
    home = os.path.expanduser('~')
    if workspace_path and isinstance(workspace_path, str) and workspace_path.startswith(home):
        workspace_path = '~' + workspace_path[len(home):]

    # 根据source显示对应文案
    if source == 'resume' or 'resume' in source or 'continue' in source:
        prefix = 'Session resumed at'
    elif source == 'startup' or 'start' in source or 'new' in source:
        prefix = 'New session started at'
    else:
        prefix = 'Session started at'

    result_parts = []
    if workspace_path and isinstance(workspace_path, str):
        result_parts.append(f'{prefix} {workspace_path}')
    else:
        result_parts.append(f'{prefix} current directory')

    # 添加会话ID信息
    if session_id:
        result_parts.append(f'Session ID: {session_id}')

    # 使用换行分隔
    result = '\n'.join(result_parts)
    print(result[:300])  # 增加长度限制
except Exception as e:
    # 出错时显示错误信息和raw内容
    print(f'Session error | {str(e)[:30]} | RAW: {sys.stdin.read()[:100]}...')
")
    fi

    # 会话启动优先显示会话信息，不需要读取对话记录
    if [ -n "$IS_SESSION" ]; then
        if [ -n "$SESSION_INFO" ]; then
            MESSAGE="$SESSION_INFO"
        else
            MESSAGE="Session started"
        fi
    elif [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
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
        # 权限请求优先显示权限信息
        if [ -n "$IS_PERMISSION" ]; then
            if [ -n "$PERMISSION_INFO" ]; then
                MESSAGE="$PERMISSION_INFO"
            else
                MESSAGE="$MESSAGE_PERMISSION"
            fi
            # 添加提示行
            MESSAGE="$MESSAGE
$MESSAGE_PERMISSION"
        elif [ -n "$USER_MSG" ]; then
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
Error: $ERROR_INFO"
            # 总长度限制在300字符以内
            if [ ${#MESSAGE} -gt 300 ]; then
                MESSAGE="${MESSAGE:0:297}..."
            fi
        fi
    else
        if [ -n "$IS_PERMISSION" ]; then
            if [ -n "$PERMISSION_INFO" ]; then
                MESSAGE="$PERMISSION_INFO"
            else
                MESSAGE="$MESSAGE_PERMISSION"
            fi
            # 添加提示行
            MESSAGE="$MESSAGE
$MESSAGE_PERMISSION"
        elif [ -z "$IS_FAILED" ]; then
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
