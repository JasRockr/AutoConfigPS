# steps/Step-ConfigureWifi.ps1
# Paso 1: configurar y conectar el perfil Wi-Fi corporativo.
# Requiere que config.ps1 y modules/Logging.ps1 ya esten cargados (dot-source) por el
# orquestador antes de invocar Invoke-StepConfigureWifi.
#
# IMPORTANTE (historial de hardware real): Windows 10/11 exige permiso de "Ubicacion"
# para las llamadas de netsh wlan que enumeran/consultan/conectan interfaces
# (WlanGetAvailableNetworkList / WlanQueryInterface / netsh wlan connect), y en un
# equipo recien instalado ese permiso esta apagado. Se comprobo exhaustivamente que
# escribir el registro (SensorPermissionState / ConsentStore) NO habilita Ubicacion de
# forma efectiva - ni siquiera reiniciando lfsvc/WlanSvc ni tras un reinicio completo
# (el switch de Configuracion sigue apagado). Por eso este paso NO usa netsh para
# conectar ni para detectar la conexion: agrega el perfil (connectionMode=auto, que NO
# requiere Ubicacion), fuerza la re-asociacion apagando/encendiendo el adaptador (el
# auto-connect de un perfil guardado NO requiere Ubicacion - por eso un usuario con
# Ubicacion apagada igual se reconecta a su Wi-Fi), y detecta la conexion con
# Get-NetAdapter/Get-NetIPAddress (tampoco requieren Ubicacion, a diferencia de netsh).

function Get-AutoConfigWifiCurrentSsid {
    <#
    .SYNOPSIS
        Devuelve el SSID de la red Wi-Fi actualmente conectada, SIN netsh (que
        requiere permiso de Ubicacion). Usa Get-NetConnectionProfile, cuyo .Name
        es el SSID en un equipo Wi-Fi NO unido a dominio - que es el estado al
        correr este paso (antes de JoinDomain). Devuelve $null si no hay conexion.
    #>
    param([Parameter(Mandatory = $true)][int]$InterfaceIndex)
    try {
        $profile = Get-NetConnectionProfile -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue
        if ($profile) { return $profile.Name }
        return $null
    } catch {
        return $null
    }
}

function Test-AutoConfigWifiConnected {
    <#
    .SYNOPSIS
        Comprueba si el adaptador Wi-Fi fisico esta conectado al SSID esperado con
        una IP valida (no APIPA). NO usa netsh (que requiere permiso de Ubicacion);
        usa Get-NetAdapter/Get-NetIPAddress/Get-NetConnectionProfile. Verifica el
        SSID a proposito: dar por buena CUALQUIER conexion Wi-Fi fue un bug real
        (el equipo quedaba en una red de invitados sin acceso al dominio y el paso
        se saltaba como si estuviera OK, haciendo fallar JoinDomain despues).
    #>
    param([Parameter(Mandatory = $true)][string]$Ssid)

    try {
        # -Physical excluye adaptadores virtuales (Wi-Fi Direct, Hosted Network, etc.)
        # que tambien pueden matchear 'Wireless|Wi-Fi|802.11' y reportar Status 'Up'
        # sin ser el adaptador fisico realmente conectado - un Select-Object -First 1
        # sobre Get-NetAdapter sin filtrar podria agarrar el equivocado.
        $wifiAdapter = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
            $_.Status -eq 'Up' -and ($_.InterfaceDescription -match 'Wireless|Wi-Fi|802.11')
        } | Select-Object -First 1

        if (-not $wifiAdapter) { return $false }

        # Debe estar conectado a la red ESPERADA, no a otra (ej. red de invitados).
        # Dos formas validas de "red correcta":
        #  1) El nombre del perfil de red coincide con el SSID: caso normal ANTES de
        #     unir el equipo al dominio (Get-NetConnectionProfile.Name = SSID).
        #  2) La red esta clasificada como DomainAuthenticated: caso DESPUES de unir
        #     al dominio, cuando Windows renombra el perfil de red al nombre del
        #     dominio (ej. "vivirlosolivos.com") en vez del SSID. Estar en una red
        #     DomainAuthenticated significa que ya estamos en la red corporativa que
        #     llega al controlador de dominio - es justamente la correcta. Sin este
        #     caso, re-ejecutar el pipeline en un equipo ya unido fallaba aca pese a
        #     estar conectado a la red corporativa (bug real: "red detectada:
        #     vivirlosolivos.com").
        $profile = Get-NetConnectionProfile -InterfaceIndex $wifiAdapter.ifIndex -ErrorAction SilentlyContinue
        $onExpectedNetwork = $false
        if ($profile) {
            if ($profile.Name -eq $Ssid) {
                $onExpectedNetwork = $true
            } elseif ($profile.NetworkCategory -eq 'DomainAuthenticated') {
                $onExpectedNetwork = $true
            }
        }
        if (-not $onExpectedNetwork) { return $false }

        $ipAddress = Get-NetIPAddress -InterfaceIndex $wifiAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notmatch '^169\.254\.' } |
            Select-Object -First 1

        return [bool]$ipAddress
    } catch {
        return $false
    }
}

