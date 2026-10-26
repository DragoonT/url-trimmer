# Build the Trim Playlist Android APK.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-apk.ps1
#
# Output: Android\dist\TrimPlaylist-Android.apk (debug-signed, personal testing).
# A Play Store release needs your own keystore (see Android\README.md).

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\Android")

# Gradle needs a JDK; prefer JDK 17 (the version this project builds with).
if (-not $env:JAVA_HOME) {
  $jdk = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "jdk-17*" } |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if ($jdk) {
    $env:JAVA_HOME = $jdk.FullName
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
  }
}

# Locate Gradle: project wrapper first, then a cached wrapper distribution.
$gradle = $null
if (Test-Path "gradlew.bat") { $gradle = ".\gradlew.bat" }
if (-not $gradle) {
  $dists = Get-ChildItem "$env:USERPROFILE\.gradle\wrapper\dists" -Directory -ErrorAction SilentlyContinue
  foreach ($dist in $dists) {
    $bin = Get-ChildItem $dist.FullName -Recurse -Filter "gradle.bat" -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($bin) {
      $gradle = $bin.FullName
      break
    }
  }
}
if (-not $gradle) { $gradle = "gradle" }
Write-Host "Using Gradle: $gradle"

& $gradle --no-daemon :app:assembleDebug
if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with exit code $LASTEXITCODE" }

$apk = Get-ChildItem "app\build\outputs\apk\debug\*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $apk) { throw "APK not found in app\build\outputs\apk\debug" }

New-Item -ItemType Directory -Force "dist" | Out-Null
Copy-Item $apk.FullName "dist\TrimPlaylist-Android.apk" -Force
Write-Host ""
Write-Host "APK ready: Android\dist\TrimPlaylist-Android.apk ($([math]::Round($apk.Length / 1MB, 1)) MB)"
