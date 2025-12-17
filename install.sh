#!/bin/bash

# ============================================================
# Tatarus YT Downloader - Installer v2.0
# Supports: macOS and Linux (apt, dnf, yum, pacman)
# Features: Menu UI, Logging, Uninstall, Status Check
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"
SERVER_SCRIPT="$SERVER_DIR/app.py"
FFMPEG_DIR="$SCRIPT_DIR/ffmpeg"
LOG_FILE="$SCRIPT_DIR/install.log"

# Service names
MACOS_PLIST="com.tatarus.ytdownloader"
LINUX_SERVICE="tatarus-server"

# ============================================================
# Utility Functions
# ============================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       Tatarus YT Downloader - Installer v2.0            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_ok() {
    echo -e "       ${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "       ${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "       ${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "       ${BLUE}[INFO]${NC} $1"
}

# ============================================================
# OS Detection
# ============================================================
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

# ============================================================
# Package Manager Detection
# ============================================================
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
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

PKG_MANAGER=$(get_pkg_manager)

# ============================================================
# Check Internet Connection
# ============================================================
check_internet() {
    echo ""
    echo -e "${BLUE}[0/6]${NC} Checking internet connection..."
    
    if ping -c 1 google.com &> /dev/null || ping -c 1 github.com &> /dev/null; then
        print_ok "Internet connection available"
        log "Internet connection OK"
        HAS_INTERNET=1
    else
        print_warn "No internet connection detected!"
        log "WARNING: No internet connection"
        HAS_INTERNET=0
    fi
}

# ============================================================
# Install Package
# ============================================================
install_package() {
    local pkg=$1
    echo -e "       📦 Installing ${CYAN}$pkg${NC}..."
    log "Installing package: $pkg"
    
    case $PKG_MANAGER in
        brew)
            if ! command -v brew &> /dev/null; then
                echo -e "       📦 Installing Homebrew first..."
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
        apk)
            sudo apk add $pkg
            ;;
        zypper)
            sudo zypper install -y $pkg
            ;;
        *)
            print_error "Unknown package manager!"
            return 1
            ;;
    esac
    
    log "Package installed: $pkg"
}

# ============================================================
# Check Python
# ============================================================
check_python() {
    echo ""
    echo -e "${BLUE}[1/6]${NC} Checking Python..."
    
    if command -v python3 &> /dev/null; then
        PY_VER=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_ok "Python $PY_VER found"
        log "Python found: $PY_VER"
        return 0
    fi
    
    print_warn "Python3 not found!"
    
    if [[ $HAS_INTERNET -eq 0 ]]; then
        print_error "Cannot install Python without internet!"
        return 1
    fi
    
    read -p "       Install Python3 automatically? [Y/n]: " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if [[ $PKG_MANAGER == "apt" ]]; then
            install_package "python3 python3-pip python3-venv"
        else
            install_package "python3"
        fi
        print_ok "Python installed"
        log "Python installed"
    else
        print_error "Python3 is required!"
        return 1
    fi
}

# ============================================================
# Check pip
# ============================================================
check_pip() {
    echo ""
    echo -e "${BLUE}[2/6]${NC} Checking pip..."
    
    if python3 -m pip --version &> /dev/null; then
        print_ok "pip is available"
        log "pip found"
        return 0
    fi
    
    print_warn "pip not found, attempting to install..."
    
    # Try ensurepip first
    if python3 -m ensurepip --upgrade &> /dev/null; then
        print_ok "pip installed via ensurepip"
        log "pip installed via ensurepip"
        return 0
    fi
    
    # Try package manager
    case $PKG_MANAGER in
        apt)
            install_package "python3-pip"
            ;;
        dnf|yum)
            install_package "python3-pip"
            ;;
        pacman)
            install_package "python-pip"
            ;;
        brew)
            # pip comes with python3 on macOS
            ;;
    esac
    
    if python3 -m pip --version &> /dev/null; then
        print_ok "pip installed"
        log "pip installed"
        return 0
    else
        print_error "Failed to install pip!"
        return 1
    fi
}

