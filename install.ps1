# Antigravity Quota Monitor Installer for Windows (PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "Installing Antigravity Quota Monitor on Windows..." -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetApp = Join-Path $env:USERPROFILE ".gemini\antigravity"
$TargetBin = Join-Path $TargetApp "bin"

New-Item -ItemType Directory -Force -Path $TargetApp | Out-Null
New-Item -ItemType Directory -Force -Path $TargetBin | Out-Null

Copy-Item "$ScriptDir\antigravity_quota_injector.js" "$TargetApp\antigravity_quota_injector.js" -Force
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
