# Claude Code Turn Notification - Uninstaller

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

function Remove-CcNotify {
    param([string]$claudeDir)

    $hooksDir     = "$claudeDir\hooks\cc-notify"
    $settingsFile = "$claudeDir\settings.json"

    Write-Host ""
    Write-Host "[Target] $claudeDir" -ForegroundColor Cyan

    # Remove hook entry from settings.json
    if (Test-Path $settingsFile) {
        $raw  = Get-Content $settingsFile -Raw -Encoding UTF8
        $json = $raw | ConvertFrom-Json

        $totalFound = 0

        # Function to remove cc-notify hooks from a specific event
        function Remove-Event-Hooks {
            param(
                [PSObject]$Json,
                [string]$EventName
            )

            $found = 0
            $eventProp = $Json.hooks.PSObject.Properties[$EventName]

            if ($eventProp) {
                $arr = @($eventProp.Value)
                $newArr = @()
                foreach ($block in $arr) {
                    if ($block.PSObject.Properties['hooks'] -and $block.hooks -is [array]) {
                        $filteredHooks = @()
                        $ccNotifyInBlock = $false
                        foreach ($hook in $block.hooks) {
                            # Only remove hooks that match our exact installer signature
                            if ($hook.PSObject.Properties['command'] -and
                                $hook.command -like "*cc-notify*" -and
                                $hook.type -eq "command" -and
                                $hook.timeout -eq 10 -and
                                $hook.async -eq $true) {
                                $ccNotifyInBlock = $true
                                $found++
                            } else {
                                # Keep all other hooks untouched
                                $filteredHooks += $hook
                            }
                        }

                        if ($filteredHooks.Count -gt 0) {
                            # Keep the block with remaining hooks
                            $newBlock = $block.PSObject.Copy()
                            $newBlock.hooks = $filteredHooks
                            $newArr += $newBlock
                        } elseif ($ccNotifyInBlock) {
                            # Block only had our cc-notify hook, skip adding it
                        } else {
                            # No cc-notify hooks, keep the block as is
                            $newArr += $block
                        }
                    } else {
                        # Not a recognized block format, keep it untouched
                        $newArr += $block
                    }
                }

                if ($found -gt 0) {
                    if ($newArr.Count -eq 0) {
                        $Json.hooks.PSObject.Properties.Remove($EventName)
                    } else {
                        $Json.hooks.$EventName = $newArr
                    }
                    Write-Host "[OK] Removed $found cc-notify $EventName hook(s) from settings.json"
                } else {
                    Write-Host "[SKIP] No cc-notify hooks found in $EventName"
                }
            } else {
                Write-Host "[SKIP] No $EventName hooks in $settingsFile"
            }

            return $found
        }

        # Process Stop, StopFailure and PermissionRequest events
        if ($json.PSObject.Properties['hooks']) {
            $totalFound += Remove-Event-Hooks -Json $json -EventName "Stop"
            $totalFound += Remove-Event-Hooks -Json $json -EventName "StopFailure"
            $totalFound += Remove-Event-Hooks -Json $json -EventName "PermissionRequest"

            if ($totalFound -gt 0) {
                # If hooks object is now empty, remove it entirely
                if ($json.hooks.PSObject.Properties.Count -eq 0) {
                    $json.PSObject.Properties.Remove('hooks')
                }

                $pretty = Format-Json ($json | ConvertTo-Json -Depth 20 -Compress)
                [System.IO.File]::WriteAllText($settingsFile, $pretty, [System.Text.Encoding]::UTF8)
            } else {
                Write-Host "[SKIP] No cc-notify hooks found in $settingsFile"
            }
        } else {
            Write-Host "[SKIP] No hooks configuration found in $settingsFile"
        }
    } else {
        Write-Host "[SKIP] settings.json not found at $settingsFile"
    }

    # Remove hooks directory
    if (Test-Path $hooksDir) {
        Remove-Item -Recurse -Force $hooksDir
        Write-Host "[OK] Removed $hooksDir"
    } else {
        Write-Host "[SKIP] hooks\cc-notify not found at $hooksDir"
    }
}

Write-Host "=== Claude Code Turn Notification Uninstaller ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Uninstall scope:"
Write-Host "  [1] Current project only  -> $PWD\.claude"
Write-Host "  [2] Global only           -> $env:USERPROFILE\.claude"
Write-Host "  [3] Both"
Write-Host ""

do {
    $choice = Read-Host "Enter 1, 2, or 3"
} while ($choice -ne '1' -and $choice -ne '2' -and $choice -ne '3')

if ($choice -eq '1' -or $choice -eq '3') {
    Remove-CcNotify -claudeDir "$PWD\.claude"
}

if ($choice -eq '2' -or $choice -eq '3') {
    Remove-CcNotify -claudeDir "$env:USERPROFILE\.claude"

    # Remove registry key (shared across all installs — warn if project-local may still exist)
    if ($choice -eq '2') {
        Write-Host "[WARN] Removing the registry key will break any remaining project-local installs." -ForegroundColor Yellow
    }
    $regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\ClaudeCode.Notify"
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force
        Write-Host "[OK] Removed registry key: $regPath"
    } else {
        Write-Host "[SKIP] Registry key not found: $regPath"
    }
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
