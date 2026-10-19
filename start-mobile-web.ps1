param([int]$Port = 8765)

Set-Location $PSScriptRoot
$address = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
  Select-Object -First 1 -ExpandProperty IPAddress

if (-not $address) {
  Write-Warning 'No Wi-Fi or LAN IPv4 address was found. Connect this PC and phone to the same network first.'
} else {
  Write-Host "\nOpen this on your phone: http://$address`:$Port/" -ForegroundColor Cyan
  Write-Host 'Keep this window open while using Trim Playlist from your phone.'
  Write-Host 'Allow Python through Windows Firewall on Private networks if Windows asks.'
}

python playlist_server.py --host 0.0.0.0 --port $Port --no-open
