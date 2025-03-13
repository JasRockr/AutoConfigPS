# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P2
# Parte2: Unir equipo al dominio y preparar sistema para el reinicio.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - Parte 2"

# ----------------------------------------------------------------
# # Flujo de ejecución del script # 2
# 0. Cargar archivo de configuración.
# 1. Configurar inicio de sesión automático con usuario administrador.
# 2. Unir equipo al dominio.
# 3. Crear una tarea programada para ejecutar la tercera parte del script tras el reinicio.
# 4. Eliminar la tarea creada en el script anterior.
# 5. Reiniciar el equipo.
# ----------------------------------------------------------------

# # ----------------------------------------------------------------
# # Flujo principal
# # ----------------------------------------------------------------

# @param $Useradmin Usuario de dominio con permisos de administrador
# @param $Passadmin Contraseña de usuario de dominio
# @param $DomainName Nombre del dominio
# @param $Delay Tiempo de espera en segundos
# @param $ScriptPath Ruta del script de la tercera parte

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

# 1. Configurar actualización de inicio de sesión automático (usuario de dominio por defecto 'administrador')
# ----------------------------------------------------------------
$SecurePassword = ConvertTo-SecureString $Passadmin -AsPlainText -Force # Contraseña del usuario de dominio (administrador)
$Credential = New-Object System.Management.Automation.PSCredential ($Useradmin, $SecurePassword) # Crear objeto de credenciales
# Ruta de la clave del registro para el inicio de sesión automático
$AutoLoginKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Convertir SecureString a texto plano (⚠️ Riesgo de seguridad)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
$PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
# Habilitar el inicio de sesión automático
Set-ItemProperty -Path $AutoLoginKey -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $AutoLoginKey -Name "DefaultUserName" -Value $Credential.UserName
Set-ItemProperty -Path $AutoLoginKey -Name "DefaultPassword" -Value $PlainTextPassword
Write-Host "Inicio de sesion automático configurado para el usuario '$Useradmin'."

# Limpiar la variable de texto plano después de su uso
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
Remove-Variable -Name PlainTextPassword

Start-Sleep -Seconds $Delay

# 2. Unir el equipo al dominio
# ----------------------------------------------------------------
try {
    # Verificar si el equipo ya está unido al dominio
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -eq $DomainName) {
        Write-Host "El equipo ya está unido al dominio '$DomainName'." -ForegroundColor Yellow
    } else {
        Add-Computer -DomainName $DomainName -Credential $Credential -Restart
        Write-Host "El equipo se unió correctamente al dominio. Reiniciando..."
        Start-Sleep -Seconds $Delay
    }
} catch {
    Write-Error "Error al unir el equipo al dominio: $($_.Exception.Message)"
    Start-Sleep -Seconds $Delay
    exit 1
}

# 3. Crear tarea programada post-reinicio
# ----------------------------------------------------------------

# Nombre de tarea programada para confirmar cambios aplicados en el equipo
$TaskName = "Exec-Check-Continue"
$Script = "$ScriptPath\Script3.ps1"
$DelayTask = 60 # Retardo en segundos para iniciar la tarea programada

# Verificar si existe el script
if (-Not (Test-Path $Script)) {
    Write-Error "El script '$Script' no existe en la ruta especificada."
    exit 1
}

# Configurar retraso de la tarea programada
$DelaySeconds = 60 # Retardo en segundos para iniciar la tarea programada
$DelayTask = New-TimeSpan -Seconds $DelaySeconds

# -- 
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $Script" # Acción a ejecutar
$Trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay $DelayTask # Disparador de la tarea programada: Al iniciar el sistema
$Settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable # Configuración de la tarea programada
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

# 4. Eliminar la tarea programada previamente creada
# ----------------------------------------------------------------
Write-Host "Eliminando tarea programada anterior..." -ForegroundColor Cyan

# Eliminar tarea programada 'Exec-Join-Domain' 
$DelTaskName = "Exec-Join-Domain"

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