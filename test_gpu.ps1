$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -match "^PCI" } | Select-Object -First 1
if (-not $gpu) {
    $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Status -eq "OK" -and $_.Name -notmatch "Parsec|Virtual|Basic|Microsoft|Remote" } | Select-Object -First 1
}
if (-not $gpu) {
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
}
Write-Output $gpu.Name
