@echo off
setlocal EnableDelayedExpansion
title Tatarus YT Downloader - Installer v2.0
color 0A

:: ============================================================
:: Configuration
:: ============================================================
set "SCRIPT_DIR=%~dp0"
set "SERVER_DIR=%SCRIPT_DIR%server"
set "SERVER_SCRIPT=%SERVER_DIR%\app.py"
set "FFMPEG_DIR=%SCRIPT_DIR%ffmpeg"
set "FFMPEG_EXE=%FFMPEG_DIR%\bin\ffmpeg.exe"
set "VBS_LAUNCHER=%SCRIPT_DIR%start_server.vbs"
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_FOLDER%\Tatarus-Server.vbs"
set "LOG_FILE=%SCRIPT_DIR%install.log"

:: Python settings
set "PYTHON_VERSION=3.12.0"
set "PYTHON_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe"

:: FFmpeg settings
set "FFMPEG_URL=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
set "FFMPEG_ZIP=%SCRIPT_DIR%ffmpeg_download.zip"
set "FFMPEG_TMP=%SCRIPT_DIR%ffmpeg_temp"

:: Internet check flag
set "HAS_INTERNET=1"

:: Parse command line arguments
set "FORCE_FFMPEG=0"
set "SILENT=0"
set "DIRECT_INSTALL=0"

for %%A in (%*) do (
    if /I "%%~A"=="/forceffmpeg" set "FORCE_FFMPEG=1"
    if /I "%%~A"=="/silent" set "SILENT=1"
    if /I "%%~A"=="/install" set "DIRECT_INSTALL=1"
    if /I "%%~A"=="/?" goto :show_help
    if /I "%%~A"=="/help" goto :show_help
)

:: Direct install mode
if "%DIRECT_INSTALL%"=="1" goto :install

:: ============================================================
:: Main Menu
:: ============================================================
:show_menu
cls
echo.
echo  ============================================================
echo       Tatarus YT Downloader - Installer v2.0
echo  ============================================================
echo.
echo       [1] Install / Repair
echo       [2] Uninstall
echo       [3] Start Server
echo       [4] Stop Server
echo       [5] Check Status
echo       [6] View Log
echo       [0] Exit
echo.
echo  ============================================================
echo.
set "CHOICE="
set /p "CHOICE=  Select option [0-6]: "

if "%CHOICE%"=="1" goto :install
if "%CHOICE%"=="2" goto :uninstall
if "%CHOICE%"=="3" goto :start_server
if "%CHOICE%"=="4" goto :stop_server
if "%CHOICE%"=="5" goto :check_status
if "%CHOICE%"=="6" goto :view_log
if "%CHOICE%"=="0" goto :exit_script
goto :show_menu

:: ============================================================
:: Show Help
:: ============================================================
:show_help
echo.
echo Usage: install.bat [options]
echo.
echo Options:
echo   /install      Run installation directly (skip menu)
echo   /forceffmpeg  Force reinstall FFmpeg
echo   /silent       Silent install (no prompts)
echo   /? /help      Show this help message
echo.
pause
exit /b 0

:: ============================================================
:: Logging Function
:: ============================================================
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: ============================================================
:: Check Internet Connection
:: ============================================================
:check_internet
echo.
echo [0/6] Checking internet connection...
ping -n 1 -w 3000 google.com >nul 2>&1
if %errorlevel% neq 0 (
    ping -n 1 -w 3000 github.com >nul 2>&1
    if !errorlevel! neq 0 (
        echo       [WARNING] No internet connection detected!
        echo       Some features may not work properly.
        call :log "WARNING: No internet connection"
        set "HAS_INTERNET=0"
        goto :eof
    )
)
echo       [OK] Internet connection available
call :log "Internet connection OK"
goto :eof

:: ============================================================
:: Install Process
:: ============================================================
:install
cls
echo.
echo  ============================================================
echo       Installing Tatarus YT Downloader...
echo  ============================================================
echo.

call :log "=== Installation started ==="
call :check_internet

:: Step 1: Check Python
call :check_python
if !errorlevel! neq 0 goto :install_failed

:: Step 2: Check pip
call :check_pip
if !errorlevel! neq 0 goto :install_failed

