@echo off
title SeedRover - Build APK
cd /d "%~dp0"

echo ===================================================
echo             Building SeedRover APK
echo ===================================================
echo.

if defined FLUTTER_BIN (
    set "FLUTTER_CMD=%FLUTTER_BIN%"
) else (
    set "FLUTTER_CMD=flutter"
)
if exist .env.mobile.json (
    call "%FLUTTER_CMD%" build apk --debug --dart-define-from-file=.env.mobile.json
) else (
    call "%FLUTTER_CMD%" build apk --debug
)

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ===================================================
    echo  Build Successful!
    echo  APK Location: build\app\outputs\flutter-apk\app-debug.apk
    echo ===================================================
    echo.
    echo Opening output folder...
    explorer.exe "build\app\outputs\flutter-apk"
) else (
    echo.
    echo Build failed with error code %ERRORLEVEL%.
)

echo.
pause
