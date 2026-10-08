@echo off
title SeedRover Test Runner
cd /d "%~dp0"

echo ===================================================
echo           SeedRover Mobile Test Runner
echo ===================================================
echo.

echo Running planting session model tests...
echo.
call "C:\Users\sophi\flutter\flutter\bin\flutter.bat" test test/planting_session_model_test.dart

echo.
echo ===================================================
echo Test run finished.
echo ===================================================
echo.
pause
