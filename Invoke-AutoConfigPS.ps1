<#
.SYNOPSIS
    Orquestador unico de AutoConfigPS: punto de entrada de todo el pipeline
    desatendido, idempotente y resumible a traves de reinicios.

.DESCRIPTION
    Ejecuta el pipeline de configuracion (Wi-Fi, renombrado, union a dominio,
    instalacion de apps, finalizacion) leyendo y persistiendo su progreso en
    C:\ProgramData\AutoConfigPS\state.json. Es SIEMPRE idempotente: se puede invocar
    tantas veces como haga falta (manualmente, o automaticamente por la tarea
    programada 'AutoConfigPS-Orchestrator' que se registra a si mismo en el primer
    arranque) y siempre retoma exactamente donde se quedo.

    No usa Read-Host en ningun punto. Las decisiones que antes eran prompts
    interactivos (reiniciar si/no, continuar con nombre duplicado) ahora se resuelven
    con configuracion ($AutoRestart) o con logica automatica sin intervencion.

.NOTES
    PowerShell 5.1 puro - sin modulos externos, sin sintaxis de PowerShell 7+.
    Autor: Json Rivera (JasRockr!)
#>

param()

$ProjectRoot = $PSScriptRoot

# ============================================================
# 0. Cargar modulos base (dot-source, sin dependencias externas)
# ============================================================

. (Join-Path $ProjectRoot 'modules\Logging.ps1')
. (Join-Path $ProjectRoot 'modules\StateMachine.ps1')
. (Join-Path $ProjectRoot 'modules\ProgressBar.ps1')
. (Join-Path $ProjectRoot 'modules\Preflight.ps1')

Initialize-AutoConfigLogging -LogDirectory 'C:\Logs'

Write-Section -Title 'AutoConfigPS - Orquestador'
Write-Host "Fecha/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Usuario: $env:USERNAME   Equipo: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host ''

Write-SuccessLog '=========================================='
Write-SuccessLog "AutoConfigPS iniciado - Usuario: $env:USERNAME, Equipo: $env:COMPUTERNAME"

# ============================================================
# 1. Verificar privilegios de administrador (sin #Requires: asi el mensaje amigable
#    de abajo siempre se puede mostrar, en vez de terminar con un error generico de
#    PowerShell antes de que este codigo llegue a ejecutarse).
# ============================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[X] Este script requiere privilegios de administrador.' -ForegroundColor Red
    Write-Host '    Ejecuta init.bat con "Ejecutar como administrador".' -ForegroundColor Yellow
    Write-ErrorLog 'Ejecucion abortada: faltan privilegios de administrador'
    exit 1
}

# ============================================================
# 2. Estado: si es la primera ejecucion, correr preflight antes de crear el estado
#    persistente. Si ya existe estado, se salta el preflight y se retoma.
# ============================================================

$stateAlreadyExisted = Initialize-AutoConfigState

if (-not $stateAlreadyExisted) {
    $preflightResult = Test-AutoConfigPrerequisites -ProjectRoot $ProjectRoot
    Write-PreflightReport -Result $preflightResult

    if (-not $preflightResult.CanProceed) {
        Write-ErrorLog 'Preflight fallido: hay validaciones criticas sin cumplir. Pipeline no iniciado.'
        exit 1
    }
}

$state = Get-AutoConfigState

if (Test-AutoConfigCompleted -State $state) {
    Write-Host '[OK] La configuracion ya se completo anteriormente. Nada que hacer.' -ForegroundColor Green
    Write-SuccessLog 'Invocacion sin efecto: el pipeline ya estaba Completed'
    exit 0
}

