# steps/Step-JoinDomain.ps1
# Paso 3: unir el equipo al dominio Active Directory.
# Requiere reinicio para completar la union -> Status = RebootRequired.
#
# Nombres duplicados: el nombre "fuente de verdad" es siempre
# el nombre ACTUAL del equipo ($env:COMPUTERNAME). Si se detecta un conflicto en AD y
# se genera un nombre alternativo, ese alternativo se usa para Add-Computer -NewName
# y nunca se vuelve a forzar el $HostName original que ya se sabia duplicado.

function Test-AutoConfigDomainController {
    <#
    .SYNOPSIS
        Valida acceso al controlador de dominio antes de intentar la union (DNS SRV,
        DNS directo, nltest).    #>
    param(
        [Parameter(Mandatory = $true)][string]$DomainName,
        [int]$MaxRetries = 3
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Host "  Intento $attempt/$MaxRetries..." -ForegroundColor Gray
        Write-AutoConfigProgress -Id 2 -ParentId 1 -Activity 'Validando controlador de dominio' -Status "Intento $attempt/$MaxRetries" -PercentComplete ((($attempt - 1) / $MaxRetries) * 100)
        try {
            try {
                $dcRecords = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop
                if ($dcRecords -and $dcRecords.Count -gt 0) {
                    $dcName = $dcRecords[0].NameTarget
                    if (Test-Connection -ComputerName $dcName -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                        Write-SuccessLog "DC alcanzable via DNS SRV: $dcName"
                        Write-AutoConfigProgress -Id 2 -Activity 'Validando controlador de dominio' -Completed
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
                    Write-AutoConfigProgress -Id 2 -Activity 'Validando controlador de dominio' -Completed
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
                        Write-AutoConfigProgress -Id 2 -Activity 'Validando controlador de dominio' -Completed
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

    Write-AutoConfigProgress -Id 2 -Activity 'Validando controlador de dominio' -Completed
    Write-ErrorLog "Fallo en validacion de DC despues de $MaxRetries intentos - Dominio: $DomainName"
    return $false
}

function Test-AutoConfigComputerNameInAD {
    <#
    .SYNOPSIS
        Verifica si un nombre de equipo ya existe en AD y, de ser asi, genera un
        nombre alternativo disponible.    .RETURNS
        Hashtable: Available (bool), AlternativeName (string|null), Message (string)
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][string]$DomainName,
        [System.Management.Automation.PSCredential]$Credential,
        # $true = generar un nombre alternativo si el nombre ya existe (politica
        # 'Alternative'); $false = solo reportar que existe, para que el caller detenga
        # el proceso (politica 'Halt', el default). Ver $OnDuplicateName en config.ps1.
        [bool]$GenerateAlternative = $true
    )

    # Este equipo aun esta en WORKGROUP (todavia no se unio al dominio), asi que una
    # consulta LDAP anonima falla con "Error de operacion". Se autentica el
    # DirectoryEntry con las credenciales de dominio para que la verificacion
    # anti-duplicados funcione de verdad desde el grupo de trabajo.
    $searchRoot = $null
    if ($Credential) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
        $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        $searchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DomainName", $Credential.UserName, $plainPass)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Remove-Variable -Name plainPass -ErrorAction SilentlyContinue
    } else {
        $searchRoot = [ADSI]"LDAP://$DomainName"
    }

    try {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.Filter = "(&(objectClass=computer)(cn=$ComputerName))"
        $searcher.SearchRoot = $searchRoot
        $result = $searcher.FindOne()

        if (-not $result) {
            return @{ Available = $true; AlternativeName = $null; Message = 'Nombre disponible' }
        }

        Write-ErrorLog "Nombre de equipo '$ComputerName' ya existe en AD"

        if (-not $GenerateAlternative) {
            # Politica 'Halt': no se genera alternativo; el caller detiene el proceso.
            return @{ Available = $false; AlternativeName = $null; Message = "El nombre '$ComputerName' ya existe en AD" }
        }

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
            $searcherAlt.SearchRoot = $searchRoot
            $resultAlt = $searcherAlt.FindOne()

            if (-not $resultAlt) {
                Write-SuccessLog "Nombre alternativo generado: $testName"
                return @{ Available = $false; AlternativeName = $testName; Message = "Nombre original existe, usando alternativo: $testName" }
            }
        }

        return @{ Available = $false; AlternativeName = $null; Message = 'Nombre existe y no se pudo generar alternativo' }

    } catch {
        # No es critico: la verificacion anti-duplicados es best-effort. Si la
        # consulta a AD falla (DC no listo aun, permisos, red), se continua con el
        # nombre actual - el propio Add-Computer fallaria despues si hubiera un
        # conflicto real. Se registra como nota informativa, no como error, para no
        # alarmar al tecnico con algo esperable/recuperable.
        Write-SuccessLog "Verificacion anti-duplicados en AD omitida (no se pudo consultar: $($_.Exception.Message)) - se continua con '$ComputerName'"
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

    # Separar dominio y usuario del credencial ("DOMINIO\usuario" o "usuario@dominio")
    # para setear DefaultDomainName/DefaultUserName por separado. Es necesario setear
    # DefaultDomainName explicitamente: el paso local (Set-AutoConfigLocalAutologin)
    # pudo haberlo dejado en '.', y hay que sobreescribirlo con el dominio real.
    $fullUser = $Credential.UserName
    $domainPart = $DomainName
    $userPart = $fullUser
    if ($fullUser.Contains('\')) {
        $domainPart = $fullUser.Split('\')[0]
        $userPart = $fullUser.Split('\')[-1]
    } elseif ($fullUser.Contains('@')) {
        $userPart = $fullUser.Split('@')[0]
        $domainPart = $fullUser.Split('@')[1]
    }

    $autoLoginKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    try {
        Set-ItemProperty -Path $autoLoginKey -Name 'AutoAdminLogon' -Value '1'
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultUserName' -Value $userPart
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultDomainName' -Value $domainPart
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultPassword' -Value $plainTextPassword
        Write-SuccessLog "Autologin de dominio configurado para '$domainPart\$userPart'"
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

    Write-Host 'Validando acceso al controlador de dominio...' -ForegroundColor Cyan
    if (-not (Test-AutoConfigDomainController -DomainName $DomainName -MaxRetries 3)) {
        Write-ErrorLog "[CRITICAL] No se pudo validar acceso al controlador de dominio: $DomainName"
        return @{ Status = 'Failed'; Message = "No se pudo contactar un controlador de dominio para $DomainName"; Retryable = $true }
    }

    # FUENTE DE VERDAD: el nombre actual real del equipo, nunca $HostName a ciegas.
    $currentComputerName = (Get-WmiObject -Class Win32_ComputerSystem).Name
    $targetName = $currentComputerName

    # Politica ante nombre duplicado en AD ($OnDuplicateName en config.ps1, default
    # 'Halt'): 'Halt' detiene el proceso (no auto-renombra; deja que un humano
    # resuelva el conflicto - borrar el objeto obsoleto en AD o cambiar $HostName);
    # 'Alternative' genera un nombre alternativo (P8989-XXX) y sigue.
    $dupPolicy = 'Halt'
    if ((Get-Variable -Name 'OnDuplicateName' -ErrorAction SilentlyContinue) -and $OnDuplicateName) {
        $dupPolicy = $OnDuplicateName
    }
    $genAlt = ($dupPolicy -eq 'Alternative')

    Write-Host "Verificando disponibilidad del nombre '$currentComputerName' en AD..." -ForegroundColor Cyan
    $nameCheck = Test-AutoConfigComputerNameInAD -ComputerName $currentComputerName -DomainName $DomainName -Credential $credential -GenerateAlternative:$genAlt

    if (-not $nameCheck.Available) {
        if ($nameCheck.AlternativeName) {
            $targetName = $nameCheck.AlternativeName
            Write-Host "Nombre '$currentComputerName' en conflicto - se usara '$targetName' al unir al dominio" -ForegroundColor Yellow
        } else {
            # Halt: el nombre ya existe en AD. Se detiene y se deja que un humano lo
            # resuelva. Las credenciales/config NO se limpian (la limpieza final solo
            # corre en exito), asi que re-ejecutar init.bat tras resolver el conflicto
            # es directo.
            Write-ErrorLog "[CRITICAL] El nombre '$currentComputerName' ya existe en AD - proceso detenido (politica '$dupPolicy'). Resolvelo: borra el objeto de equipo obsoleto en AD, o cambia `$HostName en config.ps1, y volve a ejecutar init.bat."
            return @{
                Status    = 'Failed'
                Message   = "El nombre '$currentComputerName' ya existe en AD. Borra el objeto de equipo obsoleto en AD (o cambia `$HostName en config.ps1) y volve a ejecutar init.bat."
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

        # Autologin de dominio: se configura SOLO tras una union exitosa (antes se
        # seteaba antes de intentar, y con credenciales incorrectas quedaba un
        # autologin invalido). Se hace aca, antes del reinicio que hara el orquestador,
        # para que tras reiniciar -ya en el dominio- el equipo inicie sesion solo como
        # el admin de dominio.
        Set-AutoConfigDomainAutologin -Credential $credential

        Write-SuccessLog "Equipo unido exitosamente al dominio '$DomainName' (nombre: '$targetName')"
        return @{ Status = 'RebootRequired'; Message = "Unido a $DomainName como '$targetName'"; Retryable = $false }
    } catch {
        $errMsg = $_.Exception.Message
        # Deteccion de credenciales incorrectas (ES/EN + codigo Win32 1326 =
        # ERROR_LOGON_FAILURE). No tiene sentido reintentar con las mismas credenciales.
        $isCredError = $errMsg -match '(?i)(nombre de usuario o la contrase|user name or password|logon failure|1326)'

        if ($isCredError) {
            # Las credenciales de dominio guardadas son incorrectas. El pipeline corre
            # como SYSTEM y NO puede pedirlas de forma interactiva, asi que se ELIMINA
            # cred_domain.json: en el proximo init.bat, el asistente detecta que falta y
            # te las vuelve a pedir para reingresar las correctas.
            $credDeleted = $false
            if ((Get-Variable -Name 'DomainCredPath' -ErrorAction SilentlyContinue) -and $DomainCredPath -and (Test-Path $DomainCredPath)) {
                try { Remove-Item -Path $DomainCredPath -Force -ErrorAction Stop; $credDeleted = $true } catch { }
            }
            Write-ErrorLog "[CRITICAL] Credenciales de dominio INCORRECTAS al unir a '$DomainName': $errMsg"
            if ($credDeleted) {
                Write-ErrorLog 'Se eliminaron las credenciales de dominio guardadas (cred_domain.json). Volve a ejecutar init.bat: el asistente te pedira las credenciales de dominio de nuevo.'
                $failMsg = 'Credenciales de dominio incorrectas - se eliminaron; volve a ejecutar init.bat para reingresarlas'
            } else {
                Write-ErrorLog 'Corregi las credenciales de dominio (SecureConfig\cred_domain.json via Setup-Credentials, o config.ps1 si usas texto plano) y volve a ejecutar init.bat.'
                $failMsg = 'Credenciales de dominio incorrectas - corregilas y volve a ejecutar init.bat'
            }
            return @{ Status = 'Failed'; Message = $failMsg; Retryable = $false }
        }

        Write-ErrorLog "[CRITICAL] Error al unir equipo al dominio '$DomainName': $errMsg"
        return @{ Status = 'Failed'; Message = $errMsg; Retryable = $true }
    }
}
