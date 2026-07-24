# modules/Logging.ps1
# Modulo de logging centralizado para AutoConfigPS.
# PowerShell 5.1 puro - sin dependencias externas. Se carga con dot-sourcing:
#   . "$PSScriptRoot\modules\Logging.ps1"
#   Initialize-AutoConfigLogging -LogDirectory 'C:\Logs'

$script:AutoConfigSuccessLog = $null
$script:AutoConfigErrorLog = $null
$script:AutoConfigMaxLogSizeBytes = 10 * 1024 * 1024 # 10MB

function Initialize-AutoConfigLogging {
    <#
    .SYNOPSIS
        Prepara el directorio y los archivos de log con permisos restrictivos.
    .DESCRIPTION
        Crea (si hace falta) el directorio de logs y los archivos de exito/error con
        permisos limitados a Administrators y SYSTEM. Debe llamarse una vez al inicio
        de cualquier script que vaya a loguear.
    #>
    param(
        [string]$LogDirectory = 'C:\Logs'
    )

    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $script:AutoConfigSuccessLog = Join-Path $LogDirectory 'setup_success.log'
    $script:AutoConfigErrorLog = Join-Path $LogDirectory 'setup_errors.log'

    foreach ($logFile in @($script:AutoConfigSuccessLog, $script:AutoConfigErrorLog)) {
        if (-not (Test-Path $logFile)) {
            New-Item -Path $logFile -ItemType File -Force | Out-Null
            try {
                icacls $logFile /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null
            } catch {
                # Si icacls falla (por ejemplo en pruebas locales sin permisos), continuar
                # sin bloquear la ejecucion: el logging seguira funcionando, solo sin ACL.
            }
        }
    }
}

function Write-AutoConfigLog {
    <#
    .SYNOPSIS
        Escribe una linea con fecha/hora en el archivo de log indicado, con rotacion.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )

    if (-not $LogFile) { return }

    $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[LOG][$date] $Message"

    if (Test-Path $LogFile) {
        $fileSize = (Get-Item $LogFile).Length
        if ($fileSize -gt $script:AutoConfigMaxLogSizeBytes) {
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            Rename-Item -Path $LogFile -NewName "$LogFile-$timestamp.bak"
        }
    }

    Add-Content -Path $LogFile -Value $line
}

function Write-SuccessLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    if (-not $script:AutoConfigSuccessLog) { return }
    Write-AutoConfigLog -Message "[SUCCESS] $Message" -LogFile $script:AutoConfigSuccessLog
}

function Write-ErrorLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    if (-not $script:AutoConfigErrorLog) { return }
    Write-AutoConfigLog -Message "[!ERROR] $Message" -LogFile $script:AutoConfigErrorLog
}

function Write-Section {
    <#
    .SYNOPSIS
        Encabezado de seccion consistente para salida de consola.
    #>
    param([Parameter(Mandatory = $true)][string]$Title)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Result {
    <#
    .SYNOPSIS
        Linea de resultado [OK]/[X] consistente para salida de consola.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$Details = ''
    )

    $status = 'Fallo'
    $color = 'Red'
    if ($Passed) { $status = 'OK'; $color = 'Green' }

    $detailsText = ''
    if ($Details) { $detailsText = " - $Details" }

    Write-Host "[$status] $Label$detailsText" -ForegroundColor $color
}
