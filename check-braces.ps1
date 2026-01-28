# Contar llaves en archivo
$content = Get-Content ".\scripts\Script0.ps1" -Raw

$open = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$close = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count

Write-Host "Llaves de apertura: $open" -ForegroundColor Cyan
Write-Host "Llaves de cierre: $close" -ForegroundColor Cyan

if ($open -eq $close) {
    Write-Host "Balanceadas: OK" -ForegroundColor Green
} else {
    Write-Host "DESBALANCEADAS - Diferencia: $($open - $close)" -ForegroundColor Red
}

# Buscar líneas con llaves desbalanceadas
$lines = Get-Content ".\scripts\Script0.ps1"
$balance = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $openInLine = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closeInLine = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $balance += ($openInLine - $closeInLine)

    if ($balance -lt 0) {
        Write-Host "Linea $($i+1): Balance negativo ($balance) - Mas cierres que aperturas" -ForegroundColor Red
        Write-Host "  $line" -ForegroundColor Yellow
    }
}

if ($balance -ne 0) {
    Write-Host "Balance final: $balance (deberia ser 0)" -ForegroundColor Red
}
