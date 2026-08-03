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
        Remove-ItemProperty -Path $autoLoginKey -Name 'DefaultDomainName' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $autoLoginKey -Name 'DefaultPassword' -ErrorAction SilentlyContinue
        Write-SuccessLog 'Autologin desactivado correctamente'
    } catch {
        Write-ErrorLog "Error al desactivar autologin: $($_.Exception.Message)"
    }
}

# Ruta completa a winget.exe, resuelta una vez por Update-AutoConfigWingetSources
# y reutilizada por Install-AutoConfigWingetApp.
$script:AutoConfigWingetExe = $null

function Format-AutoConfigWingetOutput {
    <#
    .SYNOPSIS
        Limpia la salida cruda de winget para que sea LEGIBLE en el log: winget
        emite spinners (| / - \), barras de progreso (bloques Unicode que salen como
        mojibake al capturarse) y lineas de descarga (KB/MB), todo ruido para un
        humano. Se queda solo con las lineas de texto real (errores, mensajes).
    #>
    param([string]$Raw)

    if (-not $Raw) { return '' }
    $clean = @()
    foreach ($line in ($Raw -split "`r?`n")) {
        $l = ($line -replace "`r", '').Trim()
        if (-not $l) { continue }
        if ($l -match '^[|/\\\-\s]+$') { continue }                    # solo spinner
        if ($l -match '\d+(\.\d+)?\s*(KB|MB|GB)\s*/') { continue }       # progreso de descarga
        # Si la linea tiene demasiados caracteres no-ASCII, es una barra de progreso
        # (o su mojibake) - se descarta.
        $nonAscii = ([regex]::Matches($l, '[^\x20-\x7E]')).Count
        if ($l.Length -gt 0 -and (($nonAscii / $l.Length) -gt 0.3)) { continue }
        $clean += $l
    }
    return ($clean -join ' | ')
}

function Get-AutoConfigWingetPath {
    <#
    .SYNOPSIS
        Devuelve la ruta completa de winget.exe, funcionando INCLUSO como SYSTEM.
    .DESCRIPTION
        winget (App Installer) es una app de Store registrada por-usuario; su alias
        vive en %LOCALAPPDATA%\Microsoft\WindowsApps, que NO esta en el PATH de la
        cuenta SYSTEM. Como el pipeline instala apps corriendo como SYSTEM (tarea
        programada tras el reinicio de union al dominio), `Get-Command winget` /
        'winget.exe' por PATH FALLA aunque winget exista para el usuario - por eso
        el preflight (contexto usuario) lo veia OK pero InstallApps (SYSTEM) no.
        Se resuelve el .exe real por tres vias, en orden.
    #>
    # 1) PATH (contexto de usuario interactivo)
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    # 2) Paquete Microsoft.DesktopAppInstaller (via Appx, -AllUsers para verlo desde SYSTEM)
    try {
        $pkg = Get-AppxPackage -AllUsers -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $p = Join-Path $pkg.InstallLocation 'winget.exe'
            if (Test-Path $p) { return $p }
        }
    } catch {
        # Appx puede no estar disponible en algun contexto - se sigue al fallback.
    }

    # 3) Fallback: buscar winget.exe bajo Program Files\WindowsApps (SYSTEM tiene acceso)
    try {
        $base = Join-Path $env:ProgramFiles 'WindowsApps'
        $exe = Get-ChildItem -Path $base -Filter 'winget.exe' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -match 'Microsoft\.DesktopAppInstaller_' } |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($exe) { return $exe.FullName }
    } catch {
        # Sin acceso a WindowsApps - se devuelve $null abajo.
    }

    return $null
}

