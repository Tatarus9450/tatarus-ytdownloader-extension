#!/bin/bash

echo ""
echo "========================================"
echo "  Tatarus YT Downloader - Installer"
echo "========================================"
echo ""

# Check Python
echo "[1/3] Checking Python..."
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python3 not found!"
    echo "Please install Python: brew install python3 (Mac) or apt install python3 (Linux)"
    exit 1
fi
echo "[OK] Python found: $(python3 --version)"

# Check pip
echo "[2/3] Checking pip..."
if ! command -v pip3 &> /dev/null; then
    echo "[ERROR] pip3 not found!"
    exit 1
fi
echo "[OK] pip found"

# Install dependencies
echo "[3/3] Installing dependencies..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../server"
pip3 install -r requirements.txt

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to install dependencies!"
    exit 1
fi

echo ""
echo "========================================"
echo "  Installation Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Load extension in Chrome (chrome://extensions)"
echo "2. Open a YouTube video"
echo "3. Click the extension icon"
echo ""
