@echo off
title SeedRover Static Analyzer
cd /d "%~dp0"

echo ===================================================
echo           SeedRover Code Analyzer
echo ===================================================
echo.

echo Analyzing mobile code...
echo.
call "C:\Users\sophi\flutter\flutter\bin\flutter.bat" analyze

echo.
echo ===================================================
echo Analysis finished.
echo ===================================================
echo.
pause
