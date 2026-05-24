param(
    [string]$Title = "",
    [string]$Sound = "",
    [switch]$Failed,
    [switch]$Permission,
    [switch]$SessionStart
)

# Default titles and messages
$TitleSuccess = "Claude Code Task Done"
$TitleFailed = "Claude Code Task Failed"
$TitlePermission = "Claude Code Permission Request"
$TitleSession = "Claude Code Session Started"
$MessageSuccess = "Task completed"
$MessageFailed = "Task execution failed"
$MessagePermission = "Permission request requires your approval"
$MessageSessionNew = "New session started at"
$MessageSessionResumed = "Session resumed at"

# Sound: filename under C:\Windows\Media\ or full path. Empty string to disable.
# Priority: -Sound param > CC_NOTIFY_SOUND env var > default sound (based on status)
$defaultSoundSuccess = "ding.wav"
$defaultSoundFailed = "Windows Error.wav"  # 失败时默认使用系统错误音效
$defaultSoundPermission = "notify.wav"     # 权限请求时使用中性提示音
$defaultSoundSession = "notify.wav"        # 会话启动时使用温和的提示音

# 音效优先级处理
$userSpecifiedSound = $PSBoundParameters.ContainsKey('Sound')
if (-not $userSpecifiedSound -and $env:CC_NOTIFY_SOUND) {
    $Sound = $env:CC_NOTIFY_SOUND
}

# 预读取stdin内容，供后面所有逻辑使用（避免重复读取流）
$raw = ""
$json = $null
if ([Console]::IsInputRedirected) {
    try {
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        $raw = [Console]::In.ReadToEnd()
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        # 解析失败不影响继续执行
        $json = $null
    }
}

# 自动检测事件类型，如果没有手动指定参数
if (-not $Failed -and -not $Permission -and -not $SessionStart -and $json -ne $null) {
    try {
        if ($json.PSObject.Properties['event_type'] -and $json.event_type -eq "PermissionRequest") {
            $Permission = $true
        } elseif ($json.PSObject.Properties['event_type'] -and $json.event_type -eq "SessionStart") {
            $SessionStart = $true
        } elseif ($json.PSObject.Properties['success'] -and $json.success -eq $false) {
            $Failed = $true
        }
    } catch {
        # 检测失败不影响继续执行
    }
}

# 设置标题和默认音效
if (-not $Title) {
    if ($SessionStart) {
        $Title = $TitleSession
    } elseif ($Permission) {
        $Title = $TitlePermission
    } elseif ($Failed) {
        $Title = $TitleFailed
    } else {
        $Title = $TitleSuccess
    }
}

# 如果没有指定音效（用户没传参数也没有环境变量），根据状态设置默认音效
if (-not $userSpecifiedSound -and $Sound -eq "") {
    if ($SessionStart) {
        $Sound = $defaultSoundSession
    } elseif ($Permission) {
        $Sound = $defaultSoundPermission
    } elseif ($Failed) {
        $Sound = $defaultSoundFailed
    } else {
        $Sound = $defaultSoundSuccess
    }
}

