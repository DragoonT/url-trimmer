param(
  [Parameter(Mandatory = $true)]
  [string]$BuilderCli
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $PSScriptRoot 'Sources'
$output = Join-Path $PSScriptRoot 'dist'
$icon = Join-Path $root 'browser-extension\icon128.png'

if (-not (Test-Path $BuilderCli)) { throw "Windows IPA Builder CLI was not found: $BuilderCli" }
if (-not (Test-Path $icon)) { throw "App icon was not found: $icon" }
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $BuilderCli toolchain
if ($LASTEXITCODE -ne 0) { throw 'Windows IPA Builder toolchain is not ready.' }

& $BuilderCli build `
  --source $source `
  --name 'Trim Playlist' `
  --bundle-id 'com.dragoon.trimplaylist' `
  --developer 'DragoonT' `
  --version '0.1.0' `
  --build-number '1' `
  --min-ios '16.5' `
  --framework UIKit `
  --framework Foundation `
  --framework CoreGraphics `
  --framework AVFoundation `
  --framework CoreMedia `
  --framework QuartzCore `
  --framework WebKit `
  --framework MediaPlayer `
  --icon $icon `
  --output $output

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ipa = Join-Path $output 'Trim Playlist.ipa'
python (Join-Path $PSScriptRoot 'add_url_scheme.py') $ipa
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
