@echo off
title Connect LDPlayer to Flutter
cd /d "%~dp0"

echo ===================================================
echo           Connecting ADB to LDPlayer
echo ===================================================
echo.

"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" connect 127.0.0.1:5555

echo.
echo ADB Device Status:
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices
echo.

echo Flutter Recognized Devices:
if defined FLUTTER_BIN (
    set "FLUTTER_CMD=%FLUTTER_BIN%"
) else (
    set "FLUTTER_CMD=flutter"
)
call "%FLUTTER_CMD%" devices

echo.
echo ===================================================
echo If connected, you can run:
echo   flutter run -d 127.0.0.1:5555 --dart-define-from-file=.env.mobile.json
echo ===================================================
echo.
pause
