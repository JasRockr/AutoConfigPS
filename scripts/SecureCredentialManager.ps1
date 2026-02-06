# Módulo de gestión de credenciales con cifrado AES compartido
# Compatible con SYSTEM y usuarios regulares

function New-SecureKey {
    <#
    .SYNOPSIS
    Genera una clave AES aleatoria de 256 bits
    #>
    $key = New-Object byte[](32) # 256 bits
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
    return $key
}

function Export-SecureCredential {
    <#
    .SYNOPSIS
    Exporta credenciales cifradas con AES que pueden ser leídas por SYSTEM
    #>
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [byte[]]$Key
    )
    
    # Convertir SecureString a texto plano temporalmente para cifrar con AES
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    # Cifrar con AES
    $SecurePassword = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force
    $EncryptedPassword = ConvertFrom-SecureString -SecureString $SecurePassword -Key $Key
    
    # Limpiar texto plano
    $PlainPassword = $null
    [System.GC]::Collect()
    
    # Crear objeto para exportar
    $credObject = @{
        UserName = $Credential.UserName
        EncryptedPassword = $EncryptedPassword
    }
    
    # Guardar como JSON
    $credObject | ConvertTo-Json | Out-File -FilePath $Path -Encoding UTF8 -Force
}

function Import-SecureCredential {
    <#
    .SYNOPSIS
    Importa credenciales cifradas con AES
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [byte[]]$Key
    )
    
    # Leer archivo JSON
    $credObject = Get-Content -Path $Path -Raw | ConvertFrom-Json
    
    # Descifrar contraseña
    $SecurePassword = ConvertTo-SecureString -String $credObject.EncryptedPassword -Key $Key
    
    # Crear PSCredential
    return New-Object System.Management.Automation.PSCredential($credObject.UserName, $SecurePassword)
}

function Protect-CredentialFiles {
    <#
    .SYNOPSIS
    Establece permisos restrictivos en archivos de credenciales
    Solo SYSTEM y Administrators pueden leer
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    try {
        # Quitar herencia
        icacls $Path /inheritance:r | Out-Null
        # Solo SYSTEM y Administrators
        icacls $Path /grant "BUILTIN\Administrators:F" /grant "SYSTEM:F" | Out-Null
        return $true
    } catch {
        Write-Warning "No se pudieron establecer permisos restrictivos en: $Path"
        return $false
    }
}
