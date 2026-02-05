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
    try {
        # Importar archivo de configuración
        . $ConfigPath
        Write-Host "Archivo 'config' cargado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "ERROR al cargar el archivo de configuración:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Presiona Enter para salir..." -ForegroundColor Yellow
        Read-Host
        exit 1
    }
} else {
    Write-Host "Parece que hubo un error importando las configuraciones." -ForegroundColor DarkRed
    Write-Host "Confirma que el archivo 'config.ps1' exista en la carpeta raíz del script." -ForegroundColor DarkRed
    Write-Host "Ruta esperada: $ConfigPath" -ForegroundColor Yellow
    # TODO: Crear archivo (config-default.ps1) de configuración predeterminado si no se encuentra
    Write-Host ""
    Write-Host "Presiona Enter para salir..." -ForegroundColor Yellow
    Read-Host
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

#! ---------------------------------------------------------------

# ----------------------------------------------------------------
# Función de validación de conectividad de red
# ----------------------------------------------------------------
function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
        Valida la conectividad de red real después de conectar a Wi-Fi

    .DESCRIPTION
        Verifica:
        - Adaptador Wi-Fi activo
        - IP válida asignada (no APIPA 169.254.x.x)
        - Gateway predeterminado accesible
        - Conectividad con DNS

    .PARAMETER MaxRetries
        Número máximo de intentos de validación (por defecto 5)

    .PARAMETER DelaySeconds
        Segundos de espera entre intentos (por defecto 5)

    .RETURNS
        $true si la conectividad es válida, $false si falla
    #>
    param(
        [int]$MaxRetries = 5,
        [int]$DelaySeconds = 5
    )

    Write-Host "Validando conectividad de red..." -ForegroundColor Cyan
    Write-SuccessLog "Iniciando validación de conectividad de red"

    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Host "  Intento $i/$MaxRetries..." -ForegroundColor Gray

        try {
            # 1. Verificar adaptador Wi-Fi activo
            $wifiAdapter = Get-NetAdapter | Where-Object {
                $_.Status -eq "Up" -and
                ($_.InterfaceDescription -match "Wireless|Wi-Fi|802.11")
            } | Select-Object -First 1

            if (-not $wifiAdapter) {
                Write-Host "  [!] Adaptador Wi-Fi no está activo" -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            Write-Host "  [OK] Adaptador Wi-Fi activo: $($wifiAdapter.Name)" -ForegroundColor Green

            # 2. Verificar IP asignada (no APIPA)
            $ipAddress = Get-NetIPAddress -InterfaceIndex $wifiAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notmatch "^169\.254\." } |
                Select-Object -First 1

            if (-not $ipAddress) {
                Write-Host "  [!] IP válida no asignada" -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            Write-Host "  [OK] IP asignada: $($ipAddress.IPAddress)" -ForegroundColor Green
            Write-SuccessLog "IP asignada: $($ipAddress.IPAddress) en interfaz $($wifiAdapter.Name)"

            # 3. Verificar gateway predeterminado
            $gateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                Where-Object { $_.InterfaceIndex -eq $wifiAdapter.ifIndex } |
                Select-Object -First 1

            if (-not $gateway) {
                Write-Host "  [!] Gateway no encontrado" -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            Write-Host "  [OK] Gateway encontrado: $($gateway.NextHop)" -ForegroundColor Green

            # 4. Verificar acceso al gateway
            $gatewayReachable = Test-Connection -ComputerName $gateway.NextHop -Count 2 -Quiet -ErrorAction SilentlyContinue

            if (-not $gatewayReachable) {
                Write-Host "  [!] Gateway no alcanzable" -ForegroundColor Yellow
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            Write-Host "  [OK] Gateway alcanzable" -ForegroundColor Green

            # 5. Verificar DNS (opcional - puede fallar si DNS interno)
            $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $wifiAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

            if ($dnsServers -and $dnsServers.ServerAddresses.Count -gt 0) {
                Write-Host "  [OK] Servidores DNS configurados: $($dnsServers.ServerAddresses -join ', ')" -ForegroundColor Green
                Write-SuccessLog "Servidores DNS: $($dnsServers.ServerAddresses -join ', ')"
            }

            # Todas las validaciones pasaron
            Write-Host "✅ Conectividad de red validada correctamente" -ForegroundColor Green
            Write-SuccessLog "Conectividad de red validada: IP=$($ipAddress.IPAddress), Gateway=$($gateway.NextHop)"
            return $true

        } catch {
            Write-Host "  [!] Error en validación: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-ErrorLog "Error en validación de conectividad (intento $i/$MaxRetries): $($_.Exception.Message)"
        }

        if ($i -lt $MaxRetries) {
            Write-Host "  Esperando $DelaySeconds segundos antes del siguiente intento..." -ForegroundColor Gray
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    # Si llegamos aquí, todas las validaciones fallaron
    Write-Host "❌ No se pudo validar conectividad después de $MaxRetries intentos" -ForegroundColor Red
    Write-ErrorLog "Fallo en validación de conectividad después de $MaxRetries intentos"
    return $false
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
# Configurar conexión de red automático (red por defecto 'RedSSID')
# ----------------------------------------------------------------

# Soporte para credenciales cifradas y texto plano
if (Get-Variable -Name 'SecureNetworkPass' -ErrorAction SilentlyContinue) {
    # Ya se proporcionó SecureString (credenciales cifradas)
    Write-Host "Usando credenciales Wi-Fi cifradas" -ForegroundColor Green
    Write-SuccessLog "Credenciales Wi-Fi: usando formato cifrado"
    $WifiSecurePass = $SecureNetworkPass
} elseif (Get-Variable -Name 'NetworkPass' -ErrorAction SilentlyContinue) {
    # Texto plano proporcionado (método legacy)
    Write-Host "ADVERTENCIA: Usando contraseña Wi-Fi en texto plano" -ForegroundColor Yellow
    Write-SuccessLog "Credenciales Wi-Fi: usando formato texto plano (no recomendado)"
    $WifiSecurePass = ConvertTo-SecureString $NetworkPass -AsPlainText -Force
} else {
    Write-Host "ERROR: No se proporcionaron credenciales de Wi-Fi" -ForegroundColor Red
    Write-ErrorLog "No se proporcionaron credenciales de Wi-Fi"
    Write-Host ""
    Write-Host "Solución:" -ForegroundColor Yellow
    Write-Host "  1. Ejecuta Setup-Credentials.ps1 para generar credenciales cifradas, O" -ForegroundColor Gray
    Write-Host "  2. Define la variable en config.ps1:" -ForegroundColor Gray
    Write-Host "     `$NetworkPass = 'contraseña_wifi'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Presiona Enter para salir..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

#! Convertir SecureString a texto plano (requerido para perfil XML Wi-Fi)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($WifiSecurePass)
$Pswdpln = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

#! Escapar caracteres especiales XML en la contraseña
# Esto es critico para contraseñas con caracteres especiales como: < > & " ' /
$PswdplnEscaped = [System.Security.SecurityElement]::Escape($Pswdpln)

# DIAGNÓSTICO: Registrar información de la contraseña (temporalmente)
Write-SuccessLog "DEBUG - Longitud contraseña original: $($Pswdpln.Length)"
Write-SuccessLog "DEBUG - Longitud contraseña escapada: $($PswdplnEscaped.Length)"
Write-SuccessLog "DEBUG - Contraseñas son iguales: $($Pswdpln -eq $PswdplnEscaped)"
if ($Pswdpln -ne $PswdplnEscaped) {
    Write-SuccessLog "DEBUG - Se aplicó escape XML a la contraseña"
}

# 1. Configurar red Wi-Fi
try {
    # Validar variables de configuración
    if (-not $NetworkSSID -or -not $Pswdpln -or -not $Delay) {
        Write-ErrorLog "Faltan variables de configuración para la red Wi-Fi"
        throw "Faltan variables de configuración para la red Wi-Fi"
    }

    # Verificar y crear perfil Wi-Fi
    # Eliminar perfil existente para asegurar que se use la configuración actualizada
    $existingProfile = netsh wlan show profiles $NetworkSSID 2>&1 | Select-String -Pattern "Perfil" | Select-Object -First 1
    
    if ($existingProfile -and $existingProfile -notmatch "No se encuentra el perfil") {
        Write-Host "  Eliminando perfil Wi-Fi existente: $NetworkSSID" -ForegroundColor Yellow
        Write-SuccessLog "Perfil Wi-Fi existente encontrado, eliminando: $NetworkSSID"
        
        $deleteResult = netsh wlan delete profile name="$NetworkSSID" 2>&1
        Write-SuccessLog "Resultado de eliminación: $deleteResult"
        
        if ($deleteResult -match "correctamente|successfully|eliminado") {
            Write-Host "  [OK] Perfil anterior eliminado" -ForegroundColor Green
        }
        
        Start-Sleep -Seconds 2
    }
    
    # Crear nuevo perfil Wi-Fi
    Write-Host "Creando perfil para: $NetworkSSID" -ForegroundColor DarkBlue
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
    <keyMaterial>$PswdplnEscaped</keyMaterial>
    </sharedKey>
</security>
</MSM>
</WLANProfile>
"@
        $tempFile = New-TemporaryFile | Rename-Item -NewName {"$NetworkSSID.xml"} -PassThru
        
        # Guardar con codificación UTF-8 SIN BOM (crítico para netsh)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempFile.FullName, $wifiProfile, $utf8NoBom)
        
        Write-SuccessLog "Perfil XML creado en: $($tempFile.FullName)"
        Write-SuccessLog "DEBUG - Archivo XML guardado con UTF-8 sin BOM"
        
        # DIAGNÓSTICO: Guardar copia del perfil para inspección
        $debugProfilePath = "$logDirectory\wifi-profile-debug.xml"
        Copy-Item -Path $tempFile.FullName -Destination $debugProfilePath -Force -ErrorAction SilentlyContinue
        Write-SuccessLog "DEBUG - Copia del perfil guardada en: $debugProfilePath"
        
        # Agregar perfil con netsh y capturar resultado
        $netshResult = netsh wlan add profile filename="$($tempFile.FullName)" 2>&1
        Write-SuccessLog "Resultado de netsh add profile: $netshResult"
        
        if ($netshResult -match "correctamente|successfully|agregado") {
            Write-Host "  [OK] Perfil Wi-Fi agregado correctamente" -ForegroundColor Green
            Write-SuccessLog "Perfil de red Wi-Fi creado correctamente: $NetworkSSID"
        } else {
            Write-Host "  [!] Posible problema al agregar perfil" -ForegroundColor Yellow
            Write-ErrorLog "Advertencia en netsh add profile: $netshResult"
        }
        
        Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue

    # Limpiar las variables de texto plano después de su uso
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    Remove-Variable -Name Pswdpln, PswdplnEscaped -ErrorAction SilentlyContinue

    # Conectar a la red Wi-Fi
    Write-Host "Conectando a la red: $NetworkSSID" -ForegroundColor Blue
    Write-SuccessLog "Intentando conectar a red Wi-Fi: $NetworkSSID"
    
    $connectResult = netsh wlan connect name=$NetworkSSID 2>&1
    Write-SuccessLog "Resultado de netsh connect: $connectResult"
    
    Start-Sleep -Seconds $Delay 

    # Verificar conexión
    $interfaceInfo = netsh wlan show interfaces 2>&1
    Write-SuccessLog "Estado de interfaz Wi-Fi: $($interfaceInfo | Out-String)"
    
    $newConnection = $interfaceInfo | Select-String -Pattern "SSID" | Select-Object -First 1
    if ($newConnection -match $NetworkSSID) {
        Write-Host "Se ha conectado a la red Wi-Fi: $NetworkSSID" -ForegroundColor Green
        Write-SuccessLog "Conexión Wi-Fi establecida correctamente: $NetworkSSID"
    } else {
        # Intentar reconectar si la primera conexión falla
        Write-Host "2/2 - Conectando nuevamente a la red: $NetworkSSID" -ForegroundColor Yellow
        Write-SuccessLog "Intentando reconectar a la red Wi-Fi: $NetworkSSID"
        Write-ErrorLog "Primera conexión falló. SSID esperado: '$NetworkSSID', Encontrado: '$newConnection'"
        
        $connectResult2 = netsh wlan connect name=$NetworkSSID 2>&1
        Write-SuccessLog "Segundo intento - Resultado de netsh connect: $connectResult2"
        
        Start-Sleep -Seconds $Delay

        # Verificar conexión nuevamente
        $interfaceInfo2 = netsh wlan show interfaces 2>&1
        $newConnection = $interfaceInfo2 | Select-String -Pattern "SSID" | Select-Object -First 1
        
        if ($newConnection -match $NetworkSSID) {
            Write-Host "Se ha conectado correctamente a $NetworkSSID" -ForegroundColor Green
            Write-SuccessLog "Conexión Wi-Fi establecida correctamente: $NetworkSSID"
        } else {
            Write-Host "❌ Error: No se pudo conectar a la red Wi-Fi" -ForegroundColor Red
            Write-Host "  SSID esperado: $NetworkSSID" -ForegroundColor Gray
            Write-Host "  Estado actual: $newConnection" -ForegroundColor Gray
            Write-ErrorLog "Error en conexión Wi-Fi: No se pudo validar la conexión"
            Write-ErrorLog "SSID esperado: '$NetworkSSID', Estado: '$newConnection'"
            Write-ErrorLog "Interfaz completa: $($interfaceInfo2 | Out-String)"
            throw "Ha ocurrido un Error: No se pudo validar la conexion"
        }
    }

    # Validar conectividad real de red (nuevo en v0.0.4)
    Write-Host ""
    $networkValid = Test-NetworkConnectivity -MaxRetries 5 -DelaySeconds 5

    if (-not $networkValid) {
        Write-ErrorLog "No se pudo validar conectividad de red a pesar de estar conectado al SSID"
        throw "Error: Conectado a Wi-Fi pero sin conectividad de red real"
    }
    Write-Host ""

} catch {
    Write-Host "Error en conexion Wi-Fi: $($_.Exception.Message)" -ForegroundColor Red
    Write-ErrorLog "Error en conexión Wi-Fi: $($_.Exception.Message)"
    throw $_
}
#!

# 2. Configurar inicio de sesión automático (usuario local por defecto 'usuario')
# ----------------------------------------------------------------

# Validar si se proporcionaron credenciales de usuario local
if (-not $Username -or -not (Get-Variable -Name 'SecurePassword' -ErrorAction SilentlyContinue)) {
    Write-Host "Autologin local no configurado (credenciales no proporcionadas)" -ForegroundColor Yellow
    Write-SuccessLog "Autologin local omitido: credenciales no configuradas"
} else {
    # Soporte para credenciales cifradas y texto plano
    if ($SecurePassword -is [System.Security.SecureString]) {
        # Ya es SecureString (credenciales cifradas)
        Write-Host "Usando credenciales de usuario local cifradas" -ForegroundColor Green
        Write-SuccessLog "Autologin local: usando credenciales cifradas"
        $LocalSecurePass = $SecurePassword
    } elseif (Get-Variable -Name 'Password' -ErrorAction SilentlyContinue) {
        # Texto plano proporcionado (método legacy)
        Write-Host "ADVERTENCIA: Usando contraseña de usuario local en texto plano" -ForegroundColor Yellow
        Write-SuccessLog "Autologin local: usando texto plano (no recomendado)"
        $LocalSecurePass = ConvertTo-SecureString $Password -AsPlainText -Force
    } else {
        $LocalSecurePass = $SecurePassword
    }

    $Credential = New-Object System.Management.Automation.PSCredential ($Username, $LocalSecurePass)

    # Ruta de la clave del registro para el inicio de sesión automático
    $AutoLoginKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    #! Convertir SecureString a texto plano ([!]️ Requerido por registro de Windows)
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Habilitar el inicio de sesión automático
    Set-ItemProperty -Path $AutoLoginKey -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path $AutoLoginKey -Name "DefaultUserName" -Value $Credential.UserName
    Set-ItemProperty -Path $AutoLoginKey -Name "DefaultPassword" -Value $PlainTextPassword
    Write-Host "Inicio de sesion automatico configurado para el usuario '$Username'." -ForegroundColor Green
    Write-SuccessLog "Inicio de sesión automático configurado para el usuario '$Username'."

    # Limpiar la variable de texto plano después de su uso
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    Remove-Variable -Name PlainTextPassword -ErrorAction SilentlyContinue
    Remove-Variable -Name LocalSecurePass -ErrorAction SilentlyContinue
}

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

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SCRIPT #1 COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Fin del script