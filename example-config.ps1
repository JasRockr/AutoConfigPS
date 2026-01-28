# Archivo de configuración inicial

# ----------------------------------------------------------------
# Configuración de parámetros
# ----------------------------------------------------------------

# ================================================================
# IMPORTANTE: SISTEMA DE CREDENCIALES SEGURAS
# ================================================================
# Este proyecto ahora soporta credenciales cifradas usando DPAPI de Windows.
#
# OPCIÓN A (RECOMENDADA): Usar credenciales cifradas
# ----------------------------------------------------
# 1. Ejecuta: .\scripts\Setup-Credentials.ps1
# 2. Sigue el asistente para configurar las credenciales
# 3. Las credenciales se guardarán cifradas en .\SecureConfig\
# 4. Descomenta las líneas "OPCIÓN A" más abajo
# 5. Comenta o elimina las líneas "OPCIÓN B" (texto plano)
#
# OPCIÓN B (NO RECOMENDADA): Usar texto plano
# ----------------------------------------------------
# Solo para ambientes de prueba sin datos sensibles.
# Mantén las configuraciones actuales con contraseñas en texto plano.
# ================================================================

# Configuración general
$DomainName = "dominio.local"   # Nombre del dominio (FQDN)
$HostName = "NuevoNombreEquipo" # Nombre del equipo (NetBIOS, max 15 caracteres)
$Delay = 5  # Tiempo en segundos para reinicio
$ScriptPath = "C:\Ruta\De\Los\Scripts"  # Ruta a la carpeta scripts\

# ----------------------------------------------------------------
# UNIDAD ORGANIZACIONAL (OU) EN ACTIVE DIRECTORY - OPCIONAL
# ----------------------------------------------------------------
# Si deseas que el equipo se una a una OU específica en lugar del contenedor
# "Computers" predeterminado, descomenta y configura la siguiente variable:
#
# Formato: Distinguished Name (DN) completo de la OU
# Ejemplo: "OU=Workstations,OU=Computers,DC=dominio,DC=local"
#
# NOTA: El usuario de dominio debe tener permisos para crear objetos en esta OU
# $OUPath = "OU=Workstations,OU=Computers,DC=dominio,DC=local"

# ----------------------------------------------------------------
# CREDENCIALES DE DOMINIO
# ----------------------------------------------------------------

# OPCIÓN A (RECOMENDADA): Credenciales cifradas
# Descomenta estas líneas después de ejecutar Setup-Credentials.ps1
# $DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.xml"
# $DomainCredential = Import-Clixml -Path $DomainCredPath
# $Useradmin = $DomainCredential.UserName
# $SecurePassadmin = $DomainCredential.Password

# OPCIÓN B (NO RECOMENDADA): Texto plano
# Comenta o elimina estas líneas cuando uses credenciales cifradas
$Useradmin = "admin"    # Usuario de dominio
$Passadmin = "P@ssw0rd" # Contraseña de usuario de dominio
$SecurePassadmin = ConvertTo-SecureString $Passadmin -AsPlainText -Force

# ----------------------------------------------------------------
# CREDENCIALES DE USUARIO LOCAL
# ----------------------------------------------------------------

# OPCIÓN A (RECOMENDADA): Credenciales cifradas
# Descomenta estas líneas después de ejecutar Setup-Credentials.ps1
# $LocalCredPath = "$PSScriptRoot\SecureConfig\cred_local.xml"
# if (Test-Path $LocalCredPath) {
#     $LocalCredential = Import-Clixml -Path $LocalCredPath
#     $Username = $LocalCredential.UserName
#     $SecurePassword = $LocalCredential.Password
# } else {
#     Write-Warning "No se encontraron credenciales locales cifradas. Autologin local deshabilitado."
#     $Username = $null
#     $SecurePassword = $null
# }

# OPCIÓN B (NO RECOMENDADA): Texto plano
# Comenta o elimina estas líneas cuando uses credenciales cifradas
$Username = "usuario"   # Usuario local
$Password = 'P@ssw0rd'  # Contraseña de usuario local
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

# ----------------------------------------------------------------
# CONFIGURACIÓN DE RED WI-FI
# ----------------------------------------------------------------

$NetworkSSID = "Red WiFi"   # SSID de la red Wi-Fi corporativa

# OPCIÓN A (RECOMENDADA): Contraseña cifrada
# Descomenta estas líneas después de ejecutar Setup-Credentials.ps1
# $WifiCredPath = "$PSScriptRoot\SecureConfig\cred_wifi.xml"
# $WifiCredential = Import-Clixml -Path $WifiCredPath
# $SecureNetworkPass = $WifiCredential.Password

# OPCIÓN B (NO RECOMENDADA): Texto plano
# Comenta o elimina estas líneas cuando uses credenciales cifradas
$NetworkPass = "ContraseñaWiFi" # Contraseña de red Wi-Fi
$SecureNetworkPass = ConvertTo-SecureString $NetworkPass -AsPlainText -Force

# ----------------------------------------------------------------
# LISTA DE APLICACIONES (v0.0.4)
# ----------------------------------------------------------------
# Campos disponibles:
#   - Name: Nombre de la aplicación (requerido)
#   - Source: "Winget" o "Network" (requerido)
#   - ID: ID específico de Winget (opcional, recomendado para evitar ambigüedades)
#   - Path: Ruta al instalador (requerido solo para Network)
#   - Arguments: Argumentos de instalación (opcional para Network, por defecto /silent)
#   - Timeout: Timeout en segundos (opcional, por defecto 300s para Winget, 600s para Network)
#
# NOTA: Si defines apps aquí Y existe apps.json, se usará apps.json
$apps = @(
    @{
        Name = "Google Chrome"
        Source = "Winget"
        ID = "Google.Chrome"
        Timeout = 300
    },
    @{
        Name = "Microsoft Visual Studio Code"
        Source = "Winget"
        ID = "Microsoft.VisualStudioCode"
        Timeout = 240
    },
    @{
        Name = "Notepad++"
        Source = "Winget"
        Timeout = 180
    },
    @{
        Name = "Adobe Acrobat Reader"
        Source = "Winget"
        ID = "Adobe.Acrobat.Reader.64-bit"
        Timeout = 360
    },
    @{
        Name = "CustomApp"
        Source = "Network"
        Path = "\\NetworkPath\Installer.exe"
        Arguments = "/silent /norestart"
        Timeout = 600
    }
)

# Configuración logging
$errorLog = "C:\Logs\setup_errors.log"  # Ruta para el log de errores
$successLog = "C:\Logs\setup_success.log"  # Ruta para el log de éxito
