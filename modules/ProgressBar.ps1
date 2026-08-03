# modules/ProgressBar.ps1
# Barra de progreso de consola personalizada (pipes + spinner animado) para
# reemplazar el render nativo de Write-Progress - en consolas con fuente
# Raster/code page limitado, Write-Progress cae a un caracter 'o' plano en vez
# de un bloque solido, y ese glyph no es configurable via parametros (encontrado
# en pruebas reales). PowerShell 5.1 puro: solo Write-Host + retorno de carro
# (`r), sin APIs de posicionamiento de cursor (Console.SetCursorPosition) para
# no arriesgar excepciones en contextos sin consola real (tarea programada sin
# sesion interactiva) - la misma clase de riesgo que motivo eliminar Read-Host
# de toda la ruta desatendida.
#
# Redibuja una unica linea de consola, asi que solo se ve una barra activa a la
# vez (la mas especifica: el paso o sub-paso que esta corriendo en ese momento)
# en vez de varias barras apiladas - mas simple de leer para un usuario no
# tecnico, y evita el riesgo de manipular varias lineas de consola a la vez.
#
# Mantiene una firma de parametros compatible con Write-Progress
# (Id/ParentId/Activity/Status/PercentComplete/Completed) para poder
# reemplazar las llamadas existentes en el resto del proyecto sin tocar la
# logica de cada step - Id/ParentId se aceptan pero se ignoran (no hay
# jerarquia visual, ver arriba).

$script:AutoConfigProgressSpinnerFrames = @('|', '/', '-', '\')
$script:AutoConfigProgressSpinnerIndex = 0
$script:AutoConfigProgressLastLineLength = 0
$script:AutoConfigProgressBarWidth = 30

function Write-AutoConfigProgress {
    <#
    .SYNOPSIS
        Barra de progreso de consola con pipes '|' y spinner animado.
    .DESCRIPTION
        Reemplazo directo de Write-Progress pensado para una UX mas clara -
        ver comentario de cabecera del archivo para el detalle completo.
    #>
    param(
        [int]$Id = 1,
        [int]$ParentId = -1,
        [Parameter(Mandatory = $true)][string]$Activity,
        [string]$Status = '',
        [int]$PercentComplete = -1,
        [switch]$Completed
    )

    if ($Completed) {
        if ($script:AutoConfigProgressLastLineLength -gt 0) {
            $blank = ' ' * $script:AutoConfigProgressLastLineLength
            Write-Host "`r$blank`r" -NoNewline
        }
        $script:AutoConfigProgressLastLineLength = 0
        return
    }

    $script:AutoConfigProgressSpinnerIndex = ($script:AutoConfigProgressSpinnerIndex + 1) % $script:AutoConfigProgressSpinnerFrames.Count
    $spinner = $script:AutoConfigProgressSpinnerFrames[$script:AutoConfigProgressSpinnerIndex]

    if ($PercentComplete -lt 0) { $PercentComplete = 0 }
    if ($PercentComplete -gt 100) { $PercentComplete = 100 }

    $filled = [Math]::Floor($script:AutoConfigProgressBarWidth * ($PercentComplete / 100))
    $empty = $script:AutoConfigProgressBarWidth - $filled
    $bar = ('|' * $filled) + (' ' * $empty)

    $line = "$spinner [$bar] $($PercentComplete.ToString().PadLeft(3))%  $Activity"
    if ($Status) { $line += " - $Status" }

    # Truncar al ancho de la consola para que la linea nunca "envuelva" a una
    # segunda linea real - si eso pasara, el retorno de carro ya no alcanzaria
    # para redibujar todo lo escrito y quedarian residuos visuales. RawUI
    # puede no estar disponible en hosts sin consola real (tarea programada sin
    # sesion interactiva) - de ahi el try/catch con ancho de respaldo fijo.
    $maxWidth = 80
    try {
        if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $maxWidth = $Host.UI.RawUI.WindowSize.Width - 1 }
    } catch {
        # Sin consola real (ej. salida redirigida) - se usa el ancho de respaldo.
    }
    if ($line.Length -gt $maxWidth) {
        $line = $line.Substring(0, $maxWidth)
    }

    # Si la linea nueva es mas corta que la anterior, rellenar con espacios
    # para no dejar residuos del texto previo a la derecha.
    $padding = ''
    if ($line.Length -lt $script:AutoConfigProgressLastLineLength) {
        $padding = ' ' * ($script:AutoConfigProgressLastLineLength - $line.Length)
    }
    $script:AutoConfigProgressLastLineLength = $line.Length

    Write-Host "`r$line$padding" -NoNewline -ForegroundColor Cyan
}
