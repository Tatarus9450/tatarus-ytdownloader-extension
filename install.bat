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
set "FFMPEG_DIR=%SCRIPT_DIR%ffmpeg"

:: ============================================================
:: Check and Install Python
:: ============================================================
echo Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] Python not found! Downloading...
    
    set "PYTHON_URL=https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    set "PYTHON_INSTALLER=%TEMP%\python_installer.exe"
    
    echo Downloading Python 3.12...
    powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_INSTALLER%'"
    
    if exist "%PYTHON_INSTALLER%" (
        echo Installing Python...
        echo [!] Check "Add Python to PATH" during installation!
        start /wait "" "%PYTHON_INSTALLER%" /passive InstallAllUsers=0 PrependPath=1
        del "%PYTHON_INSTALLER%"
        
        echo.
        echo [OK] Python installed! Please RESTART this installer.
        pause
        exit /b 0
    ) else (
        echo [ERROR] Failed to download Python!
        pause
        exit /b 1
    )
)
echo [OK] Python found

:: ============================================================
:: Check and Install FFmpeg (in script folder)
:: ============================================================
echo.
echo Checking FFmpeg...

:: First check if ffmpeg is in our local folder
if exist "%FFMPEG_DIR%\bin\ffmpeg.exe" (
    set "PATH=%FFMPEG_DIR%\bin;%PATH%"
    echo [OK] FFmpeg found (local)
    goto :ffmpeg_done
)

:: Check if ffmpeg is in system PATH
ffmpeg -version >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] FFmpeg found (system)
    goto :ffmpeg_done
)

:: Download FFmpeg to script folder
echo [!] FFmpeg not found! Downloading to script folder...

set "FFMPEG_URL=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
set "FFMPEG_ZIP=%SCRIPT_DIR%ffmpeg_download.zip"

echo Downloading FFmpeg...
powershell -Command "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%'"

if exist "%FFMPEG_ZIP%" (
    echo Extracting FFmpeg...
    
    :: Extract to temp first, then move
    powershell -Command "Expand-Archive -Path '%FFMPEG_ZIP%' -DestinationPath '%SCRIPT_DIR%ffmpeg_temp' -Force"
    del "%FFMPEG_ZIP%"
    
    :: Move the inner folder to ffmpeg
    if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%"
    for /d %%i in ("%SCRIPT_DIR%ffmpeg_temp\ffmpeg-*") do (
        xcopy "%%i\*" "%FFMPEG_DIR%\" /E /Y /Q >nul
    )
    rmdir /s /q "%SCRIPT_DIR%ffmpeg_temp"
    
    set "PATH=%FFMPEG_DIR%\bin;%PATH%"
    echo [OK] FFmpeg installed to %FFMPEG_DIR%
) else (
    echo [WARNING] Could not download FFmpeg
    echo MP3 conversion may not work
)

:ffmpeg_done

:: ============================================================
:: Install Python Dependencies
:: ============================================================
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

:: ============================================================
:: Create VBS launcher (hides console window)
:: ============================================================
echo.
echo Creating hidden launcher...

set "VBS_LAUNCHER=%SCRIPT_DIR%start_server.vbs"

:: Create VBS file that runs Python without console window
echo Set WshShell = CreateObject("WScript.Shell") > "%VBS_LAUNCHER%"
echo WshShell.CurrentDirectory = "%SERVER_DIR%" >> "%VBS_LAUNCHER%"
echo WshShell.Run "pythonw ""%SERVER_SCRIPT%""", 0, False >> "%VBS_LAUNCHER%"

echo [OK] Hidden launcher created

:: ============================================================
:: Create Startup Shortcut (uses VBS launcher)
:: ============================================================
echo.
echo Creating startup shortcut...
set "STARTUP_FOLDER=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_FOLDER%\Tatarus-Server.vbs"

:: Copy VBS launcher to startup folder
copy "%VBS_LAUNCHER%" "%SHORTCUT_PATH%" >nul

echo [OK] Startup shortcut created

:: ============================================================
:: Start the server now (hidden)
:: ============================================================
echo.
echo Starting server (hidden)...
wscript "%VBS_LAUNCHER%"

echo.
echo ============================================================
echo      Installation Complete!
echo ============================================================
echo.
echo  * Server runs HIDDEN (no console window)
echo  * Server starts automatically with Windows
echo  * FFmpeg installed at: %FFMPEG_DIR%
echo  * Extension wakes server when needed
echo.
pause
