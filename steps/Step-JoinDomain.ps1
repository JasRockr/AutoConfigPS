# steps/Step-JoinDomain.ps1
# Paso 3: unir el equipo al dominio Active Directory.
# Requiere reinicio para completar la union -> Status = RebootRequired.
#
# FIX del bug de nombres duplicados (v0.0.4): el nombre "fuente de verdad" es siempre
# el nombre ACTUAL del equipo ($env:COMPUTERNAME). Si se detecta un conflicto en AD y
# se genera un nombre alternativo, ese alternativo se usa para Add-Computer -NewName
# y nunca se vuelve a forzar el $HostName original que ya se sabia duplicado.

function Test-AutoConfigDomainController {
    <#
    .SYNOPSIS
        Valida acceso al controlador de dominio antes de intentar la union (DNS SRV,
        DNS directo, nltest). Migrado de Script2.ps1 sin cambios de logica.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$DomainName,
        [int]$MaxRetries = 3
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Host "  Intento $attempt/$MaxRetries..." -ForegroundColor Gray
        Write-Progress -Id 2 -ParentId 1 -Activity 'Validando controlador de dominio' -Status "Intento $attempt/$MaxRetries" -PercentComplete ((($attempt - 1) / $MaxRetries) * 100)
        try {
            try {
                $dcRecords = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop
                if ($dcRecords -and $dcRecords.Count -gt 0) {
                    $dcName = $dcRecords[0].NameTarget
                    if (Test-Connection -ComputerName $dcName -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                        Write-SuccessLog "DC alcanzable via DNS SRV: $dcName"
                        Write-Progress -Id 2 -Completed
                        return $true
                    }
                }
            } catch {
                Write-ErrorLog "Error en resolucion DNS SRV: $($_.Exception.Message)"
            }

            try {
                $domainIP = Resolve-DnsName -Name $DomainName -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
                if ($domainIP -and (Test-Connection -ComputerName $domainIP.IPAddress -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
                    Write-SuccessLog "Dominio alcanzable via IP: $($domainIP.IPAddress)"
                    Write-Progress -Id 2 -Completed
                    return $true
                }
            } catch {
                Write-ErrorLog "Error en resolucion DNS directa: $($_.Exception.Message)"
            }

            try {
                $nltestResult = nltest /dsgetdc:$DomainName 2>&1
                if ($LASTEXITCODE -eq 0 -and $nltestResult -match 'DC:') {
                    $dcFromNltest = $nltestResult | Select-String -Pattern 'DC: (.+)' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
                    if ($dcFromNltest -and (Test-Connection -ComputerName $dcFromNltest -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
                        Write-SuccessLog "DC encontrado y alcanzable via nltest: $dcFromNltest"
                        Write-Progress -Id 2 -Completed
                        return $true
                    }
                }
            } catch {
                # nltest no disponible; se continua con el siguiente intento
            }
        } catch {
            Write-ErrorLog "Error en validacion de DC (intento $attempt/$MaxRetries): $($_.Exception.Message)"
        }

        if ($attempt -lt $MaxRetries) { Start-Sleep -Seconds 10 }
    }

    Write-Progress -Id 2 -Completed
    Write-ErrorLog "Fallo en validacion de DC despues de $MaxRetries intentos - Dominio: $DomainName"
    return $false
}

function Test-AutoConfigComputerNameInAD {
    <#
    .SYNOPSIS
        Verifica si un nombre de equipo ya existe en AD y, de ser asi, genera un
        nombre alternativo disponible. Migrado de Script2.ps1 sin cambios de logica.
    .RETURNS
        Hashtable: Available (bool), AlternativeName (string|null), Message (string)
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][string]$DomainName
    )

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.Filter = "(&(objectClass=computer)(cn=$ComputerName))"
        $searcher.SearchRoot = [ADSI]"LDAP://$DomainName"
        $result = $searcher.FindOne()

        if (-not $result) {
            return @{ Available = $true; AlternativeName = $null; Message = 'Nombre disponible' }
        }

        Write-ErrorLog "Nombre de equipo '$ComputerName' ya existe en AD"

        $maxAttempts = 10
        for ($i = 1; $i -le $maxAttempts; $i++) {
            $suffix = Get-Random -Minimum 100 -Maximum 999
            $testName = "$ComputerName-$suffix"
            if ($testName.Length -gt 15) {
                $maxBaseLength = 15 - 4
                $testName = "$($ComputerName.Substring(0, $maxBaseLength))-$suffix"
            }

            $searcherAlt = New-Object System.DirectoryServices.DirectorySearcher
            $searcherAlt.Filter = "(&(objectClass=computer)(cn=$testName))"
            $searcherAlt.SearchRoot = [ADSI]"LDAP://$DomainName"
            $resultAlt = $searcherAlt.FindOne()

            if (-not $resultAlt) {
                Write-SuccessLog "Nombre alternativo generado: $testName"
                return @{ Available = $false; AlternativeName = $testName; Message = "Nombre original existe, usando alternativo: $testName" }
            }
        }

        return @{ Available = $false; AlternativeName = $null; Message = 'Nombre existe y no se pudo generar alternativo' }

    } catch {
        Write-ErrorLog "Error en Test-AutoConfigComputerNameInAD: $($_.Exception.Message)"
        # Si no se puede verificar, se permite continuar con el nombre actual.
        return @{ Available = $true; AlternativeName = $null; Message = 'No se pudo verificar (asumiendo disponible)' }
    }
}