# Si el pipeline habia quedado en Failed, resetear SOLO los pasos que fallaron
# (los ya completados/omitidos quedan intactos) y retomar. Esto es seguro sin
# pedir confirmacion: la tarea programada de reanudacion automatica se
# autoelimina apenas se llega a Failed, asi que este estado solo se puede
# volver a alcanzar si un humano volvio a ejecutar init.bat/el orquestador a
# proposito - nunca por una reanudacion automatica tras reinicio.
if ($state.Status -eq 'Failed') {
    $resetSteps = @()
    foreach ($stepName in $state.Steps.PSObject.Properties.Name) {
        $stepState = $state.Steps.$stepName
        if ($stepState.Status -eq 'Failed') {
            $stepState.Status = 'Pending'
            $stepState.Attempts = 0
            $stepState.Message = ''
            $resetSteps += $stepName
        }
    }
    $state.Status = 'InProgress'
    Save-AutoConfigState -State $state
    Write-Host "[i] La corrida anterior habia fallado. Reintentando: $($resetSteps -join ', ')" -ForegroundColor Cyan
    Write-SuccessLog "Pipeline retomado tras Failed previo - pasos reiniciados: $($resetSteps -join ', ')"
}

# Reactivar el pipeline si quedo en AwaitingReboot (caso normal tras un reinicio)
if ($state.Status -eq 'AwaitingReboot') {
    $state.Status = 'InProgress'
    Save-AutoConfigState -State $state
}

# ============================================================
# 3. Cargar config.ps1 (dot-source). Debe hacerse ANTES de cargar los steps porque
#    varios steps usan variables de config.ps1 directamente (mismo patron que ya
#    usaba el proyecto original).
# ============================================================

$ConfigPath = Join-Path $ProjectRoot 'config.ps1'
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[X] No se encontro config.ps1 en: $ConfigPath" -ForegroundColor Red
    Write-ErrorLog "config.ps1 no encontrado en: $ConfigPath"
    exit 1
}

try {
    Set-Location -Path $ProjectRoot
    . $ConfigPath
    Write-SuccessLog 'config.ps1 cargado correctamente'
} catch {
    Write-Host "[X] Error al cargar config.ps1: $($_.Exception.Message)" -ForegroundColor Red
    Write-ErrorLog "Error al cargar config.ps1: $($_.Exception.Message)"
    exit 1
}

if (-not (Get-Variable -Name 'AutoRestart' -ErrorAction SilentlyContinue)) { $AutoRestart = $true }
if (-not (Get-Variable -Name 'MaxStepAttempts' -ErrorAction SilentlyContinue)) { $MaxStepAttempts = 3 }
if (-not (Get-Variable -Name 'StepRetryDelaySeconds' -ErrorAction SilentlyContinue)) { $StepRetryDelaySeconds = 30 }
if (-not (Get-Variable -Name 'Delay' -ErrorAction SilentlyContinue)) { $Delay = 5 }
if (-not (Get-Variable -Name 'WifiConnectMaxRetries' -ErrorAction SilentlyContinue)) { $WifiConnectMaxRetries = 5 }
if (-not (Get-Variable -Name 'WifiConnectRetryDelaySeconds' -ErrorAction SilentlyContinue)) { $WifiConnectRetryDelaySeconds = 10 }
if (-not (Get-Variable -Name 'CleanupOnFinish' -ErrorAction SilentlyContinue)) { $CleanupOnFinish = $true }
if (-not (Get-Variable -Name 'OnDuplicateName' -ErrorAction SilentlyContinue)) { $OnDuplicateName = 'Halt' }

# ============================================================
# 4. Cargar los steps (dot-source)
# ============================================================

. (Join-Path $ProjectRoot 'steps\Step-ConfigureWifi.ps1')
. (Join-Path $ProjectRoot 'steps\Step-RenameComputer.ps1')
. (Join-Path $ProjectRoot 'steps\Step-JoinDomain.ps1')
. (Join-Path $ProjectRoot 'steps\Step-InstallApps.ps1')
. (Join-Path $ProjectRoot 'steps\Step-Finalize.ps1')

# ============================================================
# 5. Registrar (idempotente) la UNICA tarea programada que retoma el pipeline tras
#    cada reinicio. Se registra antes de ejecutar cualquier paso que pueda reiniciar.
# ============================================================