if (-not [Console]::IsInputRedirected -or $json -eq $null) {
    $Message = "(no input)"
    # 没有输入时也应用失败状态
    if ($Failed -and -not $Message) {
        $Message = $MessageFailed
    }
} else {
    try {

        $userMsg = $null

        if ($json.transcript_path -and (Test-Path $json.transcript_path)) {
            $lines = Get-Content $json.transcript_path -Encoding UTF8
            for ($i = $lines.Count - 1; $i -ge 0; $i--) {
                if (-not $lines[$i].Trim()) { continue }
                try {
                    $entry = $lines[$i] | ConvertFrom-Json
                    if ($entry.type -eq 'user' -and $entry.message) {
                        $content = $entry.message.content
                        if ($content -is [string]) {
                            $userMsg = $content; break
                        } elseif ($content -is [array]) {
                            $text = @($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join ' '
                            if ($text) { $userMsg = $text; break }
                        }
                    }
                } catch { continue }
            }
        }

        # 提取权限请求信息（如果是权限事件）
        $permissionInfo = ""
        if ($Permission) {
            try {
                # 权限类型映射
                $typeMap = @{
                    "bash_run" = "[Command]"
                    "file_edit" = "[Edit]"
                    "file_read" = "[Read]"
                    "network_access" = "[Network]"
                    "tool_call" = "[Tool]"
                }

                $permType = if ($json.PSObject.Properties['permission_type']) { $json.permission_type.ToString() } else { "" }
                $operation = if ($json.PSObject.Properties['operation']) { $json.operation } else { $null }

                $desc = ""
                if ($operation -ne $null -and $operation -is [PSCustomObject]) {
                    # 优先获取操作描述
                    if ($operation.PSObject.Properties['description']) {
                        $desc = $operation.description.ToString()
                    } else {
                        # 没有描述则尝试取工具+命令/路径
                        $tool = if ($operation.PSObject.Properties['tool']) { $operation.tool.ToString() } else { "" }
                        if ($tool -eq "Bash" -and $operation.PSObject.Properties['command']) {
                            $desc = $operation.command.ToString()
                        } elseif (($tool -eq "Edit" -or $tool -eq "Write") -and $operation.PSObject.Properties['file_path']) {
                            $desc = $operation.file_path.ToString()
                        } elseif ($tool -eq "Read" -and $operation.PSObject.Properties['file_path']) {
                            $desc = $operation.file_path.ToString()
                        }
                    }
                }

                # 组合显示内容
                if ($typeMap.ContainsKey($permType)) {
                    $prefix = $typeMap[$permType]
                } else {
                    $prefix = "[Operation]"
                }

                if ($desc) {
                    $permissionInfo = "$prefix $desc"
                    if ($permissionInfo.Length -gt 150) {
                        $permissionInfo = $permissionInfo.Substring(0, 147) + "..."
                    }
                } else {
                    $permissionInfo = "Claude requires your authorization to proceed"
                }
            } catch {
                $permissionInfo = "Claude requires your authorization to proceed"
            }
        }

        # 提取会话启动信息（如果是会话事件）
        $sessionInfo = ""
        if ($SessionStart) {
            try {
                # 根据source字段区分会话类型
                $source = if ($json.PSObject.Properties['source']) { $json.source.ToString().ToLower() } else { "" }
                # 获取工作区路径，使用cwd字段（来自官方payload）
                $workspacePath = ""
                if ($json.PSObject.Properties['cwd']) {
                    $workspacePath = $json.cwd.ToString()
                } elseif ($json.PSObject.Properties['workspace_path']) {
                    $workspacePath = $json.workspace_path.ToString()
                } elseif ($json.PSObject.Properties['path']) {
                    $workspacePath = $json.path.ToString()
                }
                # 获取会话ID
                $sessionId = if ($json.PSObject.Properties['session_id']) { $json.session_id.ToString() } else { "" }

                # 简化路径显示，用~代替用户目录
                $homePath = $env:USERPROFILE
                if ($workspacePath -and $workspacePath.StartsWith($homePath)) {
                    $workspacePath = "~" + $workspacePath.Substring($homePath.Length)
                }

                # 根据source显示对应文案
                if ($source -eq "resume") {
                    $prefix = $MessageSessionResumed
                } elseif ($source -eq "startup") {
                    $prefix = $MessageSessionNew
                } else {
                    $prefix = "Session started at"
                }

                $resultParts = @()
                if ($workspacePath) {
                    $resultParts += "$prefix $workspacePath"
                } else {
                    $resultParts += "$prefix current directory"
                }

                # 添加会话ID信息
                if ($sessionId) {
                    $resultParts += "Session ID: $sessionId"
                }

                # 使用换行分隔
                $sessionInfo = $resultParts -join "`n"
                if ($sessionInfo.Length -gt 300) {
                    $sessionInfo = $sessionInfo.Substring(0, 297) + "..."
                }
            } catch {
                $sessionInfo = "Claude Code session started"
            }
        }

        # 提取错误信息（如果是失败事件）
        $errorInfo = ""
        if ($Failed -and $json.PSObject.Properties['error']) {
            $error = $json.error
            if ($error -is [PSCustomObject]) {
                # 处理错误对象，优先取message/reason字段
                if ($error.PSObject.Properties['message']) {
                    $errorInfo = $error.message.ToString()
                } elseif ($error.PSObject.Properties['reason']) {
                    $errorInfo = $error.reason.ToString()
                } else {
                    $errorInfo = $error.ToString()
                }
            } else {
                $errorInfo = $error.ToString()
            }
            if ($errorInfo.Length -gt 100) {
                $errorInfo = $errorInfo.Substring(0, 97) + "..."
            }
        }

        # 会话启动优先显示会话信息
        if ($SessionStart) {
            if ($sessionInfo) {
                $Message = $sessionInfo
            } else {
                $Message = "$MessageSessionNew current directory"
            }
        # 权限请求优先显示权限信息
        } elseif ($Permission) {
            if ($permissionInfo) {
                $Message = $permissionInfo
            } else {
                $Message = $MessagePermission
            }
            # 添加提示行
            $Message = "$Message`n$MessagePermission"
        } elseif ($userMsg) {
            $Message = if ($userMsg.Length -gt 200) { $userMsg.Substring(0, 197) + '...' } else { $userMsg }
        } else {
            $Message = if ($Failed) { $MessageFailed } else { $MessageSuccess }
        }

        # 失败时添加错误信息
        if ($Failed -and $errorInfo) {
            $Message = "$Message`nError: $errorInfo"
            if ($Message.Length -gt 300) {
                $Message = $Message.Substring(0, 297) + "..."
            }
        }
    } catch {
        $Message = if ($Failed) { $MessageFailed } else { $MessageSuccess }
    }
}

# Escape XML special characters
$xmlTitle   = [System.Security.SecurityElement]::Escape($Title)
$xmlMessage = [System.Security.SecurityElement]::Escape($Message)

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml(@"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$xmlTitle</text>
      <text>$xmlMessage</text>
    </binding>
  </visual>
  <audio silent="true"/>
</toast>
"@)

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("ClaudeCode.Notify").Show($toast)

if ($Sound -ne "") {
    if (-not [System.IO.Path]::IsPathRooted($Sound)) {
        $Sound = "C:\Windows\Media\$Sound"
    }
    if (Test-Path $Sound) {
        $player = New-Object System.Media.SoundPlayer $Sound
        $player.PlaySync()
    }
}
