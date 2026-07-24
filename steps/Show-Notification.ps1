# steps/Show-Notification.ps1
# Se ejecuta en el contexto del usuario interactivo (via la tarea programada
# 'AutoConfigPS-Notify', trigger AtLogOn) - NUNCA en el contexto SYSTEM del pipeline.
# Por eso NO reutiliza modules/Logging.ps1: esos archivos de log tienen ACL
# restringida a Administrators+SYSTEM y un usuario normal no podria escribir en ellos.
#
# Lee C:\ProgramData\AutoConfigPS\status.json (el unico archivo del proyecto con
# permiso de lectura para Users) para saber si el pipeline sigue en progreso, ya
# termino, o fallo, y muestra un mensaje distinto en cada caso. Solo se autoelimina
# de las tareas programadas cuando el estado es definitivo (Completed o Failed) -
# mientras siga en progreso, se vuelve a mostrar en cada logon como recordatorio de
# "no apagues el equipo" durante los reinicios del pipeline.

$statusPath = 'C:\ProgramData\AutoConfigPS\status.json'
$statusText = 'AutoConfigPS sigue en progreso. No apagues el equipo.'
$isTerminal = $false

try {
    if (Test-Path $statusPath) {
        $raw = [System.IO.File]::ReadAllText($statusPath, [System.Text.Encoding]::UTF8)
        $raw = $raw.TrimStart([char]0xFEFF)
        $status = $raw | ConvertFrom-Json

        if ($status.Text) { $statusText = $status.Text }
        if ($status.Status -eq 'Completed' -or $status.Status -eq 'Failed') { $isTerminal = $true }
    }
} catch {
    # Si no se puede leer (por ejemplo, permisos), se muestra el mensaje generico
    # de "en progreso" definido arriba y no se autoelimina la tarea.
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notify.BalloonTipTitle = 'AutoConfigPS'
    $notify.BalloonTipText = $statusText
    $notify.Visible = $true
    $notify.ShowBalloonTip(10000)
    Start-Sleep -Seconds 11
    $notify.Dispose()
} catch {
    # Si la notificacion visual falla (por ejemplo, sesion sin escritorio), no hay
    # nada mas que hacer aqui - la logica de autoeliminacion de abajo sigue aplicando.
}

if ($isTerminal) {
    try {
        Unregister-ScheduledTask -TaskName 'AutoConfigPS-Notify' -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        # Sin permisos suficientes para autoeliminarse; no es critico, en el peor
        # caso se vuelve a mostrar el mismo mensaje final en el siguiente logon.
    }
}
