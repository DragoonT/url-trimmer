Set-Location $PSScriptRoot

Write-Host "Installing dependencies..."
python -m pip install -r requirements.txt -r requirements-build.txt
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nBuilding TrimPlaylist.exe ..."
python -m PyInstaller --noconfirm TrimPlaylist.spec
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nBuilding UrlTrimmer.exe ..."
python -m PyInstaller --noconfirm UrlTrimmer.spec
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "`nDone."
Write-Host "  Desktop app: dist\TrimPlaylist\TrimPlaylist.exe"
Write-Host "  Trimmer CLI: dist\UrlTrimmer\UrlTrimmer.exe"