:: Step 3: Check/Install FFmpeg
call :check_ffmpeg
if !errorlevel! neq 0 goto :install_failed

:: Step 4: Install dependencies
call :install_dependencies
if !errorlevel! neq 0 goto :install_failed

:: Step 5: Create launcher
call :create_launcher

:: Step 6: Create startup shortcut
call :create_startup_shortcut

:: Step 7: Start server
call :start_server_hidden

echo.
echo  ============================================================
echo       Installation Complete!
echo  ============================================================
echo.
echo   [OK] Server runs HIDDEN (no console window)
echo   [OK] Server starts automatically with Windows
echo   [OK] FFmpeg installed at: %FFMPEG_DIR%
echo   [OK] Extension wakes server when needed
echo.
call :log "Installation completed successfully"
pause
if "%DIRECT_INSTALL%"=="1" exit /b 0
goto :show_menu

:install_failed
echo.
echo  [ERROR] Installation failed! Check log file: %LOG_FILE%
call :log "Installation FAILED"
pause
if "%DIRECT_INSTALL%"=="1" exit /b 1
goto :show_menu

:: ============================================================
:: Check Python
:: ============================================================
:check_python
echo.
echo [1/6] Checking Python...

:: First try 'python'
python --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do set "PY_VER=%%v"
    echo       [OK] Python !PY_VER! found
    call :log "Python found: !PY_VER!"
    exit /b 0
)

:: Try 'py' command (Python Launcher)
py --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%v in ('py --version 2^>^&1') do set "PY_VER=%%v"
    echo       [OK] Python !PY_VER! found (via py launcher)
    call :log "Python found via py: !PY_VER!"
    exit /b 0
)

:: Python not found - offer to install
echo       [!] Python not found!
echo.

if "%HAS_INTERNET%"=="0" (
    echo       [ERROR] Cannot download Python without internet!
    exit /b 1
)

if "%SILENT%"=="1" (
    set "INSTALL_PY=y"
) else (
    set /p "INSTALL_PY=       Install Python %PYTHON_VERSION%? [Y/n]: "
)
if /I "!INSTALL_PY!"=="n" (
    echo       [ERROR] Python is required!
    exit /b 1
)

echo       Downloading Python %PYTHON_VERSION%...
set "PYTHON_INSTALLER=%TEMP%\python_installer.exe"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue';" ^
    "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_INSTALLER%'"

if not exist "%PYTHON_INSTALLER%" (
    echo       [ERROR] Failed to download Python!
    call :log "ERROR: Failed to download Python"
    exit /b 1
)

echo       Installing Python (this may take a minute)...
echo       [!] Make sure "Add Python to PATH" is checked!

start /wait "" "%PYTHON_INSTALLER%" /passive InstallAllUsers=0 PrependPath=1 Include_pip=1
del "%PYTHON_INSTALLER%" >nul 2>&1

echo.
echo       [OK] Python installed!
echo       [!] Please RESTART this installer for changes to take effect.
call :log "Python installed - restart required"
pause
exit /b 1

:: ============================================================
:: Check pip
:: ============================================================
:check_pip
echo [2/6] Checking pip...

python -m pip --version >nul 2>&1
if %errorlevel% equ 0 (
    echo       [OK] pip is available
    call :log "pip found"
    exit /b 0
)

:: Try with py launcher
py -m pip --version >nul 2>&1
if %errorlevel% equ 0 (
    echo       [OK] pip is available (via py)
    call :log "pip found via py"
    exit /b 0
)

echo       [!] pip not found, attempting to install...
python -m ensurepip --upgrade >nul 2>&1
if %errorlevel% equ 0 (
    echo       [OK] pip installed
    call :log "pip installed via ensurepip"
    exit /b 0
)

echo       [ERROR] Failed to install pip!
call :log "ERROR: Failed to install pip"
exit /b 1

:: ============================================================
:: Check/Install FFmpeg
:: ============================================================
:check_ffmpeg
echo [3/6] Checking FFmpeg...

:: Check local FFmpeg first
if "%FORCE_FFMPEG%"=="0" (
    if exist "%FFMPEG_EXE%" (
        echo       [OK] FFmpeg found (local)
        call :log "FFmpeg found locally"
        exit /b 0
    )
)

