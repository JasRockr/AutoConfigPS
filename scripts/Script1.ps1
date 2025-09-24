# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P1
# Parte1: Configuraciones básicas y preparación del sistema para el reinicio.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - 1/4"

# Verificar si el script se ejecuta con privilegios de administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Este script necesita privilegios de administrador para ejecutarse." -ForegroundColor Red
    Write-Host "Presione Enter para cerrar esta ventana..." -ForegroundColor Yellow
    Read-Host
    exit
}

# ----------------------------------------------------------------
# # Flujo de ejecución del script # 1
# 0. Cargar archivo de configuración.
# 1. Configurar red Wi-Fi.
# 2. Configurar inicio de sesión automático con usuario por defecto.
# 3. Cambiar nombre del equipo.
# 4. Crear una tarea programada para ejecutar la segunda parte del script tras el reinicio.
# 5. Reiniciar el equipo.
# ----------------------------------------------------------------

# # ----------------------------------------------------------------
# # Flujo principal
# # ----------------------------------------------------------------

# @param [int] $Delay - Retardo en segundos entre las operaciones
# @param [string] $NetworkSSID - Nombre de la red Wi-Fi
# @param [string] $NetworkPass - Contraseña de la red Wi-Fi
# @param [string] $Username - Nombre de usuario local
# @param [string] $Password - Contraseña de usuario local
# @param [string] $HostName - Nuevo nombre del equipo
# @param [string] $ScriptPath - Ruta del script de la segunda parte

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

# Configurar política de ejecución de scripts (global)
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# 1. Configurar red Wi-Fi
# ----------------------------------------------------------------
Write-Host "Configurando Red Wi-Fi..." -ForegroundColor Cyan
Write-SuccessLog "Configurando Red Wi-Fi..."
# Start-Sleep -Seconds $Delay

# ----------------------------------------------------------------
# Configurar conexíon de red automático (red por defecto 'RedSSID') 
# ----------------------------------------------------------------
$SecurePassword = ConvertTo-SecureString $NetworkPass -AsPlainText -Force # Contraseña de Red
#! Convertir SecureString a texto plano (⚠️ Riesgo de seguridad)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$Pswdpln = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# 1. Configurar red Wi-Fi
try {
    # Validar variables de configuración
    if (-not $NetworkSSID -or -not $NetworkPass -or -not $Delay) {
        Write-ErrorLog "Faltan variables de configuración para la red Wi-Fi" 
        throw "Faltan variables de configuración para la red Wi-Fi"
    }

    # Verificar y crear perfil Wi-Fi
    # $existingProfile = Get-WiFiProfile -Name $NetworkSSID -ErrorAction SilentlyContinue
    $existingProfile = netsh wlan show profiles $NetworkSSID | Select-String -Pattern "Perfil" | Select-Object -First 1
    if ($existingProfile -match "No se encuentra el perfil") {
        Write-Host "Creando perfil para: $NetworkSSID" -ForegroundColor DarkBlue
        Write-SuccessLog "No se encuentra el perfil de la red Wi-Fi: $NetworkSSID" 
        Write-SuccessLog "Creando perfil para la red Wi-Fi: $NetworkSSID" 
        $wifiProfile = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
<name>$NetworkSSID</name>
<SSIDConfig>
<SSID>
    <name>$NetworkSSID</name>
</SSID>
</SSIDConfig>
<connectionType>ESS</connectionType>
<connectionMode>auto</connectionMode>
<MSM>
<security>
    <authEncryption>
    <authentication>WPA2PSK</authentication>
    <encryption>AES</encryption>
    </authEncryption>
    <sharedKey>
    <keyType>passPhrase</keyType>
    <protected>false</protected>
    <keyMaterial>$Pswdpln</keyMaterial>
    </sharedKey>
</security>
</MSM>
</WLANProfile>
"@
        $tempFile = New-TemporaryFile | Rename-Item -NewName {"$NetworkSSID.xml"} -PassThru
        $wifiProfile | Out-File $tempFile.FullName -Encoding UTF8 -Force
        netsh wlan add profile filename="$($tempFile.FullName)" | Out-Null 
        Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        Write-SuccessLog "Perfil de red Wi-Fi creado correctamente: $NetworkSSID" 
    }

    # Limpiar la variable de texto plano después de su uso
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    Remove-Variable -Name Pswdpln

    # Conectar a la red Wi-Fi
    Write-Host "Conectando a la red: $NetworkSSID" -ForegroundColor Blue
    netsh wlan connect name=$NetworkSSID
    Start-Sleep -Seconds $Delay 

    # Verificar conexión
    $newConnection = netsh wlan show interfaces | Select-String -Pattern "SSID" | Select-Object -First 1
    if ($newConnection -match $NetworkSSID) {
        Write-Host "Se ha conectado a la red Wi-Fi: $NetworkSSID" -ForegroundColor Green
        Write-SuccessLog "Conexión Wi-Fi establecida correctamente: $NetworkSSID"
    } else {
        # Intentar reconectar si la primera conexión falla
        Write-Host "2/2 - Conectando nuevamente a la red: $NetworkSSID" -ForegroundColor Yellow
        Write-SuccessLog "Intentando reconectar a la red Wi-Fi: $NetworkSSID"
        netsh wlan connect name=$NetworkSSID
        Start-Sleep -Seconds $Delay

        # Verificar conexión nuevamente
        $newConnection = netsh wlan show interfaces | Select-String -Pattern "SSID" | Select-Object -First 1
        if ($newConnection -match $NetworkSSID) {
            Write-Host "Se ha conectado correctamente a $NetworkSSID" -ForegroundColor Green
            Write-SuccessLog "Conexión Wi-Fi establecida correctamente: $NetworkSSID" 
        } else {
            Write-ErrorLog "Error en conexión Wi-Fi: No se pudo validar la conexión" 
            throw "Ha ocurrido un Error: No se pudo validar la conexion"
        }
    }
} catch {
    Write-Host "Error en conexion Wi-Fi: $($_.Exception.Message)" -ForegroundColor Red
    Write-ErrorLog "Error en conexión Wi-Fi: $($_.Exception.Message)" 
    throw $_
}
#!

