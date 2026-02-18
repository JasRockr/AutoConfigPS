# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P3
# Parte3: Validar cambios, desactivar inicio de sesión automático e instalar aplicaciones.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - 3/4"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SCRIPT #3 - INSTALACION DE APLICACIONES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fecha/Hora de inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# ----------------------------------------------------------------
# Flujo de ejecución del script # 3
# 0. Cargar archivo de configuración.
# 1. Validar cambios aplicados.
# 2. Eliminar tarea programada anterior.
# 3. Desactivar el inicio de sesión automático.
# 4. Iniciar instalación de aplicaciones.
# 5. Confirmar configuración automática.
# ----------------------------------------------------------------

# # --------------------------------------------------------------
# # Flujo principal
# # --------------------------------------------------------------

# @param $HostName Nombre del equipo
# @param $DomainName Nombre del dominio
# @param $errorLog Ruta del archivo de log de errores
# @param $Delay Tiempo de espera en segundos


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
# --

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

    # Establecer permisos restrictivos (solo Administrators y SYSTEM)
    icacls $errorLog /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null
    Write-Host "Archivo de log de errores creado correctamente con permisos restrictivos." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de errores creado correctamente: $errorLog (permisos: Administrators+SYSTEM)"
} else {
    Write-Host "El archivo de log de errores ya existe." -ForegroundColor Yellow
    Write-ErrorLog "El archivo de log de errores ya existe: $errorLog"
}

# Validar si el log de éxito existe : $successLog = "C:\Logs\setup_success.log"
if (-not (Test-Path $successLog)) {
    Write-Host "Creando archivo de log de éxito..." -ForegroundColor Yellow
    New-Item -Path $successLog -ItemType File -Force | Out-Null

    # Establecer permisos restrictivos (solo Administrators y SYSTEM)
    icacls $successLog /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null
    Write-Host "Archivo de log de éxito creado correctamente con permisos restrictivos." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de éxito creado correctamente: $successLog (permisos: Administrators+SYSTEM)"
} else {
    Write-Host "El archivo de log de éxito ya existe." -ForegroundColor Yellow
    Write-SuccessLog "El archivo de log de éxito ya existe: $successLog"
}

# Registrar inicio de ejecución del Script3
Write-SuccessLog "=========================================="
Write-SuccessLog "INICIANDO SCRIPT #3 - INSTALACION DE APLICACIONES"
Write-SuccessLog "Fecha/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-SuccessLog "Ejecutado por: $env:USERNAME"
Write-SuccessLog "Nombre del equipo: $env:COMPUTERNAME"
Write-SuccessLog "Dominio actual: $((Get-WmiObject -Class Win32_ComputerSystem).Domain)"
Write-SuccessLog "=========================================="

#! ---------------------------------------------------------------

# ----------------------------------------------------------------
# Funciones de instalación de aplicaciones con timeout
# ----------------------------------------------------------------

