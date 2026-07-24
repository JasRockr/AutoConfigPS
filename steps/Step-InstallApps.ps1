# steps/Step-InstallApps.ps1
# Paso 4: desactivar autologin temporal e instalar las aplicaciones configuradas.
# No requiere reinicio. Los fallos de instalacion de apps individuales NO detienen
# el pipeline (se reportan en el resumen) - solo un error inesperado del propio paso
# (por ejemplo no poder leer apps.json) se trata como Failed retryable.
#
# FIX del bug de interpolacion: PowerShell no admite formato dentro de ${...}
# (p. ej. "${duration.TotalSeconds:N1}" se interpola vacio). Se usa
# $($duration.TotalSeconds.ToString('N1')) en su lugar.

function Disable-AutoConfigAutologin {
    $autoLoginKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    try {
        Remove-ItemProperty -Path $autoLoginKey -Name 'AutoAdminLogon' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $autoLoginKey -Name 'DefaultUserName' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $autoLoginKey -Name 'DefaultPassword' -ErrorAction SilentlyContinue
        Write-SuccessLog 'Autologin desactivado correctamente'
    } catch {
        Write-ErrorLog "Error al desactivar autologin: $($_.Exception.Message)"
    }
}

function Update-AutoConfigWingetSources {
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetAvailable) {
        Write-ErrorLog 'Winget no esta disponible - las instalaciones de Winget fallaran'
        return $false
    }
    try {
        winget source reset --force 2>&1 | Out-Null
        winget source remove -n winget 2>&1 | Out-Null
        winget source add -n winget -a https://cdn.winget.microsoft.com/cache 2>&1 | Out-Null
        winget source update 2>&1 | Out-Null
        Write-SuccessLog 'Fuentes de Winget actualizadas correctamente'
        return $true
    } catch {
        Write-ErrorLog "Error al actualizar fuentes de Winget: $($_.Exception.Message)"
        return $false
    }
}

