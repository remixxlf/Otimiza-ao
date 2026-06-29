$asciiFile = 'C:\Users\Filipe\Downloads\ascii-art.txt'
$scriptFile = 'C:\Users\Filipe\Documents\otimizador\Otimizador_Windows.ps1'
$asciiContent = Get-Content $asciiFile -Raw
$newBanner = "function Show-Banner {`r`n    Clear-Host`r`n    Write-Host `"`"`r`n`$asciiArt = @'`r`n" + $asciiContent + "`r`n'@`r`n    Write-Host `$asciiArt -ForegroundColor Cyan`r`n    Write-Host `"`"`r`n    Write-Host `"  ========================================================`" -ForegroundColor Magenta`r`n    Write-Host `"          ⚡ OTIMIZADOR ZERO-CLICK (v3.0) ⚡            `" -ForegroundColor Yellow`r`n    Write-Host `"  ========================================================`" -ForegroundColor Magenta`r`n    Write-Host `"`"`r`n    Write-Host `"  Iniciando Otimizacao Extrema Automatica em 3 segundos...`" -ForegroundColor Red`r`n    Start-Sleep -Seconds 3`r`n}"
$scriptContent = Get-Content $scriptFile -Raw
$pattern = '(?s)function Show-Banner \{.*?\s*Start-Sleep -Seconds 3\r?\n\}'
$newScriptContent = [regex]::Replace($scriptContent, $pattern, $newBanner)
Set-Content -Path $scriptFile -Value $newScriptContent -Encoding UTF8
