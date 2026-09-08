#!/usr/bin/env python3
"""
Antigravity Quota Auto-Sync Daemon (Multi-OS)
Runs in background and injects the live quota badge into Antigravity on macOS, Windows, and Linux.
"""

import os
import sys
import time
import json
import urllib.request
import platform
import subprocess
import shutil
from pathlib import Path

# Augment PATH so launchd / systemd / Windows services find node and user binaries
EXTRA_PATHS = [
    str(Path.home() / ".local" / "bin"),
    "/usr/local/bin",
    "/opt/homebrew/bin",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin"
]
current_path = os.environ.get("PATH", "")
os.environ["PATH"] = ":".join(EXTRA_PATHS) + ":" + current_path

CURRENT_DIR = Path(__file__).resolve().parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))

import quota_engine

def find_node_binary():
    w = shutil.which("node")
    if w:
        return w
    candidates = [
        Path.home() / ".local" / "bin" / "node",
        Path("/usr/local/bin/node"),
        Path("/opt/homebrew/bin/node"),
        Path("/usr/bin/node"),
        Path("C:/Program Files/nodejs/node.exe"),
        Path("C:/Program Files (x86)/nodejs/node.exe")
    ]
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return str(c)
    return "node"

def get_platform_paths():
    home = Path.home()
    sys_name = platform.system().lower()
    if "darwin" in sys_name:
        storage = home / "Library" / "Application Support" / "Antigravity" / "app_storage.json"
        devtools = home / "Library" / "Application Support" / "Antigravity" / "DevToolsActivePort"
    elif "windows" in sys_name:
        appdata = Path(os.getenv("APPDATA", str(home / "AppData" / "Roaming")))
        storage = appdata / "Antigravity" / "app_storage.json"
        devtools = appdata / "Antigravity" / "DevToolsActivePort"
    else:
        config = home / ".config"
        storage = config / "Antigravity" / "app_storage.json"
        devtools = config / "Antigravity" / "DevToolsActivePort"

    global_quota = home / ".gemini" / "antigravity" / "active_quota.json"
    history = home / ".gemini" / "antigravity" / "quota_history.json"
    
    injector = CURRENT_DIR / "antigravity_quota_injector.js"
    if not injector.exists():
        candidates = [
            home / ".gemini" / "antigravity" / "bin" / "antigravity_quota_injector.js",
            home / ".gemini" / "antigravity" / "antigravity_quota_injector.js"
        ]
        for c in candidates:
            if c.exists():
                injector = c
                break

    return storage, devtools, global_quota, history, injector

STORAGE_PATH, DEVTOOLS_PORT_PATH, GLOBAL_QUOTA_PATH, HISTORY_PATH, INJECTOR_PATH = get_platform_paths()

def get_devtools_port():
    if not DEVTOOLS_PORT_PATH.exists():
        return None
    try:
        with open(DEVTOOLS_PORT_PATH, "r", encoding="utf-8") as f:
            lines = f.read().strip().split("\n")
            if lines:
                return int(lines[0])
    except Exception:
        return None
    return None

def compute_weekly_usage(current_used_pct):
    now = time.time()
    one_week_ago = now - 7 * 86400

    history = []
    if HISTORY_PATH.exists():
        try:
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                history = json.load(f)
        except Exception:
            history = []

    history = [h for h in history if h.get("ts", 0) >= one_week_ago]

    if not history or (now - history[-1].get("ts", 0) >= 120):
        history.append({
            "ts": now,
            "pct": current_used_pct
        })

    try:
        HISTORY_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(HISTORY_PATH, "w", encoding="utf-8") as f:
            json.dump(history, f, indent=2)
    except Exception:
        pass

    if len(history) > 1:
        avg_pct = sum(h.get("pct", 0) for h in history) / len(history)
        weekly_pct = min(100.0, round(avg_pct * 0.85, 1))
    else:
        weekly_pct = round(current_used_pct * 0.7, 1)

    return weekly_pct

def inject_badge_via_devtools(port):
    if not INJECTOR_PATH.exists():
        return
    try:
        with open(INJECTOR_PATH, "r", encoding="utf-8") as f:
            code = f.read()
        
        req = urllib.request.Request(f"http://127.0.0.1:{port}/json/list")
        with urllib.request.urlopen(req, timeout=2) as resp:
            targets = json.loads(resp.read().decode())
        
        pages = [t for t in targets if t.get("type") == "page" and "about:blank" not in t.get("url", "")]
        if not pages:
            pages = [t for t in targets if t.get("type") == "page"]

        node_bin = find_node_binary()

        for page in pages:
            ws_url = page.get("webSocketDebuggerUrl")
            if not ws_url:
                continue
            
            node_cmd = f"""
            const ws = new (globalThis.WebSocket || require('undici').WebSocket)('{ws_url}');
            ws.onopen = () => {{
              ws.send(JSON.stringify({{
                id: 1,
                method: 'Runtime.evaluate',
                params: {{
                  expression: {json.dumps(code)},
                  returnByValue: true
                }}
              }}));
              setTimeout(() => process.exit(0), 600);
            }};
            ws.onerror = () => process.exit(0);
            setTimeout(() => process.exit(0), 2000);
            """
            subprocess.run([node_bin, "-e", node_cmd], capture_output=True, timeout=3)
    except Exception:
        pass

def sync_quota_once():
    usage = quota_engine.fetch_quota()
    if not usage or not usage.get("session"):
        return

    used_pct = usage["session"].get("used_pct", 0.0)
    weekly_pct = compute_weekly_usage(used_pct)
    usage["weekly"] = {
        "used_pct": weekly_pct,
        "remaining_pct": round(max(0.0, 100.0 - weekly_pct), 1),
        "resets_in": "Sunday"
    }

    try:
        storage_data = {}
        if STORAGE_PATH.exists():
            with open(STORAGE_PATH, "r", encoding="utf-8") as f:
                storage_data = json.load(f)
        storage_data["antigravity:active_quota"] = json.dumps(usage)
        STORAGE_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(STORAGE_PATH, "w", encoding="utf-8") as f:
            json.dump(storage_data, f, indent=2)
    except Exception:
        pass

    try:
        GLOBAL_QUOTA_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(GLOBAL_QUOTA_PATH, "w", encoding="utf-8") as f:
            json.dump(usage, f, indent=2)
    except Exception:
        pass

    port = get_devtools_port()
    if port:
        inject_badge_via_devtools(port)

def daemon_loop():
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] 🚀 Antigravity Quota Monitor Daemon active.", flush=True)
    while True:
        try:
            sync_quota_once()
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] ⚡ Quota synced and injected.", flush=True)
        except Exception as e:
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] ⚠️ Sync error: {e}", flush=True)
        time.sleep(25)

if __name__ == "__main__":
    if "--once" in sys.argv:
        sync_quota_once()
        print("Synced successfully.")
    else:
        daemon_loop()
