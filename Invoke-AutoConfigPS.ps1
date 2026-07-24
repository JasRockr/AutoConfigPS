<#
.SYNOPSIS
    Orquestador unico de AutoConfigPS. Reemplaza la cadena Script0-Script4 + tareas
    programadas por fase de v0.0.4.

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
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
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
    $principal = New-ScheduledTaskPrincipal -GroupId 'BUILTIN\Users' -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
    Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
    Write-SuccessLog "Tarea de notificacion '$taskName' registrada (AtLogOn; se autoelimina al llegar a un estado definitivo)"
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
    [PSCustomObject]@{ Name = 'InstallApps';    Label = '4/5 - Instalacion de aplicaciones';        Function = { Invoke-StepInstallApps -ProjectRoot $ProjectRoot } }
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
        Write-Progress -Id 1 -Activity 'AutoConfigPS' -Status "$($stepDef.Label) (ya realizado)" -PercentComplete (($StepIndex / $TotalSteps) * 100)
        continue
    }

    Write-Progress -Id 1 -Activity 'AutoConfigPS' -Status $stepDef.Label -PercentComplete ((($StepIndex - 1) / $TotalSteps) * 100)

    if ($stepState.Status -eq 'Failed' -and $stepState.Attempts -ge $MaxStepAttempts) {
        Write-Progress -Id 1 -Completed
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
        Write-Progress -Id 1 -Completed
        Set-StepResult -State $state -StepName $stepDef.Name -Status 'Failed' -Message $result.Message -Attempts $attempts
        Set-AutoConfigFailed -State $state
        Write-Host "[X] Paso '$($stepDef.Name)' fallo de forma definitiva: $($result.Message)" -ForegroundColor Red
        Write-ErrorLog "Pipeline detenido en '$($stepDef.Name)': $($result.Message)"
        Unregister-AutoConfigResumeTask
        exit 1
    }

    if ($result.Status -eq 'RebootRequired') {
        Write-Progress -Id 1 -Completed
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

    # Success o Skipped
    Set-StepResult -State $state -StepName $stepDef.Name -Status $result.Status -Message $result.Message -Attempts $attempts
    Write-Host "[OK] $($result.Message)" -ForegroundColor Green
}

# ============================================================
# 8. Pipeline completado
# ============================================================

Write-Progress -Id 1 -Completed
Complete-AutoConfigState -State $state
Unregister-AutoConfigResumeTask

Write-Section -Title 'Configuracion completada'
Write-Host 'El equipo ha sido configurado exitosamente.' -ForegroundColor Green
Write-Host 'Revisa C:\Logs\setup_success.log y C:\Logs\setup_errors.log para el detalle.' -ForegroundColor Gray
Write-Host ''

Write-SuccessLog 'Pipeline completado exitosamente - AutoConfigPS finalizado'
exit 0