:: Check system FFmpeg
if "%FORCE_FFMPEG%"=="0" (
    where ffmpeg.exe >nul 2>&1
    if !errorlevel! equ 0 (
        echo       [OK] FFmpeg found (system)
        call :log "FFmpeg found in system PATH"
        exit /b 0
    )
)

:: Need to install FFmpeg
if "%FORCE_FFMPEG%"=="1" (
    echo       [!] Force reinstalling FFmpeg...
) else (
    echo       [!] FFmpeg not found, installing...
)

if "%HAS_INTERNET%"=="0" (
    echo       [WARNING] Cannot download FFmpeg without internet!
    echo       [WARNING] Audio/video conversion may not work!
    call :log "WARNING: FFmpeg not installed - no internet"
    exit /b 0
)

:: Cleanup old files
if exist "%FFMPEG_ZIP%" del /f /q "%FFMPEG_ZIP%" >nul 2>&1
if exist "%FFMPEG_TMP%" rmdir /s /q "%FFMPEG_TMP%" >nul 2>&1
if "%FORCE_FFMPEG%"=="1" (
    if exist "%FFMPEG_DIR%" rmdir /s /q "%FFMPEG_DIR%" >nul 2>&1
)

echo       Downloading FFmpeg (this may take a while)...
call :log "Downloading FFmpeg..."

