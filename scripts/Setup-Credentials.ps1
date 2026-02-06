#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script de configuracion inicial de credenciales para AutoConfigPS

.DESCRIPTION
    Este script ayuda a generar credenciales cifradas usando DPAPI de Windows.
    Las credenciales se almacenan cifradas y solo pueden ser leidas por el usuario
    y maquina que las creo.

.NOTES
    Autor: Json Rivera (JasRockr!)
    Version: 1.0.1
    Fecha: 2026-02-06

    IMPORTANTE:
    - Debe ejecutarse con privilegios de administrador
    - Las credenciales solo seran validas en este equipo con este usuario
    - Para uso en multiples equipos, ejecutar este script en cada uno
    
    CHANGELOG v1.0.1:
    - Agregada configuracion automatica de ExecutionPolicy

.EXAMPLE
    .\Setup-Credentials.ps1
    Ejecuta el asistente interactivo de configuracion
#>

param()

# ====================================
# CONFIGURAR EXECUTION POLICY
# ====================================

Write-Host ""
Write-Host "Verificando politica de ejecucion de scripts..." -ForegroundColor Cyan

try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    
    if ($currentPolicy -ne "Bypass" -and $currentPolicy -ne "Unrestricted") {
        Write-Host "  Politica actual: $currentPolicy" -ForegroundColor Yellow
        Write-Host "  Configurando ExecutionPolicy a Bypass para usuario actual..." -ForegroundColor Yellow
        
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction Stop
        
        $newPolicy = Get-ExecutionPolicy -Scope CurrentUser
        Write-Host "  [OK] ExecutionPolicy configurada: $newPolicy" -ForegroundColor Green
        Write-Host "  Los scripts se ejecutaran sin restricciones para este usuario" -ForegroundColor Gray
    } else {
        Write-Host "  [OK] ExecutionPolicy ya permite ejecucion: $currentPolicy" -ForegroundColor Green
    }
} catch {
    Write-Host "  [!] No se pudo configurar ExecutionPolicy automaticamente" -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Configura manualmente con:" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Presiona Enter para continuar..." -ForegroundColor Yellow
    Read-Host
}

Write-Host ""

# ====================================
# CONFIGURACION
# ====================================

$ScriptVersion = "1.0.0"
$SecureConfigPath = "$PSScriptRoot\..\SecureConfig"

# Importar módulo de gestión segura de credenciales
. "$PSScriptRoot\SecureCredentialManager.ps1"

# ====================================
# FUNCIONES AUXILIARES
# ====================================

