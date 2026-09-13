param(
    [switch]$Uninstall
)

# Antigravity Quota Monitor Installer / Uninstaller for Windows (PowerShell)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetApp = Join-Path $env:USERPROFILE ".gemini\antigravity"
$TargetBin = Join-Path $TargetApp "bin"

if ($Uninstall) {
    if (Test-Path (Join-Path $ScriptDir "uninstall.ps1")) {
        & (Join-Path $ScriptDir "uninstall.ps1")
        exit
    }

    Write-Host "Uninstalling Antigravity Quota Monitor..." -ForegroundColor Yellow
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "sync_daemon\.py" } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
    }

    $StartupFolder = [Environment]::GetFolderPath("Startup")
    $ShortcutPath = Join-Path $StartupFolder "AntigravityQuotaMonitor.lnk"
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
    }

    $filesToRemove = @(
        (Join-Path $TargetApp "antigravity_quota_injector.js"),
        (Join-Path $TargetBin "antigravity_quota_injector.js"),
        (Join-Path $TargetBin "quota_engine.py"),
        (Join-Path $TargetBin "sync_daemon.py"),
        (Join-Path $TargetApp "active_quota.json"),
        (Join-Path $TargetApp "quota_history.json")
    )
    foreach ($file in $filesToRemove) {
        if (Test-Path $file) { Remove-Item $file -Force }
    }
    if ((Test-Path $TargetBin) -and ((Get-ChildItem $TargetBin | Measure-Object).Count -eq 0)) {
        Remove-Item $TargetBin -Force
    }

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
    exit
}

Write-Host "Installing Antigravity Quota Monitor on Windows..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $TargetApp | Out-Null
New-Item -ItemType Directory -Force -Path $TargetBin | Out-Null

Copy-Item "$ScriptDir\antigravity_quota_injector.js" "$TargetApp\antigravity_quota_injector.js" -Force
Copy-Item "$ScriptDir\antigravity_quota_injector.js" "$TargetBin\antigravity_quota_injector.js" -Force
Copy-Item "$ScriptDir\quota_engine.py" "$TargetBin\quota_engine.py" -Force
Copy-Item "$ScriptDir\sync_daemon.py" "$TargetBin\sync_daemon.py" -Force

# Create Windows Scheduled Task or Startup Shortcut
$WshShell = New-Object -ComObject WScript.Shell
$StartupFolder = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupFolder "AntigravityQuotaMonitor.lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "pythonw.exe"
$Shortcut.Arguments = "`"$TargetBin\sync_daemon.py`""
$Shortcut.WindowStyle = 7 # Minimized / Hidden
$Shortcut.Save()

Write-Host "Registered in Windows Startup folder." -ForegroundColor Green

# Run once
Start-Process python -ArgumentList "`"$TargetBin\sync_daemon.py`" --once" -NoNewWindow -Wait
Write-Host "Installation completed successfully! Check Antigravity model bar." -ForegroundColor Green
