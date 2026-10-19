param(
  [ValidateSet('windows', 'linux', 'macos')]
  [string]$Target = 'windows',
  [string]$DistPath = 'dist',
  [string]$WorkPath = 'build',
  [string]$CertificateThumbprint,
  [switch]$Installer
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$platform = [System.Environment]::OSVersion.Platform
$hostTarget = if ($platform -eq [PlatformID]::Win32NT) { 'windows' } elseif ($platform -eq [PlatformID]::MacOSX) { 'macos' } else { 'linux' }
if ($Target -ne $hostTarget) {
  throw "Build $Target on a $Target machine. PyInstaller does not cross-compile native apps."
}

python -m pip install -r requirements.txt -r requirements-build.txt
python -m PyInstaller --clean --noconfirm --distpath $DistPath --workpath $WorkPath TrimPlaylist.spec
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

function Find-SignTool {
  $command = Get-Command signtool.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
  if (Test-Path $kits) {
    return Get-ChildItem $kits -Recurse -Filter signtool.exe |
      Sort-Object FullName -Descending |
      Select-Object -First 1 -ExpandProperty FullName
  }
}

function Sign-ReleaseFile([string]$Path) {
  if (-not $CertificateThumbprint) { return }
  $signTool = Find-SignTool
  if (-not $signTool) { throw 'signtool.exe was not found. Install the Windows SDK signing tools.' }
  $certificate = Get-ChildItem "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
  if (-not $certificate) { throw "No code-signing certificate with thumbprint $CertificateThumbprint was found in Cert:\CurrentUser\My." }
  & $signTool sign /sha1 $CertificateThumbprint /fd SHA256 /tr 'http://timestamp.digicert.com' /td SHA256 $Path
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Installer) {
  if ($Target -ne 'windows') { throw 'Installer packaging is currently provided for Windows only.' }
  $iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
  if (-not $iscc) {
    $iscc = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
  }
  if (-not (Test-Path $iscc)) { throw 'Install Inno Setup 6, then run this command again with -Installer.' }
  $appDir = Join-Path (Join-Path $root $DistPath) 'TrimPlaylist'
  if (-not (Test-Path (Join-Path $appDir 'TrimPlaylist.exe'))) {
    throw "Expected packaged app at $appDir"
  }
  Sign-ReleaseFile (Join-Path $appDir 'TrimPlaylist.exe')
  & $iscc "/DSourceDir=$appDir" (Join-Path $root 'packaging\TrimPlaylist.iss')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Sign-ReleaseFile (Join-Path $root 'dist\installer\TrimPlaylist-Setup.exe')
}
