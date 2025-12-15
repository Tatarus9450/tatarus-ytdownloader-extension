@echo off
title Tatarus YT Downloader - Installer
color 0A

echo.
echo ============================================================
echo      Tatarus YT Downloader - Installer
echo ============================================================
echo.

:: Get script directory
set "SCRIPT_DIR=%~dp0"
set "SERVER_DIR=%SCRIPT_DIR%server"
set "SERVER_SCRIPT=%SERVER_DIR%\app.py"

:: Check Python
echo Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found!
    echo Please install Python from https://python.org
    pause
    exit /b 1
)
echo [OK] Python found

:: Install dependencies
echo.
echo Installing dependencies...
cd /d "%SERVER_DIR%"
pip install -r requirements.txt -q
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install dependencies!
    pause
    exit /b 1
)
echo [OK] Dependencies installed

:: Create startup shortcut
echo.
echo Creating startup shortcut...

set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_FOLDER%\Tatarus-Server.bat"

:: Create the startup batch file
echo @echo off > "%SHORTCUT_PATH%"
echo start /min "" pythonw "%SERVER_SCRIPT%" >> "%SHORTCUT_PATH%"

echo [OK] Startup shortcut created

:: Start the server now (minimized)
echo.
echo Starting server...
start /min "" python "%SERVER_SCRIPT%"

echo.
echo ============================================================
echo      Installation Complete!
echo ============================================================
echo.
echo  * Server starts automatically with Windows
echo  * Server starts in SLEEP mode (low resources)
echo  * Extension wakes it up when needed
echo  * Auto-sleeps after 10 min of inactivity
echo.
echo To uninstall:
echo   Delete: %SHORTCUT_PATH%
echo.
pause
