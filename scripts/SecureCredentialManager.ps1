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
    
    # Guardar como JSON sin BOM (crítico para PowerShell 5.1)
    $jsonContent = $credObject | ConvertTo-Json
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $jsonContent, $utf8NoBom)
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
    
    # Validar que el archivo existe
    if (-not (Test-Path $Path)) {
        throw "Archivo de credenciales no encontrado: $Path"
    }
    
    try {
        # Leer archivo JSON con manejo de BOM
        $jsonContent = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        
        # Remover BOM si existe (para compatibilidad)
        $jsonContent = $jsonContent.TrimStart([char]0xFEFF)
        
        # Parsear JSON
        $credObject = $jsonContent | ConvertFrom-Json
        
        # Validar estructura
        if (-not $credObject.UserName -or -not $credObject.EncryptedPassword) {
            throw "Estructura de credenciales inválida en: $Path"
        }
        
        # Descifrar contraseña
        $SecurePassword = ConvertTo-SecureString -String $credObject.EncryptedPassword -Key $Key
        
        # Crear PSCredential
        return New-Object System.Management.Automation.PSCredential($credObject.UserName, $SecurePassword)
        
    } catch {
        throw "Error al importar credenciales desde $Path`: $($_.Exception.Message)"
    }
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
