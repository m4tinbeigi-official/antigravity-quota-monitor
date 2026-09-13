# Antigravity Quota Monitor Uninstaller for Windows (PowerShell)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "Uninstalling Antigravity Quota Monitor..." -ForegroundColor Yellow

$TargetApp = Join-Path $env:USERPROFILE ".gemini\antigravity"
$TargetBin = Join-Path $TargetApp "bin"

# 1. Terminate running sync daemon processes
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "sync_daemon\.py" } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
}

# 2. Remove Startup shortcut
$StartupFolder = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupFolder "AntigravityQuotaMonitor.lnk"
if (Test-Path $ShortcutPath) {
    Remove-Item $ShortcutPath -Force
    Write-Host "Removed Startup shortcut." -ForegroundColor Green
}

# 3. Remove installed files and caches
$filesToRemove = @(
    (Join-Path $TargetApp "antigravity_quota_injector.js"),
    (Join-Path $TargetBin "antigravity_quota_injector.js"),
    (Join-Path $TargetBin "quota_engine.py"),
    (Join-Path $TargetBin "sync_daemon.py"),
    (Join-Path $TargetApp "active_quota.json"),
    (Join-Path $TargetApp "quota_history.json")
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item $file -Force
    }
}

# Remove bin folder if empty
if ((Test-Path $TargetBin) -and ((Get-ChildItem $TargetBin | Measure-Object).Count -eq 0)) {
    Remove-Item $TargetBin -Force
}

# Clean cached quota from Antigravity app_storage.json
$appStorage = Join-Path $env:APPDATA "Antigravity\app_storage.json"
if (Test-Path $appStorage) {
    try {
        $content = Get-Content $appStorage -Raw | ConvertFrom-Json
        if ($content.PSObject.Properties['antigravity:active_quota']) {
            $content.PSObject.Properties.Remove('antigravity:active_quota')
            $content | ConvertTo-Json -Depth 10 | Set-Content $appStorage -Encoding UTF8
        }
    } catch {}
}

Write-Host "Antigravity Quota Monitor has been completely uninstalled!" -ForegroundColor Green
