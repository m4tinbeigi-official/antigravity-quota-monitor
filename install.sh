#!/usr/bin/env bash
set -e

# Support uninstall option
if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/uninstall.sh" ]; then
        exec "$SCRIPT_DIR/uninstall.sh"
    fi

    echo "🗑️  Uninstalling Antigravity Quota Monitor..."
    TARGET_BIN="$HOME/.gemini/antigravity/bin"
    TARGET_APP="$HOME/.gemini/antigravity"

    OS="$(uname -s)"
    if [ "$OS" = "Darwin" ]; then
        PLIST_PATH="$HOME/Library/LaunchAgents/com.antigravity.quotasync.plist"
        if [ -f "$PLIST_PATH" ]; then
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            rm -f "$PLIST_PATH"
        fi
    elif [ "$OS" = "Linux" ]; then
        SERVICE_PATH="$HOME/.config/systemd/user/antigravity-quota.service"
        if [ -f "$SERVICE_PATH" ]; then
            systemctl --user stop antigravity-quota.service 2>/dev/null || true
            systemctl --user disable antigravity-quota.service 2>/dev/null || true
            rm -f "$SERVICE_PATH"
            systemctl --user daemon-reload 2>/dev/null || true
        fi
    fi

    pkill -f "sync_daemon.py" 2>/dev/null || true

    rm -f "$TARGET_APP/antigravity_quota_injector.js"
    rm -f "$TARGET_BIN/antigravity_quota_injector.js"
    rm -f "$TARGET_BIN/quota_engine.py"
    rm -f "$TARGET_BIN/sync_daemon.py"
    rm -f "$TARGET_APP/active_quota.json"
    rm -f "$TARGET_APP/quota_history.json"
    rm -f /tmp/agy_quota_sync.log /tmp/agy_quota_sync.err

    if [ -d "$TARGET_BIN" ] && [ -z "$(ls -A "$TARGET_BIN" 2>/dev/null)" ]; then
        rmdir "$TARGET_BIN" 2>/dev/null || true
    fi

    python3 -c '
import json, platform
from pathlib import Path
home = Path.home()
sys_name = platform.system().lower()
storage = home / ("Library/Application Support" if "darwin" in sys_name else ".config") / "Antigravity/app_storage.json"
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
    exit 0
fi

echo "✨ Installing Antigravity Quota Monitor..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="$HOME/.gemini/antigravity/bin"
TARGET_APP="$HOME/.gemini/antigravity"

mkdir -p "$TARGET_BIN"
mkdir -p "$TARGET_APP"

cp "$SCRIPT_DIR/antigravity_quota_injector.js" "$TARGET_APP/antigravity_quota_injector.js"
cp "$SCRIPT_DIR/antigravity_quota_injector.js" "$TARGET_BIN/antigravity_quota_injector.js"
cp "$SCRIPT_DIR/quota_engine.py" "$TARGET_BIN/quota_engine.py"
cp "$SCRIPT_DIR/sync_daemon.py" "$TARGET_BIN/sync_daemon.py"
chmod +x "$TARGET_BIN/quota_engine.py" "$TARGET_BIN/sync_daemon.py"

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    PLIST_PATH="$HOME/Library/LaunchAgents/com.antigravity.quotasync.plist"
    cat << PLIST_EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.antigravity.quotasync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$TARGET_BIN/sync_daemon.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/agy_quota_sync.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/agy_quota_sync.err</string>
</dict>
</plist>
PLIST_EOF
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
    echo "✅ macOS Background LaunchAgent successfully registered and started!"
elif [ "$OS" = "Linux" ]; then
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"
    cat << SERVICE_EOF > "$SYSTEMD_DIR/antigravity-quota.service"
[Unit]
Description=Antigravity Quota Monitor
After=network.target

[Service]
ExecStart=/usr/bin/python3 $TARGET_BIN/sync_daemon.py
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
SERVICE_EOF
    systemctl --user daemon-reload
    systemctl --user enable --now antigravity-quota.service
    echo "✅ Linux systemd user service registered and started!"
fi

python3 "$TARGET_BIN/sync_daemon.py" --once
echo "🎉 Installation complete! Open Antigravity and check the model selector bar."