function Set-AutoConfigDomainAutologin {
    <#
    .SYNOPSIS
        Configura autologin temporal con el usuario de dominio (para que, si el
        equipo requiere otro reinicio antes de completar la union, quede una sesion
        disponible). Se desactiva en Step-InstallApps al iniciar ese paso.
    #>
    param([Parameter(Mandatory = $true)][PSCredential]$Credential)

    $autoLoginKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    try {
        Set-ItemProperty -Path $autoLoginKey -Name 'AutoAdminLogon' -Value '1'
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultUserName' -Value $Credential.UserName
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultPassword' -Value $plainTextPassword
        Write-SuccessLog "Autologin de dominio configurado para '$($Credential.UserName)'"
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Remove-Variable -Name plainTextPassword -ErrorAction SilentlyContinue
    }
}

function Invoke-StepJoinDomain {
    <#
    .SYNOPSIS
        Une el equipo al dominio configurado. Idempotente y sin Read-Host.
    .RETURNS
        Hashtable con Status ('Success'|'Skipped'|'RebootRequired'|'Failed'), Message, Retryable.
    #>

    if (-not (Get-Variable -Name 'DomainName' -ErrorAction SilentlyContinue) -or -not $DomainName) {
        return @{ Status = 'Failed'; Message = '$DomainName no esta definido en config.ps1'; Retryable = $false }
    }

    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -eq $DomainName) {
        Write-SuccessLog "El equipo ya esta unido al dominio '$DomainName' - paso omitido"
        return @{ Status = 'Skipped'; Message = "Ya unido a $DomainName"; Retryable = $false }
    }

    if (-not (Get-Variable -Name 'Useradmin' -ErrorAction SilentlyContinue) -or -not $Useradmin) {
        return @{ Status = 'Failed'; Message = 'Faltan credenciales de dominio ($Useradmin)'; Retryable = $false }
    }

    $domainSecurePass = $null
    if (Get-Variable -Name 'SecurePassadmin' -ErrorAction SilentlyContinue) {
        $domainSecurePass = $SecurePassadmin
    } elseif (Get-Variable -Name 'Passadmin' -ErrorAction SilentlyContinue) {
        Write-Host 'ADVERTENCIA: Usando contrasena de dominio en texto plano' -ForegroundColor Yellow
        $domainSecurePass = ConvertTo-SecureString $Passadmin -AsPlainText -Force
    } else {
        return @{ Status = 'Failed'; Message = 'Faltan credenciales de dominio ($SecurePassadmin)'; Retryable = $false }
    }

    $domainUser = $Useradmin
    if (-not ($domainUser.Contains('\') -or $domainUser.Contains('@'))) {
        $domainUser = "$DomainName\$domainUser"
    }
    $credential = New-Object System.Management.Automation.PSCredential($domainUser, $domainSecurePass)

    Set-AutoConfigDomainAutologin -Credential $credential

    Write-Host 'Validando acceso al controlador de dominio...' -ForegroundColor Cyan
    if (-not (Test-AutoConfigDomainController -DomainName $DomainName -MaxRetries 3)) {
        Write-ErrorLog "[CRITICAL] No se pudo validar acceso al controlador de dominio: $DomainName"
        return @{ Status = 'Failed'; Message = "No se pudo contactar un controlador de dominio para $DomainName"; Retryable = $true }
    }

    # FUENTE DE VERDAD: el nombre actual real del equipo, nunca $HostName a ciegas.
    $currentComputerName = (Get-WmiObject -Class Win32_ComputerSystem).Name
    $targetName = $currentComputerName

    Write-Host "Verificando disponibilidad del nombre '$currentComputerName' en AD..." -ForegroundColor Cyan
    $nameCheck = Test-AutoConfigComputerNameInAD -ComputerName $currentComputerName -DomainName $DomainName

    if (-not $nameCheck.Available) {
        if ($nameCheck.AlternativeName) {
            $targetName = $nameCheck.AlternativeName
            Write-Host "Nombre '$currentComputerName' en conflicto - se usara '$targetName' al unir al dominio" -ForegroundColor Yellow
        } else {
            Write-ErrorLog "Nombre '$currentComputerName' ya existe en AD y no se pudo generar alternativo"
            return @{
                Status    = 'Failed'
                Message   = "El nombre '$currentComputerName' ya existe en AD. Cambia `$HostName en config.ps1 y vuelve a ejecutar."
                Retryable = $false
            }
        }
    }

    $addComputerParams = @{
        DomainName = $DomainName
        Credential = $credential
        Force      = $true
    }

    # Solo se pide renombrar durante la union si el nombre objetivo difiere del actual
    # (caso de conflicto resuelto arriba). Nunca se fuerza de vuelta el $HostName
    # original si ya se determino que estaba duplicado.
    if ($targetName -ne $currentComputerName) {
        $addComputerParams.Add('NewName', $targetName)
    }

    if ((Get-Variable -Name 'OUPath' -ErrorAction SilentlyContinue) -and -not [string]::IsNullOrWhiteSpace($OUPath)) {
        $addComputerParams.Add('OUPath', $OUPath)
        Write-SuccessLog "Uniendo equipo a OU: $OUPath"
    }

    try {
        Add-Computer @addComputerParams -ErrorAction Stop
        Write-SuccessLog "Equipo unido exitosamente al dominio '$DomainName' (nombre: '$targetName')"
        return @{ Status = 'RebootRequired'; Message = "Unido a $DomainName como '$targetName'"; Retryable = $false }
    } catch {
        Write-ErrorLog "[CRITICAL] Error al unir equipo al dominio '$DomainName': $($_.Exception.Message)"
        return @{ Status = 'Failed'; Message = $_.Exception.Message; Retryable = $true }
    }
}
