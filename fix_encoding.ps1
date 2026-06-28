$content = Get-Content '.\Otimizador_Windows.ps1' -Raw -Encoding UTF8
$utf8BOM = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText('.\Otimizador_Windows.ps1', $content, $utf8BOM)
Write-Host "Salvo com UTF-8 BOM" -ForegroundColor Green
