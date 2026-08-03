# scripts/Run-InstallAppsUser.ps1
# Corre la instalacion de aplicaciones EN EL CONTEXTO DEL USUARIO INTERACTIVO
# (el usuario del autologin), lanzado por el orquestador via la tarea programada
# 'AutoConfigPS-InstallApps'. NO corre como SYSTEM.
#
# Por que en contexto de usuario y no SYSTEM (encontrado en pruebas reales):
#   - winget (App Installer) es un paquete MSIX con dependencias (VCLibs/UI.Xaml)
#     registradas por-usuario; corriendo el .exe como SYSTEM falla con
#     0xC0000135 (DLL no encontrada). En una sesion de usuario tiene su contexto
#     MSIX y funciona normal.
#   - Los instaladores en un share de red (\\servidor\...) requieren credenciales
#     de usuario; SYSTEM accede como la cuenta de EQUIPO (EQUIPO$), que no suele
#     tener permiso, y "no encuentra" el archivo aunque exista.
#
# Escribe el resultado en C:\ProgramData\AutoConfigPS\installapps_result.json (via
# escritura a .tmp + rename atomico) - esa es la senal de "termine" que el
# orquestador (SYSTEM) espera para marcar el paso.

param([Parameter(Mandatory = $true)][string]$ProjectRoot)

$resultPath = 'C:\ProgramData\AutoConfigPS\installapps_result.json'
$result = @{ Status = 'Failed'; Message = 'El runner de InstallApps no llego a completar' }

try {
    . (Join-Path $ProjectRoot 'modules\Logging.ps1')
    . (Join-Path $ProjectRoot 'modules\ProgressBar.ps1')
    Initialize-AutoConfigLogging -LogDirectory 'C:\Logs'

    # config.ps1 aporta $apps (fallback si no hay apps.json) y tunables. No es
    # critico si falla al cargar (apps.json es la fuente principal, generada por el
    # wizard), por eso va en try/catch.
    $configPath = Join-Path $ProjectRoot 'config.ps1'
    if (Test-Path $configPath) {
        try {
            Set-Location -Path $ProjectRoot
            . $configPath
        } catch {
            Write-ErrorLog "No se pudo cargar config.ps1 en el runner de usuario (se usa apps.json): $($_.Exception.Message)"
        }
    }

    . (Join-Path $ProjectRoot 'steps\Step-InstallApps.ps1')

    Write-SuccessLog "InstallApps corriendo en el contexto del usuario interactivo '$env:USERNAME' (winget MSIX + share de red requieren sesion de usuario, no SYSTEM)"

    # Asegurar que winget (App Installer) este REGISTRADO para este usuario. Un perfil
    # recien creado -ej. el admin de dominio en su PRIMER login tras unir al dominio-
    # puede tener el App Installer PROVISTO a nivel de equipo pero NO registrado para
    # el usuario; entonces winget.exe falla (0xC0000135) o se cuelga. Registrarlo
    # explicitamente lo resuelve. Best-effort.
    try {
        if (-not (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)) {
            Write-SuccessLog 'winget no esta registrado para este usuario (perfil nuevo) - registrando App Installer...'
            Get-AppxPackage -AllUsers -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue | ForEach-Object {
                $manifest = Join-Path $_.InstallLocation 'AppXManifest.xml'
                if (Test-Path $manifest) { Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue }
            }
            if (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue) {
                Write-SuccessLog 'App Installer (winget) registrado correctamente para el usuario actual'
            } else {
                Write-ErrorLog 'No se pudo registrar App Installer para el usuario (winget podria fallar)'
            }
        }
    } catch {
        Write-ErrorLog "Error al registrar winget para el usuario: $($_.Exception.Message)"
    }

    $stepResult = Invoke-StepInstallApps -ProjectRoot $ProjectRoot
    $result = @{ Status = $stepResult.Status; Message = $stepResult.Message }
} catch {
    $result = @{ Status = 'Failed'; Message = "Error en el runner de InstallApps (usuario): $($_.Exception.Message)" }
} finally {
    # Escritura atomica (.tmp + rename) para que el orquestador nunca lea un JSON a
    # medio escribir.
    try {
        $json = $result | ConvertTo-Json
        $tmp = "$resultPath.tmp"
        [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -Path $tmp -Destination $resultPath -Force
    } catch {
        # Si ni siquiera se puede escribir el resultado, el orquestador cae por timeout.
    }
}