:: Try PowerShell first
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue';" ^
    "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "try { Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%' -TimeoutSec 300 } catch { exit 1 }"

:: Verify download
set "ZIP_OK=0"
if exist "%FFMPEG_ZIP%" (
    for %%F in ("%FFMPEG_ZIP%") do (
        if %%~zF gtr 1000000 set "ZIP_OK=1"
    )
)

:: Fallback to curl if needed
if "!ZIP_OK!"=="0" (
    if exist "%FFMPEG_ZIP%" del /f /q "%FFMPEG_ZIP%" >nul 2>&1
    echo       [!] PowerShell download failed, trying curl...
    where curl.exe >nul 2>&1
    if !errorlevel! neq 0 (
        echo       [ERROR] curl.exe not found!
        call :log "ERROR: Both PowerShell and curl failed"
        exit /b 1
    )
    curl.exe -L --progress-bar -o "%FFMPEG_ZIP%" "%FFMPEG_URL%"
)

if not exist "%FFMPEG_ZIP%" (
    echo       [ERROR] Failed to download FFmpeg!
    call :log "ERROR: FFmpeg download failed"
    exit /b 1
)

echo       Extracting FFmpeg...
call :log "Extracting FFmpeg..."

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Expand-Archive -Path '%FFMPEG_ZIP%' -DestinationPath '%FFMPEG_TMP%' -Force"

del /f /q "%FFMPEG_ZIP%" >nul 2>&1

:: Move extracted files
if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%" >nul 2>&1
for /d %%i in ("%FFMPEG_TMP%\ffmpeg-*") do (
    xcopy "%%i\*" "%FFMPEG_DIR%\" /E /I /Y /Q >nul
)

rmdir /s /q "%FFMPEG_TMP%" >nul 2>&1

:: Verify installation
if exist "%FFMPEG_EXE%" (
    echo       [OK] FFmpeg installed to %FFMPEG_DIR%
    call :log "FFmpeg installed successfully"
    exit /b 0
) else (
    echo       [ERROR] FFmpeg extraction failed!
    call :log "ERROR: FFmpeg extraction failed"
    exit /b 1
)

:: ============================================================
:: Install Python Dependencies
:: ============================================================
:install_dependencies
echo [4/6] Installing Python dependencies...

if not exist "%SERVER_DIR%\requirements.txt" (
    echo       [WARNING] requirements.txt not found!
    call :log "WARNING: requirements.txt not found"
    exit /b 0
)

cd /d "%SERVER_DIR%"

:: Try python first, then py
python -m pip install -r requirements.txt -q --disable-pip-version-check 2>nul
if %errorlevel% neq 0 (
    py -m pip install -r requirements.txt -q --disable-pip-version-check 2>nul
    if !errorlevel! neq 0 (
        echo       [ERROR] Failed to install dependencies!
        call :log "ERROR: pip install failed"
        exit /b 1
    )
)

echo       [OK] Dependencies installed
call :log "Dependencies installed"
exit /b 0

:: ============================================================
:: Create VBS Launcher
:: ============================================================
:create_launcher
echo [5/6] Creating hidden launcher...

:: Get Python path
set "PYTHON_CMD=python"
python --version >nul 2>&1
if %errorlevel% neq 0 (
    set "PYTHON_CMD=py"
)

:: Create a proper VBS launcher
(
    echo Set WshShell = CreateObject^("WScript.Shell"^)
    echo Set fso = CreateObject^("Scripting.FileSystemObject"^)
    echo.
    echo ' Set working directory
    echo WshShell.CurrentDirectory = "%SERVER_DIR%"
    echo.
    echo ' Build PATH with FFmpeg
    echo ffmpegPath = "%FFMPEG_DIR%\bin"
    echo.
    echo ' Create environment with FFmpeg in PATH
    echo Set env = WshShell.Environment^("Process"^)
    echo currentPath = env^("PATH"^)
    echo If InStr^(currentPath, ffmpegPath^) = 0 Then
    echo     env^("PATH"^) = ffmpegPath ^& ";" ^& currentPath
    echo End If
    echo.
    echo ' Run Python script hidden
    echo WshShell.Run "pythonw ""%SERVER_SCRIPT%""", 0, False
) > "%VBS_LAUNCHER%"

if exist "%VBS_LAUNCHER%" (
    echo       [OK] Hidden launcher created
    call :log "VBS launcher created"
) else (
    echo       [WARNING] Failed to create launcher
    call :log "WARNING: VBS launcher creation failed"
)
exit /b 0

:: ============================================================
:: Create Startup Shortcut
:: ============================================================
:create_startup_shortcut
echo [6/6] Creating startup shortcut...

if not exist "%STARTUP_FOLDER%" (
    echo       [WARNING] Startup folder not found!
    call :log "WARNING: Startup folder not found"
    exit /b 0
)

copy /Y "%VBS_LAUNCHER%" "%SHORTCUT_PATH%" >nul 2>&1

if exist "%SHORTCUT_PATH%" (
    echo       [OK] Startup shortcut created
    call :log "Startup shortcut created"
) else (
    echo       [WARNING] Failed to create startup shortcut
    call :log "WARNING: Startup shortcut creation failed"
)
exit /b 0

:: ============================================================
:: Start Server (Hidden)
:: ============================================================
:start_server_hidden
echo.
echo Starting server (hidden)...

if not exist "%VBS_LAUNCHER%" (
    echo [ERROR] Launcher not found!
    exit /b 1
)

wscript "%VBS_LAUNCHER%"
echo [OK] Server started
call :log "Server started"
exit /b 0

:: ============================================================
:: Start Server (from menu)
:: ============================================================
:start_server
cls
echo.
echo  Starting server...
echo.

:: Check if already running
tasklist /FI "IMAGENAME eq pythonw.exe" 2>nul | find /I "pythonw.exe" >nul
if %errorlevel% equ 0 (
    echo  [WARNING] Server may already be running!
    set /p "CONT=  Start anyway? [y/N]: "
    if /I not "!CONT!"=="y" goto :show_menu
)

if exist "%VBS_LAUNCHER%" (
    wscript "%VBS_LAUNCHER%"
    echo  [OK] Server started (hidden)
    call :log "Server started manually"
) else (
    echo  [ERROR] Launcher not found! Run Install first.
)

echo.
pause
goto :show_menu

:: ============================================================
:: Stop Server
:: ============================================================
:stop_server
cls
echo.
echo  Stopping server...
echo.

:: Find and kill pythonw processes
taskkill /F /IM pythonw.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo  [OK] Server stopped
    call :log "Server stopped"
) else (
    echo  [INFO] No server process found
)

echo.
pause
goto :show_menu

:: ============================================================
:: Check Status
:: ============================================================
:check_status
cls
echo.
echo  ============================================================
echo       System Status
echo  ============================================================
echo.

:: Check Python
echo  Python:
python --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do echo    [OK] Version %%v
) else (
    py --version >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=2" %%v in ('py --version 2^>^&1') do echo    [OK] Version %%v (via py)
    ) else (
        echo    [X] Not installed
    )
)