# ============================================================
# Check/Install FFmpeg
# ============================================================
check_ffmpeg() {
    echo ""
    echo -e "${BLUE}[3/6]${NC} Checking FFmpeg..."
    
    # Check local folder first
    if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
        export PATH="$FFMPEG_DIR:$PATH"
        print_ok "FFmpeg found (local)"
        log "FFmpeg found locally"
        return 0
    fi
    
    # Check system FFmpeg
    if command -v ffmpeg &> /dev/null; then
        print_ok "FFmpeg found (system): $(which ffmpeg)"
        log "FFmpeg found in system"
        return 0
    fi
    
    print_warn "FFmpeg not found!"
    
    if [[ $HAS_INTERNET -eq 0 ]]; then
        print_warn "Cannot install FFmpeg without internet!"
        print_warn "Audio/video conversion may not work!"
        log "WARNING: FFmpeg not installed - no internet"
        return 0
    fi
    
    read -p "       Install FFmpeg? [Y/n]: " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warn "MP3 conversion won't work without FFmpeg"
        return 0
    fi
    
    mkdir -p "$FFMPEG_DIR"
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        # macOS - download static build
        echo -e "       📥 Downloading FFmpeg..."
        log "Downloading FFmpeg for macOS..."
        
        FFMPEG_URL="https://evermeet.cx/ffmpeg/getrelease/zip"
        curl -L "$FFMPEG_URL" -o "$SCRIPT_DIR/ffmpeg.zip" --progress-bar
        
        if [[ -f "$SCRIPT_DIR/ffmpeg.zip" ]]; then
            unzip -o "$SCRIPT_DIR/ffmpeg.zip" -d "$FFMPEG_DIR"
            rm "$SCRIPT_DIR/ffmpeg.zip"
            chmod +x "$FFMPEG_DIR/ffmpeg" 2>/dev/null || true
            export PATH="$FFMPEG_DIR:$PATH"
            print_ok "FFmpeg installed to: $FFMPEG_DIR"
            log "FFmpeg installed locally"
        else
            print_error "Failed to download FFmpeg!"
            return 1
        fi
    else
        # Linux - use package manager
        install_package "ffmpeg"
        print_ok "FFmpeg installed via $PKG_MANAGER"
    fi
}

# ============================================================
# Install Python Dependencies
# ============================================================
install_dependencies() {
    echo ""
    echo -e "${BLUE}[4/6]${NC} Installing Python dependencies..."
    
    if [[ ! -f "$SERVER_DIR/requirements.txt" ]]; then
        print_warn "requirements.txt not found!"
        log "WARNING: requirements.txt not found"
        return 0
    fi
    
    cd "$SERVER_DIR"
    python3 -m pip install -r requirements.txt -q --disable-pip-version-check 2>/dev/null || \
    python3 -m pip install -r requirements.txt -q
    
    if [[ $? -eq 0 ]]; then
        print_ok "Dependencies installed"
        log "Dependencies installed"
    else
        print_error "Failed to install dependencies!"
        log "ERROR: pip install failed"
        return 1
    fi
}

# ============================================================
# Setup Service (macOS)
# ============================================================
setup_macos_service() {
    echo ""
    echo -e "${BLUE}[5/6]${NC} Setting up macOS LaunchAgent..."
    
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/$MACOS_PLIST.plist"
    
    mkdir -p "$PLIST_DIR"
    
    # Build PATH with local FFmpeg if exists
    FFMPEG_PATH_ENV=""
    if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
        FFMPEG_PATH_ENV="$FFMPEG_DIR:"
    fi
    
    cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$MACOS_PLIST</string>
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
        <string>${FFMPEG_PATH_ENV}/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/tatarus-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/tatarus-server.log</string>
</dict>
</plist>
EOF
    
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"
    
    print_ok "LaunchAgent installed (runs in background)"
    log "macOS LaunchAgent installed"
}

