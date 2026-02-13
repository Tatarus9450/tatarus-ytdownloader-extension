#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"

echo -e "${BLUE}Installing Tatarus YT Downloader...${NC}"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python3 not found!${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Python found"

# Check FFmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: FFmpeg not found! Install with: sudo apt install ffmpeg${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} FFmpeg found"

# Install venv if needed
if ! python3 -c "import venv" 2>/dev/null; then
    echo "Installing python3-venv..."
    sudo apt update && sudo apt install -y python3-venv
fi

# Create virtual environment
cd "$SERVER_DIR"
if [[ ! -d "venv" ]]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    ./venv/bin/python -m ensurepip --upgrade
fi

# Install dependencies
# Install dependencies
echo "Installing dependencies..."
./venv/bin/python -m pip install --upgrade pip -q
./venv/bin/python -m pip install -r requirements.txt -q
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to install dependencies!${NC}"
    exit 1
fi

# Create systemd service
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/tatarus-server.service"
mkdir -p "$SERVICE_DIR"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Tatarus YT Downloader Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$SERVER_DIR
ExecStart=$SERVER_DIR/venv/bin/python $SERVER_DIR/app.py
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF

# Enable and start service
systemctl --user daemon-reload
systemctl --user enable tatarus-server.service
systemctl --user start tatarus-server.service

echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${GREEN}✓${NC} Server running at http://127.0.0.1:4321"
echo -e "${GREEN}✓${NC} Auto-starts with system"
