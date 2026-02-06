# Script de verificación de archivos actualizados
# Ejecuta esto ANTES de copiar al equipo de pruebas

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VERIFICACIÓN DE ARCHIVOS ACTUALIZADOS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()

# Verificar archivos críticos
$criticalFiles = @(
    @{Path=".\config.ps1"; Contains="cred_domain.json"; Description="config.ps1 usa formato JSON (no XML)"}
    @{Path=".\config.ps1"; Contains="SecureCredentialManager.ps1"; Description="config.ps1 importa SecureCredentialManager"}
    @{Path=".\config.ps1"; Contains="Import-SecureCredential"; Description="config.ps1 usa Import-SecureCredential"}
    @{Path=".\scripts\SecureCredentialManager.ps1"; Contains="Export-SecureCredential"; Description="Módulo SecureCredentialManager existe"}
    @{Path=".\scripts\Setup-Credentials.ps1"; Contains="cred_domain.json"; Description="Setup-Credentials usa formato JSON"}
    @{Path=".\scripts\Script1.ps1"; Contains="Set-Location -Path"; Description="Script1 cambia directorio de trabajo"}
    @{Path=".\scripts\Script2.ps1"; Contains="Set-Location -Path"; Description="Script2 cambia directorio de trabajo"}
)

foreach ($check in $criticalFiles) {
    if (Test-Path $check.Path) {
        $content = Get-Content $check.Path -Raw
        if ($content -match [regex]::Escape($check.Contains)) {
            Write-Host "[OK] $($check.Description)" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] $($check.Description) - NO encontrado" -ForegroundColor Red
            $errors += $check.Description
        }
    } else {
        Write-Host "[ERROR] Archivo no existe: $($check.Path)" -ForegroundColor Red
        $errors += "Falta archivo: $($check.Path)"
    }
}

Write-Host ""

# Verificar archivos antiguos que NO deberían existir en equipo de pruebas
Write-Host "Verificando que no existan archivos antiguos en SecureConfig..." -ForegroundColor Cyan
if (Test-Path ".\SecureConfig\cred_domain.xml") {
    Write-Host "[ADVERTENCIA] Existe cred_domain.xml antiguo - ELIMÍNALO del equipo de pruebas" -ForegroundColor Yellow
    $warnings += "Eliminar SecureConfig\cred_domain.xml del equipo de pruebas"
}
if (Test-Path ".\SecureConfig\cred_wifi.xml") {
    Write-Host "[ADVERTENCIA] Existe cred_wifi.xml antiguo - ELIMÍNALO del equipo de pruebas" -ForegroundColor Yellow
    $warnings += "Eliminar SecureConfig\cred_wifi.xml del equipo de pruebas"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0) {
    Write-Host "[OK] Todos los archivos están actualizados correctamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "SIGUIENTE PASO:" -ForegroundColor Cyan
    Write-Host "1. Copia TODA la carpeta AutoConfigPS al equipo de pruebas" -ForegroundColor White
    Write-Host "2. En el equipo de pruebas, ELIMINA la carpeta SecureConfig si existe" -ForegroundColor White
    Write-Host "3. Ejecuta Setup-Credentials.ps1" -ForegroundColor White
    Write-Host "4. Ejecuta init.bat" -ForegroundColor White
} else {
    Write-Host "[ERROR] Se encontraron $($errors.Count) errores:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - $err" -ForegroundColor Yellow
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "[ADVERTENCIA] Acciones requeridas en equipo de pruebas:" -ForegroundColor Yellow
    foreach ($warn in $warnings) {
        Write-Host "  - $warn" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Presiona Enter para salir..." -ForegroundColor Gray
Read-Host
