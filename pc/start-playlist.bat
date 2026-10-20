@echo off
title Trim Playlist
cd /d "%~dp0.."

if exist "%cd%\dist\TrimPlaylist\TrimPlaylist.exe" (
  start "" "%cd%\dist\TrimPlaylist\TrimPlaylist.exe"
  exit /b 0
)

if exist "%cd%\TrimPlaylist.exe" (
  start "" "%cd%\TrimPlaylist.exe"
  exit /b 0
)

python pc\app\trim_playlist_app.py
if errorlevel 1 (
  echo.
  echo Failed. Run scripts\build-exe.bat or: pip install -r requirements.txt
  pause
)
