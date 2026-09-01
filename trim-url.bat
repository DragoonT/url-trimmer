@echo off
title URL Trimmer
cd /d "%~dp0"

if exist "%~dp0dist\UrlTrimmer\UrlTrimmer.exe" (
  "%~dp0dist\UrlTrimmer\UrlTrimmer.exe" --config setlist.json
  goto done
)

python cut_url.py --config setlist.json
if errorlevel 1 (
  echo.
  echo Failed. Install Python deps: pip install -r requirements.txt
)

:done
echo.
pause