# 2. Configurar inicio de sesión automático (usuario local por defecto 'usuario')  
# ----------------------------------------------------------------
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force # Contraseña del usuario
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword) # Crear objeto de credenciales
# Ruta de la clave del registro para el inicio de sesión automático
$AutoLoginKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

#! Convertir SecureString a texto plano (⚠️ Riesgo de seguridad)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
$PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
# Habilitar el inicio de sesión automático
Set-ItemProperty -Path $AutoLoginKey -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $AutoLoginKey -Name "DefaultUserName" -Value $Credential.UserName
Set-ItemProperty -Path $AutoLoginKey -Name "DefaultPassword" -Value $PlainTextPassword
Write-Host "Inicio de sesion automatico configurado para el usuario '$Username'."
Write-SuccessLog "Inicio de sesión automático configurado para el usuario '$Username'."

# Limpiar la variable de texto plano después de su uso
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
Remove-Variable -Name PlainTextPassword

# 3. Cambiar nombre del equipo
# ----------------------------------------------------------------
try {
    # Cambiar el nombre del equipo
    Rename-Computer -NewName $HostName -Force -PassThru
    Write-Host "El nombre del equipo ha cambiado correctamente a '$HostName'."
    Write-SuccessLog "El nombre del equipo ha cambiado correctamente a '$HostName'."
    Start-Sleep -Seconds $Delay
} catch {
    Write-Error "Error al cambiar el nombre del equipo: $($_.Exception.Message)"
    Write-Host "Por favor, verifica que el nombre del equipo sea válido y no esté en uso en la red."
    Write-ErrorLog "Error al cambiar el nombre del equipo: $($_.Exception.Message)"
    Start-Sleep -Seconds $Delay
    exit 1
}

# 4. Crear tarea programada post-reinicio
# ----------------------------------------------------------------

# Nombre de tarea programada para unir el equipo al dominio
$TaskName = "Exec-Join-Domain" # Nombre de la tarea programada
$Script = "$ScriptPath\Script2.ps1" # Ruta del script de la segunda parte

# Verificar si existe el script
if (-Not (Test-Path $Script)) {
    Write-Error "El script '$Script' no existe en la ruta especificada."
    Write-ErrorLog "El script '$Script' no existe en la ruta especificada."  
    exit 1
}
Write-SuccessLog "Siguiente script '$Script' programado para ejecutarse al inicio."

# Configurar retraso de la tarea programada
$DelaySeconds = 30 # Retardo en segundos para iniciar la tarea programada
$DelayTask = New-TimeSpan -Seconds $DelaySeconds

# -- Crear tarea programada
$Action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoExit -ExecutionPolicy Bypass -File `"$Script`" *>> `"$successLog`" 2>> `"$errorLog`"" # Ejecutar el siguiente script
$Trigger = New-ScheduledTaskTrigger -AtLogOn -RandomDelay $DelayTask # Ejectuar al iniciar sesión
$Settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable # Ejectuar solo si hay red disponible
# $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest # Configuración de Permisos
$Principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName) -LogonType Interactive -RunLevel Highest # Configuración de Permisos
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal

