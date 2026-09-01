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
echo Building UrlTrimmer.exe (optional — Windows may block/delete this file) ...
python -m PyInstaller --noconfirm UrlTrimmer.spec
if errorlevel 1 goto failed

> "dist\UrlTrimmer\Run Url Trimmer.bat" echo @echo off
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo cd /d "%%~dp0..\..\"
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo if exist "%%~dp0UrlTrimmer.exe" ^(
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo   "%%~dp0UrlTrimmer.exe" --config setlist.json
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo ^) else ^(
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo   python cut_url.py --config setlist.json
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo ^)
>> "dist\UrlTrimmer\Run Url Trimmer.bat" echo pause

echo.
echo Done.
echo   Desktop app: dist\TrimPlaylist\TrimPlaylist.exe
echo   Shortcut:    dist\TrimPlaylist\Run Trim Playlist.bat
echo   URL trim:    trim-url.bat  ^(recommended — use if UrlTrimmer.exe is missing^)
echo   URL trim exe: dist\UrlTrimmer\UrlTrimmer.exe  ^(may be removed by Windows Security^)
echo.
echo If UrlTrimmer.exe disappears, use trim-url.bat or python cut_url.py instead.
pause
exit /b 0

:failed
echo.
echo Build failed.
pause
exit /b 1
