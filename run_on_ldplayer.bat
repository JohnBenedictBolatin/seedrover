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
call "C:\Users\sophi\flutter\flutter\bin\flutter.bat" run -d 127.0.0.1:5555 --dart-define-from-file=.env.mobile.json --android-skip-build-dependency-validation

echo.
pause
