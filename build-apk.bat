@echo off
setlocal EnableExtensions
cd /d "%~dp0"

REM Build the Android APK (Android\dist\TrimPlaylist-Android.apk).
REM Prefers the per-user Temurin JDK 17 and SDK under %USERPROFILE%.

if not defined JAVA_HOME (
  if exist "C:\Users\rtodsan\tools\jdk\bin\java.exe" (
    set "JAVA_HOME=C:\Users\rtodsan\tools\jdk"
  )
)
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"

if not exist "C:\Users\rtodsan\Android\Sdk" (
  echo Android SDK not found at C:\Users\rtodsan\Android\Sdk
  echo Install Android Studio: https://developer.android.com/studio
  echo Or run: C:\Users\rtodsan\tools\install-android-sdk.ps1
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-apk.ps1" %*
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo Build failed with exit code %ERR%
  pause
  exit /b %ERR%
)

echo.
pause
exit /b 0