function Install-WingetApp {
    <#
    .SYNOPSIS
        Instala una aplicación usando Winget con timeout y validación

    .DESCRIPTION
        Instala aplicaciones desde Winget con:
        - Timeout configurable
        - Validación de exit code
        - Logging detallado
        - Manejo de casos especiales

    .PARAMETER AppName
        Nombre de la aplicación en Winget

    .PARAMETER AppID
        ID específico de Winget (opcional, para evitar ambigüedades)

    .PARAMETER TimeoutSeconds
        Timeout en segundos (por defecto 300 = 5 minutos)

    .RETURNS
        Objeto con Success (bool), ExitCode (int), Message (string), Duration (timespan)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,

        [string]$AppID,

        [int]$TimeoutSeconds = 300
    )

    Write-Host "  → Instalando: $AppName" -ForegroundColor Cyan
    $startTime = Get-Date

    try {
        # Construir comando de instalación
        if ($AppID) {
            $installArgs = "install --id=$AppID -e --silent --accept-package-agreements --accept-source-agreements"
            Write-SuccessLog "Instalando $AppName con ID específico: $AppID"
        } else {
            $installArgs = "install `"$AppName`" -e --silent --accept-package-agreements --accept-source-agreements"
            Write-SuccessLog "Instalando $AppName por nombre"
        }

        # Crear proceso con timeout
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "winget.exe"
        $processInfo.Arguments = $installArgs
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo

        # Iniciar proceso
        $process.Start() | Out-Null

        # Esperar con timeout
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        $duration = (Get-Date) - $startTime

        if (-not $finished) {
            # Timeout alcanzado
            $process.Kill()
            $process.WaitForExit()

            Write-Host "    [!] Timeout (${TimeoutSeconds}s)" -ForegroundColor Yellow
            Write-ErrorLog "Timeout en instalación de $AppName después de ${TimeoutSeconds}s"

            return @{
                Success = $false
                ExitCode = -1
                Message = "Timeout después de ${TimeoutSeconds}s"
                Duration = $duration
                AppName = $AppName
            }
        }

        $exitCode = $process.ExitCode
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()

        # Evaluar exit code
        # Winget exit codes: 0 = éxito, -1978335189 (0x8A15002B) = ya instalado
        $success = ($exitCode -eq 0) -or ($exitCode -eq -1978335189)

        if ($success) {
            $message = if ($exitCode -eq -1978335189) { "Ya instalado" } else { "Instalado correctamente" }
            Write-Host "    [OK] $message (${duration.TotalSeconds:N1}s)" -ForegroundColor Green
            Write-SuccessLog "`/${AppName}: $message - Duración: ${duration.TotalSeconds:N1}s"
        } else {
            $message = "Error (Exit code: $exitCode)"
            Write-Host "    [X] $message" -ForegroundColor Red
            Write-ErrorLog "$`/${AppName}: $message - Duración: ${duration.TotalSeconds:N1}s"

            if ($errorOutput) {
                Write-ErrorLog "`/${AppName} - Error output: $errorOutput"
            }
        }

        return @{
            Success = $success
            ExitCode = $exitCode
            Message = $message
            Duration = $duration
            AppName = $AppName
        }

    } catch {
        $duration = (Get-Date) - $startTime
        Write-Host "    [X] Excepción: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Excepción en instalación de $AppName : $($_.Exception.Message)"

        return @{
            Success = $false
            ExitCode = -2
            Message = "Excepción: $($_.Exception.Message)"
            Duration = $duration
            AppName = $AppName
        }
    }
}

function Install-NetworkApp {
    <#
    .SYNOPSIS
        Instala una aplicación desde una ruta de red con timeout y validación

    .DESCRIPTION
        Instala aplicaciones desde recursos de red con:
        - Validación de existencia del archivo
        - Timeout configurable
        - Validación de exit code
        - Logging detallado

    .PARAMETER AppName
        Nombre de la aplicación

    .PARAMETER InstallerPath
        Ruta UNC o local al instalador

    .PARAMETER Arguments
        Argumentos para el instalador (por defecto /silent)

    .PARAMETER TimeoutSeconds
        Timeout en segundos (por defecto 600 = 10 minutos)

    .RETURNS
        Objeto con Success (bool), ExitCode (int), Message (string), Duration (timespan)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,

        [Parameter(Mandatory=$true)]
        [string]$InstallerPath,

        [string]$Arguments = "/silent",

        [int]$TimeoutSeconds = 600
    )

    Write-Host "  → Instalando desde red: $AppName" -ForegroundColor Cyan
    $startTime = Get-Date

    try {
        # Validar existencia del archivo
        if (-not (Test-Path $InstallerPath)) {
            Write-Host "    [X] Archivo no encontrado: $InstallerPath" -ForegroundColor Red
            Write-ErrorLog "$`/${AppName}: Archivo no encontrado en $InstallerPath"

            return @{
                Success = $false
                ExitCode = -3
                Message = "Archivo no encontrado"
                Duration = (Get-Date) - $startTime
                AppName = $AppName
            }
        }

        Write-Host "    Ejecutando: $InstallerPath $Arguments" -ForegroundColor Gray
        Write-SuccessLog "Instalando $AppName desde: $InstallerPath con argumentos: $Arguments"

        # Crear proceso con timeout
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallerPath
        $processInfo.Arguments = $Arguments
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo

        # Iniciar proceso
        $process.Start() | Out-Null

        # Esperar con timeout
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        $duration = (Get-Date) - $startTime

        if (-not $finished) {
            # Timeout alcanzado
            $process.Kill()
            $process.WaitForExit()

            Write-Host "    [!] Timeout (${TimeoutSeconds}s)" -ForegroundColor Yellow
            Write-ErrorLog "Timeout en instalación de $AppName después de ${TimeoutSeconds}s"

            return @{
                Success = $false
                ExitCode = -1
                Message = "Timeout después de ${TimeoutSeconds}s"
                Duration = $duration
                AppName = $AppName
            }
        }

        $exitCode = $process.ExitCode
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()

        # La mayoría de instaladores usan exit code 0 = éxito, 3010 = requiere reinicio (pero éxito)
        $success = ($exitCode -eq 0) -or ($exitCode -eq 3010)

        if ($success) {
            $message = if ($exitCode -eq 3010) { "Instalado (requiere reinicio)" } else { "Instalado correctamente" }
            Write-Host "    [OK] $message (${duration.TotalSeconds:N1}s)" -ForegroundColor Green
            Write-SuccessLog "$`/${AppName}: $message - Duración: ${duration.TotalSeconds:N1}s"
        } else {
            $message = "Error (Exit code: $exitCode)"
            Write-Host "    [X] $message" -ForegroundColor Red
            Write-ErrorLog "$`/${AppName}: $message - Duración: ${duration.TotalSeconds:N1}s"
            if ($errorOutput) {
                Write-ErrorLog "$AppName - Error output: $errorOutput"
            }
        }

        return @{
            Success = $success
            ExitCode = $exitCode
            Message = $message
            Duration = $duration
            AppName = $AppName
        }

    } catch {
        $duration = (Get-Date) - $startTime
        Write-Host "    [X] Excepción: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Excepción en instalación de $AppName : $($_.Exception.Message)"

        return @{
            Success = $false
            ExitCode = -2
            Message = "Excepción: $($_.Exception.Message)"
            Duration = $duration
            AppName = $AppName
        }
    }
}

