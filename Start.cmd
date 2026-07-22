@echo off
title creedBuilder Start (TradingView webhook + Jupiter)
cd /d "%~dp0"
echo.
echo Starting bot + Cloudflare tunnel...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup\Start-TradingBot.ps1"
echo.
pause