function Register-AutoConfigResumeTask {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $taskName = 'AutoConfigPS-Orchestrator'
    $scriptPath = Join-Path $ProjectRoot 'Invoke-AutoConfigPS.ps1'

    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) { return }

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = 'PT1M'
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    # SID (S-1-5-18) en vez del nombre "SYSTEM": aunque en pruebas reales este
    # nombre si resolvio bien, se usa SID por consistencia con el resto del
    # proyecto tras dos bugs reales de resolucion de nombres por locale.
    $principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
    Enable-ScheduledTask -TaskName $taskName | Out-Null
    Write-SuccessLog "Tarea de reanudacion '$taskName' registrada (AtStartup +60s, SYSTEM)"
}

function Unregister-AutoConfigResumeTask {
    $taskName = 'AutoConfigPS-Orchestrator'
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-SuccessLog "Tarea de reanudacion '$taskName' eliminada (pipeline finalizado)"
    }
}

function Register-AutoConfigNotifyTask {
    <#
    .SYNOPSIS
        Registra (idempotente) la tarea AtLogOn que muestra al usuario interactivo el
        estado del pipeline (en progreso / completado / fallido). Se registra desde
        el primer arranque -no solo al finalizar- para que alguien que inicie sesion
        DURANTE una ventana de reinicio vea "no apagues el equipo" en vez de nada.
    #>
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $taskName = 'AutoConfigPS-Notify'
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) { return }

    $notifyScript = Join-Path $ProjectRoot 'steps\Show-Notification.ps1'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$notifyScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    # SID (S-1-5-32-545) en vez de "BUILTIN\Users": en Windows en espanol el
    # grupo se llama "Usuarios" y Register-ScheduledTask no resuelve el nombre
    # en ingles (mismo tipo de bug que icacls con Administrators, encontrado
    # en pruebas reales - HRESULT 0x80070534 = ERROR_NONE_MAPPED).
    $principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
    Write-SuccessLog "Tarea de notificacion '$taskName' registrada (AtLogOn; se autoelimina al llegar a un estado definitivo)"
}