:: Check pip
echo.
echo  pip:
python -m pip --version >nul 2>&1
if %errorlevel% equ 0 (
    echo    [OK] Available
) else (
    py -m pip --version >nul 2>&1
    if !errorlevel! equ 0 (
        echo    [OK] Available (via py)
    ) else (
        echo    [X] Not available
    )
)

:: Check FFmpeg
echo.
echo  FFmpeg:
if exist "%FFMPEG_EXE%" (
    echo    [OK] Installed locally
) else (
    where ffmpeg.exe >nul 2>&1
    if !errorlevel! equ 0 (
        echo    [OK] Available in system PATH
    ) else (
        echo    [X] Not installed
    )
)

:: Check Server
echo.
echo  Server:
tasklist /FI "IMAGENAME eq pythonw.exe" 2>nul | find /I "pythonw.exe" >nul
if %errorlevel% equ 0 (
    echo    [OK] Running
) else (
    echo    [ ] Not running
)

:: Check Startup
echo.
echo  Auto-start:
if exist "%SHORTCUT_PATH%" (
    echo    [OK] Enabled
) else (
    echo    [ ] Disabled
)

:: Check Launcher
echo.
echo  Launcher:
if exist "%VBS_LAUNCHER%" (
    echo    [OK] Created
) else (
    echo    [ ] Not created
)

:: Check requirements
echo.
echo  Dependencies:
if exist "%SERVER_DIR%\requirements.txt" (
    echo    [OK] requirements.txt found
) else (
    echo    [X] requirements.txt missing
)

echo.
echo  ============================================================
echo.
pause
goto :show_menu

:: ============================================================
:: View Log
:: ============================================================
:view_log
cls
echo.
echo  ============================================================
echo       Installation Log
echo  ============================================================
echo.

if exist "%LOG_FILE%" (
    type "%LOG_FILE%"
) else (
    echo  No log file found.
)

echo.
echo  ============================================================
echo.
pause
goto :show_menu

:: ============================================================
:: Uninstall
:: ============================================================
:uninstall
cls
echo.
echo  ============================================================
echo       Uninstall Tatarus YT Downloader
echo  ============================================================
echo.
echo  This will:
echo    - Stop the server
echo    - Remove startup shortcut
echo    - Remove FFmpeg folder
echo    - Remove launcher script
echo    - Remove log file
echo.
echo  [!] This will NOT remove: Python, pip, or the extension files
echo.

set /p "CONFIRM=  Are you sure? [y/N]: "
if /I not "%CONFIRM%"=="y" goto :show_menu

echo.
echo  Uninstalling...
call :log "=== Uninstall started ==="

:: Stop server
echo  [1/5] Stopping server...
taskkill /F /IM pythonw.exe >nul 2>&1
echo        Done
call :log "Server stopped"

:: Remove startup shortcut
echo  [2/5] Removing startup shortcut...
if exist "%SHORTCUT_PATH%" (
    del /f /q "%SHORTCUT_PATH%" >nul 2>&1
    echo        [OK] Removed
) else (
    echo        [OK] Not present
)
call :log "Startup shortcut removed"

:: Remove VBS launcher
echo  [3/5] Removing launcher...
if exist "%VBS_LAUNCHER%" (
    del /f /q "%VBS_LAUNCHER%" >nul 2>&1
    echo        [OK] Removed
) else (
    echo        [OK] Not present
)
call :log "Launcher removed"

:: Remove FFmpeg
echo  [4/5] Removing FFmpeg...
if exist "%FFMPEG_DIR%" (
    rmdir /s /q "%FFMPEG_DIR%" >nul 2>&1
    echo        [OK] Removed
) else (
    echo        [OK] Not present
)
call :log "FFmpeg removed"

:: Remove log
echo  [5/5] Removing log file...
set /p "DEL_LOG=        Remove log file too? [y/N]: "
if /I "%DEL_LOG%"=="y" (
    if exist "%LOG_FILE%" del /f /q "%LOG_FILE%" >nul 2>&1
    echo        [OK] Removed
) else (
    echo        [OK] Kept
)

echo.
echo  ============================================================
echo       Uninstall Complete!
echo  ============================================================
echo.
pause
goto :show_menu

:: ============================================================
:: Exit
:: ============================================================
:exit_script
echo.
echo  Goodbye!
call :log "Installer closed"
endlocal
exit /b 0
