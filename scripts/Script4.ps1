# Script4.ps1 - Confirmación Final y Notificación Toast

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - 4/4"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SCRIPT #4 - FINALIZACION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fecha/Hora de inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""


# 0. Cargar archivo de configuración
# ----------------------------------------------------------------
Write-Host "Cargando archivo de config..." -ForegroundColor Cyan

# Determinar la ruta base del proyecto
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ProjectRoot = Split-Path -Parent $ScriptDir
$ConfigPath = "$ProjectRoot\config.ps1"

# Validar si el archivo de configuración se cargó correctamente
# TODO: Migrar funcion al modulo de validación
if (Test-Path $ConfigPath) {
    try {
        # CRÍTICO: Cambiar el directorio de trabajo a la carpeta del proyecto
        # Esto asegura que las rutas relativas en config.ps1 funcionen correctamente
        Set-Location -Path $ProjectRoot
        
        # Importar archivo de configuración
        . $ConfigPath
        Write-Host "Archivo 'config' cargado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "ERROR al cargar el archivo de configuración:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        exit 1
    }
} else {
    Write-Host "Parece que hubo un error importando las configuraciones." -ForegroundColor DarkRed
    Write-Host "Confirma que el archivo 'config.ps1' exista en la carpeta raíz del script." -ForegroundColor DarkRed
    Write-Host "Ruta esperada: $ConfigPath" -ForegroundColor Yellow
    # TODO: Crear archivo (config-default.ps1) de configuración predeterminado si no se encuentra
    Start-Sleep -Seconds 30
    exit 1
}

#! ---------------------------------------------------------------
# @param [string] $logDirectory - Directorio de logs
# @param [string] $successLog - Archivo de log de éxito
# @param [string] $errorLog - Archivo de log de errores
# @param [int] $maxSize - Tamaño máximo del archivo de log (10MB por defecto)

# @function Write-Log - Función principal de logging
# @function Write-SuccessLog - Función de log de éxito
# @function Write-ErrorLog - Función de log de errores

# @param [string] $message - Mensaje a registrar en el log
# @param [string] $logFile - Archivo de log donde se registrará el mensaje

# @output [string] $log - Mensaje de log formateado con fecha y hora

# @output [string] $date - Fecha y hora actual formateada
# @output [int] $fileSize - Tamaño del archivo de log
# @output [string] $timestamp - Marca de tiempo para renombrar el archivo de log

# @output [string] $logDirectory - Directorio de logs por defecto
# @output [string] $successLog - Archivo de log de éxito por defecto
# @output [string] $errorLog - Archivo de log de errores por defecto
# @output [int] $maxSize - Tamaño máximo del archivo de log por defecto

# ----------------------------------------------------------------

# Directorio por defecto de logs
if (-not $logDirectory) { $logDirectory = "C:\Logs" } else { $logDirectory } 
# Archivo de log de éxito
if (-not $successLog) { $successLog = "$logDirectory\setup_success.log" } else { $successLog }
# Archivo de log de errores
if (-not $errorLog) { $errorLog = "$logDirectory\setup_errors.log" } else { $errorLog }

#! Funciones de Logging
function Write-Log {
    param (
        [string]$message,
        [string]$logFile
    )
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $log = "[LOG][$date] $message"
    
    # Si el archivo de log supera los 10 MB, se renombra con timestamp
    $maxSize = 10 * 1024 * 1024 # 10MB
    if (Test-Path $logFile) {
        $fileSize = (Get-Item $logFile).Length
        if ($fileSize -gt $maxSize) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            Rename-Item -Path $logFile -NewName "$logFile-$timestamp.bak"
        }
    }

    Add-Content -Path $logFile -Value $log
}

# Función success log
function Write-SuccessLog { param ( [string]$message ) Write-Log -message "[SUCCESS] $message" -logFile $successLog }

# Función error log
function Write-ErrorLog { param ( [string]$message ) Write-Log -message "[!ERROR] $message" -logFile $errorLog }

# TODO: Ajustar la lógica, basado en el tipo de log (errores o exito) y el tamaño del archivo de log

# Validar si el directorio de logs existe
if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    Write-Host "Directorio de logs creado: $logDirectory" -ForegroundColor Green
    Write-SuccessLog "Directorio de logs creado correctamente: $logDirectory"
} else {
    Write-Host "Directorio de logs ya existe: $logDirectory" -ForegroundColor Yellow
    Write-SuccessLog "Se ha encontrado el directorio de logs: $logDirectory"
}