# ============================================================
# Setup Service (Linux)
# ============================================================
setup_linux_service() {
    echo ""
    echo -e "${BLUE}[5/6]${NC} Setting up Linux systemd service..."
    
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/$LINUX_SERVICE.service"
    
    mkdir -p "$SERVICE_DIR"
    
    # Build Environment line with FFmpeg if exists
    EXTRA_PATH=""
    if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
        EXTRA_PATH="Environment=PATH=$FFMPEG_DIR:\$PATH"
    fi
    
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Tatarus YT Downloader Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$SERVER_DIR
ExecStart=$(which python3) $SERVER_SCRIPT
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1
$EXTRA_PATH

[Install]
WantedBy=default.target
EOF
    
    systemctl --user daemon-reload
    systemctl --user enable "$LINUX_SERVICE.service" 2>/dev/null || true
    systemctl --user start "$LINUX_SERVICE.service" 2>/dev/null || true
    
    print_ok "Systemd service installed (runs in background)"
    log "Linux systemd service installed"
}

# ============================================================
# Start Server
# ============================================================
start_server() {
    echo ""
    echo -e "${BLUE}[6/6]${NC} Starting server..."
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        PLIST_FILE="$HOME/Library/LaunchAgents/$MACOS_PLIST.plist"
        if [[ -f "$PLIST_FILE" ]]; then
            launchctl start "$MACOS_PLIST" 2>/dev/null || true
            print_ok "Server started (LaunchAgent)"
        else
            # Fallback: start directly
            nohup python3 "$SERVER_SCRIPT" > /tmp/tatarus-server.log 2>&1 &
            print_ok "Server started (background process)"
        fi
    else
        if systemctl --user is-enabled "$LINUX_SERVICE.service" &>/dev/null; then
            systemctl --user restart "$LINUX_SERVICE.service" 2>/dev/null || true
            print_ok "Server started (systemd)"
        else
            # Fallback: start directly
            nohup python3 "$SERVER_SCRIPT" > /tmp/tatarus-server.log 2>&1 &
            print_ok "Server started (background process)"
        fi
    fi
    
    log "Server started"
}

# ============================================================
# Stop Server
# ============================================================
stop_server() {
    print_header
    echo -e "  ${YELLOW}Stopping server...${NC}"
    echo ""
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        launchctl stop "$MACOS_PLIST" 2>/dev/null || true
    else
        systemctl --user stop "$LINUX_SERVICE.service" 2>/dev/null || true
    fi
    
    # Also kill any orphan processes
    pkill -f "python3.*app.py" 2>/dev/null || true
    pkill -f "python.*app.py" 2>/dev/null || true
    
    print_ok "Server stopped"
    log "Server stopped"
    echo ""
    read -p "  Press Enter to continue..."
}

# ============================================================
# Check Status
# ============================================================
check_status() {
    print_header
    echo -e "  ${CYAN}============================================================${NC}"
    echo -e "  ${CYAN}      System Status${NC}"
    echo -e "  ${CYAN}============================================================${NC}"
    echo ""
    
    # OS
    echo -e "  ${BLUE}OS:${NC}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo -e "     [OK] macOS ($(sw_vers -productVersion 2>/dev/null || echo 'unknown'))"
    else
        echo -e "     [OK] Linux ($PKG_MANAGER)"
    fi
    
    # Python
    echo ""
    echo -e "  ${BLUE}Python:${NC}"
    if command -v python3 &> /dev/null; then
        echo -e "     ${GREEN}[OK]${NC} $(python3 --version)"
    else
        echo -e "     ${RED}[X]${NC} Not installed"
    fi
    
    # pip
    echo ""
    echo -e "  ${BLUE}pip:${NC}"
    if python3 -m pip --version &> /dev/null; then
        echo -e "     ${GREEN}[OK]${NC} Available"
    else
        echo -e "     ${RED}[X]${NC} Not available"
    fi
    
    # FFmpeg
    echo ""
    echo -e "  ${BLUE}FFmpeg:${NC}"
    if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
        echo -e "     ${GREEN}[OK]${NC} Installed locally"
    elif command -v ffmpeg &> /dev/null; then
        echo -e "     ${GREEN}[OK]${NC} Available in system"
    else
        echo -e "     ${RED}[X]${NC} Not installed"
    fi
    
    # Server
    echo ""
    echo -e "  ${BLUE}Server:${NC}"
    if pgrep -f "python3.*app.py" &> /dev/null || pgrep -f "python.*app.py" &> /dev/null; then
        echo -e "     ${GREEN}[OK]${NC} Running"
    else
        echo -e "     ${YELLOW}[ ]${NC} Not running"
    fi
    
    # Auto-start
    echo ""
    echo -e "  ${BLUE}Auto-start:${NC}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        if [[ -f "$HOME/Library/LaunchAgents/$MACOS_PLIST.plist" ]]; then
            echo -e "     ${GREEN}[OK]${NC} LaunchAgent enabled"
        else
            echo -e "     ${YELLOW}[ ]${NC} Not configured"
        fi
    else
        if systemctl --user is-enabled "$LINUX_SERVICE.service" &>/dev/null; then
            echo -e "     ${GREEN}[OK]${NC} Systemd service enabled"
        else
            echo -e "     ${YELLOW}[ ]${NC} Not configured"
        fi
    fi
    
    # Dependencies
    echo ""
    echo -e "  ${BLUE}Dependencies:${NC}"
    if [[ -f "$SERVER_DIR/requirements.txt" ]]; then
        echo -e "     ${GREEN}[OK]${NC} requirements.txt found"
    else
        echo -e "     ${RED}[X]${NC} requirements.txt missing"
    fi
    
    echo ""
    echo -e "  ${CYAN}============================================================${NC}"
    echo ""
    read -p "  Press Enter to continue..."
}

