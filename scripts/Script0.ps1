#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script de pre-validación de requisitos para AutoConfigPS

.DESCRIPTION
    Valida que el sistema cumpla con todos los requisitos necesarios antes
    de iniciar el proceso de configuración automatizada.

    Validaciones:
    - Privilegios de administrador
    - Versión de PowerShell
    - Adaptador Wi-Fi disponible
    - Winget instalado y funcional
    - Archivo config.ps1 existe
    - Credenciales configuradas (opcional)
    - Espacio en disco suficiente

.NOTES
    Autor: Json Rivera (JasRockr!)
    Versión: 1.0.0
    Fecha: 2026-01-28
    Parte de: AutoConfigPS v0.0.4

.EXAMPLE
    .\scripts\Script0.ps1
    Ejecuta todas las validaciones de requisitos
#>

param()

# ====================================
# CONFIGURACIÓN
# ====================================

$ScriptVersion = "1.0.0"
$MinPowerShellVersion = [Version]"5.1"
$MinDiskSpaceGB = 10
$ConfigPath = "$PSScriptRoot\..\config.ps1"
$SecureConfigPath = "$PSScriptRoot\..\SecureConfig"

# ====================================
# FUNCIONES AUXILIARES
# ====================================

function Write-CheckResult {
    param(
        [string]$CheckName,
        [bool]$Passed,
        [string]$Details = ""
    )

    $status = if ($Passed) { "[✓]" } else { "[✗]" }
    $color = if ($Passed) { "Green" } else { "Red" }
    $detailsText = if ($Details) { " - $Details" } else { "" }

    Write-Host "$status $CheckName$detailsText" -ForegroundColor $color
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ====================================
# BANNER
# ====================================

Clear-Host
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                                               ║" -ForegroundColor Magenta
Write-Host "║       AutoConfigPS - Pre-validación          ║" -ForegroundColor Magenta
Write-Host "║                                               ║" -ForegroundColor Magenta
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "Versión: $ScriptVersion" -ForegroundColor Gray
Write-Host "Validando requisitos del sistema..." -ForegroundColor Gray
Write-Host ""

# ====================================
# ARRAY PARA ALMACENAR RESULTADOS
# ====================================

$checks = @()

# ====================================
# VALIDACIÓN 1: PRIVILEGIOS DE ADMINISTRADOR
# ====================================

Write-SectionHeader "1. PRIVILEGIOS DE ADMINISTRADOR"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$checks += [PSCustomObject]@{
    Category = "Sistema"
    Check = "Privilegios de Administrador"
    Passed = $isAdmin
    Critical = $true
    Details = if ($isAdmin) { "Ejecutándose como administrador" } else { "Se requieren privilegios de administrador" }
}

Write-CheckResult -CheckName "Privilegios de Administrador" -Passed $isAdmin -Details $checks[-1].Details

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "INSTRUCCIONES:" -ForegroundColor Yellow
    Write-Host "  1. Cierra esta ventana" -ForegroundColor Yellow
    Write-Host "  2. Haz clic derecho en init.bat" -ForegroundColor Yellow
    Write-Host "  3. Selecciona 'Ejecutar como administrador'" -ForegroundColor Yellow
}

# ====================================
# VALIDACIÓN 2: VERSIÓN DE POWERSHELL
# ====================================

Write-SectionHeader "2. VERSIÓN DE POWERSHELL"

$psVersion = $PSVersionTable.PSVersion
$psVersionOk = $psVersion -ge $MinPowerShellVersion

$checks += [PSCustomObject]@{
    Category = "PowerShell"
    Check = "Versión de PowerShell"
    Passed = $psVersionOk
    Critical = $true
    Details = "Versión actual: $psVersion (Mínima: $MinPowerShellVersion)"
}

Write-CheckResult -CheckName "Versión de PowerShell" -Passed $psVersionOk -Details $checks[-1].Details

if (-not $psVersionOk) {
    Write-Host ""
    Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
    Write-Host "  Actualiza PowerShell a la versión $MinPowerShellVersion o superior" -ForegroundColor Yellow
    Write-Host "  Descarga: https://aka.ms/powershell-release?tag=stable" -ForegroundColor Yellow
}

# ====================================
# VALIDACIÓN 3: ADAPTADOR WI-FI
# ====================================

Write-SectionHeader "3. ADAPTADOR WI-FI"

try {
    $wifiAdapter = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -match "Wireless|Wi-Fi|802.11"
    } | Select-Object -First 1

    $wifiAvailable = $null -ne $wifiAdapter

    if ($wifiAvailable) {
        $wifiDetails = "Adaptador: $($wifiAdapter.Name) - Estado: $($wifiAdapter.Status)"
    } else {
        $wifiDetails = "No se detectó ningún adaptador Wi-Fi"
    }
} catch {
    $wifiAvailable = $false
    $wifiDetails = "Error al detectar adaptador: $($_.Exception.Message)"
}

$checks += [PSCustomObject]@{
    Category = "Red"
    Check = "Adaptador Wi-Fi"
    Passed = $wifiAvailable
    Critical = $true
    Details = $wifiDetails
}

