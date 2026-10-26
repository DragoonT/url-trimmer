@echo off
setlocal
cd /d "%~dp0"
REM Build the iOS IPA with Windows IPA Builder (iOS\dist\Trim Playlist.ipa).
set "CLI=%~dp0..\tools\WindowsIPABuilder\ipabuilder-cli.exe"
if not exist "%CLI%" set "CLI=%~dp0tools\WindowsIPABuilder\ipabuilder-cli.exe"
if not exist "%CLI%" set /p CLI=Path to ipabuilder-cli.exe: 
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iOS\build-ipa.ps1" -BuilderCli "%CLI%"
pause
