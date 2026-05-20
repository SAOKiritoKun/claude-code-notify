param(
    [string]$Title = "Claude Code Task Done"
)

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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info
$notify.BalloonTipTitle = $Title
$notify.BalloonTipText  = $Message
$notify.Visible = $true

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5500
$timer.Add_Tick({
    $timer.Stop()
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$notify.ShowBalloonTip(5000)
$timer.Start()
[System.Windows.Forms.Application]::Run()
