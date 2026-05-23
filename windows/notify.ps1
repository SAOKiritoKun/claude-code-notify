param(
    [string]$Title = "",
    [string]$Sound = "",
    [switch]$Failed
)

# Default titles and messages
$TitleSuccess = "✅ Claude Code Task Done"
$TitleFailed = "❌ Claude Code Task Failed"
$MessageSuccess = "Task completed"
$MessageFailed = "Task execution failed"

# Sound: filename under C:\Windows\Media\ or full path. Empty string to disable.
# Priority: -Sound param > CC_NOTIFY_SOUND env var > default sound (based on status)
$defaultSoundSuccess = "ding.wav"
$defaultSoundFailed = "Windows Error.wav"  # 失败时默认使用系统错误音效

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

# 自动检测失败状态，如果没有手动指定-Failed参数
if (-not $Failed -and $json -ne $null) {
    try {
        if ($json.PSObject.Properties['success'] -and $json.success -eq $false) {
            $Failed = $true
        }
    } catch {
        # 检测失败不影响继续执行
    }
}

# 设置标题和默认音效
if (-not $Title) {
    if ($Failed) {
        $Title = $TitleFailed
    } else {
        $Title = $TitleSuccess
    }
}

# 如果没有指定音效（用户没传参数也没有环境变量），根据状态设置默认音效
if (-not $userSpecifiedSound -and $Sound -eq "") {
    if ($Failed) {
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

        if ($userMsg) {
            $Message = if ($userMsg.Length -gt 200) { $userMsg.Substring(0, 197) + '...' } else { $userMsg }
        } else {
            $Message = if ($Failed) { $MessageFailed } else { $MessageSuccess }
        }

        # 失败时添加错误信息
        if ($Failed -and $errorInfo) {
            $Message = "$Message`n⚠️ Error: $errorInfo"
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