#! ---------------------------------------------------------------

# 1. Validar cambios aplicados
# ----------------------------------------------------------------
Write-Host "Validando cambios aplicados..." -ForegroundColor Cyan
Write-SuccessLog "Validando cambios aplicados..."

# Validar cambios aplicados en pasos previos
try {
    # Verificar si el nombre del equipo ha cambiado correctamente
    $currentName = (Get-WmiObject -Class Win32_ComputerSystem).Name
    $pendingName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name "ComputerName" -ErrorAction SilentlyContinue).ComputerName
    
    Write-Host "Verificando nombre del equipo..." -ForegroundColor Gray
    Write-Host "  Nombre actual (activo): $currentName" -ForegroundColor Gray
    Write-Host "  Nombre esperado: $HostName" -ForegroundColor Gray
    if ($pendingName -and $pendingName -ne $currentName) {
        Write-Host "  Nombre pendiente (tras próximo reinicio): $pendingName" -ForegroundColor Gray
    }
    
    if ($currentName -eq $HostName) {
        Write-Host "[OK] El nombre del equipo es correcto: '$HostName'" -ForegroundColor Green
        Write-SuccessLog "El nombre del equipo se cambió correctamente a '$HostName'."
    } elseif ($pendingName -eq $HostName) {
        Write-Host "[ADVERTENCIA] El nombre está programado para cambiar a '$HostName' en el próximo reinicio" -ForegroundColor Yellow
        Write-SuccessLog "Cambio de nombre pendiente: '$currentName' -> '$HostName' (requiere reinicio adicional)"
        # No lanzar error, continuar
    } else {
        Write-Host "[!] El nombre del equipo NO coincide" -ForegroundColor Red
        Write-Host "    Actual: '$currentName', Esperado: '$HostName'" -ForegroundColor Yellow
        Write-ErrorLog "El nombre del equipo no se cambió correctamente. Nombre actual: '$currentName', Esperado: '$HostName'"
        
        # IMPORTANTE: No detener el flujo por esto, solo advertir
        Write-Host ""
        Write-Host "NOTA: Este puede ser un problema cosmético. Continuando con instalación..." -ForegroundColor Cyan
        Write-Host ""
    }

    # Verificar si el equipo está unido al dominio
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -eq $DomainName) {
        Write-Host "[OK] El equipo está unido al dominio '$DomainName'" -ForegroundColor Green
        Write-SuccessLog "El equipo está unido correctamente al dominio '$DomainName'."
    } else {
        Write-Host "[!] El equipo NO está unido al dominio esperado" -ForegroundColor Red
        Write-Host "    Dominio actual: '$currentDomain', Esperado: '$DomainName'" -ForegroundColor Yellow
        Write-ErrorLog "El equipo no está unido al dominio '$DomainName'. Dominio actual: '$currentDomain'"
        throw "El equipo no está unido al dominio '$DomainName'."
    }
} catch {
    Write-Host "Error al validar cambios: $($_.Exception.Message)" -ForegroundColor Red
    Write-ErrorLog "Error al validar cambios: $($_.Exception.Message)"
    exit 0 # Salir sin error para continuar con el script
}
# --

# 2. Eliminar tarea programada previamente creada
# ----------------------------------------------------------------
Write-Host "Eliminando tarea programada anterior..." -ForegroundColor Cyan

# Eliminar tarea programada 'Exec-Join-Domain' 
$DelTaskName = "Exec-Check-Continue"

