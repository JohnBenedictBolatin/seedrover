@echo off
title SeedRover - Build APK
cd /d "%~dp0"

echo ===================================================
echo             Building SeedRover APK
echo ===================================================
echo.

call "C:\Users\sophi\flutter\flutter\bin\flutter.bat" build apk --debug --dart-define-from-file=.env.mobile.json --android-skip-build-dependency-validation

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
