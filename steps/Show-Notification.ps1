# steps/Show-Notification.ps1
# Se ejecuta en el contexto del usuario interactivo (via la tarea programada
# 'AutoConfigPS-Notify', trigger AtLogOn) - NUNCA en el contexto SYSTEM del pipeline.
# Por eso NO reutiliza modules/Logging.ps1: esos archivos de log tienen ACL
# restringida a Administrators+SYSTEM y un usuario normal no podria escribir en ellos.
#
# VENTANA DE ESTADO PERSISTENTE (no un globo fugaz): el pipeline corre como SYSTEM
# (invisible para el usuario tras cada reinicio), pero escribe
# C:\ProgramData\AutoConfigPS\status.json -el unico archivo del proyecto legible por
# Users- en CADA cambio de estado. Este script vive en la sesion interactiva (que
# existe por el autologin) y muestra una VENTANA chica, siempre visible (TopMost) en
# la esquina inferior derecha, que sondea status.json cada 2s y actualiza el texto y
# color en vivo: azul = en progreso, verde = completado, amarillo = completado con
# apps que fallaron, rojo = error. Antes se usaban balloon tips, pero eran fugaces y
# el tecnico se los perdia si no miraba justo en ese instante (encontrado en pruebas
# reales); una ventana persistente resuelve "saber siempre como va el proceso".
#
# Sale -y autoelimina su tarea- solo al llegar a un estado definitivo (Completed /
# CompletedWithErrors / Failed) y tras mostrarlo un rato, o cuando el tecnico cierra
# la ventana. En un reinicio intermedio la sesion termina y el autologin vuelve a
# lanzar esta ventana, que retoma el sondeo.

$statusPath = 'C:\ProgramData\AutoConfigPS\status.json'
$progressPath = 'C:\ProgramData\AutoConfigPS\installapps_progress.txt'

function Read-AutoConfigInstallProgress {
    # Durante InstallApps el runner reporta la app actual aqui; se agrega al texto de
    # la ventana para que no parezca colgada en instalaciones largas.
    try {
        if (Test-Path $progressPath) {
            return ([System.IO.File]::ReadAllText($progressPath, [System.Text.Encoding]::UTF8)).Trim()
        }
    } catch { }
    return $null
}

function Read-AutoConfigStatus {
    try {
        if (Test-Path $statusPath) {
            $raw = [System.IO.File]::ReadAllText($statusPath, [System.Text.Encoding]::UTF8)
            $raw = $raw.TrimStart([char]0xFEFF)
            return ($raw | ConvertFrom-Json)
        }
    } catch {
        # status.json ilegible o a medio escribir - se reintenta en el proximo sondeo.
    }
    return $null
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    # Sin ensamblados de GUI (sesion sin escritorio) - no hay nada que mostrar.
    return
}

$script:isTerminal = $false
$script:terminalSeconds = 0

$form = New-Object System.Windows.Forms.Form
$form.Text = 'AutoConfigPS'
$form.Size = New-Object System.Drawing.Size(440, 150)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$form.TopMost = $true
$form.ShowInTaskbar = $true
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.BackColor = [System.Drawing.Color]::White
try {
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object System.Drawing.Point(($wa.Right - 460), ($wa.Bottom - 170))
} catch {
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
}

$strip = New-Object System.Windows.Forms.Panel
$strip.Size = New-Object System.Drawing.Size(10, 150)
$strip.Location = New-Object System.Drawing.Point(0, 0)
$strip.BackColor = [System.Drawing.Color]::RoyalBlue
$form.Controls.Add($strip)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'AutoConfigPS'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::RoyalBlue
$title.Location = New-Object System.Drawing.Point(22, 12)
$title.AutoSize = $true
$form.Controls.Add($title)

$msg = New-Object System.Windows.Forms.Label
$msg.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$msg.Location = New-Object System.Drawing.Point(24, 40)
$msg.Size = New-Object System.Drawing.Size(400, 95)
$msg.Text = 'Iniciando...'
$form.Controls.Add($msg)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({
    # Una vez en estado definitivo, CONGELAR: no volver a leer status.json (la limpieza
    # final del pipeline lo borra, y sin este freeze la ventana volveria a "en
    # progreso"). Solo se cuenta el tiempo para cerrarse sola.
    if ($script:isTerminal) {
        $script:terminalSeconds += 2
        if ($script:terminalSeconds -ge 120) { $form.Close() }
        return
    }

    $status = Read-AutoConfigStatus

    $text = 'AutoConfigPS: configuracion en progreso. No apagues el equipo.'
    $color = [System.Drawing.Color]::RoyalBlue
    $terminal = $false

    if ($status) {
        if ($status.Text) { $text = $status.Text }
        switch ($status.Status) {
            'Completed'           { $terminal = $true; $color = [System.Drawing.Color]::SeaGreen }
            'CompletedWithErrors' { $terminal = $true; $color = [System.Drawing.Color]::DarkGoldenrod }
            'Failed'              { $terminal = $true; $color = [System.Drawing.Color]::Firebrick }
        }
    }

    # Mientras el pipeline avanza, si hay instalacion de apps en curso, mostrar la app
    # actual (evita que la ventana parezca estatica/colgada durante instalaciones largas).
    if (-not $terminal) {
        $installProgress = Read-AutoConfigInstallProgress
        if ($installProgress) { $text = "$text`r`n`r`nInstalando: $installProgress" }
    }

    $msg.Text = $text
    $strip.BackColor = $color
    $title.ForeColor = $color

    if ($terminal) {
        $script:isTerminal = $true
        # Mantener visible el estado final un rato y luego cerrar sola, para no quedar
        # para siempre si el tecnico no la cierra (se sigue viendo ~2 min).
        $script:terminalSeconds += 2
        if ($script:terminalSeconds -ge 120) { $form.Close() }
    }
})
$timer.Start()

try {
    [System.Windows.Forms.Application]::Run($form)
} catch {
    # Si el bucle de mensajes falla, se sigue a la logica de autoeliminacion.
}

try { $timer.Stop() } catch { }
try { $form.Dispose() } catch { }

# Autoeliminar la tarea solo en estado definitivo; mientras siga en progreso (la
# ventana se cerro por un reinicio, no por fin del proceso), el proximo logon la
# vuelve a lanzar.
if ($script:isTerminal) {
    try {
        Unregister-ScheduledTask -TaskName 'AutoConfigPS-Notify' -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        # Sin permisos para autoeliminarse; no es critico (se vuelve a mostrar el
        # mismo estado final en el proximo logon).
    }
}