function Install-AutoConfigWingetApp {
    param(
        [Parameter(Mandatory = $true)][string]$AppName,
        [string]$AppID,
        [int]$TimeoutSeconds = 300
    )

    Write-Host "  -> Instalando: $AppName" -ForegroundColor Cyan
    $startTime = Get-Date

    try {
        if ($AppID) {
            $installArgs = "install --id=$AppID -e --silent --accept-package-agreements --accept-source-agreements"
        } else {
            $installArgs = "install `"$AppName`" -e --silent --accept-package-agreements --accept-source-agreements"
        }

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = 'winget.exe'
        $processInfo.Arguments = $installArgs
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        # Poll en vez de un WaitForExit() bloqueante: permite mostrar progreso real
        # (tiempo transcurrido / timeout) en vez de dejar la consola muda mientras
        # dura la instalacion.
        while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            $elapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
            $percent = [Math]::Min(100, [Math]::Round(($elapsedSeconds / $TimeoutSeconds) * 100))
            Write-Progress -Id 3 -ParentId 2 -Activity "Instalando $AppName" -Status "$([Math]::Round($elapsedSeconds))s / ${TimeoutSeconds}s" -PercentComplete $percent
            Start-Sleep -Milliseconds 500
        }
        Write-Progress -Id 3 -Completed

        $duration = (Get-Date) - $startTime
        $durationText = $duration.TotalSeconds.ToString('N1')

        if (-not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
            Write-Host "    [!] Timeout (${TimeoutSeconds}s)" -ForegroundColor Yellow
            Write-ErrorLog "Timeout en instalacion de $AppName despues de ${TimeoutSeconds}s"
            return @{ Success = $false; ExitCode = -1; Message = "Timeout despues de ${TimeoutSeconds}s"; Duration = $duration; AppName = $AppName }
        }

        $exitCode = $process.ExitCode
        $errorOutput = $process.StandardError.ReadToEnd()

        # Winget: 0 = exito, -1978335189 (0x8A15002B) = ya instalado
        $success = ($exitCode -eq 0) -or ($exitCode -eq -1978335189)
        $message = if ($exitCode -eq -1978335189) { 'Ya instalado' } elseif ($success) { 'Instalado correctamente' } else { "Error (Exit code: $exitCode)" }

        if ($success) {
            Write-Host "    [OK] $message (${durationText}s)" -ForegroundColor Green
            Write-SuccessLog "${AppName}: $message - Duracion: ${durationText}s"
        } else {
            Write-Host "    [X] $message" -ForegroundColor Red
            Write-ErrorLog "${AppName}: $message - Duracion: ${durationText}s"
            if ($errorOutput) { Write-ErrorLog "${AppName} - Error output: $errorOutput" }
        }

        return @{ Success = $success; ExitCode = $exitCode; Message = $message; Duration = $duration; AppName = $AppName }

    } catch {
        $duration = (Get-Date) - $startTime
        Write-Host "    [X] Excepcion: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Excepcion en instalacion de $AppName : $($_.Exception.Message)"
        return @{ Success = $false; ExitCode = -2; Message = "Excepcion: $($_.Exception.Message)"; Duration = $duration; AppName = $AppName }
    }
}

function Install-AutoConfigNetworkApp {
    param(
        [Parameter(Mandatory = $true)][string]$AppName,
        [Parameter(Mandatory = $true)][string]$InstallerPath,
        [string]$Arguments = '/silent',
        [int]$TimeoutSeconds = 600
    )

    Write-Host "  -> Instalando desde red: $AppName" -ForegroundColor Cyan
    $startTime = Get-Date

    if (-not (Test-Path $InstallerPath)) {
        Write-Host "    [X] Archivo no encontrado: $InstallerPath" -ForegroundColor Red
        Write-ErrorLog "${AppName}: Archivo no encontrado en $InstallerPath"
        return @{ Success = $false; ExitCode = -3; Message = 'Archivo no encontrado'; Duration = (Get-Date) - $startTime; AppName = $AppName }
    }

    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallerPath
        $processInfo.Arguments = $Arguments
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            $elapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
            $percent = [Math]::Min(100, [Math]::Round(($elapsedSeconds / $TimeoutSeconds) * 100))
            Write-Progress -Id 3 -ParentId 2 -Activity "Instalando $AppName" -Status "$([Math]::Round($elapsedSeconds))s / ${TimeoutSeconds}s" -PercentComplete $percent
            Start-Sleep -Milliseconds 500
        }
        Write-Progress -Id 3 -Completed

        $duration = (Get-Date) - $startTime
        $durationText = $duration.TotalSeconds.ToString('N1')

        if (-not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
            Write-Host "    [!] Timeout (${TimeoutSeconds}s)" -ForegroundColor Yellow
            Write-ErrorLog "Timeout en instalacion de $AppName despues de ${TimeoutSeconds}s"
            return @{ Success = $false; ExitCode = -1; Message = "Timeout despues de ${TimeoutSeconds}s"; Duration = $duration; AppName = $AppName }
        }

        $exitCode = $process.ExitCode
        $errorOutput = $process.StandardError.ReadToEnd()

        # 0 = exito, 3010 = exito pero requiere reinicio
        $success = ($exitCode -eq 0) -or ($exitCode -eq 3010)
        $message = if ($exitCode -eq 3010) { 'Instalado (requiere reinicio)' } elseif ($success) { 'Instalado correctamente' } else { "Error (Exit code: $exitCode)" }

        if ($success) {
            Write-Host "    [OK] $message (${durationText}s)" -ForegroundColor Green
            Write-SuccessLog "${AppName}: $message - Duracion: ${durationText}s"
        } else {
            Write-Host "    [X] $message" -ForegroundColor Red
            Write-ErrorLog "${AppName}: $message - Duracion: ${durationText}s"
            if ($errorOutput) { Write-ErrorLog "${AppName} - Error output: $errorOutput" }
        }

        return @{ Success = $success; ExitCode = $exitCode; Message = $message; Duration = $duration; AppName = $AppName }

    } catch {
        $duration = (Get-Date) - $startTime
        Write-Host "    [X] Excepcion: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "Excepcion en instalacion de $AppName : $($_.Exception.Message)"
        return @{ Success = $false; ExitCode = -2; Message = "Excepcion: $($_.Exception.Message)"; Duration = $duration; AppName = $AppName }
    }
}

function Invoke-StepInstallApps {
    <#
    .SYNOPSIS
        Instala las aplicaciones configuradas (apps.json o $apps de config.ps1).
    .PARAMETER ProjectRoot
        Carpeta raiz del proyecto (donde vive apps.json).
    .RETURNS
        Hashtable con Status ('Success'|'Failed'), Message, Retryable.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    Disable-AutoConfigAutologin

    Write-Host 'Actualizando fuentes de Winget...' -ForegroundColor Cyan
    Update-AutoConfigWingetSources | Out-Null

    $appsPath = Join-Path $ProjectRoot 'apps.json'
    if (Test-Path $appsPath) {
        try {
            $apps = Get-Content -Path $appsPath | ConvertFrom-Json
            Write-SuccessLog "Lista de aplicaciones cargada desde: $appsPath"
        } catch {
            Write-ErrorLog "Error al cargar apps.json: $($_.Exception.Message)"
            return @{ Status = 'Failed'; Message = "apps.json invalido: $($_.Exception.Message)"; Retryable = $false }
        }
    }
    # Si apps.json no existe, se usa $apps definido en config.ps1 (ya cargado por el orquestador).

    if (-not $apps -or $apps.Count -eq 0) {
        Write-Host '[!] No se encontraron aplicaciones para instalar' -ForegroundColor Yellow
        Write-SuccessLog 'No se encontraron aplicaciones configuradas para instalacion'
        return @{ Status = 'Success'; Message = 'Sin aplicaciones configuradas'; Retryable = $false }
    }

    $installStartTime = Get-Date
    $installResults = @()
    $totalApps = @($apps | Where-Object { $_.Name -and $_.Source }).Count
    $appIndex = 0

    foreach ($app in $apps) {
        if (-not $app.Name -or -not $app.Source) {
            continue
        }

        $appIndex++
        Write-Progress -Id 2 -ParentId 1 -Activity 'Instalando aplicaciones' -Status "($appIndex/$totalApps) $($app.Name)" -PercentComplete ((($appIndex - 1) / $totalApps) * 100)

        if ($app.Source -eq 'Winget') {
            $appID = $null
            if ($app.ID) { $appID = $app.ID }
            $timeout = 300
            if ($app.Timeout) { $timeout = $app.Timeout }
            $installResults += Install-AutoConfigWingetApp -AppName $app.Name -AppID $appID -TimeoutSeconds $timeout

        } elseif ($app.Source -eq 'Network') {
            $arguments = '/silent'
            if ($app.Arguments) { $arguments = $app.Arguments }
            $timeout = 600
            if ($app.Timeout) { $timeout = $app.Timeout }
            $installResults += Install-AutoConfigNetworkApp -AppName $app.Name -InstallerPath $app.Path -Arguments $arguments -TimeoutSeconds $timeout

        } else {
            Write-ErrorLog "Origen desconocido para $($app.Name): $($app.Source)"
            $installResults += @{ Success = $false; ExitCode = -4; Message = "Origen desconocido: $($app.Source)"; Duration = [TimeSpan]::Zero; AppName = $app.Name }
        }
    }

    Write-Progress -Id 2 -Completed

    $totalDuration = (Get-Date) - $installStartTime
    $successCount = ($installResults | Where-Object { $_.Success }).Count
    $failCount = ($installResults | Where-Object { -not $_.Success }).Count
    $totalCount = $installResults.Count

    Write-Host ''
    Write-Host "Resumen: $successCount/$totalCount exitosas, $failCount fallidas ($($totalDuration.ToString('mm\:ss')))" -ForegroundColor Cyan
    Write-SuccessLog "Resumen de instalaciones: $successCount exitosas, $failCount fallidas de $totalCount totales ($($totalDuration.ToString('mm\:ss')))"

    if ($failCount -gt 0) {
        $failedApps = ($installResults | Where-Object { -not $_.Success } | ForEach-Object { $_.AppName }) -join ', '
        Write-ErrorLog "Aplicaciones con errores: $failedApps"
    }

    # Los fallos de apps individuales no detienen el pipeline (se reportan, no bloquean).
    return @{ Status = 'Success'; Message = "$successCount/$totalCount aplicaciones instaladas correctamente"; Retryable = $false }
}
