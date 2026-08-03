# modules/StateMachine.ps1
# Motor de estado persistente para AutoConfigPS. Permite que el pipeline se reanude
# despues de un reinicio sin depender de tareas programadas distintas por fase ni de
# adivinar en que paso quedo mirando efectos colaterales del sistema.
#
# PowerShell 5.1 puro. Se carga con dot-sourcing antes de usar sus funciones:
#   . "$PSScriptRoot\modules\StateMachine.ps1"

$script:AutoConfigStateDir = 'C:\ProgramData\AutoConfigPS'
$script:AutoConfigStatePath = Join-Path $script:AutoConfigStateDir 'state.json'
$script:AutoConfigStatusMarkerPath = Join-Path $script:AutoConfigStateDir 'status.json'
$script:AutoConfigSchemaVersion = 1

# Lista canonica de pasos del pipeline. El orquestador define el ORDEN y que funcion
# ejecuta cada uno; esta lista solo se usa para inicializar el esqueleto del estado.
$script:AutoConfigStepNames = @(
    'ConfigureWifi',
    'RenameComputer',
    'JoinDomain',
    'InstallApps',
    'Finalize'
)

# Nombres amigables para el marcador de estado que lee Show-Notification.ps1 (que
# corre en el contexto del usuario interactivo, no tiene por que conocer los
# nombres tecnicos de los pasos).
$script:AutoConfigStepLabels = @{
    ConfigureWifi  = 'Configuracion de red Wi-Fi'
    RenameComputer = 'Cambio de nombre del equipo'
    JoinDomain     = 'Union al dominio'
    InstallApps    = 'Instalacion de aplicaciones'
    Finalize       = 'Finalizacion'
}

function New-AutoConfigStateObject {
    <#
    .SYNOPSIS
        Crea un objeto de estado nuevo (en memoria) con todos los pasos en 'Pending'.
    #>
    $now = (Get-Date).ToString('o')

    $steps = New-Object PSObject
    foreach ($stepName in $script:AutoConfigStepNames) {
        $stepState = [PSCustomObject]@{
            Status    = 'Pending'
            Attempts  = 0
            Message   = ''
            UpdatedAt = $now
        }
        $steps | Add-Member -MemberType NoteProperty -Name $stepName -Value $stepState
    }

    return [PSCustomObject]@{
        SchemaVersion = $script:AutoConfigSchemaVersion
        StartedAt     = $now
        UpdatedAt     = $now
        Status        = 'InProgress'
        Steps         = $steps
    }
}

function Initialize-AutoConfigState {
    <#
    .SYNOPSIS
        Garantiza que exista el directorio y el archivo state.json. No sobrescribe un
        estado existente (idempotente).
    .RETURNS
        $true si el estado ya existia antes de llamar a esta funcion, $false si se creo.
    #>
    if (-not (Test-Path $script:AutoConfigStateDir)) {
        New-Item -Path $script:AutoConfigStateDir -ItemType Directory -Force | Out-Null
        try {
            # SID (*S-1-5-32-544 / *S-1-5-18) en vez de nombre: en Windows en
            # espanol (grupo "Administradores") icacls no resuelve el nombre en
            # ingles y falla, dejando el directorio sin el permiso esperado -
            # encontrado en pruebas reales.
            icacls $script:AutoConfigStateDir /inheritance:r /grant "*S-1-5-32-544:(OI)(CI)F" /grant "*S-1-5-18:(OI)(CI)F" | Out-Null
        } catch {
            # No bloquear si icacls falla; el estado seguira funcionando sin ACL reforzada.
        }
    }

    if (Test-Path $script:AutoConfigStatePath) {
        return $true
    }

    $newState = New-AutoConfigStateObject
    Save-AutoConfigState -State $newState
    return $false
}

function Get-AutoConfigState {
    <#
    .SYNOPSIS
        Lee y devuelve el estado actual desde disco. Si no existe, lo crea primero.
    #>
    Initialize-AutoConfigState | Out-Null

    $raw = [System.IO.File]::ReadAllText($script:AutoConfigStatePath, [System.Text.Encoding]::UTF8)
    $raw = $raw.TrimStart([char]0xFEFF)

    return $raw | ConvertFrom-Json
}

