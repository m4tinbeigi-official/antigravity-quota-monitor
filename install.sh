#!/usr/bin/env bash
set -e

echo "✨ Installing Antigravity Quota Monitor..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="$HOME/.gemini/antigravity/bin"
TARGET_APP="$HOME/.gemini/antigravity"

mkdir -p "$TARGET_BIN"
mkdir -p "$TARGET_APP"

cp "$SCRIPT_DIR/antigravity_quota_injector.js" "$TARGET_APP/antigravity_quota_injector.js"
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
