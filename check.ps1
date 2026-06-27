$content = Get-Content 'C:\Users\Filipe\Downloads\otimizador\Otimizador_Windows.ps1' -Raw
$tokens = $null
$errors = $null
[System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors) | Out-Null
if ($errors.Count -eq 0) {
    Write-Host "SEM ERROS DE SINTAXE!" -ForegroundColor Green
} else {
    foreach ($e in $errors) {
        Write-Host "Linha $($e.Token.StartLine): $($e.Message)" -ForegroundColor Red
    }
}
