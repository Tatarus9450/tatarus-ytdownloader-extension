#!/bin/bash

# Tatarus YT Downloader - Universal Start Script
# This script finds the project folder automatically and starts the server

echo ""
echo "========================================"
echo "  Tatarus YT Downloader - Server"
echo "========================================"
echo ""

# Find the project directory
PROJECT_DIR=$(find ~ -name "tatarus-ytdownloader-extension" -type d 2>/dev/null | head -1)

if [ -z "$PROJECT_DIR" ]; then
    echo "[ERROR] Project folder not found!"
    echo "Make sure 'tatarus-ytdownloader-extension' folder exists in your home directory"
    exit 1
fi

echo "[INFO] Found project at: $PROJECT_DIR"
cd "$PROJECT_DIR/server"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python3 not found!"
    exit 1
fi

# Install dependencies if needed
pip3 install -r requirements.txt -q 2>/dev/null

echo "[OK] Starting server..."
echo ""
python3 app.py
