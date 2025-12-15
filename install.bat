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
    echo.
    echo [!] Python not found! Downloading...
    echo.
    
    :: Download Python installer
    set "PYTHON_URL=https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    set "PYTHON_INSTALLER=%TEMP%\python_installer.exe"
    
    echo Downloading Python 3.12...
    powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_INSTALLER%'"
    
    if exist "%PYTHON_INSTALLER%" (
        echo Installing Python...
        echo [!] Please check "Add Python to PATH" during installation!
        echo.
        start /wait "" "%PYTHON_INSTALLER%" /passive InstallAllUsers=0 PrependPath=1
        del "%PYTHON_INSTALLER%"
        
        :: Refresh PATH
        call refreshenv >nul 2>&1
        
        echo.
        echo [OK] Python installed! Please RESTART this installer.
        pause
        exit /b 0
    ) else (
        echo [ERROR] Failed to download Python!
        echo Please install manually from https://python.org
        pause
        exit /b 1
    )
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

echo @echo off > "%SHORTCUT_PATH%"
echo start /min "" pythonw "%SERVER_SCRIPT%" >> "%SHORTCUT_PATH%"

echo [OK] Startup shortcut created

:: Start the server now
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
echo.
pause
