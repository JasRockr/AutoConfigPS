# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P3
# Parte3: Validar cambios, desactivar inicio de sesión automático e instalar aplicaciones.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - Parte 3"

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

# 1. Validar cambios aplicados
# ----------------------------------------------------------------
Write-Host "Validando cambios aplicados..." -ForegroundColor Cyan

# Validar cambios aplicados en pasos previos
try {
    # Verificar si el nombre del equipo ha cambiado correctamente
    $currentName = (Get-WmiObject -Class Win32_ComputerSystem).Name
    if ($currentName -eq $HostName) {
        Write-Host "Validación exitosa: El nombre del equipo es '$HostName'." -ForegroundColor Green
    } else {
        throw "El nombre del equipo no se cambió correctamente. Nombre actual: '$currentName'."
    }

    # Verificar si el equipo está unido al dominio
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -eq $DomainName) {
        Write-Host "El equipo está correctamente unido al dominio '$DomainName'." -ForegroundColor Green
    } else {
        throw "El equipo no está unido al dominio '$DomainName'."
    }
} catch {
    Write-Host "Error al validar cambios: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
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
    } else {
        Write-Host "La tarea programada '$DelTaskName' no existe." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Error al eliminar la tarea programada '$DelTaskName': $($_.Exception.Message)"
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
} catch {
    Write-Host "Error al desactivar el inicio de sesión automático: $($_.Exception.Message)" -ForegroundColor Red
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

# Ruta del archivo JSON que contiene la lista de aplicaciones
$appsPath = "$PSScriptRoot\..\apps.json"

# Validar si el archivo JSON existe
if (Test-Path $appsPath) {
    try {
        # Cargar la lista de aplicaciones desde el archivo JSON
        $apps = Get-Content -Path $appsPath | ConvertFrom-Json
        Write-Host "Lista de aplicaciones cargada desde: $appsPath" -ForegroundColor Green
    } catch {
        Write-Host "Error al cargar el archivo JSON: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "No se encontró un archivo 'apps.json'. Continuando..." -ForegroundColor Yellow
    # exit 1
}

# Instalación de aplicaciones
foreach ($app in $apps) {
    try {
        # Filtrar objetos que no representan aplicaciones (por ejemplo, comentarios)
        if (-not $app.Name -or -not $app.Source) {
            Write-Host "Advertencia: Objeto no válido de aplicación en el JSON. Se omitirá." -ForegroundColor Yellow
            continue
        }
        Write-Host "Instalando $($app.Name)..." -ForegroundColor Cyan

        if ($app.Source -eq "Winget") {
            # Instalación de aplicaciones con Winget
            Write-Host "Instalando $($app.Name) usando Winget..." -ForegroundColor Blue
            winget install $app.Name -e --silent --accept-package-agreements --accept-source-agreements
        } elseif ($app.Source -eq "Network") {
            # Instalación de aplicaciones desde la red
            if (Test-Path $app.Path) {
                Write-Host "Instalando $($app.Name) desde la red..." -ForegroundColor Blue
                # Uso de argumentos adicionales si se proporcionan
                $arguments = if ($app.Arguments) { $app.Arguments } else { "/silent" }
                Start-Process -FilePath $app.Path -ArgumentList $arguments -Wait
            } else {
                throw "No se encontró el archivo de instalación en la ruta: $($app.Path)"
            }
        } else {
            throw "Origen de la aplicación desconocido para: $($app.Source)."
        }

        # Confirmar instalación exitosa
        Write-Host "$($app.Name) instalado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al instalar $($app.Name): $($_.Exception.Message)" -ForegroundColor Red

        # Registrar error en archivo de log (opcional)
        $errorMessage = "Error al instalar $($app.Name): $($_.Exception.Message)"
        $errorMessage | Out-File -FilePath $errorLog -Append
    }
}
# --

# 5. Confirmar configuración automática
# ----------------------------------------------------------------
Write-Host "Confirmando configuración automática..." -ForegroundColor Cyan

try {
    # Crear un archivo de confirmación
    $confirmationFile = "$env:SystemDrive\ConfiguracionCompleta.txt"
    Set-Content -Path $confirmationFile -Value "Configuración automática completada el $(Get-Date)."
    Write-Host "Configuración automática confirmada. Archivo creado en: $confirmationFile" -ForegroundColor Green
} catch {
    Write-Host "Error al confirmar la configuración automática: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
# --

# Restablecer título de ventana al valor predeterminado
# ----------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = $tituloPredeterminado
Write-Host "Script finalizado. Puedes cerrar la ventana." -ForegroundColor Green

# Fin del script