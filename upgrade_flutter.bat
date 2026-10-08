@echo off
title Upgrade Flutter SDK
cd /d "%~dp0"

echo ===================================================
echo             Upgrading Flutter SDK
echo ===================================================
echo.
echo Your current Flutter is version 3.24.3 (Dart 3.5.3).
echo SeedRover requires Dart 3.6+ (Flutter 3.27+).
echo.
echo Running flutter upgrade now...
echo.

call "C:\Users\sophi\flutter\flutter\bin\flutter.bat" upgrade

echo.
echo ===================================================
echo Upgrade complete!
echo You can now double-click run_on_ldplayer.bat to launch!
echo ===================================================
echo.
pause
