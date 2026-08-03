# steps/Step-RenameComputer.ps1
# Paso 2: configurar autologin local temporal (opcional) y renombrar el equipo.
# Requiere reinicio para que el nuevo nombre tome efecto -> Status = RebootRequired.

function Set-AutoConfigLocalAutologin {
    <#
    .SYNOPSIS
        Configura autologin con un usuario local (opcional). No hace nada si no hay
        credenciales locales definidas en config.ps1 - es un paso opcional.
    #>
    if (-not (Get-Variable -Name 'Username' -ErrorAction SilentlyContinue) -or -not $Username) {
        Write-SuccessLog 'Autologin local omitido: credenciales no configuradas'
        return
    }
    if (-not (Get-Variable -Name 'SecurePassword' -ErrorAction SilentlyContinue) -or -not $SecurePassword) {
        Write-SuccessLog 'Autologin local omitido: SecurePassword no configurado'
        return
    }

    # DefaultUserName debe ser el nombre de cuenta "pelado" (sin prefijo de dominio
    # ni de equipo): el tecnico puede ingresarlo como ".\usuario" o "EQUIPO\usuario".
    $localUser = $Username
    if ($localUser.Contains('\')) { $localUser = $localUser.Split('\')[-1] }

    $autoLoginKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    try {
        Set-ItemProperty -Path $autoLoginKey -Name 'AutoAdminLogon' -Value '1'
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultUserName' -Value $localUser
        # DefaultDomainName '.' = cuenta LOCAL de este equipo. Es CRITICO ponerlo:
        # este paso renombra el equipo, y el reinicio del rename ocurre justo despues.
        # Sin DefaultDomainName, Windows puede intentar el autologin contra el nombre
        # viejo/ambiguo y fallar (el tecnico quedaria en la pantalla de login igual).
        # '.' es independiente del nombre del equipo, asi que sobrevive al rename.
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultDomainName' -Value '.'
        Set-ItemProperty -Path $autoLoginKey -Name 'DefaultPassword' -Value $plainTextPassword
        Write-SuccessLog "Autologin local configurado para el usuario '$localUser' (para el reinicio previo a unir al dominio)"
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        Remove-Variable -Name plainTextPassword -ErrorAction SilentlyContinue
    }
}

function Invoke-StepRenameComputer {
    <#
    .SYNOPSIS
        Renombra el equipo si hace falta. Idempotente y sin Read-Host.
    .RETURNS
        Hashtable con Status ('Success'|'Skipped'|'RebootRequired'|'Failed'), Message, Retryable.
    #>

    if (-not (Get-Variable -Name 'HostName' -ErrorAction SilentlyContinue) -or -not $HostName) {
        return @{ Status = 'Failed'; Message = '$HostName no esta definido en config.ps1'; Retryable = $false }
    }

    if ($env:COMPUTERNAME -eq $HostName) {
        Write-SuccessLog "El equipo ya tiene el nombre correcto: '$HostName' - paso omitido"
        return @{ Status = 'Skipped'; Message = "Nombre ya es '$HostName'"; Retryable = $false }
    }

    Set-AutoConfigLocalAutologin

    try {
        $computerInfo = Get-WmiObject -Class Win32_ComputerSystem
        $isInDomain = $computerInfo.PartOfDomain

        $renameParams = @{
            NewName     = $HostName
            Force       = $true
            PassThru    = $true
            ErrorAction = 'Stop'
        }

        if ($isInDomain) {
            if (-not (Get-Variable -Name 'Useradmin' -ErrorAction SilentlyContinue) -or -not $Useradmin -or
                -not (Get-Variable -Name 'SecurePassadmin' -ErrorAction SilentlyContinue) -or -not $SecurePassadmin) {
                return @{ Status = 'Failed'; Message = 'El equipo ya esta en dominio; se requieren credenciales de dominio para renombrarlo'; Retryable = $false }
            }

            $domainUser = $Useradmin
            if (-not ($domainUser.Contains('\') -or $domainUser.Contains('@'))) {
                $domainUser = "$DomainName\$domainUser"
            }

            $domainCredential = New-Object System.Management.Automation.PSCredential($domainUser, $SecurePassadmin)
            $renameParams.Add('DomainCredential', $domainCredential)
        }

        Rename-Computer @renameParams | Out-Null
        Write-SuccessLog "Cambio de nombre programado: '$($env:COMPUTERNAME)' -> '$HostName' (aplicara tras reinicio)"

        return @{ Status = 'RebootRequired'; Message = "Nombre programado a '$HostName'"; Retryable = $false }

    } catch {
        Write-ErrorLog "Error al cambiar el nombre del equipo: $($_.Exception.Message)"
        return @{ Status = 'Failed'; Message = $_.Exception.Message; Retryable = $true }
    }
}