function Write-ColoredMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Header")]
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Header"  { "Magenta" }
    }

    $prefix = switch ($Type) {
        "Info"    { "[INFO]" }
        "Success" { "[OK]" }
        "Warning" { "[!]" }
        "Error"   { "[ERROR]" }
        "Header"  { "===" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-CredentialValid {
    param([PSCredential]$Credential)

    if (-not $Credential) { return $false }
    if ([string]::IsNullOrWhiteSpace($Credential.UserName)) { return $false }
    if ($Credential.Password.Length -eq 0) { return $false }

    return $true
}

# ====================================
# BANNER
# ====================================

Clear-Host
Write-Host ""
Write-ColoredMessage "AutoConfigPS - Configuracion de Credenciales Seguras" -Type Header
Write-Host "Version: $ScriptVersion" -ForegroundColor Gray
Write-Host ""
Write-ColoredMessage "Este asistente te guiara en la configuracion de credenciales cifradas" -Type Info
Write-ColoredMessage "Las credenciales se cifraran usando DPAPI de Windows" -Type Info
Write-Host ""

# ====================================
# VERIFICAR PRIVILEGIOS
# ====================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColoredMessage "Este script requiere privilegios de administrador" -Type Error
    Write-Host ""
    Write-Host "Por favor, ejecuta como administrador y vuelve a intentar." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 1
}

# ====================================
# CREAR DIRECTORIO SEGURO
# ====================================

Write-ColoredMessage "Preparando directorio de configuracion segura..." -Type Info

if (-not (Test-Path $SecureConfigPath)) {
    try {
        New-Item -ItemType Directory -Path $SecureConfigPath -Force | Out-Null
        Write-ColoredMessage "Directorio creado: $SecureConfigPath" -Type Success
    } catch {
        Write-ColoredMessage "Error al crear directorio: $_" -Type Error
        Read-Host "Presiona Enter para salir"
        exit 1
    }
}

# Establecer permisos restrictivos (solo Administradores y SYSTEM)
try {
    icacls $SecureConfigPath /inheritance:r /grant "BUILTIN\Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" | Out-Null
    Write-ColoredMessage "Permisos restrictivos aplicados" -Type Success
} catch {
    Write-ColoredMessage "Advertencia: No se pudieron establecer permisos restrictivos" -Type Warning
}

# Generar clave AES compartida (compatible con SYSTEM)
$keyPath = "$SecureConfigPath\.aeskey"
if (-not (Test-Path $keyPath)) {
    Write-Host ""
    Write-ColoredMessage "Generando clave de cifrado compartida..." -Type Info
    $aesKey = New-SecureKey
    [System.IO.File]::WriteAllBytes($keyPath, $aesKey)
    Protect-CredentialFiles -Path $keyPath | Out-Null
    Write-ColoredMessage "Clave de cifrado creada" -Type Success
} else {
    Write-Host ""
    Write-ColoredMessage "Usando clave de cifrado existente" -Type Info
    $aesKey = [System.IO.File]::ReadAllBytes($keyPath)
}

Write-Host ""

# ====================================
# CREDENCIALES DE DOMINIO
# ====================================

Write-ColoredMessage "PASO 1: Credenciales de Administrador de Dominio" -Type Header
Write-Host ""
Write-Host "Ingresa las credenciales del usuario con permisos para unir equipos al dominio." -ForegroundColor Gray
Write-Host "Formato del usuario: DOMINIO\usuario o usuario@dominio.local" -ForegroundColor Gray
Write-Host ""

$domainCredPath = "$SecureConfigPath\cred_domain.json"
$domainCredValid = $false

while (-not $domainCredValid) {
    try {
        $domainCred = Get-Credential -Message "Credenciales de Administrador de Dominio"

        if (Test-CredentialValid -Credential $domainCred) {
            # Guardar credenciales cifradas con AES (compatible con SYSTEM)
            Export-SecureCredential -Credential $domainCred -Path $domainCredPath -Key $aesKey
            Protect-CredentialFiles -Path $domainCredPath | Out-Null

            # Verificar que se guard\u00f3 correctamente
            if (Test-Path $domainCredPath) {
                # Intentar leer para validar
                $testCred = Import-SecureCredential -Path $domainCredPath -Key $aesKey
                if (Test-CredentialValid -Credential $testCred) {
                    Write-ColoredMessage "Credenciales de dominio guardadas correctamente" -Type Success
                    Write-Host "Ubicaci\u00f3n: $domainCredPath" -ForegroundColor Gray
                    $domainCredValid = $true
                } else {
                    throw "Error al validar credenciales guardadas"
                }
            } else {
                throw "Error al guardar archivo de credenciales"
            }
        } else {
            Write-ColoredMessage "Credenciales invalidas o canceladas" -Type Warning
            $retry = Read-Host "¿Intentar nuevamente? (S/N)"
            if ($retry -notmatch "^[Ss]") {
                Write-ColoredMessage "Configuracion cancelada por el usuario" -Type Warning
                exit 0
            }
        }
    } catch {
        Write-ColoredMessage "Error al procesar credenciales: $_" -Type Error
        $retry = Read-Host "¿Intentar nuevamente? (S/N)"
        if ($retry -notmatch "^[Ss]") {
            Write-ColoredMessage "Configuracion cancelada por el usuario" -Type Warning
            exit 0
        }
    }
}

Write-Host ""

# ====================================
# USUARIO LOCAL
# ====================================

Write-ColoredMessage "PASO 2: Credenciales de Usuario Local (Opcional)" -Type Header
Write-Host ""
Write-Host "Si deseas configurar autologin temporal con usuario local," -ForegroundColor Gray
Write-Host "ingresa las credenciales. De lo contrario, presiona Cancelar." -ForegroundColor Gray
Write-Host ""

$localCredPath = "$SecureConfigPath\cred_local.json"

try {
    $localCred = Get-Credential -Message "Credenciales de Usuario Local (Opcional - Cancelar para omitir)"

    if (Test-CredentialValid -Credential $localCred) {
        Export-SecureCredential -Credential $localCred -Path $localCredPath -Key $aesKey
        Protect-CredentialFiles -Path $localCredPath | Out-Null

        if (Test-Path $localCredPath) {
            Write-ColoredMessage "Credenciales de usuario local guardadas correctamente" -Type Success
            Write-Host "Ubicación: $localCredPath" -ForegroundColor Gray
        }
    } else {
        Write-ColoredMessage "Credenciales de usuario local omitidas" -Type Info
    }
} catch {
    Write-ColoredMessage "Credenciales de usuario local omitidas" -Type Info
}

Write-Host ""

# ====================================
# CONTRASENA DE WI-FI
# ====================================

Write-ColoredMessage "PASO 3: Contrasena de Red Wi-Fi" -Type Header
Write-Host ""
Write-Host "Ingresa la contrasena de la red Wi-Fi corporativa." -ForegroundColor Gray
Write-Host "El SSID se configurara en config.ps1" -ForegroundColor Gray
Write-Host ""

$wifiCredPath = "$SecureConfigPath\cred_wifi.json"
$wifiCredValid = $false

while (-not $wifiCredValid) {
    try {
        $wifiCred = Get-Credential -UserName "WiFi-Password" -Message "Contraseña de Red Wi-Fi (usar campo de contraseña)"

        if ($wifiCred -and $wifiCred.Password.Length -gt 0) {
            # Guardar contraseña cifrada con AES
            Export-SecureCredential -Credential $wifiCred -Path $wifiCredPath -Key $aesKey
            Protect-CredentialFiles -Path $wifiCredPath | Out-Null

            if (Test-Path $wifiCredPath) {
                Write-ColoredMessage "Contraseña de Wi-Fi guardada correctamente" -Type Success
                Write-Host "Ubicación: $wifiCredPath" -ForegroundColor Gray
                $wifiCredValid = $true
            }
        } else {
            Write-ColoredMessage "Contrasena invalida o cancelada" -Type Warning
            $retry = Read-Host "¿Intentar nuevamente? (S/N)"
            if ($retry -notmatch "^[Ss]") {
                Write-ColoredMessage "Configuracion de Wi-Fi cancelada" -Type Warning
                Write-ColoredMessage "Deberas configurar la contrasena manualmente en config.ps1" -Type Info
                break
            }
        }
    } catch {
        Write-ColoredMessage "Error al procesar contrasena de Wi-Fi: $_" -Type Error
        $retry = Read-Host "¿Intentar nuevamente? (S/N)"
        if ($retry -notmatch "^[Ss]") {
            break
        }
    }
}

Write-Host ""

# ====================================
# RESUMEN
# ====================================

Write-ColoredMessage "CONFIGURACIoN COMPLETADA" -Type Header
Write-Host ""
Write-ColoredMessage "Resumen de credenciales configuradas:" -Type Info
Write-Host ""

$summary = @()
if (Test-Path $domainCredPath) {
    $summary += "  [OK] Credenciales de dominio: $domainCredPath"
}
if (Test-Path $localCredPath) {
    $summary += "  [OK] Credenciales locales: $localCredPath"
}
if (Test-Path $wifiCredPath) {
    $summary += "  [OK] Contrasena Wi-Fi: $wifiCredPath"
}

if ($summary.Count -eq 0) {
    Write-ColoredMessage "No se configuraron credenciales" -Type Warning
} else {
    $summary | ForEach-Object { Write-Host $_ -ForegroundColor Green }
}

Write-Host ""
Write-ColoredMessage "PROXIMOS PASOS:" -Type Info
Write-Host "  1. Edita el archivo 'config.ps1' para configurar otros parametros" -ForegroundColor Gray
Write-Host "  2. Asegurate de que config.ps1 este configurado para usar credenciales cifradas" -ForegroundColor Gray
Write-Host "  3. Ejecuta 'init.bat' para iniciar el proceso de configuracion" -ForegroundColor Gray
Write-Host ""

Write-ColoredMessage "IMPORTANTE: Las credenciales solo funcionaran en este equipo con este usuario" -Type Warning
Write-Host ""

Read-Host "Presiona Enter para salir"
exit 0