function Invoke-AutoConfigInstallAppsAsUser {
    <#
    .SYNOPSIS
        Ejecuta la instalacion de apps EN EL CONTEXTO DEL USUARIO INTERACTIVO (el del
        autologin), no como SYSTEM. Devuelve el mismo hashtable de resultado que un
        step normal (Status/Message/Retryable).
    .DESCRIPTION
        winget (MSIX por-usuario) y los instaladores en shares de red requieren una
        sesion de usuario; corriendo como SYSTEM fallan (winget con 0xC0000135 DLL no
        encontrada; el share con "archivo no encontrado" porque SYSTEM accede como la
        cuenta de equipo). Se registra una tarea que corre como el usuario logueado
        (LogonType Interactive, sin password), se arranca, y se espera a que el runner
        escriba installapps_result.json. Si no hay sesion interactiva, se cae a
        ejecutar inline como SYSTEM (best-effort, para no romper el pipeline).
    #>
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $taskName = 'AutoConfigPS-InstallApps'
    $runnerPath = Join-Path $ProjectRoot 'scripts\Run-InstallAppsUser.ps1'
    $resultPath = Join-Path $env:ProgramData 'AutoConfigPS\installapps_result.json'

    # Esperar (hasta ~2 min) a que exista una sesion de usuario interactiva (autologin).
    $interactiveUser = $null
    for ($i = 0; $i -lt 24; $i++) {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs -and $cs.UserName) { $interactiveUser = $cs.UserName; break }
        Start-Sleep -Seconds 5
    }

    if (-not $interactiveUser) {
        Write-ErrorLog 'No hay sesion de usuario interactiva para instalar apps en su contexto - se intenta como SYSTEM (winget/red pueden fallar)'
        return (Invoke-StepInstallApps -ProjectRoot $ProjectRoot)
    }

    Write-Host "Instalando aplicaciones en la sesion del usuario '$interactiveUser'..." -ForegroundColor Cyan
    Write-SuccessLog "Instalando apps en el contexto del usuario interactivo '$interactiveUser' (winget MSIX + share de red requieren sesion de usuario, no SYSTEM)"

    Remove-Item -Path $resultPath -Force -ErrorAction SilentlyContinue

    try {
        $arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runnerPath`" -ProjectRoot `"$ProjectRoot`""
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        # LogonType Interactive: corre en la sesion ya iniciada del usuario, sin
        # necesitar su contrasena (usa el token de la sesion interactiva).
        $principal = New-ScheduledTaskPrincipal -UserId $interactiveUser -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        $task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings
        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
        Write-SuccessLog "Tarea '$taskName' registrada como '$interactiveUser' (Interactive) - arrancando..."
        Start-ScheduledTask -TaskName $taskName

        # El runner escribe installapps_result.json al terminar (senal de completado).
        # Mientras tanto: (a) mostrar spinner + tiempo + app actual para que la consola
        # no parezca colgada; (b) MONITOREAR el estado de la tarea para detectar
        # fallos/fin sin esperar el timeout completo. Si la tarea corre y termina sin
        # dejar resultado (o nunca arranca), se falla rapido con el codigo de la tarea
        # -util para diagnosticar (ej. el runner no pudo lanzarse, o winget fallo en el
        # perfil del usuario) en vez de un "cuelgue" silencioso de 40 min.
        $progressPath = Join-Path $env:ProgramData 'AutoConfigPS\installapps_progress.txt'
        $spinnerFrames = @('|', '/', '-', '\')
        $timeoutSeconds = 2400
        $waited = 0
        $spin = 0
        $taskEverRan = $false
        $failInfo = $null
        while ($waited -lt $timeoutSeconds) {
            if (Test-Path $resultPath) { break }

            $taskState = 'Desconocido'
            try {
                $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if ($t) { $taskState = "$($t.State)" }
            } catch { }
            if ($taskState -eq 'Running') { $taskEverRan = $true }

            # La tarea ya corrio y termino (no Running) pero no dejo resultado -> fallo.
            if ($taskEverRan -and $taskState -ne 'Running' -and -not (Test-Path $resultPath)) {
                Start-Sleep -Seconds 3
                if (-not (Test-Path $resultPath)) {
                    $lastResult = $null
                    try { $lastResult = (Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue).LastTaskResult } catch { }
                    $failInfo = "la tarea de instalacion termino sin dejar resultado (LastTaskResult=$lastResult) - posible fallo al lanzar el runner o de winget en el perfil del usuario"
                    break
                }
                break
            }
            # La tarea nunca arranco en 2 min -> no va a correr.
            if ($waited -ge 120 -and -not $taskEverRan -and $taskState -ne 'Running') {
                $lastResult = $null
                try { $lastResult = (Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue).LastTaskResult } catch { }
                $failInfo = "la tarea de instalacion no arranco en 2 min (estado='$taskState', LastTaskResult=$lastResult)"
                break
            }

            $current = ''
            try {
                if (Test-Path $progressPath) {
                    $current = ([System.IO.File]::ReadAllText($progressPath, [System.Text.Encoding]::UTF8)).Trim()
                }
            } catch { }
            $mins = [Math]::Floor($waited / 60)
            $secs = $waited % 60
            $line = "  {0} Instalando aplicaciones ({1:00}:{2:00}, tarea={3})... {4}" -f $spinnerFrames[$spin], $mins, $secs, $taskState, $current
            Write-Host ("`r" + $line.PadRight(95)) -NoNewline -ForegroundColor Gray
            $spin = ($spin + 1) % $spinnerFrames.Count
            Start-Sleep -Seconds 2
            $waited += 2
        }
        Write-Host ("`r" + (' ' * 95) + "`r") -NoNewline

        if ($failInfo) {
            Write-ErrorLog "InstallApps (contexto usuario): $failInfo"
            return @{ Status = 'Failed'; Message = "Instalacion de apps fallida: $failInfo"; Retryable = $true }
        }

        if (-not (Test-Path $resultPath)) {
            return @{ Status = 'Failed'; Message = "La instalacion de apps (contexto usuario) no termino en $timeoutSeconds s"; Retryable = $true }
        }

        $res = $null
        try {
            $raw = [System.IO.File]::ReadAllText($resultPath, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
            $res = $raw | ConvertFrom-Json
        } catch {
            return @{ Status = 'Failed'; Message = "No se pudo leer el resultado de la instalacion de apps: $($_.Exception.Message)"; Retryable = $true }
        }

        return @{ Status = $res.Status; Message = $res.Message; Retryable = $false }
    } catch {
        Write-ErrorLog "Error al ejecutar InstallApps en contexto de usuario: $($_.Exception.Message)"
        return @{ Status = 'Failed'; Message = $_.Exception.Message; Retryable = $true }
    } finally {
        try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    }
}

function Invoke-AutoConfigFinalCleanup {
    <#
    .SYNOPSIS
        Limpieza final tras completar el pipeline: elimina los artefactos del proceso
        que no aportan valor al equipo ya configurado y, sobre todo, las credenciales
        de dominio cifradas (riesgo de seguridad si quedan). Los LOGS (C:\Logs) NUNCA
        se tocan - son la salida permanente / registro de auditoria.
    .DESCRIPTION
        Controlado por $CleanupOnFinish (config.ps1, default $true). Si es $false, NO
        borra nada pero DEJA EN EL LOG las rutas exactas de lo que quedo, para que un
        tecnico avanzado (que lo desactivo para depuracion controlada) sepa que borrar
        a mano despues. Solo se invoca en el camino de exito (nunca si el pipeline
        fallo - ahi los artefactos se necesitan para reintentar/depurar).
    #>
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    # Artefactos del proceso (NO incluye C:\Logs, que es permanente).
    $targets = @(
        (Join-Path $ProjectRoot 'SecureConfig'),      # credenciales cifradas (sensible!)
        (Join-Path $ProjectRoot 'config.ps1'),        # config generada (SSID/dominio/nombre)
        (Join-Path $ProjectRoot 'apps.json'),         # lista de apps generada
        'C:\ConfiguracionCompleta.txt',               # marcador de fin
        (Join-Path $env:ProgramData 'AutoConfigPS')   # estado del pipeline (state/status/etc.)
    )

    if (-not $CleanupOnFinish) {
        Write-Host '[i] Limpieza final DESACTIVADA ($CleanupOnFinish = $false). Ver el log para las rutas que quedaron.' -ForegroundColor Yellow
        Write-SuccessLog 'Limpieza final DESACTIVADA por configuracion ($CleanupOnFinish = $false). Los siguientes artefactos del proceso QUEDAN en el equipo - borrarlos a mano tras la depuracion controlada (SecureConfig contiene credenciales de dominio):'
        foreach ($t in $targets) {
            if (Test-Path $t) { Write-SuccessLog "  [PENDIENTE DE BORRAR MANUALMENTE] $t" }
        }
        return
    }

    Write-Host 'Limpieza final: eliminando artefactos del proceso (los logs se conservan)...' -ForegroundColor Cyan
    Write-SuccessLog 'Limpieza final: eliminando artefactos del proceso (credenciales, estado, config). Los logs en C:\Logs se conservan.'
    foreach ($t in $targets) {
        try {
            if (Test-Path $t) {
                Remove-Item -Path $t -Recurse -Force -ErrorAction Stop
                Write-SuccessLog "  [LIMPIADO] $t"
            }
        } catch {
            Write-ErrorLog "  No se pudo limpiar '$t': $($_.Exception.Message) - borrar a mano (puede contener datos sensibles)"
        }
    }
}

Register-AutoConfigResumeTask -ProjectRoot $ProjectRoot
Register-AutoConfigNotifyTask -ProjectRoot $ProjectRoot
Save-AutoConfigState -State $state

# ============================================================
# 6. Definicion fija del pipeline (a proposito NO es configurable dinamicamente:
#    mantenerlo simple y predecible).
# ============================================================

$Pipeline = @(
    [PSCustomObject]@{ Name = 'ConfigureWifi';  Label = '1/5 - Configuracion de red Wi-Fi';        Function = { Invoke-StepConfigureWifi } }
    [PSCustomObject]@{ Name = 'RenameComputer'; Label = '2/5 - Cambio de nombre del equipo';        Function = { Invoke-StepRenameComputer } }
    [PSCustomObject]@{ Name = 'JoinDomain';     Label = '3/5 - Union al dominio';                   Function = { Invoke-StepJoinDomain } }
    [PSCustomObject]@{ Name = 'InstallApps';    Label = '4/5 - Instalacion de aplicaciones';        Function = { Invoke-AutoConfigInstallAppsAsUser -ProjectRoot $ProjectRoot } }
    [PSCustomObject]@{ Name = 'Finalize';       Label = '5/5 - Finalizacion';                       Function = { Invoke-StepFinalize } }
)

$TotalSteps = $Pipeline.Count
$StepIndex = 0

# ============================================================
# 7. Bucle principal: ejecutar el siguiente paso pendiente, con reintentos acotados.
# ============================================================

foreach ($stepDef in $Pipeline) {
    $StepIndex++
    $stepState = Get-StepState -State $state -StepName $stepDef.Name

    if ($stepState.Status -eq 'Completed' -or $stepState.Status -eq 'Skipped') {
        Write-AutoConfigProgress -Id 1 -Activity 'AutoConfigPS' -Status "$($stepDef.Label) (ya realizado)" -PercentComplete (($StepIndex / $TotalSteps) * 100)
        continue
    }

    Write-AutoConfigProgress -Id 1 -Activity 'AutoConfigPS' -Status $stepDef.Label -PercentComplete ((($StepIndex - 1) / $TotalSteps) * 100)

    if ($stepState.Status -eq 'Failed' -and $stepState.Attempts -ge $MaxStepAttempts) {
        Write-AutoConfigProgress -Id 1 -Activity 'AutoConfigPS' -Completed
        Write-Host "[X] El paso '$($stepDef.Name)' ya agoto sus reintentos ($MaxStepAttempts). Revisa C:\Logs\setup_errors.log." -ForegroundColor Red
        Write-ErrorLog "Paso '$($stepDef.Name)' con reintentos agotados - pipeline detenido"
        Set-AutoConfigFailed -State $state
        Unregister-AutoConfigResumeTask
        exit 1
    }

    Write-Section -Title $stepDef.Label

    $attempts = $stepState.Attempts
    $result = $null

    while ($true) {
        $attempts++
        Set-StepResult -State $state -StepName $stepDef.Name -Status 'InProgress' -Message '' -Attempts $attempts

        $result = & $stepDef.Function

        if ($result.Status -ne 'Failed') { break }
        if (-not $result.Retryable -or $attempts -ge $MaxStepAttempts) { break }

        Write-Host "Reintentando '$($stepDef.Name)' en $StepRetryDelaySeconds s (intento $attempts/$MaxStepAttempts)..." -ForegroundColor Yellow
        Write-ErrorLog "Reintentando '$($stepDef.Name)' (intento $attempts/$MaxStepAttempts): $($result.Message)"
        Start-Sleep -Seconds $StepRetryDelaySeconds
    }

    if ($result.Status -eq 'Failed') {
        Write-AutoConfigProgress -Id 1 -Activity 'AutoConfigPS' -Completed
        Set-StepResult -State $state -StepName $stepDef.Name -Status 'Failed' -Message $result.Message -Attempts $attempts
        Set-AutoConfigFailed -State $state
        Write-Host "[X] Paso '$($stepDef.Name)' fallo de forma definitiva: $($result.Message)" -ForegroundColor Red
        Write-ErrorLog "Pipeline detenido en '$($stepDef.Name)': $($result.Message)"
        Unregister-AutoConfigResumeTask
        exit 1
    }

    if ($result.Status -eq 'RebootRequired') {
        Write-AutoConfigProgress -Id 1 -Activity 'AutoConfigPS' -Completed
        Set-StepResult -State $state -StepName $stepDef.Name -Status 'Completed' -Message $result.Message -Attempts $attempts
        Set-AutoConfigAwaitingReboot -State $state

        if ($AutoRestart) {
            Write-Host "Reiniciando el equipo para continuar (paso siguiente se retoma solo)..." -ForegroundColor Cyan
            Write-SuccessLog "Reiniciando tras '$($stepDef.Name)' - la tarea programada retomara el pipeline"
            Start-Sleep -Seconds $Delay
            Restart-Computer -Force
            exit 0
        } else {
            Write-Host "AutoRestart = `$false: reinicia el equipo manualmente cuando quieras. El pipeline continuara solo al arrancar." -ForegroundColor Yellow
            Write-SuccessLog "AutoRestart deshabilitado - esperando reinicio manual tras '$($stepDef.Name)'"
            exit 0
        }
    }

    # Success o Skipped. El contrato de un step devuelve 'Success', pero el estado
    # persistido usa 'Completed' (Set-StepResult valida contra
    # Pending/InProgress/Completed/Skipped/Failed - NO acepta 'Success'). Sin este
    # mapeo, un step exitoso lanzaba un error de ValidateSet y su estado NO se
    # guardaba como Completed (quedaba InProgress), forzando una re-ejecucion
    # innecesaria tras el siguiente reinicio (se auto-sanaba por idempotencia, pero
    # ensuciaba la consola con un error rojo y el state.json quedaba inconsistente).
    $persistStatus = if ($result.Status -eq 'Success') { 'Completed' } else { $result.Status }
    Set-StepResult -State $state -StepName $stepDef.Name -Status $persistStatus -Message $result.Message -Attempts $attempts
    Write-Host "[OK] $($result.Message)" -ForegroundColor Green
}

# ============================================================
# 8. Pipeline completado
# ============================================================

Write-AutoConfigProgress -Id 1 -Activity 'AutoConfigPS' -Completed
Complete-AutoConfigState -State $state
Unregister-AutoConfigResumeTask

Write-Section -Title 'Configuracion completada'
Write-Host 'El equipo ha sido configurado exitosamente.' -ForegroundColor Green
Write-Host 'Revisa C:\Logs\setup_success.log y C:\Logs\setup_errors.log para el detalle.' -ForegroundColor Gray
Write-Host ''

Write-SuccessLog 'Pipeline completado exitosamente - AutoConfigPS finalizado'

# Tiempo de gracia para que la ventana de estado (sesion de usuario, sondea cada 2s) alcance a
# leer el estado 'Completed' y se congele en el, ANTES de que la limpieza borre
# status.json (si no, la ventana volveria a "en progreso" al no poder leerlo).
Start-Sleep -Seconds 8

# Limpieza final (ultimo paso de todo). Se OMITE si alguna app fallo (el paso
# InstallApps reporta "... Z fallidas"): en ese caso se conservan credenciales/config
# para que el tecnico pueda reintentar/depurar las apps SIN re-configurar todo por el
# asistente. Solo se limpia en un cierre 100% limpio. Controlada por $CleanupOnFinish.
$appsHadFailures = $false
if ($state.Steps.InstallApps -and $state.Steps.InstallApps.Message -match '[1-9]\d*\s+fallidas') {
    $appsHadFailures = $true
}

if ($appsHadFailures) {
    Write-Host '[i] Algunas apps no se instalaron - se OMITE la limpieza final para que puedas reintentar/depurar sin re-configurar. Ver C:\Logs\setup_errors.log.' -ForegroundColor Yellow
    Write-SuccessLog 'Limpieza final OMITIDA: hubo apps que fallaron. Se conservan credenciales/config para reintentar (re-ejecuta init.bat). Cuando las apps queden OK, la limpieza correra sola; o pon $CleanupOnFinish=$false para depurar y limpia a mano.'
} else {
    Invoke-AutoConfigFinalCleanup -ProjectRoot $ProjectRoot
}

exit 0