try {
    # Verificar si la tarea ya existe
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "La tarea '$TaskName' ya existe. Eliminando tarea existente..." -ForegroundColor Yellow
        Write-SuccessLog "Tarea programada existente encontrada: $TaskName"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Tarea '$TaskName' eliminada correctamente." -ForegroundColor Green
        Write-SuccessLog "Tarea programada eliminada correctamente: $TaskName" 
    }
    # Crear la tarea programada
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force
    Write-Host "Se ha creado la tarea '$TaskName' para ejecutarse al inicio."
    Write-SuccessLog "Tarea programada creada correctamente: $TaskName" 
    # Start-Sleep -Seconds $Delay

    #! Verificar si la tarea se creó correctamente
    $checkTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue 
    if ($checkTask) {
        Write-Host "La tarea programada '$TaskName' se ha creado correctamente." -ForegroundColor Green
        Write-SuccessLog "Confirmación: Tarea programada '$TaskName' creada correctamente." 
    } else {
        Write-Error "Error al crear la tarea programada '$TaskName'."
        Write-ErrorLog "Error al crear la tarea programada '$TaskName'." 
        # exit 1
    }

} catch {
    Write-Error "Error al crear la tarea programada '$TaskName': $($_.Exception.Message)"
    Write-ErrorLog "Error al crear la tarea programada '$TaskName': $($_.Exception.Message)"
    # Start-Sleep -Seconds $Delay
    exit 1
}
# --

# 5. Reiniciar el equipo
# ----------------------------------------------------------------
# Verificar si el reinicio automático está habilitado en la configuración
if (-not (Get-Variable -Name 'AutoRestart' -ErrorAction SilentlyContinue)) {
    # Variable no definida en config, preguntar al usuario
    $confirmation = Read-Host "¿Estás seguro de que deseas reiniciar el equipo? (S/N)"
    # Validar entrada del usuario
    while ($confirmation -ne 'S' -and $confirmation -ne 'N') {
        Write-Host "Opción no válida. Por favor, introduce 'S' para Sí o 'N' para No." -ForegroundColor Yellow
        Write-ErrorLog "Registro de opción no válida: $confirmation"
        $confirmation = Read-Host "¿Estás seguro de que deseas reiniciar el equipo? (S/N)"
    }
} else {
    # Usar la configuración predefinida
    $confirmation = if ($AutoRestart) { 'S' } else { 'N' }
    Write-Host "Reinicio automático configurado: $(if ($AutoRestart) { 'Sí' } else { 'No' })" -ForegroundColor Cyan
    Write-SuccessLog "Modo de reinicio automático configurado: $($confirmation)"
}

# Verificar si se debe proceder con el reinicio
if ($confirmation -eq 'S') {
    Write-Host "Iniciando reinicio del sistema..." -ForegroundColor Yellow
    Write-SuccessLog "Iniciando reinicio del sistema para aplicar cambios"

    # Verificar que las tareas programadas se crearon correctamente antes de reiniciar
    $taskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "¡ADVERTENCIA! La tarea programada '$TaskName' no se encuentra." -ForegroundColor Red
        Write-ErrorLog "Advertencia pre-reinicio: Tarea programada '$TaskName' no encontrada"
        
        $forceRestart = Read-Host "¿Deseas continuar con el reinicio de todas formas? (S/N)"
        if ($forceRestart -ne 'S') {
            Write-Host "Reinicio cancelado." -ForegroundColor Yellow
            Write-ErrorLog "Reinicio cancelado - Tarea programada no encontrada"
            exit 0
        }
    }

    # Esperar antes de reiniciar
    Start-Sleep -Seconds $Delay

    # Reiniciar el equipo
    try {
        Restart-Computer -Force -ErrorAction Stop
    } catch {
        Write-Host "Error al intentar reiniciar el equipo: $_" -ForegroundColor Red
        Write-ErrorLog "Error al reiniciar el equipo: $_"
        exit 1
    }
} else {
    Write-Host "Reinicio cancelado por el usuario." -ForegroundColor Yellow
    Write-Host "Los cambios no serán aplicados hasta el reinicio del sistema!" -ForegroundColor Yellow
    Write-ErrorLog "Reinicio cancelado - Los cambios requieren reinicio para ser aplicados completamente"
    exit 0
}
# --

# Restablecer titulo de ventana al valor predeterminado
# ----------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = $tituloPredeterminado
Write-SuccessLog "Script #1 finalizado."
Write-ErrorLog "Script #1 finalizado."

# Fin del script