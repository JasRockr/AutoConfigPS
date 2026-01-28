# Script de validación de sintaxis
param([string]$ScriptPath)

try {
    $errors = $null
    $tokens = $null
    $content = Get-Content $ScriptPath -Raw

    $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)

    if ($errors.Count -eq 0) {
        Write-Host "[OK] Sintaxis correcta: $ScriptPath" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[ERROR] Errores de sintaxis encontrados:" -ForegroundColor Red
        $errors | ForEach-Object {
            Write-Host "  Linea $($_.Token.StartLine): $($_.Message)" -ForegroundColor Yellow
        }
        exit 1
    }
} catch {
    Write-Host "[ERROR] No se pudo validar: $_" -ForegroundColor Red
    exit 1
}
