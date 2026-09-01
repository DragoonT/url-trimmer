@echo off
title Trim Playlist
cd /d "%~dp0"

if exist "%~dp0dist\TrimPlaylist\TrimPlaylist.exe" (
  start "" "%~dp0dist\TrimPlaylist\TrimPlaylist.exe"
  exit /b 0
)

if exist "%~dp0TrimPlaylist.exe" (
  start "" "%~dp0TrimPlaylist.exe"
  exit /b 0
)

python trim_playlist_app.py
if errorlevel 1 (
  echo.
  echo Failed. Run build-exe.bat or: pip install -r requirements.txt
  pause
)
