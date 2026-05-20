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

# 2. Patch settings.json
$settingsExisted = Test-Path $settingsFile
if (-not $settingsExisted) {
    '{}' | Set-Content $settingsFile -Encoding UTF8
    Write-Host "[OK] Created $settingsFile"
}

$raw  = Get-Content $settingsFile -Raw -Encoding UTF8
$json = $raw | ConvertFrom-Json

# Ensure hooks object exists
if (-not $json.PSObject.Properties['hooks']) {
    $json | Add-Member -MemberType NoteProperty -Name 'hooks' -Value ([PSCustomObject]@{})
}

$hookEntry = [PSCustomObject]@{
    type    = "command"
    command = "powershell -ExecutionPolicy Bypass -NonInteractive -File `"$notifyDest`""
    timeout = 10
    async   = $true
}
$stopBlock = [PSCustomObject]@{ hooks = @($hookEntry) }

$stopProp = $json.hooks.PSObject.Properties['Stop']

# Check if a cc-notify entry already exists in Stop
$existingIndex = -1
if ($stopProp) {
    $arr = @($stopProp.Value)
    for ($i = 0; $i -lt $arr.Count; $i++) {
        $cmds = @($arr[$i].hooks) | Where-Object { $_.command -like "*cc-notify*" }
        if ($cmds) { $existingIndex = $i; break }
    }
}

if ($settingsExisted) {
    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$settingsFile.$timestamp.bak"
    Copy-Item -Path $settingsFile -Destination $backupFile
    Write-Host "[OK] Backup -> $backupFile"
}

if ($existingIndex -ge 0) {
    # Replace the existing cc-notify entry in-place
    $arr[$existingIndex] = $stopBlock
    $json.hooks.Stop = $arr
    Write-Host "[OK] Updated existing Stop hook in settings.json"
} elseif ($stopProp) {
    # Stop array exists but no cc-notify entry — append
    $json.hooks.Stop = @($stopProp.Value) + $stopBlock
    Write-Host "[OK] Appended Stop hook to settings.json"
} else {
    # No Stop array yet — create it
    $json.hooks | Add-Member -MemberType NoteProperty -Name 'Stop' -Value @($stopBlock)
    Write-Host "[OK] Added Stop hook to settings.json"
}

$pretty = Format-Json ($json | ConvertTo-Json -Depth 20 -Compress)
[System.IO.File]::WriteAllText($settingsFile, $pretty, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "Installation complete." -ForegroundColor Green
Write-Host "Restart Claude Code (or open /hooks) to activate notifications."
