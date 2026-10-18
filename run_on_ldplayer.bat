@echo off
title SeedRover - Run on LDPlayer
cd /d "%~dp0"

echo ===================================================
echo        Launching SeedRover App on LDPlayer
echo ===================================================
echo.

echo 1. Connecting to LDPlayer...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" connect 127.0.0.1:5555

echo.
echo 2. Building and installing SeedRover onto LDPlayer...
echo.
if defined FLUTTER_BIN (
    set "FLUTTER_CMD=%FLUTTER_BIN%"
) else (
    set "FLUTTER_CMD=flutter"
)
if exist .env.mobile.json (
    call "%FLUTTER_CMD%" run -d 127.0.0.1:5555 --dart-define-from-file=.env.mobile.json
) else (
    call "%FLUTTER_CMD%" run -d 127.0.0.1:5555
)

echo.
pause
