# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P3
# Parte3: Validar cambios, desactivar inicio de sesión automático e instalar aplicaciones.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - 3/4"

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
$ConfigPath = "$PSScriptRoot\..\config.ps1"

# Validar si el archivo de configuración se cargó correctamente
# TODO: Migrar funcion al modulo de validación
if (Test-Path $ConfigPath) {
    # Importar archivo de configuración
    . $ConfigPath   
    Write-Host "Archivo 'config' cargado correctamente." -ForegroundColor Green
} else {
    Write-Host "Parece que hubo un error importando las configuraciones." -ForegroundColor DarkRed
    Write-Host "Confirma que el archivo 'config.ps1' exista en la carpeta raíz del script." -ForegroundColor DarkRed
    # TODO: Crear archivo (config-default.ps1) de configuración predeterminado si no se encuentra
    Start-Sleep -Seconds $Delay
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
    icacls $errorLog /grant Everyone:F /inheritance:r | Out-Null #! Permisos de escritura para todos
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
    icacls $successLog /grant Everyone:F /inheritance:r | Out-Null #! Permisos de escritura para todos
    Write-Host "Archivo de log de éxito creado correctamente." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de éxito creado correctamente: $successLog"
} else {
    Write-Host "El archivo de log de éxito ya existe." -ForegroundColor Yellow
    Write-SuccessLog "El archivo de log de éxito ya existe: $successLog"
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
    if ($currentName -eq $HostName) {
        Write-Host "Validación exitosa: El nombre del equipo es '$HostName'." -ForegroundColor Green
        Write-SuccessLog "El nombre del equipo se cambió correctamente a '$HostName'."
    } else {
        Write-ErrorLog "El nombre del equipo no se cambió correctamente. Nombre actual: '$currentName'."
        throw "El nombre del equipo no se cambió correctamente. Nombre actual: '$currentName'."
    }

    # Verificar si el equipo está unido al dominio
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -eq $DomainName) {
        Write-Host "El equipo está correctamente unido al dominio '$DomainName'." -ForegroundColor Green
        Write-SuccessLog "El equipo está unido correctamente al dominio '$DomainName'."
    } else {
        Write-ErrorLog "El equipo no está unido al dominio '$DomainName'."
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
Write-Host "Iniciando instalación de aplicaciones..." -ForegroundColor Cyan
# Lista de aplicaciones a instalar (definida en config.ps1 o apps.json)
# winget install --id=Google.Chrome -e --silent --accept-package-agreements --accept-source-agreements

# Actualizar la fuentes de winget
winget source reset --force
winget source remove -n winget
# winget source add -n winget -a https://winget.azureedge.net/cache
winget source add -n winget -a https://cdn.winget.microsoft.com/cache
winget source update
Write-SuccessLog "Fuentes de Winget actualizadas correctamente."

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
        exit 1
    }
} else {
    Write-Host "No se encontró un archivo 'apps.json'. Continuando..." -ForegroundColor Yellow
    Write-SuccessLog "No se encontró un archivo 'apps.json'. Continuando..."
    Write-ErrorLog "No se encontró un archivo 'apps.json'. Continuando..."
    # exit 1
}

# Instalación de aplicaciones
foreach ($app in $apps) {
    try {
        # Filtrar objetos que no representan aplicaciones (por ejemplo, comentarios)
        if (-not $app.Name -or -not $app.Source) {
            Write-Host "Advertencia: Objeto no válido de aplicación en el JSON. Se omitirá." -ForegroundColor Yellow
            Write-SuccessLog "Advertencia: Objeto no válido de aplicación en el JSON. Se omitirá."
            Write-ErrorLog "Advertencia: Objeto no válido de aplicación en el JSON. Se omitirá."
            continue
        }
        Write-Host "Instalando $($app.Name)..." -ForegroundColor Cyan

        if ($app.Source -eq "Winget") {
            # Instalar Google Chrome con argumentos adicionales para evitar error de coincidencia de nombre
            if ($app.Name -eq "Google Chrome") {
                winget install --id=Google.Chrome -e --silent --accept-package-agreements --accept-source-agreements
            }
            # Instalación de aplicaciones con Winget
            Write-Host "Instalando $($app.Name) usando Winget..." -ForegroundColor Blue
            Write-SuccessLog "Instalando $($app.Name) usando Winget..."
            winget install $app.Name -e --silent --accept-package-agreements --accept-source-agreements
        } elseif ($app.Source -eq "Network") {
            # Instalación de aplicaciones desde la red
            if (Test-Path $app.Path) {
                Write-Host "Instalando $($app.Name) desde la red..." -ForegroundColor Blue
                Write-SuccessLog "Instalando $($app.Name) desde la red..."
                # Uso de argumentos adicionales si se proporcionan
                $arguments = if ($app.Arguments) { $app.Arguments } else { "/silent" }
                Start-Process -FilePath $app.Path -ArgumentList $arguments -Wait
            } else {
                Write-ErrorLog "No se encontró el archivo de instalación en la ruta: $($app.Path)"
                throw "No se encontró el archivo de instalación en la ruta: $($app.Path)"
            }
        } else {
            Write-ErrorLog "Origen de la aplicación desconocido para: $($app.Source)."
            throw "Origen de la aplicación desconocido para: $($app.Source)."
        }

        # Confirmar instalación exitosa
        Write-Host "$($app.Name) instalado correctamente." -ForegroundColor Green
        Write-SuccessLog "$($app.Name) instalado correctamente."
    } catch {
        Write-Host "Error al instalar $($app.Name): $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Error al instalar $($app.Name): $($_.Exception.Message)"
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