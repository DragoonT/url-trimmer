# Build the Trim Playlist Android APK.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-apk.ps1
#   build-apk.bat
#
# Output: Android\dist\TrimPlaylist-Android.apk (debug-signed, personal testing).
# A Play Store release needs your own keystore (see Android\README.md).

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$AndroidDir = Join-Path $Root "Android"
$Tools = "C:\Users\rtodsan\tools"
$Sdk = "C:\Users\rtodsan\Android\Sdk"
$GradleVersion = "8.9"
# Official checksum from https://gradle.org/release-checksums/
$GradleSha256 = "d725d707bfabd4dfdc958c624003b3c80accc03f7037b5122c4b1d0ef15cecab"
$GradleUrl = "https://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip"

Set-Location $AndroidDir

function Find-Jdk17 {
  $candidates = @()
  if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
  $candidates += (Join-Path $Tools "jdk")
  $adoptium = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "jdk-17*" } |
    Sort-Object Name -Descending
  foreach ($jdk in $adoptium) { $candidates += $jdk.FullName }
  $microsoft = Get-ChildItem "C:\Program Files\Microsoft" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "jdk-17*" }
  foreach ($jdk in $microsoft) { $candidates += $jdk.FullName }
  foreach ($jdkPath in $candidates | Select-Object -Unique) {
    $java = Join-Path $jdkPath "bin\java.exe"
    if (-not (Test-Path $java)) { continue }
    $ver = cmd /c "`"$java`" -version 2>&1"
    if ("$ver" -match 'version "17\.') { return $jdkPath }
  }
  return $null
}

function Ensure-LocalProperties([string]$sdkDir) {
  $props = Join-Path $AndroidDir "local.properties"
  # local.properties wants escaped backslashes for Gradle on Windows.
  $escaped = $sdkDir.Replace('\', '\\')
  Set-Content -Path $props -Value "sdk.dir=$escaped" -Encoding ASCII
  Write-Host "Wrote local.properties -> $sdkDir"
}

function Find-Gradle {
  if (Test-Path (Join-Path $AndroidDir "gradlew.bat")) {
    return (Join-Path $AndroidDir "gradlew.bat")
  }
  $toolGradle = Join-Path $Tools "gradle-$GradleVersion\bin\gradle.bat"
  if (Test-Path $toolGradle) { return $toolGradle }
  $dists = Get-ChildItem "$env:USERPROFILE\.gradle\wrapper\dists" -Directory -ErrorAction SilentlyContinue
  foreach ($dist in $dists) {
    $bin = Get-ChildItem $dist.FullName -Recurse -Filter "gradle.bat" -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($bin) { return $bin.FullName }
  }
  return $null
}

function Install-Gradle {
  $dest = Join-Path $Tools "gradle-$GradleVersion"
  $bat = Join-Path $dest "bin\gradle.bat"
  if (Test-Path $bat) { return $bat }

  New-Item -ItemType Directory -Force -Path (Join-Path $Tools "downloads") | Out-Null
  $zip = Join-Path $Tools "downloads\gradle-$GradleVersion-bin.zip"
  $needDownload = $true
  if (Test-Path $zip) {
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -eq $GradleSha256) { $needDownload = $false }
  }
  if ($needDownload) {
    Write-Host "Downloading official Gradle $GradleVersion"
    Write-Host "  URL: $GradleUrl"
    Write-Host "  SHA256: $GradleSha256"
    & curl.exe -L --fail --retry 3 --retry-delay 2 -o $zip $GradleUrl
    if ($LASTEXITCODE -ne 0) { throw "Gradle download failed (exit $LASTEXITCODE)" }
  }
  $hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($hash -ne $GradleSha256) {
    throw "Gradle checksum mismatch: got $hash expected $GradleSha256"
  }
  Write-Host "Gradle checksum OK"

  $extract = Join-Path $Tools "downloads\gradle-extract"
  if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
  New-Item -ItemType Directory -Force -Path $extract | Out-Null
  Expand-Archive -Path $zip -DestinationPath $extract -Force
  $inner = Get-ChildItem $extract -Directory | Select-Object -First 1
  if (-not $inner) { throw "Gradle zip had no directory" }
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  Move-Item $inner.FullName $dest
  if (-not (Test-Path $bat)) { throw "gradle.bat missing after extract" }
  return $bat
}

function Ensure-AndroidPlatform([string]$sdkDir, [string]$api) {
  $platform = Join-Path $sdkDir "platforms\android-$api"
  if (Test-Path $platform) { return }
  $sdkmanager = Join-Path $sdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
  if (-not (Test-Path $sdkmanager)) {
    throw "Android platform android-$api is missing and sdkmanager was not found. Install Android Studio or platform android-$api."
  }
  Write-Host "Installing Android SDK platform android-$api (official Google sdkmanager)"
  $yes = Join-Path $Tools "downloads\yes.txt"
  if (-not (Test-Path $yes)) { Set-Content -Path $yes -Value "y`r`ny`r`ny`r`n" }
  cmd /c "type `"$yes`" | `"$sdkmanager`" --sdk_root=`"$sdkDir`" `"platforms;android-$api`""
  if (-not (Test-Path $platform)) {
    throw "Failed to install platforms;android-$api"
  }
}

# --- JDK ---
$jdkHome = Find-Jdk17
if (-not $jdkHome) {
  throw @"
JDK 17 not found.
Install Temurin 17 from:
  https://adoptium.net/temurin/releases/?version=17&os=windows&arch=x64&package=jdk
Or run: C:\Users\rtodsan\tools\install-android-sdk.ps1
"@
}
$env:JAVA_HOME = $jdkHome
$env:PATH = "$jdkHome\bin;$env:PATH"
Write-Host "Using JDK: $jdkHome"
cmd /c "`"$jdkHome\bin\java.exe`" -version 2>&1"

# --- SDK ---
if (-not (Test-Path $Sdk)) {
  throw @"
Android SDK not found at $Sdk
Install Android Studio from:
  https://developer.android.com/studio
Or run: C:\Users\rtodsan\tools\install-android-sdk.ps1
"@
}
$env:ANDROID_HOME = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
Ensure-LocalProperties $Sdk

# compileSdk 35 needs this platform package
Ensure-AndroidPlatform $Sdk "35"

# --- Gradle ---
$gradle = Find-Gradle
if (-not $gradle) {
  Write-Host "Gradle not on PATH / no project wrapper — fetching official Gradle $GradleVersion"
  $gradle = Install-Gradle
}
Write-Host "Using Gradle: $gradle"

$env:ORG_GRADLE_JAVA_HOME = $jdkHome
cmd /c "`"$gradle`" --no-daemon :app:assembleDebug"
if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with exit code $LASTEXITCODE" }

$apk = Get-ChildItem "app\build\outputs\apk\debug\*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $apk) { throw "APK not found in app\build\outputs\apk\debug" }

New-Item -ItemType Directory -Force "dist" | Out-Null
Copy-Item $apk.FullName "dist\TrimPlaylist-Android.apk" -Force
$docsApk = Join-Path $Root "docs\downloads\Android\TrimPlaylist-Android.apk"
if (Test-Path (Split-Path $docsApk -Parent)) {
  Copy-Item $apk.FullName $docsApk -Force
}

Write-Host ""
Write-Host "APK ready: Android\dist\TrimPlaylist-Android.apk ($([math]::Round($apk.Length / 1MB, 1)) MB)"
