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

:: Optional: force reinstall ffmpeg
set "FORCE_FFMPEG=0"
for %%A in (%*) do (
    if /I "%%~A"=="/forceffmpeg" set "FORCE_FFMPEG=1"
)

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

set "FFMPEG_EXE=%FFMPEG_DIR%\bin\ffmpeg.exe"
set "FFMPEG_URL=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
set "FFMPEG_ZIP=%SCRIPT_DIR%ffmpeg_download.zip"
set "FFMPEG_TMP=%SCRIPT_DIR%ffmpeg_temp"

:: If already installed locally and not forcing reinstall
if "%FORCE_FFMPEG%"=="0" (
    if exist "%FFMPEG_EXE%" (
        set "PATH=%FFMPEG_DIR%\bin;%PATH%"
        echo [OK] FFmpeg found (local)
        goto :ffmpeg_done
    )
)

:: Always install local FFmpeg if missing (or forced)
if "%FORCE_FFMPEG%"=="1" (
    echo [!] Force reinstall FFmpeg...
) else (
    echo [!] FFmpeg not found (local). Installing to script folder...
)

:: Cleanup old leftovers
if exist "%FFMPEG_ZIP%" del /f /q "%FFMPEG_ZIP%" >nul 2>&1
if exist "%FFMPEG_TMP%" rmdir /s /q "%FFMPEG_TMP%" >nul 2>&1
if exist "%FFMPEG_DIR%" (
    if "%FORCE_FFMPEG%"=="1" rmdir /s /q "%FFMPEG_DIR%" >nul 2>&1
)

echo Downloading FFmpeg...

:: Try PowerShell download with TLS 1.2
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%'" >nul 2>&1

:: If download failed or zip too small, fallback to curl
set "ZIP_OK=0"
if exist "%FFMPEG_ZIP%" (
    for %%F in ("%FFMPEG_ZIP%") do (
        if %%~zF gtr 1000000 set "ZIP_OK=1"
    )
)

if "%ZIP_OK%"=="0" (
    del /f /q "%FFMPEG_ZIP%" >nul 2>&1
    echo [!] PowerShell download failed - trying curl...
    where curl.exe >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] curl.exe not found, and PowerShell download failed.
        echo         Check internet/firewall/antivirus and try again.
        pause
        exit /b 1
    )
    curl.exe -L -o "%FFMPEG_ZIP%" "%FFMPEG_URL%"
)

:: Verify zip exists
if not exist "%FFMPEG_ZIP%" (
    echo [ERROR] Could not download FFmpeg zip.
    echo         Check internet/firewall/antivirus and try again.
    pause
    exit /b 1
)

echo Extracting FFmpeg...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Expand-Archive -Path '%FFMPEG_ZIP%' -DestinationPath '%FFMPEG_TMP%' -Force" >nul 2>&1

del /f /q "%FFMPEG_ZIP%" >nul 2>&1

:: Move the inner folder to ffmpeg
if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%" >nul 2>&1
for /d %%i in ("%FFMPEG_TMP%\ffmpeg-*") do (
    xcopy "%%i\*" "%FFMPEG_DIR%\" /E /I /Y /Q >nul
)

rmdir /s /q "%FFMPEG_TMP%" >nul 2>&1

:: Final verify
if exist "%FFMPEG_EXE%" (
    set "PATH=%FFMPEG_DIR%\bin;%PATH%"
    echo [OK] FFmpeg installed to %FFMPEG_DIR%
) else (
    echo [ERROR] FFmpeg install failed (ffmpeg.exe not found in %FFMPEG_DIR%\bin)
    echo         Your server may not be able to convert audio/video.
    pause
    exit /b 1
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

:: IMPORTANT: ensure local ffmpeg is on PATH for startup-run too
echo WshShell.Run "cmd /c ""set """"PATH=%FFMPEG_DIR%\bin;%%PATH%%"""" ^& pythonw """"%SERVER_SCRIPT%"""" """, 0, False >> "%VBS_LAUNCHER%"

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
