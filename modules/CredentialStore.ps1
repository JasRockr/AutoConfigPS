# modules/CredentialStore.ps1
# Modulo de gestion de credenciales con cifrado AES compartido.
# Compatible con SYSTEM y usuarios regulares (por eso no se usa DPAPI: DPAPI de
# usuario no es legible por la cuenta SYSTEM que ejecuta el pipeline desatendido).
#
# NOTA DE SEGURIDAD: esto NO es DPAPI. La clave AES se genera una vez y se guarda en
# disco junto a los datos cifrados (SecureConfig\.aeskey), protegida solo por ACL de
# NTFS (Administrators + SYSTEM). Protege contra lectura casual por un usuario sin
# privilegios, no contra un administrador local con acceso al disco.
#
# Movido desde scripts/SecureCredentialManager.ps1 durante la migracion a la nueva
# arquitectura de orquestador. La API no cambio.

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
    Exporta credenciales cifradas con AES que pueden ser leidas por SYSTEM
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
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
        UserName          = $Credential.UserName
        EncryptedPassword = $EncryptedPassword
    }

    # Guardar como JSON sin BOM (critico para PowerShell 5.1)
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
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
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
            throw "Estructura de credenciales invalida en: $Path"
        }

        # Descifrar contrasena
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
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        # Quitar herencia
        icacls $Path /inheritance:r | Out-Null
        # Solo SYSTEM y Administrators. Se usa SID (*S-1-5-32-544 / *S-1-5-18) en
        # vez del nombre "BUILTIN\Administrators"/"SYSTEM": en Windows con idioma
        # distinto al ingles (ej. espanol, donde el grupo se llama
        # "Administradores"), icacls no resuelve el nombre en ingles y falla en
        # silencio, dejando el archivo sin el permiso esperado - encontrado en
        # pruebas reales sobre Windows en espanol.
        icacls $Path /grant "*S-1-5-32-544:F" /grant "*S-1-5-18:F" | Out-Null
        return $true
    } catch {
        Write-Warning "No se pudieron establecer permisos restrictivos en: $Path"
        return $false
    }
}
