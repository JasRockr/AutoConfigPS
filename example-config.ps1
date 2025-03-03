# Archivo de configuración inicial

# ----------------------------------------------------------------
# Configuración de parámetros 
# ----------------------------------------------------------------

# Configuración general
$DomainName = "dominio.local"   # Nombre del dominio
$Useradmin = "admin"    # Usuario de dominio
$Passadmin = "P@ssw0rd" # Contraseña de usuario de dominio
$HostName = "NuevoNombreEquipo" # Nombre del equipo
$Delay = 5  # Tiempo en segundos para reinicio
$ScriptPath = "C:\Ruta\De\Los\Scripts"  # Ruta al segundo script (crear en el próximo paso)

# Configurar inicio de sesión local
$Username = "usuario"   # Usuario local
$Password = 'P@ssw0rd'  # Contraseña de usuario local

# Configuración de red Wi-Fi
$NetworkSSID = "Red WiFi"   # Usuario de red Wi-Fi
$NetworkPass = "ContraseñaWiFi" # Contraseña de usuario local

# Lista de aplicaciones a instalar (nombre, origen, ruta de red, parametros)
    # Winget: Instalación mediante winget
    # Network: Instalación desde una ruta de red (requiere acceso a la carpeta de red
$apps = @(
    @{ Name = "Google Chrome"; Source = "Winget" },
    @{ Name = "Notepad++"; Source = "Winget" },
    @{ Name = "Adobe.Acrobat.Reader.64-bit"; Source = "Winget" },
    @{ Name = "CustomApp"; Source = "Network"; Path = "\\NetworkPath\Installer.exe"; Arguments = "/silent /norestart" }
)

# Configuración logging
$errorLog = "C:\Logs\setup_errors.log"  # Ruta para el log de errores
$successLog = "C:\Logs\setup_success.log"  # Ruta para el log de éxito