# ============================================================
# View Log
# ============================================================
view_log() {
    print_header
    echo -e "  ${CYAN}============================================================${NC}"
    echo -e "  ${CYAN}      Installation Log${NC}"
    echo -e "  ${CYAN}============================================================${NC}"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        cat "$LOG_FILE"
    else
        echo "  No log file found."
    fi
    
    echo ""
    echo -e "  ${CYAN}============================================================${NC}"
    echo ""
    read -p "  Press Enter to continue..."
}

# ============================================================
# Uninstall
# ============================================================
uninstall() {
    print_header
    echo -e "  ${RED}============================================================${NC}"
    echo -e "  ${RED}      Uninstall Tatarus YT Downloader${NC}"
    echo -e "  ${RED}============================================================${NC}"
    echo ""
    echo "  This will:"
    echo "    - Stop the server"
    echo "    - Remove startup service"
    echo "    - Remove FFmpeg folder (if local)"
    echo "    - Remove log file"
    echo ""
    echo -e "  ${YELLOW}[!] This will NOT remove: Python, pip, or extension files${NC}"
    echo ""
    
    read -p "  Are you sure? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    echo ""
    log "=== Uninstall started ==="
    
    # Stop server
    echo -e "  ${BLUE}[1/4]${NC} Stopping server..."
    if [[ "$OS_TYPE" == "macos" ]]; then
        launchctl stop "$MACOS_PLIST" 2>/dev/null || true
    else
        systemctl --user stop "$LINUX_SERVICE.service" 2>/dev/null || true
    fi
    pkill -f "python3.*app.py" 2>/dev/null || true
    print_ok "Stopped"
    
    # Remove service
    echo -e "  ${BLUE}[2/4]${NC} Removing startup service..."
    if [[ "$OS_TYPE" == "macos" ]]; then
        PLIST_FILE="$HOME/Library/LaunchAgents/$MACOS_PLIST.plist"
        if [[ -f "$PLIST_FILE" ]]; then
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            rm -f "$PLIST_FILE"
            print_ok "LaunchAgent removed"
        else
            print_info "Not present"
        fi
    else
        SERVICE_FILE="$HOME/.config/systemd/user/$LINUX_SERVICE.service"
        if [[ -f "$SERVICE_FILE" ]]; then
            systemctl --user disable "$LINUX_SERVICE.service" 2>/dev/null || true
            rm -f "$SERVICE_FILE"
            systemctl --user daemon-reload
            print_ok "Systemd service removed"
        else
            print_info "Not present"
        fi
    fi
    
    # Remove FFmpeg
    echo -e "  ${BLUE}[3/4]${NC} Removing local FFmpeg..."
    if [[ -d "$FFMPEG_DIR" ]]; then
        rm -rf "$FFMPEG_DIR"
        print_ok "Removed"
    else
        print_info "Not present"
    fi
    
    # Remove log
    echo -e "  ${BLUE}[4/4]${NC} Removing log file..."
    read -p "       Remove log file too? [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$LOG_FILE"
        print_ok "Removed"
    else
        print_info "Kept"
    fi
    
    log "Uninstall completed"
    
    echo ""
    echo -e "  ${GREEN}============================================================${NC}"
    echo -e "  ${GREEN}      Uninstall Complete!${NC}"
    echo -e "  ${GREEN}============================================================${NC}"
    echo ""
    read -p "  Press Enter to continue..."
}

