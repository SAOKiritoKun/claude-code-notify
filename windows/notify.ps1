param(
    [string]$Title = "Claude Code Task Done",
    [string]$Sound = "ding.wav"
)

# Sound: filename under C:\Windows\Media\ or full path. Empty string to disable.
# Priority: -Sound param > CC_NOTIFY_SOUND env var > default ding.wav
if ($Sound -eq "ding.wav" -and $env:CC_NOTIFY_SOUND) {
    $Sound = $env:CC_NOTIFY_SOUND
}

if (-not [Console]::IsInputRedirected) {
    $Message = "(no input)"
} else {
    try {
        [Console]::InputEncoding = [System.Text.Encoding]::UTF8
        $raw  = [Console]::In.ReadToEnd()
        $json = $raw | ConvertFrom-Json

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

        if ($userMsg) {
            $Message = if ($userMsg.Length -gt 200) { $userMsg.Substring(0, 197) + '...' } else { $userMsg }
        } else {
            $Message = "Task completed"
        }
    } catch {
        $Message = "Task completed"
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