function Install-AutoConfigWinget {
    <#
    .SYNOPSIS
        Bootstrap best-effort de winget (App Installer) cuando NO esta presente.
    .DESCRIPTION
        Aprovisiona winget a nivel de EQUIPO con Add-AppxProvisionedPackage -Online
        (no Add-AppxPackage per-usuario) - funciona desde SYSTEM y deja winget
        disponible para todos los usuarios y para la propia cuenta SYSTEM. Descarga
        el bundle y la dependencia VCLibs de los enlaces estables de Microsoft
        (aka.ms). Es BEST-EFFORT: si algo falla (sin internet, o falta la
        dependencia UI.Xaml -especifica de version, sin enlace estable-), devuelve
        $false y el paso omite las apps de Winget sin frenar el pipeline. En un
        Windows 10/11 recien instalado de ISO estandar winget casi siempre YA
        esta, asi que este camino es un respaldo para el caso borde (LTSC,
        imagenes recortadas, etc.).
    #>
    $tempDir = Join-Path $env:TEMP "acps_winget_$(Get-Random)"
    try {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

        # TLS 1.2: PowerShell 5.1 puede no negociarlo por defecto y aka.ms/GitHub lo exigen.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $bundlePath = Join-Path $tempDir 'winget.msixbundle'
        $vclibsPath = Join-Path $tempDir 'vclibs.appx'

        Write-Host '  Winget no encontrado - descargando App Installer...' -ForegroundColor Yellow
        Write-SuccessLog 'winget ausente - intentando bootstrap (descarga + aprovisionamiento a nivel de equipo)'

        Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $bundlePath -UseBasicParsing
        Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vclibsPath -UseBasicParsing

        Write-Host '  Aprovisionando winget a nivel de equipo...' -ForegroundColor Gray
        # -DependencyPackagePath: en aprovisionamiento -Online las dependencias NO se
        # resuelven solas, hay que pasarlas. UI.Xaml (si el bundle la exige y no esta
        # presente en el equipo) haria fallar esto -> se cae al catch (best-effort).
        Add-AppxProvisionedPackage -Online -PackagePath $bundlePath -DependencyPackagePath $vclibsPath -SkipLicense -ErrorAction Stop | Out-Null

        Write-SuccessLog 'winget aprovisionado correctamente via bootstrap'
        return $true
    } catch {
        Write-ErrorLog "No se pudo instalar winget automaticamente: $($_.Exception.Message). Las apps de Winget se omitiran (instala App Installer manualmente y re-corre init.bat si las necesitas)."
        return $false
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Update-AutoConfigWingetSources {
    $wingetExe = Get-AutoConfigWingetPath
    if (-not $wingetExe) {
        # Intento best-effort de instalarlo (caso borde: winget genuinamente ausente).
        if (Install-AutoConfigWinget) {
            $wingetExe = Get-AutoConfigWingetPath
        }
    }
    if (-not $wingetExe) {
        Write-ErrorLog 'Winget no esta disponible (no se encontro ni se pudo instalar) - las apps de Winget se omitiran'
        return $false
    }
    $script:AutoConfigWingetExe = $wingetExe
    Write-SuccessLog "Winget resuelto en: $wingetExe"
    try {
        # SOLO refrescar la fuente por defecto. NO hacer remove + add de la fuente
        # 'winget': encontrado en pruebas reales que `source add -n winget -a <URL>`
        # (sin el --type correcto) deja la fuente SIN el tipo indexado que winget
        # necesita para resolver paquetes -> TODAS las instalaciones fallan rapido
        # (~1-2s, exit -1978335138) porque no puede encontrar el paquete. La fuente
        # 'winget' por defecto ya funciona; solo se actualiza.
        & $wingetExe source update --accept-source-agreements 2>&1 | Out-Null
        Write-SuccessLog 'Fuentes de Winget actualizadas'
        return $true
    } catch {
        Write-ErrorLog "Error al actualizar fuentes de Winget: $($_.Exception.Message)"
        # Las fuentes pueden fallar pero winget igual sirve para instalar - no es fatal.
        return $true
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

    if (-not $script:AutoConfigWingetExe) {
        Write-Host "    [X] Winget no disponible" -ForegroundColor Red
        Write-ErrorLog "${AppName}: winget no disponible en este equipo - instalacion omitida"
        return @{ Success = $false; ExitCode = -5; Message = 'Winget no disponible'; Duration = (Get-Date) - $startTime; AppName = $AppName }
    }

    try {
        # NO se fuerza --scope machine: para paquetes que solo tienen instalador
        # per-usuario (ej. Microsoft.VisualStudioCode), `--scope machine` falla con
        # "no hay instalador aplicable" (exit -1978335138). Sin forzar el scope,
        # winget elige el que corresponda (machine para MSI en contexto admin,
        # user si el paquete solo lo tiene). Como el paso corre en la sesion de un
        # usuario real (no SYSTEM), la instalacion per-user tambien funciona.
        # --source winget: usar SOLO la fuente 'winget' (la comunitaria). La fuente
        # 'msstore' suele fallar en redes corporativas con inspeccion SSL
        # ("0x8a15005e: The server certificate did not match..."), y ese fallo hacia
        # que winget no pudiera resolver el paquete y pidiera --source. Forzando la
        # fuente winget se evita la msstore rota (encontrado en el log real).
        if ($AppID) {
            $installArgs = "install --id=$AppID -e --silent --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity"
        } else {
            $installArgs = "install `"$AppName`" -e --silent --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity"
        }

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $script:AutoConfigWingetExe
        $processInfo.Arguments = $installArgs
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        # CRITICO: leer stdout/stderr de forma ASINCRONA (ReadToEndAsync) apenas
        # arranca. Si se redirige la salida pero no se drena, winget se BLOQUEA cuando
        # el buffer se llena (encontrado en pruebas reales: Chrome, que produce mucha
        # salida de progreso, se colgaba hasta el timeout de 300s). Los reads async
        # vacian los buffers continuamente y ademas capturan el error real de winget.
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        # Poll en vez de WaitForExit() bloqueante: permite mostrar progreso real.
        while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            $elapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
            $percent = [Math]::Min(100, [Math]::Round(($elapsedSeconds / $TimeoutSeconds) * 100))
            Write-AutoConfigProgress -Id 3 -ParentId 2 -Activity "Instalando $AppName" -Status "$([Math]::Round($elapsedSeconds))s / ${TimeoutSeconds}s" -PercentComplete $percent
            Start-Sleep -Milliseconds 500
        }
        Write-AutoConfigProgress -Id 3 -Activity "Instalando $AppName" -Completed

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
        $wingetOutput = ''
        try { $wingetOutput = (($stdoutTask.Result) + "`n" + ($stderrTask.Result)).Trim() } catch { }

        # Winget: 0 = exito, -1978335189 (0x8A15002B) = ya instalado, 0x8A15002B tambien
        $success = ($exitCode -eq 0) -or ($exitCode -eq -1978335189)
        $message = if ($exitCode -eq -1978335189) { 'Ya instalado' } elseif ($success) { 'Instalado correctamente' } else { "Error (Exit code: $exitCode)" }

        if ($success) {
            Write-Host "    [OK] $message (${durationText}s)" -ForegroundColor Green
            Write-SuccessLog "${AppName}: $message - Duracion: ${durationText}s"
        } else {
            Write-Host "    [X] $message" -ForegroundColor Red
            Write-ErrorLog "${AppName}: $message - Duracion: ${durationText}s"
            # Loguear la salida real de winget, LIMPIA (sin spinners/barras/mojibake)
            # y recortada, para diagnosticar el fallo de forma legible.
            $cleanOutput = Format-AutoConfigWingetOutput -Raw $wingetOutput
            if ($cleanOutput) {
                if ($cleanOutput.Length -gt 600) { $cleanOutput = $cleanOutput.Substring(0, 600) + '...' }
                Write-ErrorLog "${AppName} - Salida de winget: $cleanOutput"
            }
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
        [int]$TimeoutSeconds = 600,
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Host "  -> Instalando desde red: $AppName" -ForegroundColor Cyan
    Write-Host "     (si el instalador abre un asistente, completalo a mano: algunos no soportan modo silencioso)" -ForegroundColor Yellow
    $startTime = Get-Date

    # Preparar el instalador: copiarlo a un temp LOCAL antes de ejecutarlo. Esto
    # resuelve DOS problemas encontrados en pruebas reales:
    #   1) Acceso: el usuario interactivo puede ser LOCAL (no de dominio) y no tener
    #      permiso al share; se autentica con las credenciales de dominio ($Credential)
    #      via New-PSDrive para poder leer el archivo.
    #   2) Rutas con espacios (ej. "...\01.Instaladores Equipos\...") u otras
    #      particularidades UNC al ejecutar: correr desde un temp local con nombre
    #      simple lo evita por completo.
    $localInstaller = $null
    $mappedDrive = $null
    try {
        $accessible = $false
        try { $accessible = Test-Path -LiteralPath $InstallerPath } catch { $accessible = $false }

        if (-not $accessible -and $Credential) {
            # [System.IO.Path]::GetDirectoryName en vez de Split-Path -LiteralPath -Parent:
            # en PowerShell 5.1, Split-Path -LiteralPath NO es compatible con -Parent/-Leaf
            # (lanza "no se puede resolver el conjunto de parametros"). GetDirectoryName
            # maneja UNC y rutas con espacios sin ese problema.
            $shareFolder = [System.IO.Path]::GetDirectoryName($InstallerPath)
            try {
                New-PSDrive -Name 'AcpsNet' -PSProvider FileSystem -Root $shareFolder -Credential $Credential -Scope Script -ErrorAction Stop | Out-Null
                $mappedDrive = 'AcpsNet'
                $accessible = Test-Path -LiteralPath $InstallerPath
                Write-SuccessLog "${AppName}: share autenticado con credenciales de dominio"
            } catch {
                Write-ErrorLog "${AppName}: no se pudo autenticar al share con credenciales de dominio: $($_.Exception.Message)"
            }
        }

        if (-not $accessible) {
            Write-Host "    [X] Archivo no encontrado o sin acceso: $InstallerPath" -ForegroundColor Red
            Write-ErrorLog "${AppName}: Archivo no encontrado o sin acceso en $InstallerPath"
            return @{ Success = $false; ExitCode = -3; Message = 'Archivo no encontrado o sin acceso'; Duration = (Get-Date) - $startTime; AppName = $AppName }
        }

        $localInstaller = Join-Path $env:TEMP ("acps_" + [System.IO.Path]::GetFileName($InstallerPath))
        Copy-Item -LiteralPath $InstallerPath -Destination $localInstaller -Force -ErrorAction Stop
    } catch {
        Write-Host "    [X] Error al acceder al instalador: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrorLog "${AppName}: error al preparar el instalador de red: $($_.Exception.Message)"
        return @{ Success = $false; ExitCode = -3; Message = "Error al acceder al instalador: $($_.Exception.Message)"; Duration = (Get-Date) - $startTime; AppName = $AppName }
    } finally {
        # El share ya se copio localmente; se libera la conexion autenticada.
        if ($mappedDrive) { Remove-PSDrive -Name $mappedDrive -Force -ErrorAction SilentlyContinue }
    }

    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $localInstaller
        $processInfo.Arguments = $Arguments
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        # Leer stdout/stderr async para no bloquear el instalador si llena el buffer
        # (mismo motivo que en Install-AutoConfigWingetApp).
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()

        while (-not $process.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
            $elapsedSeconds = ((Get-Date) - $startTime).TotalSeconds
            $percent = [Math]::Min(100, [Math]::Round(($elapsedSeconds / $TimeoutSeconds) * 100))
            Write-AutoConfigProgress -Id 3 -ParentId 2 -Activity "Instalando $AppName" -Status "$([Math]::Round($elapsedSeconds))s / ${TimeoutSeconds}s" -PercentComplete $percent
            Start-Sleep -Milliseconds 500
        }
        Write-AutoConfigProgress -Id 3 -Activity "Instalando $AppName" -Completed

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
        $errorOutput = ''
        try { $errorOutput = (($stdoutTask.Result) + "`n" + ($stderrTask.Result)).Trim() } catch { }

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
    } finally {
        # Limpiar la copia local temporal del instalador de red.
        if ($localInstaller -and (Test-Path -LiteralPath $localInstaller)) {
            Remove-Item -LiteralPath $localInstaller -Force -ErrorAction SilentlyContinue
        }
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
    $wingetOk = Update-AutoConfigWingetSources

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

    # Credencial de dominio para acceder a shares de red (la carga config.ps1 como
    # $DomainCredential). Se usa solo para las apps Source=Network, para autenticar
    # al share aunque el usuario interactivo sea local. Si no esta disponible, las
    # apps de red se intentan con el acceso del usuario actual.
    $networkCredential = $null
    if (Get-Variable -Name 'DomainCredential' -ErrorAction SilentlyContinue) {
        $networkCredential = $DomainCredential
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
        Write-AutoConfigProgress -Id 2 -ParentId 1 -Activity 'Instalando aplicaciones' -Status "($appIndex/$totalApps) $($app.Name)" -PercentComplete ((($appIndex - 1) / $totalApps) * 100)

        # Reportar el avance a un archivo que el orquestador (SYSTEM) y la ventana de
        # estado (sesion de usuario) leen para mostrar "instalando app X" en vivo -
        # asi el proceso no parece colgado durante instalaciones largas (winget puede
        # tardar minutos por app). Best-effort: si no se puede escribir, no pasa nada.
        try {
            $progressFile = Join-Path $env:ProgramData 'AutoConfigPS\installapps_progress.txt'
            [System.IO.File]::WriteAllText($progressFile, "($appIndex/$totalApps) $($app.Name)", (New-Object System.Text.UTF8Encoding($false)))
        } catch {
            # No critico.
        }

        if ($app.Source -eq 'Winget') {
            if (-not $wingetOk) {
                Write-Host "  -> Omitida (winget no disponible): $($app.Name)" -ForegroundColor Yellow
                Write-ErrorLog "$($app.Name): omitida - winget no esta disponible en este equipo"
                $installResults += @{ Success = $false; Skipped = $false; ExitCode = -5; Message = 'Winget no disponible'; Duration = [TimeSpan]::Zero; AppName = $app.Name }
                continue
            }
            $appID = $null
            if ($app.ID) { $appID = $app.ID }
            $timeout = 300
            if ($app.Timeout) { $timeout = $app.Timeout }
            $installResults += Install-AutoConfigWingetApp -AppName $app.Name -AppID $appID -TimeoutSeconds $timeout

        } elseif ($app.Source -eq 'Network') {
            # Apps de red son OPCIONALES: si no estan configuradas (sin Path, o con el
            # Path de ejemplo del template `\\NetworkPath\...`), se OMITEN en vez de
            # fallar - un equipo que no instala apps de red no debe reportar errores
            # por eso. Una app de red con un Path real que no se alcanza SI se reporta
            # como error (el tecnico la configuro a proposito).
            $netPath = "$($app.Path)".Trim()
            if (-not $netPath -or $netPath -match '(?i)\\\\NetworkPath\\') {
                Write-Host "  -> Omitida (app de red no configurada): $($app.Name)" -ForegroundColor Yellow
                Write-SuccessLog "$($app.Name): omitida - app de red sin Path configurado (opcional)"
                $installResults += @{ Success = $true; Skipped = $true; ExitCode = 0; Message = 'Omitida (no configurada)'; Duration = [TimeSpan]::Zero; AppName = $app.Name }
                continue
            }
            $arguments = '/silent'
            if ($app.Arguments) { $arguments = $app.Arguments }
            $timeout = 600
            if ($app.Timeout) { $timeout = $app.Timeout }
            # Aviso visible: algunos instaladores de red no soportan modo silencioso
            # (ej. FortiClient VPN) y abren su asistente GUI pidiendo interaccion. Se
            # actualiza el progreso (consola + ventana de estado) para que el tecnico
            # sepa que puede tener que completar un asistente a mano y no parezca colgado.
            try {
                [System.IO.File]::WriteAllText($progressFile, "($appIndex/$totalApps) $($app.Name) [app de red: si abre un asistente, completalo a mano]", (New-Object System.Text.UTF8Encoding($false)))
            } catch { }
            $installResults += Install-AutoConfigNetworkApp -AppName $app.Name -InstallerPath $netPath -Arguments $arguments -TimeoutSeconds $timeout -Credential $networkCredential

        } else {
            Write-ErrorLog "Origen desconocido para $($app.Name): $($app.Source)"
            $installResults += @{ Success = $false; ExitCode = -4; Message = "Origen desconocido: $($app.Source)"; Duration = [TimeSpan]::Zero; AppName = $app.Name }
        }
    }

    Write-AutoConfigProgress -Id 2 -Activity 'Instalando aplicaciones' -Completed

    $totalDuration = (Get-Date) - $installStartTime
    $successCount = @($installResults | Where-Object { $_.Success -and -not $_.Skipped }).Count
    $skippedCount = @($installResults | Where-Object { $_.Skipped }).Count
    $failCount = @($installResults | Where-Object { -not $_.Success }).Count
    $totalCount = $installResults.Count

    Write-Host ''
    Write-Host "Resumen: $successCount instaladas, $skippedCount omitidas, $failCount fallidas de $totalCount ($($totalDuration.ToString('mm\:ss')))" -ForegroundColor Cyan
    Write-SuccessLog "Resumen de instalaciones: $successCount instaladas, $skippedCount omitidas, $failCount fallidas de $totalCount totales ($($totalDuration.ToString('mm\:ss')))"

    if ($failCount -gt 0) {
        $failedApps = ($installResults | Where-Object { -not $_.Success } | ForEach-Object { $_.AppName }) -join ', '
        Write-ErrorLog "Aplicaciones con errores: $failedApps"
    }

    # Los fallos de apps individuales no detienen el pipeline (se reportan, no bloquean).
    return @{ Status = 'Success'; Message = "$successCount instaladas, $skippedCount omitidas, $failCount fallidas de $totalCount"; Retryable = $false }
}