Write-CheckResult -CheckName "Adaptador Wi-Fi" -Passed $wifiAvailable -Details $checks[-1].Details

if (-not $wifiAvailable) {
    Write-Host ""
    Write-Host "NOTA:" -ForegroundColor Yellow
    Write-Host "  Si el equipo usa conexión por cable, puedes continuar" -ForegroundColor Yellow
    Write-Host "  pero el script de configuración Wi-Fi fallará." -ForegroundColor Yellow
}

# ====================================
# VALIDACIÓN 4: WINGET INSTALADO
# ====================================

Write-SectionHeader "4. WINGET (WINDOWS PACKAGE MANAGER)"

try {
    $wingetCommand = Get-Command winget -ErrorAction Stop
    $wingetAvailable = $true

    # Intentar obtener versión
    $wingetVersionOutput = winget --version 2>&1
    if ($wingetVersionOutput -match "v(\d+\.\d+\.\d+)") {
        $wingetVersion = $matches[1]
        $wingetDetails = "Instalado - Versión: v$wingetVersion"
    } else {
        $wingetDetails = "Instalado (versión no detectada)"
    }
} catch {
    $wingetAvailable = $false
    $wingetDetails = "No instalado o no accesible"
}

$checks += [PSCustomObject]@{
    Category = "Herramientas"
    Check = "Winget"
    Passed = $wingetAvailable
    Critical = $false
    Details = $wingetDetails
}

Write-CheckResult -CheckName "Winget" -Passed $wingetAvailable -Details $checks[-1].Details

if (-not $wingetAvailable) {
    Write-Host ""
    Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
    Write-Host "  Winget viene preinstalado en Windows 11 y Windows 10 (1809+)" -ForegroundColor Yellow
    Write-Host "  Si no está disponible:" -ForegroundColor Yellow
    Write-Host "    1. Instala 'App Installer' desde Microsoft Store" -ForegroundColor Yellow
    Write-Host "    2. O descarga desde: https://aka.ms/getwinget" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  NOTA: Las instalaciones de Winget fallarán sin esta herramienta" -ForegroundColor Yellow
}

# ====================================
# VALIDACIÓN 5: ARCHIVO CONFIG.PS1
# ====================================

Write-SectionHeader "5. ARCHIVO DE CONFIGURACIÓN"

$configExists = Test-Path $ConfigPath

$checks += [PSCustomObject]@{
    Category = "Configuración"
    Check = "Archivo config.ps1"
    Passed = $configExists
    Critical = $true
    Details = if ($configExists) { "Encontrado: $ConfigPath" } else { "No encontrado: $ConfigPath" }
}

Write-CheckResult -CheckName "Archivo config.ps1" -Passed $configExists -Details $checks[-1].Details

if (-not $configExists) {
    Write-Host ""
    Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
    Write-Host "  1. Copia 'example-config.ps1' a 'config.ps1'" -ForegroundColor Yellow
    Write-Host "  2. Edita 'config.ps1' con tu configuración" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Comando rápido:" -ForegroundColor Cyan
    Write-Host "    Copy-Item '.\example-config.ps1' '.\config.ps1'" -ForegroundColor Gray
}

# ====================================
# VALIDACIÓN 6: CREDENCIALES CONFIGURADAS
# ====================================

Write-SectionHeader "6. CREDENCIALES SEGURAS (OPCIONAL)"

$secureConfigExists = Test-Path $SecureConfigPath

if ($secureConfigExists) {
    $domainCredExists = Test-Path "$SecureConfigPath\cred_domain.xml"
    $localCredExists = Test-Path "$SecureConfigPath\cred_local.xml"
    $wifiCredExists = Test-Path "$SecureConfigPath\cred_wifi.xml"

    $credDetails = @()
    if ($domainCredExists) { $credDetails += "Dominio" }
    if ($localCredExists) { $credDetails += "Local" }
    if ($wifiCredExists) { $credDetails += "Wi-Fi" }

    if ($credDetails.Count -gt 0) {
        $credSummary = "Configuradas: $($credDetails -join ', ')"
        $credPassed = $true
    } else {
        $credSummary = "Directorio existe pero sin credenciales"
        $credPassed = $false
    }
} else {
    $credSummary = "No configuradas (se usará texto plano de config.ps1)"
    $credPassed = $false
}

$checks += [PSCustomObject]@{
    Category = "Seguridad"
    Check = "Credenciales Cifradas"
    Passed = $credPassed
    Critical = $false
    Details = $credSummary
}

Write-CheckResult -CheckName "Credenciales Cifradas" -Passed $credPassed -Details $checks[-1].Details

if (-not $credPassed) {
    Write-Host ""
    Write-Host "RECOMENDACIÓN:" -ForegroundColor Yellow
    Write-Host "  Ejecuta '.\scripts\Setup-Credentials.ps1' para configurar credenciales seguras" -ForegroundColor Yellow
    Write-Host "  Esto cifrará contraseñas usando DPAPI de Windows" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ALTERNATIVA: Usa texto plano en config.ps1 (no recomendado)" -ForegroundColor Gray
}

