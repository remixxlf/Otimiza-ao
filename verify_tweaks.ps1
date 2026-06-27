$results = @()
$results += "=== VERIFICACAO DE OTIMIZACOES ==="

$gameMode = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -ErrorAction SilentlyContinue).AutoGameModeEnabled
$results += "Game Mode (1=ON): $gameMode"

$hags = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction SilentlyContinue).HwSchMode
$results += "HAGS (2=ON): $hags"

$mouseSpeed = (Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -ErrorAction SilentlyContinue).MouseSpeed
$results += "Mouse Speed (0=OFF): $mouseSpeed"

$networkThrottling = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -ErrorAction SilentlyContinue).NetworkThrottlingIndex
$results += "Network Throttling (-1/4294967295=OFF): $networkThrottling"

$diagTrack = (Get-Service -Name 'DiagTrack' -ErrorAction SilentlyContinue).Status
$results += "DiagTrack (Telemetria) Status: $diagTrack"

$powerPlan = powercfg /getactivescheme
$results += "Power Plan: $powerPlan"

$results | Out-Host