function Get-AutoConfigStatusSummary {
    <#
    .SYNOPSIS
        Deriva un resumen legible (Status + Text) del estado actual, pensado para
        mostrarse en un balloon tip al usuario interactivo (steps/Show-Notification.ps1).
    #>
    param([Parameter(Mandatory = $true)][PSObject]$State)

    switch ($State.Status) {
        'Completed' {
            # El pipeline puede completar aunque algunas apps hayan fallado (los
            # fallos de apps individuales NO detienen el pipeline, por diseno). El
            # tecnico debe poder distinguir "completado limpio" de "completado pero
            # con apps que no se instalaron" - se lee el mensaje del paso InstallApps
            # (formato "X instaladas, Y omitidas, Z fallidas") y si hay fallidas > 0
            # se avisa en el texto.
            $installMsg = $null
            if ($State.Steps -and $State.Steps.InstallApps) { $installMsg = $State.Steps.InstallApps.Message }
            if ($installMsg -and $installMsg -match '[1-9]\d*\s+fallidas') {
                return [PSCustomObject]@{ Status = 'CompletedWithErrors'; Text = "AutoConfigPS: configuracion completada, pero algunas apps no se instalaron ($installMsg). Revisa C:\Logs\setup_errors.log." }
            }
            return [PSCustomObject]@{ Status = 'Completed'; Text = 'AutoConfigPS: configuracion completada correctamente.' }
        }
        'Failed' {
            return [PSCustomObject]@{ Status = 'Failed'; Text = 'AutoConfigPS: proceso detenido por un error. Revisa C:\Logs\setup_errors.log.' }
        }
        default {
            # InProgress o AwaitingReboot: buscar el paso activo (InProgress) o, si no
            # hay ninguno corriendo en este instante, el primer paso pendiente.
            $activeStepName = $null
            foreach ($stepName in $script:AutoConfigStepNames) {
                $stepState = $State.Steps.$stepName
                if ($stepState.Status -eq 'InProgress') { $activeStepName = $stepName; break }
            }
            if (-not $activeStepName) {
                foreach ($stepName in $script:AutoConfigStepNames) {
                    $stepState = $State.Steps.$stepName
                    if ($stepState.Status -eq 'Pending') { $activeStepName = $stepName; break }
                }
            }

            $label = $activeStepName
            if ($activeStepName -and $script:AutoConfigStepLabels.ContainsKey($activeStepName)) {
                $label = $script:AutoConfigStepLabels[$activeStepName]
            }

            $text = 'AutoConfigPS: configuracion en progreso. No apagues el equipo.'
            if ($label) {
                $text = "AutoConfigPS: configuracion en progreso (paso actual: $label). No apagues el equipo."
            }

            return [PSCustomObject]@{ Status = 'InProgress'; Text = $text }
        }
    }
}

function Save-AutoConfigStatusMarker {
    <#
    .SYNOPSIS
        Escribe un marcador de estado liviano (status.json) que cualquier usuario
        interactivo puede leer, sin necesitar permisos de Administrator/SYSTEM como el
        resto de C:\ProgramData\AutoConfigPS. Lo usa steps/Show-Notification.ps1, que
        corre en el contexto del usuario que inicia sesion (no SYSTEM).
    #>
    param([Parameter(Mandatory = $true)][PSObject]$State)

    $summary = Get-AutoConfigStatusSummary -State $State
    $json = $summary | ConvertTo-Json
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($script:AutoConfigStatusMarkerPath, $json, $utf8NoBom)

    try {
        # El directorio solo permite lectura a Administrators/SYSTEM; este archivo en
        # particular necesita ser legible por cualquier usuario (no escribible).
        # SID *S-1-5-32-545 en vez de "BUILTIN\Users": en Windows en espanol el
        # grupo se llama "Usuarios" y el nombre en ingles no resuelve con icacls.
        icacls $script:AutoConfigStatusMarkerPath /grant "*S-1-5-32-545:(R)" | Out-Null
    } catch {
        # Si falla, Show-Notification.ps1 simplemente no podra leerlo (try/catch alli)
        # y no mostrara detalle - no es critico para el pipeline.
    }
}

function Save-AutoConfigState {
    <#
    .SYNOPSIS
        Persiste el objeto de estado en state.json, sin BOM (igual que los archivos de
        credenciales: un BOM en JSON puede romper ConvertFrom-Json en PowerShell 5.1).
        Tambien actualiza el marcador de estado legible por cualquier usuario.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$State
    )

    $State.UpdatedAt = (Get-Date).ToString('o')

    $json = $State | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($script:AutoConfigStatePath, $json, $utf8NoBom)

    Save-AutoConfigStatusMarker -State $State
}

function Get-StepState {
    param(
        [Parameter(Mandatory = $true)][PSObject]$State,
        [Parameter(Mandatory = $true)][string]$StepName
    )
    return $State.Steps.$StepName
}

function Set-StepResult {
    <#
    .SYNOPSIS
        Actualiza y persiste el resultado de un paso ejecutado.
    #>
    param(
        [Parameter(Mandatory = $true)][PSObject]$State,
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][ValidateSet('Pending', 'InProgress', 'Completed', 'Skipped', 'Failed')]
        [string]$Status,
        [string]$Message = '',
        [int]$Attempts = 0
    )

    $stepState = Get-StepState -State $State -StepName $StepName
    $stepState.Status = $Status
    $stepState.Message = $Message
    $stepState.Attempts = $Attempts
    $stepState.UpdatedAt = (Get-Date).ToString('o')

    Save-AutoConfigState -State $State
}

function Test-AutoConfigCompleted {
    param([Parameter(Mandatory = $true)][PSObject]$State)
    return ($State.Status -eq 'Completed')
}

function Complete-AutoConfigState {
    param([Parameter(Mandatory = $true)][PSObject]$State)
    $State.Status = 'Completed'
    Save-AutoConfigState -State $State
}

function Set-AutoConfigFailed {
    param([Parameter(Mandatory = $true)][PSObject]$State)
    $State.Status = 'Failed'
    Save-AutoConfigState -State $State
}

function Set-AutoConfigAwaitingReboot {
    param([Parameter(Mandatory = $true)][PSObject]$State)
    $State.Status = 'AwaitingReboot'
    Save-AutoConfigState -State $State
}
