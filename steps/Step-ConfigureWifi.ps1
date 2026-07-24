# steps/Step-ConfigureWifi.ps1
# Paso 1: configurar y conectar el perfil Wi-Fi corporativo.
# Requiere que config.ps1 y modules/Logging.ps1 ya esten cargados (dot-source) por el
# orquestador antes de invocar Invoke-StepConfigureWifi.

function Test-AutoConfigWifiConnected {
    <#
    .SYNOPSIS
        Comprueba si ya estamos conectados al SSID esperado con una IP valida
        (no APIPA). Se usa para idempotencia: si ya esta conectado, el paso se salta.
    #>
    param([Parameter(Mandatory = $true)][string]$Ssid)

    try {
        $currentSsidLine = netsh wlan show interfaces | Select-String -Pattern '^\s*SSID\s*:' | Select-Object -First 1
        if (-not $currentSsidLine -or $currentSsidLine -notmatch [regex]::Escape($Ssid)) {
            return $false
        }

        $wifiAdapter = Get-NetAdapter | Where-Object {
            $_.Status -eq 'Up' -and ($_.InterfaceDescription -match 'Wireless|Wi-Fi|802.11')
        } | Select-Object -First 1

        if (-not $wifiAdapter) { return $false }

        $ipAddress = Get-NetIPAddress -InterfaceIndex $wifiAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notmatch '^169\.254\.' } |
            Select-Object -First 1

        return [bool]$ipAddress
    } catch {
        return $false
    }
}

function Test-AutoConfigNetworkConnectivity {
    <#
    .SYNOPSIS
        Valida conectividad de red real tras conectar a Wi-Fi (adaptador activo, IP
        valida, gateway alcanzable). Migrado de Script1.ps1 sin cambios de logica.
    #>
    param(
        [int]$MaxRetries = 5,
        [int]$DelaySeconds = 5
    )

    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Host "  Intento $i/$MaxRetries..." -ForegroundColor Gray
        Write-Progress -Id 2 -ParentId 1 -Activity 'Validando conectividad de red' -Status "Intento $i/$MaxRetries" -PercentComplete ((($i - 1) / $MaxRetries) * 100)
        try {
            $wifiAdapter = Get-NetAdapter | Where-Object {
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
            Write-Progress -Id 2 -Completed
            return $true
        } catch {
            Write-ErrorLog "Error en validacion de conectividad (intento $i/$MaxRetries): $($_.Exception.Message)"
        }

        if ($i -lt $MaxRetries) { Start-Sleep -Seconds $DelaySeconds }
    }

    Write-Progress -Id 2 -Completed
    return $false
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
        # Eliminar perfil existente para asegurar que se use la configuracion actual
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

        # Limpiar variables de texto plano tan pronto como sea posible
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Remove-Variable -Name plainPassword, escapedPassword -ErrorAction SilentlyContinue

        netsh wlan connect name=$NetworkSSID | Out-Null
        Start-Sleep -Seconds $Delay

        $connected = Test-AutoConfigWifiConnected -Ssid $NetworkSSID
        if (-not $connected) {
            Write-Host 'Reintentando conexion Wi-Fi...' -ForegroundColor Yellow
            netsh wlan connect name=$NetworkSSID | Out-Null
            Start-Sleep -Seconds $Delay
            $connected = Test-AutoConfigWifiConnected -Ssid $NetworkSSID
        }

        if (-not $connected) {
            Write-ErrorLog "No se pudo conectar a la red Wi-Fi '$NetworkSSID'"
            return @{ Status = 'Failed'; Message = "No se pudo conectar a $NetworkSSID"; Retryable = $true }
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
