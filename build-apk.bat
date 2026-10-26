@echo off
setlocal
cd /d "%~dp0"
REM Build the Android APK (Android\dist\TrimPlaylist-Android.apk).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-apk.ps1"
pause