# ============================================================
# Install Process
# ============================================================
install() {
    print_header
    echo -e "  ${CYAN}Installing Tatarus YT Downloader...${NC}"
    
    log "=== Installation started ==="
    
    check_internet
    
    check_python || { log "Installation FAILED"; read -p "  Press Enter to continue..."; return; }
    check_pip || { log "Installation FAILED"; read -p "  Press Enter to continue..."; return; }
    check_ffmpeg || { log "Installation FAILED"; read -p "  Press Enter to continue..."; return; }
    install_dependencies || { log "Installation FAILED"; read -p "  Press Enter to continue..."; return; }
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        setup_macos_service
    else
        setup_linux_service
    fi
    
    start_server
    
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║     ✅ Installation Complete!                            ║${NC}"
    echo -e "  ${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "  ${GREEN}║${NC}  • Server runs as BACKGROUND SERVICE (no console)        ${GREEN}║${NC}"
    echo -e "  ${GREEN}║${NC}  • Server starts automatically with your computer        ${GREEN}║${NC}"
    echo -e "  ${GREEN}║${NC}  • Server starts in SLEEP mode (low resources)           ${GREEN}║${NC}"
    echo -e "  ${GREEN}║${NC}  • Extension wakes it up when needed                     ${GREEN}║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Installation completed successfully"
    read -p "  Press Enter to continue..."
}

# ============================================================
# Show Help
# ============================================================
show_help() {
    echo ""
    echo "Usage: install.sh [options]"
    echo ""
    echo "Options:"
    echo "  --install     Run installation directly"
    echo "  --uninstall   Run uninstallation directly"
    echo "  --start       Start the server"
    echo "  --stop        Stop the server"
    echo "  --status      Show system status"
    echo "  --help, -h    Show this help message"
    echo ""
    exit 0
}

# ============================================================
# Main Menu
# ============================================================
show_menu() {
    while true; do
        print_header
        echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${CYAN}║${NC}                                                          ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${GREEN}[1]${NC} Install / Repair                                   ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${GREEN}[2]${NC} Uninstall                                          ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${GREEN}[3]${NC} Start Server                                       ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${GREEN}[4]${NC} Stop Server                                        ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${GREEN}[5]${NC} Check Status                                       ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${GREEN}[6]${NC} View Log                                           ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}   ${RED}[0]${NC} Exit                                               ${CYAN}║${NC}"
        echo -e "  ${CYAN}║${NC}                                                          ${CYAN}║${NC}"
        echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "  Select option [0-6]: " choice
        
        case $choice in
            1) install ;;
            2) uninstall ;;
            3)
                print_header
                echo -e "  ${YELLOW}Starting server...${NC}"
                start_server
                echo ""
                read -p "  Press Enter to continue..."
                ;;
            4) stop_server ;;
            5) check_status ;;
            6) view_log ;;
            0)
                echo ""
                echo -e "  ${GREEN}Goodbye!${NC}"
                log "Installer closed"
                exit 0
                ;;
            *) ;;
        esac
    done
}

# ============================================================
# Parse Arguments
# ============================================================
case "${1:-}" in
    --install)
        install
        ;;
    --uninstall)
        uninstall
        ;;
    --start)
        start_server
        ;;
    --stop)
        stop_server
        ;;
    --status)
        check_status
        ;;
    --help|-h)
        show_help
        ;;
    *)
        show_menu
        ;;
esac
