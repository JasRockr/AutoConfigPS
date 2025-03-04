# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P1
# Parte1: Configuraciones básicas y preparación del sistema para el reinicio.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - Parte 1"

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
}Nop 

# Configurar política de ejecución de scripts (global)
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# 1. Configurar red Wi-Fi
# ----------------------------------------------------------------
Write-Host "Configurando Red Wi-Fi..." -ForegroundColor Cyan
Start-Sleep -Seconds $Delay

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
        throw "Faltan variables de configuración para la red Wi-Fi"
    }

    # Verificar y crear perfil Wi-Fi
    # $existingProfile = Get-WiFiProfile -Name $NetworkSSID -ErrorAction SilentlyContinue
    $existingProfile = netsh wlan show profiles $NetworkSSID | Select-String -Pattern "Perfil" | Select-Object -First 1
    if ($existingProfile -match "No se encuentra el perfil") {
        Write-Host "Creando perfil para: $NetworkSSID" -ForegroundColor DarkBlue
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
    }

    # Limpiar la variable de texto plano después de su uso
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    Remove-Variable -Name Pswdpln

    # Conectar a la red Wi-Fi
    Write-Host "Iniciando conexión a: $NetworkSSID" -ForegroundColor Blue
    netsh wlan connect name=$NetworkSSID
    Start-Sleep -Seconds $Delay 

    # Verificar conexión
    $newConnection = netsh wlan show interfaces | Select-String -Pattern "SSID" | Select-Object -First 1
    if ($newConnection -match $NetworkSSID) {
        Write-Host "Conexión exitosa a $NetworkSSID" -ForegroundColor Green
    } else {
        # Intentar reconectar si la primera conexión falla
        Write-Host "Primer intento de conexión fallido. Intentando nuevamente..." -ForegroundColor Yellow
        netsh wlan connect name=$NetworkSSID
        Start-Sleep -Seconds $Delay

        # Verificar conexión nuevamente
        $newConnection = netsh wlan show interfaces | Select-String -Pattern "SSID" | Select-Object -First 1
        if ($newConnection -match $NetworkSSID) {
            Write-Host "Conexión exitosa a $NetworkSSID" -ForegroundColor Green
        } else {
            throw "Error de conexión: No se pudo validar la conexión"
        }
    }
} catch {
    Write-Host "Error en conexión Wi-Fi: $($_.Exception.Message)" -ForegroundColor Red
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

# Limpiar la variable de texto plano después de su uso
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
Remove-Variable -Name PlainTextPassword

# 3. Cambiar nombre del equipo
# ----------------------------------------------------------------
try {
    # Cambiar el nombre del equipo
    Rename-Computer -NewName $HostName -Force -PassThru
    Write-Host "El nombre del equipo ha cambiado correctamente a '$HostName'."
    Start-Sleep -Seconds $Delay
} catch {
    Write-Error "Error al cambiar el nombre del equipo: $($_.Exception.Message)"
    Write-Host "Por favor, verifica que el nombre del equipo sea válido y no esté en uso en la red."
    Start-Sleep -Seconds $Delay
    exit 1
}

# 4. Crear tarea programada post-reinicio
# ----------------------------------------------------------------

# Nombre de tarea programada para unir el equipo al dominio
$TaskName = "Exec-Join-Domain" # Nombre de la tarea programada
$Script = "$ScriptPath\Script2.ps1" # Ruta del script de la segunda parte
$DelayTask = 60 # Retardo en segundos para iniciar la tarea programada

# Verificar si existe el script
if (-Not (Test-Path $Script)) {
    Write-Error "El script '$Script' no existe en la ruta especificada."
    exit 1
}

# -- 
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $Script" # Acción a ejecutar
$Trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay "00:00:$DelayTask" # Disparador de la tarea programada: Al iniciar el sistema
$Settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable -HistoryEnabled # Configuración de la tarea programada
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest # Configuración del usuario principal con permisos de administrador
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal

try {
    # Verificar si la tarea ya existe
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "La tarea '$TaskName' ya existe. Eliminando tarea existente..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Tarea '$TaskName' eliminada correctamente." -ForegroundColor Green
    }
    # Crear la tarea programada
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force
    Write-Host "Se ha creado la tarea '$TaskName' para ejecutarse al inicio."
    Start-Sleep -Seconds $Delay
} catch {
    Write-Error "Error al crear la tarea programada '$TaskName': $($_.Exception.Message)"
    Start-Sleep -Seconds $Delay
    exit 1
}
# --

# 5. Reiniciar el equipo
# ----------------------------------------------------------------
# $confirmation = Read-Host "¿Estás seguro de que deseas reiniciar el equipo? (S/N)"
$confirmation = 'S'
if ($confirmation -eq 'S') {
    Write-Host "Iniciando reinicio del sistema..."
    Start-Sleep -Seconds $Delay
    Restart-Computer -Force
} else {
    Write-Host "Reinicio cancelado por el usuario."
    Write-Host "Los cambios no serán aplicados hasta el reinicio del sistema!" -ForegroundColor Yellow
    exit 0
}

# Restablecer titulo de ventana al valor predeterminado
# ----------------------------------------------------------------
#
$Host.UI.RawUI.WindowTitle = $tituloPredeterminado
# Write-Host "Script finalizado. Puedes cerrar la ventana." -ForegroundColor Green
# Read-Host -Prompt "Presione Enter para cerrar la consola..."

# Fin del script