function Set-AutoConfigOtherWifiProfilesManual {
    <#
    .SYNOPSIS
        Pone en modo "manual" (no auto-connect) todos los perfiles Wi-Fi guardados
        excepto el corporativo, para que el equipo NO se auto-conecte a una red de
        invitados u otra red guardada que le gane la conexion a la corporativa. Asi
        el unico perfil que se auto-conecta (tras reasociar el adaptador y tambien
        tras cada reinicio del pipeline) es el corporativo.

        Enumera los perfiles leyendo los XML de WlanSvc en disco (no netsh: evita el
        gate de Ubicacion y el parseo locale-dependiente de la salida de netsh).
        Para cambiar el modo si usa netsh wlan set profileparameter, que es una
        operacion de configuracion (no de escaneo) y no requiere Ubicacion.
    #>
    param([Parameter(Mandatory = $true)][string]$KeepSsid)

    try {
        $profileRoot = Join-Path $env:ProgramData 'Microsoft\Wlansvc\Profiles\Interfaces'
        if (-not (Test-Path $profileRoot)) { return }

        $xmlFiles = Get-ChildItem -Path $profileRoot -Filter *.xml -Recurse -ErrorAction SilentlyContinue
        foreach ($xmlFile in $xmlFiles) {
            try {
                # XmlDocument.Load respeta la codificacion declarada/BOM del XML, asi
                # que no corrompe SSIDs con tildes/enies (a diferencia de Get-Content
                # -Raw bajo PowerShell 5.1, que asume el codepage ANSI del sistema).
                $doc = New-Object System.Xml.XmlDocument
                $doc.Load($xmlFile.FullName)
                $name = $doc.WLANProfile.name

                if ($name -and $name -ne $KeepSsid) {
                    netsh wlan set profileparameter name="$name" connectionmode=manual 2>&1 | Out-Null
                    Write-SuccessLog "Perfil Wi-Fi '$name' puesto en modo manual (no auto-connect) para priorizar la red corporativa '$KeepSsid'"
                }
            } catch {
                # XML ilegible o sin nodo esperado - se ignora, no bloquea el resto.
            }
        }
    } catch {
        Write-ErrorLog "No se pudieron ajustar los otros perfiles Wi-Fi a modo manual: $($_.Exception.Message)"
    }
}

function Test-AutoConfigNetworkConnectivity {
    <#
    .SYNOPSIS
        Valida conectividad de red real tras conectar a Wi-Fi (adaptador activo, IP
        valida, gateway alcanzable). No usa netsh (ninguno de estos cmdlets requiere
        permiso de Ubicacion).
    #>
    param(
        [int]$MaxRetries = 5,
        [int]$DelaySeconds = 5
    )

    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Host "  Intento $i/$MaxRetries..." -ForegroundColor Gray
        Write-AutoConfigProgress -Id 2 -ParentId 1 -Activity 'Validando conectividad de red' -Status "Intento $i/$MaxRetries" -PercentComplete ((($i - 1) / $MaxRetries) * 100)
        try {
            $wifiAdapter = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
                $_.Status -eq 'Up' -and ($_.InterfaceDescription -match 'Wireless|Wi-Fi|802.11')
            } | Select-Object -First 1

            if (-not $wifiAdapter) {
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            $ipAddress = Get-NetIPAddress -InterfaceIndex $wifiAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notmatch '^169\.254\.' } |
                Select-Object -First 1

            if (-not $ipAddress) {
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            $gateway = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Where-Object { $_.InterfaceIndex -eq $wifiAdapter.ifIndex } |
                Select-Object -First 1

            if (-not $gateway) {
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            $gatewayReachable = Test-Connection -ComputerName $gateway.NextHop -Count 2 -Quiet -ErrorAction SilentlyContinue
            if (-not $gatewayReachable) {
                Start-Sleep -Seconds $DelaySeconds
                continue
            }

            Write-SuccessLog "Conectividad de red validada: IP=$($ipAddress.IPAddress), Gateway=$($gateway.NextHop)"
            Write-AutoConfigProgress -Id 2 -Activity 'Validando conectividad de red' -Completed
            return $true
        } catch {
            Write-ErrorLog "Error en validacion de conectividad (intento $i/$MaxRetries): $($_.Exception.Message)"
        }

        if ($i -lt $MaxRetries) { Start-Sleep -Seconds $DelaySeconds }
    }

    Write-AutoConfigProgress -Id 2 -Activity 'Validando conectividad de red' -Completed
    return $false
}

