@echo off
title Trim Playlist Mobile Web Player
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-mobile-web.ps1"
pause
