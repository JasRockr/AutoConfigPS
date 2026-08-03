# modules/Preflight.ps1
# Validaciones previas a iniciar el pipeline, como funcion reutilizable SIN
# Read-Host: el orquestador decide que hacer
# con el resultado (loguear y salir), nunca se bloquea esperando una tecla.
#
# PowerShell 5.1 puro. Se carga con dot-sourcing:
#   . "$PSScriptRoot\modules\Preflight.ps1"

function Test-AutoConfigPrerequisites {
    <#
    .SYNOPSIS
        Ejecuta todas las validaciones previas y devuelve un resumen.
    .PARAMETER ProjectRoot
        Carpeta raiz del proyecto (donde vive config.ps1).
    .RETURNS
        PSCustomObject con CanProceed (bool) y Checks (array de resultados).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $minPowerShellVersion = [Version]'5.1'
    $minDiskSpaceGB = 10
    $configPath = Join-Path $ProjectRoot 'config.ps1'
    $secureConfigPath = Join-Path $ProjectRoot 'SecureConfig'

    $checks = @()
    $totalChecks = 8
    $checkIndex = 0

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Privilegios de Administrador' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 1. Privilegios de administrador
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $checks += [PSCustomObject]@{
        Check    = 'Privilegios de Administrador'
        Passed   = $isAdmin
        Critical = $true
        Details  = if ($isAdmin) { 'Ejecutandose como administrador' } else { 'Se requieren privilegios de administrador (clic derecho > Ejecutar como administrador sobre init.bat)' }
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Version de PowerShell' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 2. Version de PowerShell
    $psVersion = $PSVersionTable.PSVersion
    $psVersionOk = $psVersion -ge $minPowerShellVersion
    $checks += [PSCustomObject]@{
        Check    = 'Version de PowerShell'
        Passed   = $psVersionOk
        Critical = $true
        Details  = "Version actual: $psVersion (Minima: $minPowerShellVersion)"
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Adaptador Wi-Fi' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 3. Adaptador Wi-Fi
    $wifiAvailable = $false
    $wifiDetails = 'No se detecto ningun adaptador Wi-Fi'
    try {
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wireless|Wi-Fi|802.11' } | Select-Object -First 1
        if ($wifiAdapter) {
            $wifiAvailable = $true
            $wifiDetails = "Adaptador: $($wifiAdapter.Name) - Estado: $($wifiAdapter.Status)"
        }
    } catch {
        $wifiDetails = "Error al detectar adaptador: $($_.Exception.Message)"
    }
    $checks += [PSCustomObject]@{
        Check    = 'Adaptador Wi-Fi'
        Passed   = $wifiAvailable
        Critical = $true
        Details  = $wifiDetails
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Winget' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 4. Winget
    $wingetAvailable = $false
    $wingetDetails = 'No instalado o no accesible'
    try {
        Get-Command winget -ErrorAction Stop | Out-Null
        $wingetAvailable = $true
        $wingetVersionOutput = winget --version 2>&1
        if ($wingetVersionOutput -match 'v(\d+\.\d+\.\d+)') {
            $wingetDetails = "Instalado - Version: v$($matches[1])"
        } else {
            $wingetDetails = 'Instalado (version no detectada)'
        }
    } catch {
        # Winget no disponible: no critico, solo afectara al paso InstallApps.
    }
    $checks += [PSCustomObject]@{
        Check    = 'Winget'
        Passed   = $wingetAvailable
        Critical = $false
        Details  = $wingetDetails
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Archivo config.ps1' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 5. config.ps1
    $configExists = Test-Path $configPath
    $checks += [PSCustomObject]@{
        Check    = 'Archivo config.ps1'
        Passed   = $configExists
        Critical = $true
        Details  = if ($configExists) { "Encontrado: $configPath" } else { "No encontrado: $configPath (copia example-config.ps1 a config.ps1)" }
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Credenciales cifradas' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 6. Credenciales cifradas (informativo)
    $credPassed = $false
    $credSummary = 'No configuradas (se usara texto plano de config.ps1 si esta definido)'
    if (Test-Path $secureConfigPath) {
        $credDetails = @()
        if (Test-Path (Join-Path $secureConfigPath 'cred_domain.json')) { $credDetails += 'Dominio' }
        if (Test-Path (Join-Path $secureConfigPath 'cred_local.json')) { $credDetails += 'Local' }
        if (Test-Path (Join-Path $secureConfigPath 'cred_wifi.json')) { $credDetails += 'Wi-Fi' }
        if ($credDetails.Count -gt 0) {
            $credPassed = $true
            $credSummary = "Configuradas: $($credDetails -join ', ')"
        } else {
            $credSummary = 'Directorio SecureConfig existe pero sin credenciales'
        }
    }
    $checks += [PSCustomObject]@{
        Check    = 'Credenciales Cifradas'
        Passed   = $credPassed
        Critical = $false
        Details  = $credSummary
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Espacio en disco' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 7. Espacio en disco
    $diskSpaceOk = $false
    $diskDetails = 'No se pudo obtener informacion de disco'
    try {
        $systemDrive = Get-PSDrive -Name ($env:SystemDrive -replace ':', '') -ErrorAction Stop
        $freeSpaceGB = [Math]::Round($systemDrive.Free / 1GB, 2)
        $diskSpaceOk = $freeSpaceGB -ge $minDiskSpaceGB
        $diskDetails = "Espacio libre: $freeSpaceGB GB (Minimo: $minDiskSpaceGB GB)"
    } catch {
        # Se deja el valor por defecto (no criticio, solo advertencia)
    }
    $checks += [PSCustomObject]@{
        Check    = 'Espacio en Disco'
        Passed   = $diskSpaceOk
        Critical = $false
        Details  = $diskDetails
    }

    $checkIndex++
    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Status 'Conectividad de red' -PercentComplete (($checkIndex - 1) / $totalChecks * 100)
    # 8. Conectividad de red basica
    $networkOk = $false
    try {
        $networkOk = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction SilentlyContinue
    } catch {
        # Se deja $networkOk = $false
    }
    $checks += [PSCustomObject]@{
        Check    = 'Conectividad de Red'
        Passed   = [bool]$networkOk
        Critical = $false
        Details  = if ($networkOk) { 'Conectividad a Internet disponible' } else { 'Sin conectividad a Internet detectada' }
    }

    Write-AutoConfigProgress -Id 1 -Activity 'Validando requisitos' -Completed

    $criticalFailed = ($checks | Where-Object { $_.Critical -and -not $_.Passed }).Count

    return [PSCustomObject]@{
        CanProceed = ($criticalFailed -eq 0)
        Checks     = $checks
    }
}

function Write-PreflightReport {
    <#
    .SYNOPSIS
        Imprime en consola el resultado de Test-AutoConfigPrerequisites.
        Requiere que modules/Logging.ps1 ya este cargado (usa Write-Section / Write-Result).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Result
    )

    Write-Section -Title 'AutoConfigPS - Validacion previa'

    foreach ($check in $Result.Checks) {
        Write-Result -Label $check.Check -Passed $check.Passed -Details $check.Details
    }

    Write-Host ''
    if ($Result.CanProceed) {
        Write-Host '[OK] Sistema listo para iniciar la configuracion' -ForegroundColor Green
    } else {
        Write-Host '[X] No se puede continuar - hay validaciones criticas sin cumplir' -ForegroundColor Red
        $Result.Checks | Where-Object { $_.Critical -and -not $_.Passed } | ForEach-Object {
            Write-Host "  [X] $($_.Check): $($_.Details)" -ForegroundColor Red
        }
    }
    Write-Host ''
}
