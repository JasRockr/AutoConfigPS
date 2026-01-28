# Script de prueba para verificar el escape de contraseñas Wi-Fi
# Uso: .\test-password-escape.ps1

Write-Host "==============================================
" -ForegroundColor Cyan
Write-Host "   Test de Escape de Contraseña Wi-Fi       " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# Solicitar contraseña de prueba
Write-Host "Ingresa la contraseña Wi-Fi para probar el escape:" -ForegroundColor Yellow
$testPassword = Read-Host -AsSecureString

# Convertir a texto plano
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($testPassword)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

Write-Host ""
Write-Host "==================== RESULTADOS ====================" -ForegroundColor Green
Write-Host ""

# Mostrar contraseña original
Write-Host "Contraseña original:" -ForegroundColor Cyan
Write-Host "  $plainPassword" -ForegroundColor White
Write-Host ""

# Aplicar escape XML
$escapedPassword = [System.Security.SecurityElement]::Escape($plainPassword)

Write-Host "Contraseña escapada para XML:" -ForegroundColor Cyan
Write-Host "  $escapedPassword" -ForegroundColor White
Write-Host ""

# Verificar si hubo cambios
if ($plainPassword -eq $escapedPassword) {
    Write-Host "[OK] La contraseña NO contiene caracteres especiales XML" -ForegroundColor Green
    Write-Host "     No se requiere escape especial" -ForegroundColor Gray
} else {
    Write-Host "[!] La contraseña CONTIENE caracteres especiales XML" -ForegroundColor Yellow
    Write-Host "    Se aplicaron los siguientes escapes:" -ForegroundColor Gray
    Write-Host "      < -> &lt;" -ForegroundColor Gray
    Write-Host "      > -> &gt;" -ForegroundColor Gray
    Write-Host "      & -> &amp;" -ForegroundColor Gray
    Write-Host '      " -> &quot;' -ForegroundColor Gray
    Write-Host "      ' -> &apos;" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==================== ANALISIS =====================" -ForegroundColor Magenta
Write-Host ""

# Analizar caracteres individuales
$specialChars = @{
    '<' = 'Menor que'
    '>' = 'Mayor que'
    '&' = 'Ampersand'
    '"' = 'Comillas dobles'
    "'" = 'Comilla simple'
    '/' = 'Slash (barra inclinada)'
    '\' = 'Backslash (barra invertida)'
    ' ' = 'Espacio'
    '$' = 'Signo de dolar'
    '@' = 'Arroba'
    '#' = 'Numeral'
    '%' = 'Porcentaje'
    '^' = 'Circunflejo'
    '*' = 'Asterisco'
}

$foundChars = @()
foreach ($char in $specialChars.Keys) {
    if ($plainPassword.Contains($char)) {
        $foundChars += "$char ($($specialChars[$char]))"
    }
}

if ($foundChars.Count -gt 0) {
    Write-Host "Caracteres especiales detectados:" -ForegroundColor Yellow
    foreach ($char in $foundChars) {
        Write-Host "  - $char" -ForegroundColor White
    }
} else {
    Write-Host "No se detectaron caracteres especiales comunes" -ForegroundColor Green
}

Write-Host ""
Write-Host "Longitud de la contraseña: $($plainPassword.Length) caracteres" -ForegroundColor Cyan

# Limpiar variables sensibles
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
Remove-Variable -Name plainPassword, escapedPassword, testPassword -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Presiona Enter para salir..."
Read-Host