# ====================================
# VALIDACIÓN 7: ESPACIO EN DISCO
# ====================================

Write-SectionHeader "7. ESPACIO EN DISCO"

try {
    $systemDrive = Get-PSDrive -Name ($env:SystemDrive -replace ':','') -ErrorAction Stop
    $freeSpaceGB = [Math]::Round($systemDrive.Free / 1GB, 2)
    $diskSpaceOk = $freeSpaceGB -ge $MinDiskSpaceGB

    $diskDetails = "Espacio libre: $freeSpaceGB GB (Mínimo: $MinDiskSpaceGB GB)"
} catch {
    $diskSpaceOk = $false
    $freeSpaceGB = 0
    $diskDetails = "No se pudo obtener información de disco"
}

$checks += [PSCustomObject]@{
    Category = "Sistema"
    Check = "Espacio en Disco"
    Passed = $diskSpaceOk
    Critical = $false
    Details = $diskDetails
}

Write-CheckResult -CheckName "Espacio en Disco" -Passed $diskSpaceOk -Details $checks[-1].Details

if (-not $diskSpaceOk) {
    Write-Host ""
    Write-Host "ADVERTENCIA:" -ForegroundColor Yellow
    Write-Host "  Espacio insuficiente puede causar fallos en instalación de aplicaciones" -ForegroundColor Yellow
    Write-Host "  Libera espacio antes de continuar" -ForegroundColor Yellow
}

# ====================================
# VALIDACIÓN 8: CONECTIVIDAD DE RED (BÁSICA)
# ====================================

Write-SectionHeader "8. CONECTIVIDAD DE RED"

try {
    # Verificar si hay conexión a Internet básica (ping a DNS público)
    $networkTest = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction SilentlyContinue
    $networkDetails = if ($networkTest) { "Conectividad a Internet disponible" } else { "Sin conectividad a Internet detectada" }
} catch {
    $networkTest = $false
    $networkDetails = "No se pudo verificar conectividad"
}

$checks += [PSCustomObject]@{
    Category = "Red"
    Check = "Conectividad de Red"
    Passed = $networkTest
    Critical = $false
    Details = $networkDetails
}

Write-CheckResult -CheckName "Conectividad de Red" -Passed $networkTest -Details $checks[-1].Details

if (-not $networkTest) {
    Write-Host ""
    Write-Host "NOTA:" -ForegroundColor Yellow
    Write-Host "  Sin Internet, las instalaciones de Winget fallarán" -ForegroundColor Yellow
    Write-Host "  Configura la conexión de red antes de continuar" -ForegroundColor Yellow
}

# ====================================
# RESUMEN FINAL
# ====================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║           RESUMEN DE VALIDACIÓN               ║" -ForegroundColor Magenta
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Estadísticas
$totalChecks = $checks.Count
$passedChecks = ($checks | Where-Object { $_.Passed }).Count
$failedChecks = $totalChecks - $passedChecks
$criticalChecks = ($checks | Where-Object { $_.Critical }).Count
$criticalFailed = ($checks | Where-Object { $_.Critical -and -not $_.Passed }).Count

Write-Host "Total de validaciones: $totalChecks" -ForegroundColor Cyan
Write-Host "  ✓ Pasadas: $passedChecks" -ForegroundColor Green
Write-Host "  ✗ Fallidas: $failedChecks" -ForegroundColor $(if ($failedChecks -eq 0) { "Green" } else { "Red" })
Write-Host ""
Write-Host "Validaciones críticas: $criticalChecks" -ForegroundColor Yellow
Write-Host "  ✗ Fallidas críticas: $criticalFailed" -ForegroundColor $(if ($criticalFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

# Determinar si se puede continuar
$canProceed = $criticalFailed -eq 0

if ($canProceed) {
    Write-Host "════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   ✓ SISTEMA LISTO PARA CONFIGURACIÓN" -ForegroundColor Green
    Write-Host "════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    if ($failedChecks -gt 0) {
        Write-Host "ADVERTENCIAS NO CRÍTICAS:" -ForegroundColor Yellow
        $checks | Where-Object { -not $_.Passed -and -not $_.Critical } | ForEach-Object {
            Write-Host "  ⚠ $($_.Check): $($_.Details)" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Puedes continuar, pero considera resolver estas advertencias." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "Presiona Enter para continuar con la configuración..." -ForegroundColor Cyan
    Read-Host
    exit 0

} else {
    Write-Host "════════════════════════════════════════" -ForegroundColor Red
    Write-Host "   ✗ NO SE PUEDE CONTINUAR" -ForegroundColor Red
    Write-Host "════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""

    Write-Host "PROBLEMAS CRÍTICOS ENCONTRADOS:" -ForegroundColor Red
    $checks | Where-Object { $_.Critical -and -not $_.Passed } | ForEach-Object {
        Write-Host "  ✗ $($_.Check): $($_.Details)" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "Resuelve los problemas críticos antes de continuar." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Presiona Enter para salir..." -ForegroundColor Gray
    Read-Host
    exit 1
}
