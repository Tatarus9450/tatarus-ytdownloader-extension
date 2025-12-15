#!/bin/bash

# ============================================================
# Tatarus YT Downloader - One-Time Installer
# Auto-installs Python if not found
# ============================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Tatarus YT Downloader - Installer                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/server/app.py"

# Function to install Python
install_python() {
    echo "📦 Installing Python3..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - Use Homebrew
        if ! command -v brew &> /dev/null; then
            echo "📦 Installing Homebrew first..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install python3
    else
        # Linux - Detect package manager
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3 python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3 python3-pip
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm python python-pip
        else
            echo "❌ Could not detect package manager!"
            echo "   Please install Python3 manually: https://python.org"
            exit 1
        fi
    fi
    
    echo "✅ Python3 installed successfully!"
}

# Check Python - auto-install if not found
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python3 not found!"
    read -p "   Install Python3 automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_python
    else
        echo "❌ Python3 is required. Exiting."
        exit 1
    fi
fi

echo "✅ Python3 found: $(python3 --version)"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
cd "$SCRIPT_DIR/server"
pip3 install -r requirements.txt -q
echo "✅ Dependencies installed"

# Detect OS and install service
if [[ "$OSTYPE" == "darwin"* ]]; then
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
    
    launchctl unload "$PLIST_FILE" 2>/dev/null
    launchctl load "$PLIST_FILE"
    
    echo "✅ LaunchAgent installed"
    
else
    echo ""
    echo "🐧 Linux detected - Installing systemd service..."
    
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
    
    systemctl --user daemon-reload
    systemctl --user enable tatarus-server.service
    systemctl --user start tatarus-server.service
    
    echo "✅ Systemd service installed"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     ✅ Installation Complete!                             ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  • Server starts automatically with your computer         ║"
echo "║  • Server starts in SLEEP mode (low resources)            ║"
echo "║  • Extension wakes it up when needed                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
