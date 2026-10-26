# Build Trim Playlist with the Tauri shell (portable exe + NSIS setup).
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-tauri.ps1
#
# Outputs:
#   src-tauri\target\release\bundle\nsis\Trim Playlist_<version>_x64-setup.exe
#   dist-tauri\TrimPlaylist-Setup.exe           (renamed copy of the above)
#   dist-tauri\TrimPlaylist-Windows.zip          (portable: exe + resources)
#
# The macOS .dmg is built by .github/workflows/build-tauri.yml on a Mac runner;
# Tauri cannot cross-compile macOS bundles from Windows.

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

# A running instance locks files packaging needs to overwrite (base_library.zip,
# _socket.pyd). Close both processes before rebuilding.
Get-Process -Name "TrimPlaylistServer", "Trim Playlist" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

# Delete a folder that may be locked by a running app or a virus-scanner
# filter: close the processes again and retry before giving up.
function Remove-TreeRetry([string]$path) {
  for ($attempt = 1; $attempt -le 6; $attempt++) {
    Get-Process -Name "TrimPlaylistServer", "Trim Playlist" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    try {
      if (Test-Path $path) {
        Remove-Item -Recurse -Force $path -ErrorAction Stop
      }
      return
    } catch {
      Write-Host "  $path is locked (attempt $attempt of 6) - close Trim Playlist and wait..."
      Start-Sleep -Seconds 3
    }
  }
  throw "Could not remove $path. Close Trim Playlist (and its server window) and run the build again."
}

Write-Host "Installing Python dependencies..."
python -m pip install -r requirements.txt -r requirements-build.txt
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nBuilding the headless server sidecar (PyInstaller)..."
python -m PyInstaller --clean --noconfirm TrimPlaylistServer.spec
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nStaging the sidecar into src-tauri/resources/server ..."
Remove-TreeRetry "src-tauri\resources\server"
New-Item -ItemType Directory -Force "src-tauri\resources\server" | Out-Null
robocopy "dist\TrimPlaylistServer" "src-tauri\resources\server\TrimPlaylistServer" /E /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
$global:LASTEXITCODE = 0

Write-Host "`nInstalling the Tauri CLI..."
pnpm install
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nBuilding the Tauri app (NSIS setup)..."
pnpm tauri build --bundles nsis
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nAssembling the portable exe..."
$release = "src-tauri\target\release"
$portable = "dist-tauri\TrimPlaylist"
Remove-TreeRetry "dist-tauri"
New-Item -ItemType Directory -Force "$portable\resources" | Out-Null
Copy-Item "$release\Trim Playlist.exe" "$portable\Trim Playlist.exe"
robocopy "src-tauri\resources\server" "$portable\resources\server" /E /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy (portable) failed with exit code $LASTEXITCODE" }
$global:LASTEXITCODE = 0

$setup = Get-ChildItem "$release\bundle\nsis\*-setup.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($setup) {
  Copy-Item $setup.FullName "dist-tauri\TrimPlaylist-Setup.exe"
} else {
  throw "NSIS setup exe not found in $release\bundle\nsis"
}
# Antivirus filters briefly hold freshly written files (sharing violations with
# no persistent locker). zip-tree.ps1 retries each file individually.
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\zip-tree.ps1" -Source "$portable" -Destination "dist-tauri\TrimPlaylist-Windows.zip"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nDone. Artifacts in dist-tauri\:"
Get-ChildItem "dist-tauri" | ForEach-Object { Write-Host ("  " + $_.Name) }
Write-Host "`nNSIS bundle:"
Get-ChildItem "$release\bundle\nsis" | ForEach-Object { Write-Host ("  " + $_.FullName) }
