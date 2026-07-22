@echo off
title creedBuilder Install (TradingView + Jupiter)
cd /d "%~dp0"

where git >nul 2>&1
if errorlevel 1 (
  echo Git is required. Install from https://git-scm.com/download/win
  echo Then:  git clone https://github.com/tritonSama/creedBuilder.git
  pause
  exit /b 1
)

echo.
echo creedBuilder - clone-friendly installer
echo Repo: %cd%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup\Install-Prerequisites.ps1"
set ERR=%ERRORLEVEL%
echo.
if not "%ERR%"=="0" (
  echo Install failed with exit code %ERR%.
  pause
  exit /b %ERR%
)
echo Next: double-click Start.cmd
echo.
pause