# Validar si el log de errores existe : $errorLog = "C:\Logs\setup_errors.log"
if (-not (Test-Path $errorLog)) {
    Write-Host "Creando archivo de log de errores..." -ForegroundColor Yellow
    New-Item -Path $errorLog -ItemType File -Force | Out-Null
    icacls $errorLog /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null # Permisos restrictivos (solo Administrators y SYSTEM)
    Write-Host "Archivo de log de errores creado correctamente." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de errores creado correctamente: $errorLog"
} else {
    Write-Host "El archivo de log de errores ya existe." -ForegroundColor Yellow
    Write-ErrorLog "El archivo de log de errores ya existe: $errorLog"
}

# Validar si el log de éxito existe : $successLog = "C:\Logs\setup_success.log"
if (-not (Test-Path $successLog)) {
    Write-Host "Creando archivo de log de éxito..." -ForegroundColor Yellow
    New-Item -Path $successLog -ItemType File -Force | Out-Null
    icacls $successLog /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null # Permisos restrictivos (solo Administrators y SYSTEM)
    Write-Host "Archivo de log de éxito creado correctamente." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de éxito creado correctamente: $successLog"
} else {
    Write-Host "El archivo de log de éxito ya existe." -ForegroundColor Yellow
    Write-SuccessLog "El archivo de log de éxito ya existe: $successLog"
}

# Registrar inicio de ejecución del Script4
Write-SuccessLog "=========================================="
Write-SuccessLog "INICIANDO SCRIPT #4 - FINALIZACION"
Write-SuccessLog "Fecha/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-SuccessLog "Ejecutado por: $env:USERNAME"
Write-SuccessLog "Nombre del equipo: $env:COMPUTERNAME"
Write-SuccessLog "Dominio actual: $((Get-WmiObject -Class Win32_ComputerSystem).Domain)"
Write-SuccessLog "=========================================="

#! ---------------------------------------------------------------

# Confirmación final
try {
  # Mostrar mensaje en la terminal
  Write-Host "==============================================" -ForegroundColor Cyan
  Write-Host "** El equipo ha sido configurado.." -ForegroundColor Green
  Write-Host "==============================================" -ForegroundColor Cyan
  Write-Host "Detalles:" -ForegroundColor Yellow
  Write-Host "- Se ha cambiado el nombre del equipo." -ForegroundColor Gray
  Write-Host "- Se ha unido el equipo al dominio." -ForegroundColor Gray
  Write-Host "- Se ha configurado la red Wi-Fi." -ForegroundColor Gray
  Write-Host "- Se han instalado las aplicaciones necesarias." -ForegroundColor Gray
  Write-Host "==============================================" -ForegroundColor Cyan
  Write-Host "Revise los archivos de log para los detalles:" -ForegroundColor Yellow
  Write-Host "- Success Logs: C:\Logs\success.log" -ForegroundColor Gray
  Write-Host "- Error Logs: C:\Logs\errors.log" -ForegroundColor Gray
  Write-Host "==============================================" -ForegroundColor Cyan
  Write-Host "Presione Enter para cerrar esta ventana..." -ForegroundColor Yellow
  Read-Host
  Write-SuccessLog "Confirmación final enviada correctamente."

  # Mostrar notificación Toast
  Add-Type -AssemblyName System.Windows.Forms
  $notify = New-Object System.Windows.Forms.NotifyIcon
  $notify.Icon = [System.Drawing.SystemIcons]::Information
  $notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
  $notify.BalloonTipTitle = "El equipo ha sido configurado"
  $notify.BalloonTipText = "Revisa los archivos de log para los detalles."
  $notify.Visible = $true
  $notify.ShowBalloonTip(10000) # 10 segundos
  Start-Sleep -Seconds 1
  Write-SuccessLog "Notificación Toast enviada correctamente."
  $notify.Dispose()
}
catch {
  Write-Host "Error: $_" -ForegroundColor Red
  Write-ErrorLog "Error en confirmación: $_"
  Write-Host "Presione Enter para cerrar esta ventana..." -ForegroundColor Yellow
  Read-Host
}

# Restablecer titulo de ventana al valor predeterminado
# ----------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = $tituloPredeterminado
Write-SuccessLog "Script #1 finalizado."
Write-ErrorLog "Script #1 finalizado."

    # Fin del script