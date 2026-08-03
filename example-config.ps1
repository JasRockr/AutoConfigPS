# Archivo de configuración inicial

# ----------------------------------------------------------------
# Configuración de parámetros
# ----------------------------------------------------------------

# ================================================================
# IMPORTANTE: SISTEMA DE CREDENCIALES SEGURAS
# ================================================================
# Este archivo asume que ya ejecutaste .\scripts\Setup-Credentials.ps1 (o que
# init.bat lo hizo automáticamente en el primer arranque) - eso es lo que
# genera SecureConfig\ con las credenciales cifradas que se cargan abajo
# (OPCIÓN A, activa por defecto).
#
# Si por algún motivo preferís texto plano (NO recomendado, solo para
# pruebas sin datos sensibles), cada sección de credenciales más abajo trae
# comentada la OPCIÓN B como alternativa: comentá/eliminá el bloque de la
# OPCIÓN A correspondiente y descomentá el de la OPCIÓN B.
# ================================================================

# Configuración general
$DomainName = "dominio.local"   # Nombre del dominio (FQDN)
$HostName = "NuevoNombreEquipo" # Nombre del equipo (NetBIOS, max 15 caracteres)
$Delay = 5  # Tiempo en segundos para reinicio
$ScriptPath = "$PSScriptRoot\scripts"  # Ruta dinámica a la carpeta scripts\

# ----------------------------------------------------------------
# EJECUCIÓN DESATENDIDA (orquestador Invoke-AutoConfigPS.ps1)
# ----------------------------------------------------------------
$AutoRestart = $true           # Reinicia automáticamente entre pasos (recomendado
                                # para ejecución 100% desatendida). Si es $false, el
                                # pipeline espera un reinicio manual y retoma solo.
$MaxStepAttempts = 3            # Reintentos por paso antes de detener el pipeline
$StepRetryDelaySeconds = 30     # Espera entre reintentos de un mismo paso

# Politica cuando el nombre del equipo YA existe en Active Directory:
#   'Halt'        (recomendado, default) -> detiene el proceso, loguea la causa y
#                  notifica. NO auto-renombra ni limpia (las credenciales/config se
#                  conservan). Un humano resuelve el conflicto: borra el objeto de
#                  equipo obsoleto en AD, o cambia $HostName aca, y re-ejecuta init.bat.
#   'Alternative' -> genera un nombre alternativo (ej. P8989-358) y continua. Deja el
#                  objeto viejo en AD y puede violar el esquema de nombres; usar solo
#                  si tu organizacion lo prefiere asi.
$OnDuplicateName = 'Halt'
$WifiConnectMaxRetries = 5      # Intentos de asociacion Wi-Fi (AP con trafico puede
                                 # tardar en asociar aunque el perfil sea correcto)
$WifiConnectRetryDelaySeconds = 10  # Espera entre intentos de conexion Wi-Fi

# Limpieza final al completar el pipeline (recomendado dejar en $true). Al terminar,
# elimina los artefactos del proceso que no aportan valor al equipo ya configurado:
# las credenciales cifradas (SecureConfig\ - IMPORTANTE por seguridad), el estado
# (C:\ProgramData\AutoConfigPS), config.ps1, apps.json y el marcador de fin. Los LOGS
# (C:\Logs\setup_*.log) SIEMPRE se conservan como registro permanente/auditoria.
# Ponelo en $false SOLO para depuracion controlada: en ese caso NO se borra nada y el
# log deja registradas las rutas exactas que quedaron, para borrarlas a mano despues.
$CleanupOnFinish = $true

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

# Importar módulo de gestión segura de credenciales
. "$PSScriptRoot\modules\CredentialStore.ps1"

# Cargar clave AES compartida (generada por Setup-Credentials.ps1)
$keyPath = "$PSScriptRoot\SecureConfig\.aeskey"
if (-not (Test-Path $keyPath)) {
    throw "No se encontro la clave de cifrado en '$keyPath'. Ejecuta .\scripts\Setup-Credentials.ps1 primero (o init.bat, que lo hace por vos)."
}
$aesKey = [System.IO.File]::ReadAllBytes($keyPath)

# OPCIÓN A (RECOMENDADA, activa por defecto): Credenciales cifradas con AES
$DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.json"
try {
    $DomainCredential = Import-SecureCredential -Path $DomainCredPath -Key $aesKey
    $Useradmin = $DomainCredential.UserName
    $SecurePassadmin = $DomainCredential.Password
} catch {
    throw "No se pudieron cargar las credenciales de dominio desde '$DomainCredPath': $($_.Exception.Message). Ejecuta .\scripts\Setup-Credentials.ps1 para configurarlas."
}

# OPCIÓN B (NO RECOMENDADA): Texto plano
# Para usar esto en vez de la Opción A: comenta/elimina el bloque de arriba
# (desde "Importar módulo..." hasta el "catch" de credenciales de dominio) y
# descomenta estas 3 líneas.
# $Useradmin = "admin"    # Usuario de dominio
# $Passadmin = "P@ssw0rd" # Contraseña de usuario de dominio
# $SecurePassadmin = ConvertTo-SecureString $Passadmin -AsPlainText -Force

# ----------------------------------------------------------------
# CREDENCIALES DE USUARIO LOCAL (opcional - autologin temporal)
# ----------------------------------------------------------------

# OPCIÓN A (RECOMENDADA, activa por defecto): Credenciales cifradas
$LocalCredPath = "$PSScriptRoot\SecureConfig\cred_local.json"
if (Test-Path $LocalCredPath) {
    try {
        $LocalCredential = Import-SecureCredential -Path $LocalCredPath -Key $aesKey
        $Username = $LocalCredential.UserName
        $SecurePassword = $LocalCredential.Password
    } catch {
        Write-Warning "No se pudieron cargar credenciales locales cifradas: $($_.Exception.Message). Autologin local deshabilitado."
        $Username = $null
        $SecurePassword = $null
    }
} else {
    # Es opcional: si no se configuro con Setup-Credentials.ps1, simplemente se omite.
    $Username = $null
    $SecurePassword = $null
}

# OPCIÓN B (NO RECOMENDADA): Texto plano
# Para usar esto en vez de la Opción A: comenta/elimina el bloque de arriba y
# descomenta estas 3 líneas.
# $Username = "usuario"   # Usuario local
# $Password = 'P@ssw0rd'  # Contraseña de usuario local
# $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

# ----------------------------------------------------------------
# CONFIGURACIÓN DE RED WI-FI
# ----------------------------------------------------------------

$NetworkSSID = "Red WiFi"   # SSID de la red Wi-Fi corporativa

# OPCIÓN A (RECOMENDADA, activa por defecto): Contraseña cifrada
$WifiCredPath = "$PSScriptRoot\SecureConfig\cred_wifi.json"
try {
    $WifiCredential = Import-SecureCredential -Path $WifiCredPath -Key $aesKey
    $SecureNetworkPass = $WifiCredential.Password
} catch {
    throw "No se pudo cargar la contraseña de Wi-Fi cifrada desde '$WifiCredPath': $($_.Exception.Message). Ejecuta .\scripts\Setup-Credentials.ps1 para configurarla."
}

# OPCIÓN B (NO RECOMENDADA): Texto plano
# Para usar esto en vez de la Opción A: comenta/elimina el bloque de arriba y
# descomenta estas 2 líneas.
# $NetworkPass = "ContraseñaWiFi" # Contraseña de red Wi-Fi
# $SecureNetworkPass = ConvertTo-SecureString $NetworkPass -AsPlainText -Force

# ----------------------------------------------------------------
# LISTA DE APLICACIONES
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
