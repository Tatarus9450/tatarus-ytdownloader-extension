#!/bin/bash

# ============================================================
# Tatarus YT Downloader - One-Time Installer
# Installs server as a startup service (runs once)
# ============================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Tatarus YT Downloader - Installer                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Get script directory (where project is located)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/server/app.py"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found!"
    echo "   Install: brew install python3 (Mac) or apt install python3 (Linux)"
    exit 1
fi

echo "✅ Python3 found: $(python3 --version)"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
cd "$SCRIPT_DIR/server"
pip3 install -r requirements.txt -q
echo "✅ Dependencies installed"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - Use launchd
    echo ""
    echo "🍎 macOS detected - Installing LaunchAgent..."
    
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/com.tatarus.ytdownloader.plist"
    
    mkdir -p "$PLIST_DIR"
    
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tatarus.ytdownloader</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which python3)</string>
        <string>$SERVER_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/tatarus-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/tatarus-server.log</string>
</dict>
</plist>
EOF
    
    # Load the service
    launchctl unload "$PLIST_FILE" 2>/dev/null
    launchctl load "$PLIST_FILE"
    
    echo "✅ LaunchAgent installed: $PLIST_FILE"
    echo "✅ Server will start automatically on login"
    
else
    # Linux - Use systemd user service
    echo ""
    echo "🐧 Linux detected - Installing systemd user service..."
    
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/tatarus-server.service"
    
    mkdir -p "$SERVICE_DIR"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Tatarus YT Downloader Server
After=network.target

[Service]
Type=simple
ExecStart=$(which python3) $SERVER_SCRIPT
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF
    
    # Reload and enable the service
    systemctl --user daemon-reload
    systemctl --user enable tatarus-server.service
    systemctl --user start tatarus-server.service
    
    echo "✅ Systemd service installed: $SERVICE_FILE"
    echo "✅ Server will start automatically on login"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     ✅ Installation Complete!                             ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  • Server starts automatically with your computer         ║"
echo "║  • Server starts in SLEEP mode (low resources)            ║"
echo "║  • Extension wakes it up when needed                      ║"
echo "║  • Auto-sleeps after 10 min of inactivity                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📝 To uninstall:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   launchctl unload ~/Library/LaunchAgents/com.tatarus.ytdownloader.plist"
    echo "   rm ~/Library/LaunchAgents/com.tatarus.ytdownloader.plist"
else
    echo "   systemctl --user disable tatarus-server.service"
    echo "   rm ~/.config/systemd/user/tatarus-server.service"
fi
echo ""
