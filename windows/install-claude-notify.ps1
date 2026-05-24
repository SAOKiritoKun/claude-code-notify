# Claude Code Turn Notification - One-click installer

$ErrorActionPreference = "Stop"

function Format-Json {
    param([string]$json)
    $sb     = [System.Text.StringBuilder]::new()
    $indent = 0
    $inStr  = $false
    $escape = $false
    $nl     = "`n"
    $pad    = '    '

    for ($i = 0; $i -lt $json.Length; $i++) {
        $c = $json[$i]
        if ($escape) { $null = $sb.Append($c); $escape = $false; continue }
        if ($c -eq '\' -and $inStr) { $null = $sb.Append($c); $escape = $true; continue }
        if ($c -eq '"') { $inStr = -not $inStr }
        if ($inStr) { $null = $sb.Append($c); continue }
        switch ($c) {
            '{' { $null = $sb.Append($c).Append($nl).Append($pad * ++$indent) }
            '[' { $null = $sb.Append($c).Append($nl).Append($pad * ++$indent) }
            '}' { $null = $sb.Append($nl).Append($pad * --$indent).Append($c) }
            ']' { $null = $sb.Append($nl).Append($pad * --$indent).Append($c) }
            ',' { $null = $sb.Append($c).Append($nl).Append($pad * $indent) }
            ':' { $null = $sb.Append(': ') }
            default {
                if ($c -ne ' ' -and $c -ne "`t" -and $c -ne "`r" -and $c -ne "`n") {
                    $null = $sb.Append($c)
                }
            }
        }
    }
    $sb.ToString()
}

Write-Host "=== Claude Code Turn Notification Installer ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Install location:"
Write-Host "  [1] Global (applies to all projects)  -> $env:USERPROFILE\.claude"
Write-Host "  [2] Current project only              -> $PWD\.claude"
Write-Host ""

do {
    $choice = Read-Host "Enter 1 or 2"
} while ($choice -ne '1' -and $choice -ne '2')

if ($choice -eq '1') {
    $claudeDir = "$env:USERPROFILE\.claude"
    Write-Host ""
    Write-Host "[Target] Global: $claudeDir" -ForegroundColor Green
} else {
    $claudeDir = "$PWD\.claude"
    Write-Host ""
    Write-Host "[Target] Project: $claudeDir" -ForegroundColor Green
}

$hooksDir     = "$claudeDir\hooks\cc-notify"
$settingsFile = "$claudeDir\settings.json"
$notifyDest   = "$hooksDir\notify.ps1"

# 1. Always overwrite notify script (update in place)
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
}
Copy-Item -Path "$PSScriptRoot\notify.ps1" -Destination $notifyDest -Force
Write-Host "[OK] Installed notify.ps1 -> $notifyDest"

# Register AppUserModelID so Toast notifications show "Claude Code"
$regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\ClaudeCode.Notify"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code"
Write-Host "[OK] Registered AppUserModelId: ClaudeCode.Notify"

# 2. Patch settings.json
if (-not (Test-Path $settingsFile)) {
    '{}' | Set-Content $settingsFile -Encoding UTF8
    Write-Host "[OK] Created $settingsFile"
}

$raw  = Get-Content $settingsFile -Raw -Encoding UTF8
$json = $raw | ConvertFrom-Json

# Ensure hooks object exists
if (-not $json.PSObject.Properties['hooks']) {
    $json | Add-Member -MemberType NoteProperty -Name 'hooks' -Value ([PSCustomObject]@{})
}

# Create hook entries for Stop (success), StopFailure (failed), PermissionRequest, and SessionStart events
$hookEntrySuccess = [PSCustomObject]@{
    type    = "command"
    command = "powershell -ExecutionPolicy Bypass -NonInteractive -File `"$notifyDest`""
    timeout = 10
    async   = $true
}
$hookEntryFailed = [PSCustomObject]@{
    type    = "command"
    command = "powershell -ExecutionPolicy Bypass -NonInteractive -File `"$notifyDest`" -Failed"
    timeout = 10
    async   = $true
}
$hookEntryPermission = [PSCustomObject]@{
    type    = "command"
    command = "powershell -ExecutionPolicy Bypass -NonInteractive -File `"$notifyDest`" -Permission"
    timeout = 10
    async   = $true  # 权限通知是异步的，不阻塞审批流程
}
$hookEntrySession = [PSCustomObject]@{
    type    = "command"
    command = "powershell -ExecutionPolicy Bypass -NonInteractive -File `"$notifyDest`" -SessionStart"
    timeout = 5
    async   = $true  # 会话通知是异步的，不阻塞启动流程
}
$stopBlock = [PSCustomObject]@{ hooks = @($hookEntrySuccess) }
$stopFailureBlock = [PSCustomObject]@{ hooks = @($hookEntryFailed) }
$permissionBlock = [PSCustomObject]@{ hooks = @($hookEntryPermission) }
$sessionBlock = [PSCustomObject]@{ hooks = @($hookEntrySession) }

# Function to add or update hook for a specific event
function Add-Or-Update-Hook {
    param(
        [PSObject]$Json,
        [string]$EventName,
        [PSObject]$HookBlock
    )

    $eventProp = $Json.hooks.PSObject.Properties[$EventName]
    $existingIndex = -1

    if ($eventProp) {
        $arr = @($eventProp.Value)
        for ($i = 0; $i -lt $arr.Count; $i++) {
            $cmds = @($arr[$i].hooks) | Where-Object { $_.command -like "*cc-notify*" }
            if ($cmds) { $existingIndex = $i; break }
        }

        if ($existingIndex -ge 0) {
            # Replace existing entry
            $arr[$existingIndex] = $HookBlock
            $Json.hooks.$EventName = $arr
            Write-Host "[OK] Updated existing $EventName hook in settings.json"
        } else {
            # Append to existing array
            $Json.hooks.$EventName = @($eventProp.Value) + $HookBlock
            Write-Host "[OK] Appended $EventName hook to settings.json"
        }
    } else {
        # Create new event array
        $Json.hooks | Add-Member -MemberType NoteProperty -Name $EventName -Value @($HookBlock)
        Write-Host "[OK] Added $EventName hook to settings.json"
    }
}

# Add all four events
Add-Or-Update-Hook -Json $json -EventName "Stop" -HookBlock $stopBlock
Add-Or-Update-Hook -Json $json -EventName "StopFailure" -HookBlock $stopFailureBlock
Add-Or-Update-Hook -Json $json -EventName "PermissionRequest" -HookBlock $permissionBlock
Add-Or-Update-Hook -Json $json -EventName "SessionStart" -HookBlock $sessionBlock

$pretty = Format-Json ($json | ConvertTo-Json -Depth 20 -Compress)
[System.IO.File]::WriteAllText($settingsFile, $pretty, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "Installation complete." -ForegroundColor Green
Write-Host "Restart Claude Code (or open /hooks) to activate notifications."
