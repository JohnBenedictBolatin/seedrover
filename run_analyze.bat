@echo off
title SeedRover Static Analyzer
cd /d "%~dp0"

echo ===================================================
echo           SeedRover Code Analyzer
echo ===================================================
echo.

echo Analyzing mobile code...
echo.
if defined FLUTTER_BIN (
    set "FLUTTER_CMD=%FLUTTER_BIN%"
) else (
    set "FLUTTER_CMD=flutter"
)
call "%FLUTTER_CMD%" analyze

echo.
echo ===================================================
echo Analysis finished.
echo ===================================================
echo.
pause