function Connect-AutoConfigWifiAdapter {
    <#
    .SYNOPSIS
        Fuerza la re-asociacion del adaptador Wi-Fi para disparar el auto-connect del
        perfil recien agregado, SIN usar netsh (no requiere permiso de Ubicacion).
        Apagar/encender el adaptador hace que Windows re-escanee y se conecte solo a
        los perfiles con connectionMode=auto que esten al alcance.
    #>
    $wifiAdapter = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
        $_.InterfaceDescription -match 'Wireless|Wi-Fi|802.11'
    } | Select-Object -First 1

    if (-not $wifiAdapter) {
        Write-ErrorLog 'No se encontro un adaptador Wi-Fi fisico para reasociar'
        return
    }

    try {
        Write-Host '  Reasociando el adaptador Wi-Fi para forzar el auto-connect...' -ForegroundColor Gray
        Disable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false -ErrorAction SilentlyContinue
        Write-SuccessLog "Adaptador Wi-Fi '$($wifiAdapter.Name)' reasociado para disparar el auto-connect del perfil"
    } catch {
        Write-ErrorLog "No se pudo reasociar el adaptador Wi-Fi: $($_.Exception.Message)"
    }
}

function Invoke-StepConfigureWifi {
    <#
    .SYNOPSIS
        Ejecuta el paso de configuracion de red Wi-Fi. Idempotente y sin Read-Host.
    .RETURNS
        Hashtable con Status ('Success'|'Skipped'|'Failed'), Message y Retryable.
    #>

    if (-not (Get-Variable -Name 'NetworkSSID' -ErrorAction SilentlyContinue) -or -not $NetworkSSID) {
        return @{ Status = 'Failed'; Message = 'NetworkSSID no esta definido en config.ps1'; Retryable = $false }
    }

    if (Test-AutoConfigWifiConnected -Ssid $NetworkSSID) {
        Write-SuccessLog "Wi-Fi ya conectado a '$NetworkSSID' con IP valida - paso omitido"
        return @{ Status = 'Skipped'; Message = "Ya conectado a $NetworkSSID"; Retryable = $false }
    }

    # Resolver la contrasena: credenciales cifradas (preferido) o texto plano (legacy)
    $wifiSecurePass = $null
    if (Get-Variable -Name 'SecureNetworkPass' -ErrorAction SilentlyContinue) {
        $wifiSecurePass = $SecureNetworkPass
        Write-SuccessLog 'Credenciales Wi-Fi: usando formato cifrado'
    } elseif (Get-Variable -Name 'NetworkPass' -ErrorAction SilentlyContinue) {
        Write-Host 'ADVERTENCIA: Usando contrasena Wi-Fi en texto plano' -ForegroundColor Yellow
        Write-SuccessLog 'Credenciales Wi-Fi: usando formato texto plano (no recomendado)'
        $wifiSecurePass = ConvertTo-SecureString $NetworkPass -AsPlainText -Force
    } else {
        Write-ErrorLog 'No se proporcionaron credenciales de Wi-Fi'
        return @{ Status = 'Failed'; Message = 'Faltan credenciales de Wi-Fi (ejecuta Setup-Credentials.ps1 o define $NetworkPass)'; Retryable = $false }
    }

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($wifiSecurePass)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    $escapedPassword = [System.Security.SecurityElement]::Escape($plainPassword)

    try {
        # Eliminar perfil existente para asegurar que se use la configuracion actual.
        # netsh wlan (delete/add/show) profile NO requiere permiso de Ubicacion - solo
        # las operaciones que enumeran/consultan/conectan interfaces lo requieren.
        $existingProfile = netsh wlan show profiles $NetworkSSID 2>&1 | Select-String -Pattern 'Perfil' | Select-Object -First 1
        if ($existingProfile -and $existingProfile -notmatch 'No se encuentra el perfil') {
            netsh wlan delete profile name="$NetworkSSID" | Out-Null
            Start-Sleep -Seconds 2
        }

        $wifiProfile = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
<name>$NetworkSSID</name>
<SSIDConfig>
<SSID>
    <name>$NetworkSSID</name>
</SSID>
</SSIDConfig>
<connectionType>ESS</connectionType>
<connectionMode>auto</connectionMode>
<MSM>
<security>
    <authEncryption>
    <authentication>WPA2PSK</authentication>
    <encryption>AES</encryption>
    </authEncryption>
    <sharedKey>
    <keyType>passPhrase</keyType>
    <protected>false</protected>
    <keyMaterial>$escapedPassword</keyMaterial>
    </sharedKey>
</security>
</MSM>
</WLANProfile>
"@

        $tempFile = New-TemporaryFile | Rename-Item -NewName { "$NetworkSSID.xml" } -PassThru
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempFile.FullName, $wifiProfile, $utf8NoBom)

        netsh wlan add profile filename="$($tempFile.FullName)" | Out-Null
        Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        Write-SuccessLog "Perfil Wi-Fi '$NetworkSSID' agregado (connectionMode=auto)"

        # Limpiar variables de texto plano tan pronto como sea posible
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Remove-Variable -Name plainPassword, escapedPassword -ErrorAction SilentlyContinue

        # Evitar que una red de invitados u otra red guardada le gane la conexion a la
        # corporativa: se ponen todos los demas perfiles Wi-Fi en modo manual, asi el
        # unico que se auto-conecta (aca y tras cada reinicio del pipeline) es el
        # corporativo. Esto fue un bug real: el equipo se auto-conectaba a la red de
        # invitados (sin acceso al dominio) y JoinDomain fallaba despues.
        Set-AutoConfigOtherWifiProfilesManual -KeepSsid $NetworkSSID

        # Conexion SIN netsh wlan connect (requiere Ubicacion): se fuerza el auto-connect
        # del perfil reasociando el adaptador, y se espera/detecta con
        # Get-NetConnectionProfile/Get-NetIPAddress. Como respaldo inofensivo, se intenta
        # ademas un netsh wlan connect silencioso: si Ubicacion estuviera habilitada
        # conecta de una; si no, falla en silencio y el auto-connect se encarga. El
        # handshake WPA2 + DHCP puede tardar, por eso el loop paciente
        # ($WifiConnectMaxRetries / $WifiConnectRetryDelaySeconds).
        Connect-AutoConfigWifiAdapter
        netsh wlan connect name=$NetworkSSID 2>&1 | Out-Null

        $connected = $false
        for ($i = 1; $i -le $WifiConnectMaxRetries; $i++) {
            Write-Host "  Esperando conexion Wi-Fi (intento $i/$WifiConnectMaxRetries)..." -ForegroundColor Gray
            Write-AutoConfigProgress -Id 2 -ParentId 1 -Activity 'Conectando a Wi-Fi' -Status "Intento $i/$WifiConnectMaxRetries" -PercentComplete ((($i - 1) / $WifiConnectMaxRetries) * 100)
            Start-Sleep -Seconds $WifiConnectRetryDelaySeconds
            $connected = Test-AutoConfigWifiConnected -Ssid $NetworkSSID
            if ($connected) { break }
        }
        Write-AutoConfigProgress -Id 2 -Activity 'Conectando a Wi-Fi' -Completed

        if (-not $connected) {
            $adState = 'no encontrado'
            $ips = ''
            $currentSsid = '(ninguna)'
            $ad2 = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
                $_.InterfaceDescription -match 'Wireless|Wi-Fi|802.11'
            } | Select-Object -First 1
            if ($ad2) {
                $adState = $ad2.Status
                $ips = (Get-NetIPAddress -InterfaceIndex $ad2.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.IPAddress }) -join ', '
                $detected = Get-AutoConfigWifiCurrentSsid -InterfaceIndex $ad2.ifIndex
                if ($detected) { $currentSsid = $detected }
            }
            Write-ErrorLog "No se pudo conectar a la red Wi-Fi '$NetworkSSID' tras $WifiConnectMaxRetries intentos (via auto-connect del perfil). Red detectada: '$currentSsid'; estado del adaptador: $adState; IPs: $ips"
            return @{ Status = 'Failed'; Message = "No se pudo conectar a $NetworkSSID (red detectada: $currentSsid)"; Retryable = $true }
        }

        Write-Host 'Validando conectividad de red...' -ForegroundColor Cyan
        $networkValid = Test-AutoConfigNetworkConnectivity -MaxRetries 5 -DelaySeconds 5
        if (-not $networkValid) {
            Write-ErrorLog 'Conectado a Wi-Fi pero sin conectividad de red real'
            return @{ Status = 'Failed'; Message = 'Conectado a Wi-Fi pero sin conectividad de red real'; Retryable = $true }
        }

        Write-SuccessLog "Conexion Wi-Fi establecida y validada correctamente: $NetworkSSID"
        return @{ Status = 'Success'; Message = "Conectado a $NetworkSSID"; Retryable = $false }

    } catch {
        Write-ErrorLog "Error en configuracion de Wi-Fi: $($_.Exception.Message)"
        return @{ Status = 'Failed'; Message = $_.Exception.Message; Retryable = $true }
    } finally {
        if ($plainPassword) { Remove-Variable -Name plainPassword -ErrorAction SilentlyContinue }
    }
}
