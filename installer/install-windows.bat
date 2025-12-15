@echo off
title Tatarus YT Downloader - Installer
color 0A

echo.
echo ========================================
echo   Tatarus YT Downloader - Installer
echo ========================================
echo.

:: Check Python
echo [1/3] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found!
    echo Please install Python from https://python.org
    pause
    exit /b 1
)
echo [OK] Python found

:: Check pip
echo [2/3] Checking pip...
pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] pip not found!
    pause
    exit /b 1
)
echo [OK] pip found

:: Install dependencies
echo [3/3] Installing dependencies...
cd /d "%~dp0..\server"
pip install -r requirements.txt

if %errorlevel% neq 0 (
    echo [ERROR] Failed to install dependencies!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Installation Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Load extension in Chrome (chrome://extensions)
echo 2. Open a YouTube video
echo 3. Click the extension icon
echo.
pause