try {
    # Verificar si la tarea existe antes de eliminarla
    $existingTask = Get-ScheduledTask -TaskName $DelTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $DelTaskName -Confirm:$false
        Write-Host "Tarea programada '$DelTaskName' eliminada correctamente." -ForegroundColor Green
        Write-SuccessLog "Tarea programada '$DelTaskName' eliminada correctamente."
    } else {
        Write-Host "La tarea programada '$DelTaskName' no existe." -ForegroundColor Yellow
        Write-ErrorLog "La tarea programada '$DelTaskName' no existe."
    }
} catch {
    Write-Error "Error al eliminar la tarea programada '$DelTaskName': $($_.Exception.Message)"
    Write-ErrorLog "Error al eliminar la tarea programada '$DelTaskName': $($_.Exception.Message)"
    Start-Sleep -Seconds $Delay
    exit 1
}
# --

# 3. Desactivar el inicio de sesión automático
# ----------------------------------------------------------------
Write-Host "Desactivando inicio de sesión automático..." -ForegroundColor Cyan

# Ruta del registro para el inicio de sesión automático
$AutoLoginKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

try {
    Remove-ItemProperty -Path $AutoLoginKey -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $AutoLoginKey -Name "DefaultUserName" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $AutoLoginKey -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Write-Host "Inicio de sesión automático desactivado correctamente." -ForegroundColor Green
    Write-SuccessLog "Inicio de sesión automático desactivado correctamente."
} catch {
    Write-Host "Error al desactivar el inicio de sesión automático: $($_.Exception.Message)" -ForegroundColor Red
    Write-ErrorLog "Error al desactivar el inicio de sesión automático: $($_.Exception.Message)"
    exit 1
}
# --

# 4. Iniciar instalación de aplicaciones
# ----------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  INSTALACIÓN DE APLICACIONES" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

$installStartTime = Get-Date

# Actualizar las fuentes de winget
Write-Host "Actualizando fuentes de Winget..." -ForegroundColor Cyan
try {
    # Verificar si winget está disponible
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $wingetAvailable) {
        Write-Host '  [!] Winget no está disponible en este sistema' -ForegroundColor Yellow
        Write-ErrorLog "Winget no está disponible - las instalaciones de Winget fallarán"
    } else {
        winget source reset --force 2>&1 | Out-Null
        winget source remove -n winget 2>&1 | Out-Null
        winget source add -n winget -a https://cdn.winget.microsoft.com/cache 2>&1 | Out-Null
        winget source update 2>&1 | Out-Null
        Write-Host "  [OK] Fuentes de Winget actualizadas" -ForegroundColor Green
        Write-SuccessLog "Fuentes de Winget actualizadas correctamente."
    }
} catch {
    Write-Host "  [!] Error al actualizar fuentes de Winget: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-ErrorLog "Error al actualizar fuentes de Winget: $($_.Exception.Message)"
}

Write-Host ""

# Ruta del archivo JSON que contiene la lista de aplicaciones
$appsPath = "$PSScriptRoot\..\apps.json"

# Validar si el archivo JSON existe
if (Test-Path $appsPath) {
    try {
        # Cargar la lista de aplicaciones desde el archivo JSON
        $apps = Get-Content -Path $appsPath | ConvertFrom-Json
        Write-Host "Lista de aplicaciones cargada desde: $appsPath" -ForegroundColor Green
        Write-SuccessLog "Lista de aplicaciones cargada correctamente desde: $appsPath"
    } catch {
        Write-Host "Error al cargar el archivo JSON: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Error al cargar el archivo JSON: $($_.Exception.Message)"
        # No salir, continuar con apps de config.ps1 si existe
    }
}

