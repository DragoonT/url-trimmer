# Zip a folder tree, retrying individual files that an AV minifilter briefly
# holds open (ERROR_SHARING_VIOLATION with no persistent locker).
# Usage: zip-tree.ps1 -Source <dir> -Destination <zip>
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceFull = (Resolve-Path $Source).Path.TrimEnd("\")
if (Test-Path $Destination) { Remove-Item -Force $Destination }

$zipStream = [System.IO.File]::Open($Destination, "Create")
$zip = New-Object System.IO.Compression.ZipArchive($zipStream, "Create")
$added = 0
$failed = @()
try {
  $files = Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force
  foreach ($file in $files) {
    $entryName = $file.FullName.Substring($sourceFull.Length + 1).Replace("\", "/")
    $done = $false
    for ($attempt = 1; $attempt -le 12 -and -not $done; $attempt++) {
      try {
        $fs = [System.IO.File]::Open($file.FullName, "Open", "Read", "ReadWrite")
        try {
          $entry = $zip.CreateEntry($entryName, "Optimal")
          $es = $entry.Open()
          try { $fs.CopyTo($es) } finally { $es.Dispose() }
          $done = $true
        } finally { $fs.Dispose() }
      } catch {
        Start-Sleep -Milliseconds 400
      }
    }
    if ($done) { $added++ } else { $failed += $file.FullName }
  }
} finally {
  $zip.Dispose()
  $zipStream.Dispose()
}

if ($failed.Count -gt 0) {
  throw "Could not read $($failed.Count) file(s) after retries:`n$($failed -join "`n")"
}
Write-Host "Zipped $added files -> $Destination"
