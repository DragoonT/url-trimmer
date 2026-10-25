@echo off
setlocal
cd /d "%~dp0"
REM Tauri desktop build: portable exe + NSIS setup.
REM Runs scripts\build-tauri.ps1; outputs land in dist-tauri\
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-tauri.ps1"
pause
