#!/bin/bash

# ============================================================
# Tatarus YT Downloader - One-Time Installer
# Auto-installs Python and FFmpeg if not found
# FFmpeg stored in script folder (not temp)
# Server runs as background service (no visible console)
# ============================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Tatarus YT Downloader - Installer                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/server/app.py"
FFMPEG_DIR="$SCRIPT_DIR/ffmpeg"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

OS_TYPE=$(detect_os)

# Detect package manager
get_pkg_manager() {
    if [[ "$OS_TYPE" == "macos" ]]; then
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
# Check and Install FFmpeg (prefer script folder)
# ============================================================
echo ""
echo "🎬 Checking FFmpeg..."

# Check local folder first
if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
    export PATH="$FFMPEG_DIR:$PATH"
    echo "✅ FFmpeg found (local): $FFMPEG_DIR"
elif command -v ffmpeg &> /dev/null; then
    echo "✅ FFmpeg found (system): $(which ffmpeg)"
else
    echo "⚠️  FFmpeg not found!"
    read -p "   Install FFmpeg? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$FFMPEG_DIR"
        
        if [[ "$OS_TYPE" == "macos" ]]; then
            # macOS - download static build to script folder
            echo "📥 Downloading FFmpeg to script folder..."
            FFMPEG_URL="https://evermeet.cx/ffmpeg/getrelease/zip"
            curl -L "$FFMPEG_URL" -o "$SCRIPT_DIR/ffmpeg.zip"
            unzip -o "$SCRIPT_DIR/ffmpeg.zip" -d "$FFMPEG_DIR"
            rm "$SCRIPT_DIR/ffmpeg.zip"
            chmod +x "$FFMPEG_DIR/ffmpeg"
            export PATH="$FFMPEG_DIR:$PATH"
            echo "✅ FFmpeg installed to: $FFMPEG_DIR"
        else
            # Linux - use package manager (cleaner)
            install_package "ffmpeg"
        fi
    else
        echo "⚠️  Warning: MP3 conversion won't work without FFmpeg"
    fi
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
# Setup Startup Service (runs in background, no console)
# ============================================================
if [[ "$OS_TYPE" == "macos" ]]; then
    echo ""
    echo "🍎 Setting up macOS LaunchAgent (background service)..."
    
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/com.tatarus.ytdownloader.plist"
    
    mkdir -p "$PLIST_DIR"
    
    # Add FFMPEG_DIR to PATH in plist if local ffmpeg exists
    FFMPEG_PATH_ENV=""
    if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
        FFMPEG_PATH_ENV="$FFMPEG_DIR:"
    fi
    
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
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${FFMPEG_PATH_ENV}/usr/local/bin:/usr/bin:/bin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/tatarus-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/tatarus-server.log</string>
</dict>
</plist>
EOF
    
    launchctl unload "$PLIST_FILE" 2>/dev/null
    launchctl load "$PLIST_FILE"
    
    echo "✅ LaunchAgent installed (runs in background)"
    
else
    echo ""
    echo "🐧 Setting up Linux systemd service (background)..."
    
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/tatarus-server.service"
    
    mkdir -p "$SERVICE_DIR"
    
    # Add FFMPEG_DIR to PATH if local ffmpeg exists
    EXTRA_PATH=""
    if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
        EXTRA_PATH="Environment=PATH=$FFMPEG_DIR:\$PATH"
    fi
    
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
$EXTRA_PATH

[Install]
WantedBy=default.target
EOF
    
    systemctl --user daemon-reload
    systemctl --user enable tatarus-server.service
    systemctl --user start tatarus-server.service
    
    echo "✅ Systemd service installed (runs in background)"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     ✅ Installation Complete!                             ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  • Server runs as BACKGROUND SERVICE (no console)         ║"
echo "║  • Server starts automatically with your computer         ║"
echo "║  • Server starts in SLEEP mode (low resources)            ║"
echo "║  • Extension wakes it up when needed                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
