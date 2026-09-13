#!/usr/bin/env bash
set -e

echo "🗑️  Uninstalling Antigravity Quota Monitor..."

TARGET_BIN="$HOME/.gemini/antigravity/bin"
TARGET_APP="$HOME/.gemini/antigravity"

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    PLIST_PATH="$HOME/Library/LaunchAgents/com.antigravity.quotasync.plist"
    if [ -f "$PLIST_PATH" ]; then
        echo "🛑 Unloading macOS LaunchAgent..."
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        echo "✅ Removed LaunchAgent plist."
    fi
elif [ "$OS" = "Linux" ]; then
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    SERVICE_PATH="$SYSTEMD_DIR/antigravity-quota.service"
    if [ -f "$SERVICE_PATH" ]; then
        echo "🛑 Stopping and disabling systemd user service..."
        systemctl --user stop antigravity-quota.service 2>/dev/null || true
        systemctl --user disable antigravity-quota.service 2>/dev/null || true
        rm -f "$SERVICE_PATH"
        systemctl --user daemon-reload 2>/dev/null || true
        echo "✅ Removed systemd service."
    fi
fi

# Terminate any running daemon instances
pkill -f "sync_daemon.py" 2>/dev/null || true

# Remove installed scripts and binaries
echo "🧹 Removing installed files..."
rm -f "$TARGET_APP/antigravity_quota_injector.js"
rm -f "$TARGET_BIN/antigravity_quota_injector.js"
rm -f "$TARGET_BIN/quota_engine.py"
rm -f "$TARGET_BIN/sync_daemon.py"
rm -f "$TARGET_APP/active_quota.json"
rm -f "$TARGET_APP/quota_history.json"
rm -f /tmp/agy_quota_sync.log /tmp/agy_quota_sync.err

# Remove bin directory if empty
if [ -d "$TARGET_BIN" ] && [ -z "$(ls -A "$TARGET_BIN" 2>/dev/null)" ]; then
    rmdir "$TARGET_BIN" 2>/dev/null || true
fi

# Clean cached quota from Antigravity app_storage.json
python3 -c '
import json, platform
from pathlib import Path

home = Path.home()
sys_name = platform.system().lower()
if "darwin" in sys_name:
    storage = home / "Library" / "Application Support" / "Antigravity" / "app_storage.json"
elif "windows" in sys_name:
    import os
    storage = Path(os.getenv("APPDATA", str(home / "AppData" / "Roaming"))) / "Antigravity" / "app_storage.json"
else:
    storage = home / ".config" / "Antigravity" / "app_storage.json"

if storage.exists():
    try:
        with open(storage, "r", encoding="utf-8") as f:
            data = json.load(f)
        if "antigravity:active_quota" in data:
            del data["antigravity:active_quota"]
            with open(storage, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
    except Exception:
        pass
' 2>/dev/null || true

echo "🎉 Antigravity Quota Monitor has been completely uninstalled!"
