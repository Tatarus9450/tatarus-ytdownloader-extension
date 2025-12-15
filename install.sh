#!/bin/bash

# ============================================================
# Tatarus YT Downloader - One-Time Installer
# Auto-installs Python and FFmpeg if not found
# ============================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Tatarus YT Downloader - Installer                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/server/app.py"

# Detect package manager
get_pkg_manager() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "brew"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

PKG_MANAGER=$(get_pkg_manager)

# Install package function
install_package() {
    local pkg=$1
    echo "📦 Installing $pkg..."
    
    case $PKG_MANAGER in
        brew)
            if ! command -v brew &> /dev/null; then
                echo "📦 Installing Homebrew first..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install $pkg
            ;;
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y $pkg
            ;;
        dnf)
            sudo dnf install -y $pkg
            ;;
        yum)
            sudo yum install -y $pkg
            ;;
        pacman)
            sudo pacman -S --noconfirm $pkg
            ;;
        *)
            echo "❌ Unknown package manager!"
            return 1
            ;;
    esac
}

# ============================================================
# Check and Install Python
# ============================================================
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python3 not found!"
    read -p "   Install Python3 automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ $PKG_MANAGER == "apt" ]]; then
            install_package "python3 python3-pip"
        else
            install_package "python3"
        fi
    else
        echo "❌ Python3 is required. Exiting."
        exit 1
    fi
fi
echo "✅ Python3: $(python3 --version)"

# ============================================================
# Check and Install FFmpeg
# ============================================================
if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️  FFmpeg not found! (Required for MP3 conversion)"
    read -p "   Install FFmpeg automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_package "ffmpeg"
    else
        echo "⚠️  Warning: MP3 conversion won't work without FFmpeg"
    fi
else
    echo "✅ FFmpeg: $(ffmpeg -version 2>&1 | head -1)"
fi

# ============================================================
# Install Python Dependencies
# ============================================================
echo ""
echo "📦 Installing Python dependencies..."
cd "$SCRIPT_DIR/server"
pip3 install -r requirements.txt -q
echo "✅ Dependencies installed"

# ============================================================
# Setup Startup Service
# ============================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "🍎 Setting up macOS LaunchAgent..."
    
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
    echo "🐧 Setting up Linux systemd service..."
    
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
