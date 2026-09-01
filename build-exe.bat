@echo off
title Build Trim Playlist .exe
cd /d "%~dp0"

echo Installing dependencies...
python -m pip install -r requirements.txt -r requirements-build.txt
if errorlevel 1 goto failed

echo.
echo Building TrimPlaylist.exe ...
python -m PyInstaller --noconfirm TrimPlaylist.spec
if errorlevel 1 goto failed

> "dist\TrimPlaylist\Run Trim Playlist.bat" echo @echo off
>> "dist\TrimPlaylist\Run Trim Playlist.bat" echo cd /d "%%~dp0"
>> "dist\TrimPlaylist\Run Trim Playlist.bat" echo start "" "%%~dp0TrimPlaylist.exe"

echo.
echo Building UrlTrimmer.exe ...
python -m PyInstaller --noconfirm UrlTrimmer.spec
if errorlevel 1 goto failed

echo.
echo Done.
echo   Desktop app: dist\TrimPlaylist\TrimPlaylist.exe
echo   Shortcut:    dist\TrimPlaylist\Run Trim Playlist.bat
echo   Trimmer CLI: dist\UrlTrimmer\UrlTrimmer.exe
echo.
echo Double-click TrimPlaylist.exe — server starts automatically inside the app.
pause
exit /b 0

:failed
echo.
echo Build failed.
pause
exit /b 1