# Si no hay apps de JSON ni de config, notificar
if (-not $apps -or $apps.Count -eq 0) {
    Write-Host '[!] No se encontraron aplicaciones para instalar' -ForegroundColor Yellow
    Write-SuccessLog "No se encontraron aplicaciones configuradas para instalación"
    Write-Host ""
} else {
    Write-Host "Total de aplicaciones a instalar: $($apps.Count)" -ForegroundColor Cyan
    Write-Host ""

    # Array para almacenar resultados de instalación
    $installResults = @()

    # Instalación de aplicaciones con funciones mejoradas
    foreach ($app in $apps) {
        # Filtrar objetos que no representan aplicaciones válidas
        if (-not $app.Name -or -not $app.Source) {
            Write-Host '[!] Objeto no válido en lista de aplicaciones - omitiendo' -ForegroundColor Yellow
            Write-ErrorLog "Objeto no válido de aplicación en la lista"
            continue
        }

        # Instalar según el origen
        if ($app.Source -eq "Winget") {
            # Winget: usar AppID si está disponible, sino usar Name
            $appID = if ($app.ID) { $app.ID } elseif ($app.Name -eq "Google Chrome") { "Google.Chrome" } else { $null }
            $timeout = if ($app.Timeout) { $app.Timeout } else { 300 }

            $result = Install-WingetApp -AppName $app.Name -AppID $appID -TimeoutSeconds $timeout
            $installResults += $result

        } elseif ($app.Source -eq "Network") {
            # Red: instalar desde ruta UNC
            $arguments = if ($app.Arguments) { $app.Arguments } else { "/silent" }
            $timeout = if ($app.Timeout) { $app.Timeout } else { 600 }

            $result = Install-NetworkApp -AppName $app.Name -InstallerPath $app.Path -Arguments $arguments -TimeoutSeconds $timeout
            $installResults += $result

        } else {
            Write-Host "  [X] Origen desconocido para: $($app.Name) ($($app.Source))" -ForegroundColor Red
            Write-ErrorLog "Origen desconocido para $($app.Name): $($app.Source)"

            $installResults += @{
                Success = $false
                ExitCode = -4
                Message = "Origen desconocido: $($app.Source)"
                Duration = [TimeSpan]::Zero
                AppName = $app.Name
            }
        }

        Write-Host ""
    }

    # Resumen de instalaciones
    $installEndTime = Get-Date
    $totalDuration = $installEndTime - $installStartTime

    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  RESUMEN DE INSTALACIONES" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""

    $successCount = ($installResults | Where-Object { $_.Success }).Count
    $failCount = ($installResults | Where-Object { -not $_.Success }).Count
    $totalCount = $installResults.Count

    Write-Host "Total de aplicaciones: $totalCount" -ForegroundColor Cyan
    Write-Host "  [OK] Exitosas: $successCount" -ForegroundColor Green
    Write-Host "  [X] Fallidas: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
    Write-Host "Tiempo total: $($totalDuration.ToString('mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""

    # Listar aplicaciones exitosas
    if ($successCount -gt 0) {
        Write-Host "Aplicaciones instaladas correctamente:" -ForegroundColor Green
        $installResults | Where-Object { $_.Success } | ForEach-Object {
            $durationSeconds = ('{0:N1}' -f $_.Duration.TotalSeconds) + 's'
            Write-Host "  [OK] $($_.AppName) - $($_.Message) ($durationSeconds)" -ForegroundColor Green
        }
        Write-Host ""
    }   

    # Listar aplicaciones fallidas
    if ($failCount -gt 0) {
        Write-Host "Aplicaciones con errores:" -ForegroundColor Red
        $installResults | Where-Object { -not $_.Success } | ForEach-Object {
            Write-Host "  [X] $($_.AppName) - $($_.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }

    # Logging del resumen
    Write-SuccessLog "Resumen de instalaciones: $successCount exitosas, $failCount fallidas de $totalCount totales"
    Write-SuccessLog "Tiempo total de instalaciones: $($totalDuration.ToString('mm\:ss'))"

    if ($failCount -gt 0) {
        $failedApps = ($installResults | Where-Object { -not $_.Success } | ForEach-Object { $_.AppName }) -join ", "
        Write-ErrorLog "Aplicaciones con errores: $failedApps"
    }
}
# --

# 5. Confirmar configuración automática completada
# ----------------------------------------------------------------
Write-Host "Confirmando configuración automática..." -ForegroundColor Cyan

#TODO: Crear archivo de confirmación con resumen de la cantidad de errores procesados durante el proceso, el flujo de ejecución y el tiempo total de ejecución.

# Confirmación en archivo
try {
    # Crear un archivo de confirmación
    $confirmationFile = "$env:SystemDrive\ConfiguracionCompleta.txt"
    Set-Content -Path $confirmationFile -Value "Configuración automática completada el $(Get-Date)."
    Write-Host "Configuración automática confirmada. Archivo creado en: $confirmationFile" -ForegroundColor Green
    Write-SuccessLog "Configuración automática confirmada. Archivo creado en: $confirmationFile"

} catch {
    Write-Host "Error al confirmar la configuración automática: $($_.Exception.Message)" -ForegroundColor Red
    Write-ErrorLog "Error al confirmar la configuración automática: $($_.Exception.Message)"
    exit 1
}

# Confirmación en terminal y notificación Toast script4.ps1
Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\script4.ps1`""

# --

# Restablecer título de ventana al valor predeterminado
# ----------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = $tituloPredeterminado
Write-SuccessLog "Script #3 finalizado."
Write-ErrorLog "Script #3 finalizado."

        # Fin del script