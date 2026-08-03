#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Asistente de configuracion inicial para AutoConfigPS (config.ps1 + credenciales)

.DESCRIPTION
    Paso 0: si 'config.ps1' no existe todavia, pide por consola los 3 valores
    minimos que el pipeline necesita para arrancar (dominio, nombre de equipo,
    SSID de Wi-Fi) y genera 'config.ps1' a partir de 'example-config.ps1' con
    esos valores ya cargados - para que un tecnico no tenga que editar el
    archivo a mano. Los parametros avanzados (OU, lista de apps, timeouts)
    quedan con su valor por defecto, pensados para que los ajuste manualmente
    un usuario mas tecnico si hace falta. Si 'config.ps1' ya existe, este paso
    se omite por completo (no lo sobreescribe).

    Pasos 1-3: genera credenciales cifradas con AES-256 (modulo
    modules/CredentialStore.ps1). La clave de cifrado se guarda en
    SecureConfig\.aeskey protegida con permisos NTFS restrictivos
    (Administrators + SYSTEM), para que el pipeline desatendido (que corre como
    SYSTEM via tarea programada) pueda descifrarlas sin intervencion manual.

    NOTA: esto NO es DPAPI. DPAPI en modo usuario no es legible por la cuenta
    SYSTEM que ejecuta el pipeline tras cada reinicio, por eso se usa AES con
    clave propia. La proteccion real depende de las ACL del archivo de clave:
    cualquier administrador local de este equipo puede descifrar las credenciales,
    no solo el usuario que las creo.

.NOTES
    Autor: Json Rivera (JasRockr!)

    IMPORTANTE:
    - Debe ejecutarse con privilegios de administrador
    - Las credenciales solo seran validas en este equipo (la clave AES es local)
    - Para uso en multiples equipos, ejecutar este script en cada uno
    - El wizard de config.ps1 (Paso 0) esta pensado para un tecnico configurando
      un equipo a la vez; para preparar muchos equipos de una sola vez conviene
      generar los config.ps1 por otro medio (no es el caso de uso de este paso)

.EXAMPLE
    .\Setup-Credentials.ps1
    Ejecuta el asistente interactivo de configuracion (config.ps1 + credenciales)
#>

param()

# ====================================
# CONFIGURAR EXECUTION POLICY
# ====================================

Write-Host ""
Write-Host "Verificando politica de ejecucion de scripts..." -ForegroundColor Cyan

try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    
    if ($currentPolicy -ne "Bypass" -and $currentPolicy -ne "Unrestricted") {
        Write-Host "  Politica actual: $currentPolicy" -ForegroundColor Yellow
        Write-Host "  Configurando ExecutionPolicy a Bypass para usuario actual..." -ForegroundColor Yellow
        
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force -ErrorAction Stop
        
        $newPolicy = Get-ExecutionPolicy -Scope CurrentUser
        Write-Host "  [OK] ExecutionPolicy configurada: $newPolicy" -ForegroundColor Green
        Write-Host "  Los scripts se ejecutaran sin restricciones para este usuario" -ForegroundColor Gray
    } else {
        Write-Host "  [OK] ExecutionPolicy ya permite ejecucion: $currentPolicy" -ForegroundColor Green
    }
} catch {
    Write-Host "  [!] No se pudo configurar ExecutionPolicy automaticamente" -ForegroundColor Yellow
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Configura manualmente con:" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Presiona Enter para continuar..." -ForegroundColor Yellow
    Read-Host
}

Write-Host ""

# ====================================
# CONFIGURACION
# ====================================

$ScriptVersion = "1.0.0"
$SecureConfigPath = "$PSScriptRoot\..\SecureConfig"

# Importar módulo de gestión segura de credenciales
. "$PSScriptRoot\..\modules\CredentialStore.ps1"

# ====================================
# FUNCIONES AUXILIARES
# ====================================

function Write-ColoredMessage {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Header")]
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Header"  { "Magenta" }
    }

    $prefix = switch ($Type) {
        "Info"    { "[INFO]" }
        "Success" { "[OK]" }
        "Warning" { "[!]" }
        "Error"   { "[ERROR]" }
        "Header"  { "===" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-CredentialValid {
    param([PSCredential]$Credential)

    if (-not $Credential) { return $false }
    if ([string]::IsNullOrWhiteSpace($Credential.UserName)) { return $false }
    if ($Credential.Password.Length -eq 0) { return $false }

    return $true
}

function Read-RequiredValue {
    <#
    .SYNOPSIS
    Pide un valor por consola y reintenta hasta que pase el validador.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][scriptblock]$Validator,
        [Parameter(Mandatory = $true)][string]$ErrorMessage
    )

    while ($true) {
        $value = (Read-Host $Prompt).Trim()
        if (& $Validator $value) {
            return $value
        }
        Write-ColoredMessage $ErrorMessage -Type Warning
    }
}

function Read-AutoConfigCredential {
    <#
    .SYNOPSIS
        Pide usuario + contrasena por CONSOLA (Read-Host), NO via el dialogo GUI de
        Get-Credential.
    .DESCRIPTION
        Get-Credential puede fallar / devolver null en ciertas sesiones (encontrado
        en pruebas reales: la sesion del admin de dominio dejaba el asistente en un
        loop de "credenciales invalidas o canceladas" porque el dialogo GUI no
        aceptaba input, aunque los Read-Host de S/N si funcionaban). Read-Host anda
        igual en cualquier consola interactiva, sin depender del CredUI.
        Devuelve $null si el usuario deja el usuario vacio (equivale a cancelar).
    #>
    param(
        [string]$UserPrompt = 'Usuario',
        [string]$DefaultUser,
        [switch]$PasswordOnly,
        [string]$FixedUser = 'WiFi-Password'
    )

    if ($PasswordOnly) {
        $user = $FixedUser
    } else {
        $p = $UserPrompt
        if ($DefaultUser) { $p = "$UserPrompt (Enter = $DefaultUser)" }
        $user = (Read-Host $p).Trim()
        if (-not $user -and $DefaultUser) { $user = $DefaultUser }
    }
    if ([string]::IsNullOrWhiteSpace($user)) { return $null }

    $securePass = Read-Host 'Contrasena' -AsSecureString
    if (-not $securePass -or $securePass.Length -eq 0) { return $null }

    return (New-Object System.Management.Automation.PSCredential($user, $securePass))
}

# ====================================
# BANNER
# ====================================

Clear-Host
Write-Host ""
Write-ColoredMessage "AutoConfigPS - Asistente de Configuracion Inicial" -Type Header
Write-Host "Version: $ScriptVersion" -ForegroundColor Gray
Write-Host ""
Write-ColoredMessage "Este asistente configura config.ps1 (si hace falta) y las credenciales cifradas" -Type Info
Write-ColoredMessage "Las credenciales se cifraran con AES-256 (clave local en SecureConfig\.aeskey)" -Type Info
Write-Host ""

# ====================================
# VERIFICAR PRIVILEGIOS
# ====================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColoredMessage "Este script requiere privilegios de administrador" -Type Error
    Write-Host ""
    Write-Host "Por favor, ejecuta como administrador y vuelve a intentar." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 1
}

# ====================================
# PASO 0: CONFIGURACION BASICA (config.ps1)
# ====================================

$ProjectRoot = "$PSScriptRoot\.."
$ConfigPath = "$ProjectRoot\config.ps1"
$ExampleConfigPath = "$ProjectRoot\example-config.ps1"

Write-ColoredMessage "PASO 0: Configuracion Basica del Equipo" -Type Header
Write-Host ""

if (Test-Path $ConfigPath) {
    Write-ColoredMessage "Ya existe 'config.ps1' - se omite este paso" -Type Info
    Write-Host "  Si necesitas cambiar dominio/nombre/Wi-Fi, edita config.ps1 a mano," -ForegroundColor Gray
    Write-Host "  o elimina el archivo para que este asistente te lo vuelva a generar." -ForegroundColor Gray
} elseif (-not (Test-Path $ExampleConfigPath)) {
    Write-ColoredMessage "No se encontro example-config.ps1 - no se puede generar config.ps1 automaticamente" -Type Error
    Write-Host "  Copia example-config.ps1 a config.ps1 manualmente y edita los valores." -ForegroundColor Gray
} else {
    Write-Host "No se encontro 'config.ps1' todavia. Vamos a crearlo con los 3 valores" -ForegroundColor Gray
    Write-Host "minimos para que el pipeline pueda arrancar. El resto (OU, lista de" -ForegroundColor Gray
    Write-Host "aplicaciones, timeouts) queda con su valor por defecto - editalo despues" -ForegroundColor Gray
    Write-Host "en config.ps1 directamente si lo necesitas." -ForegroundColor Gray
    Write-Host ""

    $domainName = Read-RequiredValue `
        -Prompt "Dominio (FQDN, ej: empresa.local)" `
        -Validator { param($v) $v -match '^[a-zA-Z0-9][a-zA-Z0-9\-\.]*\.[a-zA-Z]{2,}$' } `
        -ErrorMessage "Formato invalido - debe ser un FQDN, ej: empresa.local"

    $hostName = Read-RequiredValue `
        -Prompt "Nombre del equipo (maximo 15 caracteres, sin espacios)" `
        -Validator { param($v) $v.Length -ge 1 -and $v.Length -le 15 -and $v -notmatch '[\s\\/:\*\?"<>\|]' } `
        -ErrorMessage 'Debe tener entre 1 y 15 caracteres, sin espacios ni los caracteres \ / : * ? " < > |'

    $networkSSID = Read-RequiredValue `
        -Prompt "SSID de la red Wi-Fi corporativa" `
        -Validator { param($v) -not [string]::IsNullOrWhiteSpace($v) } `
        -ErrorMessage "El SSID no puede estar vacio"

    try {
        $configContent = Get-Content -Path $ExampleConfigPath -Raw
        $configContent = $configContent -replace '(?m)^\$DomainName\s*=\s*"[^"]*"(\s*#.*)?$', "`$DomainName = `"$domainName`"   # Configurado por el asistente"
        $configContent = $configContent -replace '(?m)^\$HostName\s*=\s*"[^"]*"(\s*#.*)?$', "`$HostName = `"$hostName`" # Configurado por el asistente"
        $configContent = $configContent -replace '(?m)^\$NetworkSSID\s*=\s*"[^"]*"(\s*#.*)?$', "`$NetworkSSID = `"$networkSSID`"   # Configurado por el asistente"

        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($ConfigPath, $configContent, $utf8Bom)

        Write-Host ""
        Write-ColoredMessage "config.ps1 creado correctamente" -Type Success
        Write-Host "  Dominio: $domainName" -ForegroundColor Gray
        Write-Host "  Nombre de equipo: $hostName" -ForegroundColor Gray
        Write-Host "  Wi-Fi SSID: $networkSSID" -ForegroundColor Gray
        Write-Host ""
        Write-ColoredMessage "Valores avanzados (OU, lista de apps, timeouts) quedaron con su" -Type Info
        Write-ColoredMessage "valor por defecto - editalos en config.ps1 si hace falta." -Type Info
    } catch {
        Write-ColoredMessage "Error al generar config.ps1: $_" -Type Error
        Write-Host "  Copia example-config.ps1 a config.ps1 manualmente y edita los valores." -ForegroundColor Gray
    }
}

Write-Host ""

# ====================================
# CREAR DIRECTORIO SEGURO
# ====================================

Write-ColoredMessage "Preparando directorio de configuracion segura..." -Type Info

if (-not (Test-Path $SecureConfigPath)) {
    try {
        New-Item -ItemType Directory -Path $SecureConfigPath -Force | Out-Null
        Write-ColoredMessage "Directorio creado: $SecureConfigPath" -Type Success
    } catch {
        Write-ColoredMessage "Error al crear directorio: $_" -Type Error
        Read-Host "Presiona Enter para salir"
        exit 1
    }
}

# Establecer permisos restrictivos (solo Administradores y SYSTEM)
# CRITICO: usar SID (*S-1-5-32-544 / *S-1-5-18) en vez de "BUILTIN\Administrators"
# / "SYSTEM" por nombre - en Windows con idioma distinto al ingles (ej. espanol,
# donde el grupo se llama "Administradores"), icacls no resuelve el nombre en
# ingles y falla con "No se efectuo ninguna asignacion...", dejando el archivo
# sin el permiso esperado (encontrado en pruebas reales sobre Windows en espanol).
try {
    icacls $SecureConfigPath /inheritance:r /grant "*S-1-5-32-544:(OI)(CI)F" /grant "*S-1-5-18:(OI)(CI)F" | Out-Null
    Write-ColoredMessage "Permisos restrictivos aplicados" -Type Success
} catch {
    Write-ColoredMessage "Advertencia: No se pudieron establecer permisos restrictivos" -Type Warning
}

# Generar clave AES compartida (compatible con SYSTEM)
$keyPath = "$SecureConfigPath\.aeskey"
if (-not (Test-Path $keyPath)) {
    Write-Host ""
    Write-ColoredMessage "Generando clave de cifrado compartida..." -Type Info
    $aesKey = New-SecureKey
    [System.IO.File]::WriteAllBytes($keyPath, $aesKey)
    Protect-CredentialFiles -Path $keyPath | Out-Null
    Write-ColoredMessage "Clave de cifrado creada" -Type Success
} else {
    Write-Host ""
    Write-ColoredMessage "Usando clave de cifrado existente" -Type Info
    $aesKey = [System.IO.File]::ReadAllBytes($keyPath)
}

Write-Host ""

# ====================================
# CREDENCIALES DE DOMINIO
# ====================================

Write-ColoredMessage "PASO 1: Credenciales de Administrador de Dominio" -Type Header
Write-Host ""

$domainCredPath = "$SecureConfigPath\cred_domain.json"
$domainCredValid = Test-Path $domainCredPath

if ($domainCredValid) {
    Write-ColoredMessage "Credenciales de dominio ya configuradas - se omite (elimina cred_domain.json para reconfigurar)" -Type Info
} else {
    Write-Host "Ingresa las credenciales del usuario con permisos para unir equipos al dominio." -ForegroundColor Gray
    Write-Host "Formato del usuario: DOMINIO\usuario o usuario@dominio.local" -ForegroundColor Gray
    Write-Host ""
}

while (-not $domainCredValid) {
    try {
        $domainCred = Read-AutoConfigCredential -UserPrompt "Usuario de dominio (DOMINIO\usuario o usuario@dominio)"

        if (Test-CredentialValid -Credential $domainCred) {
            # Guardar credenciales cifradas con AES (compatible con SYSTEM)
            Export-SecureCredential -Credential $domainCred -Path $domainCredPath -Key $aesKey
            Protect-CredentialFiles -Path $domainCredPath | Out-Null

            # Verificar que se guard\u00f3 correctamente
            if (Test-Path $domainCredPath) {
                # Intentar leer para validar
                $testCred = Import-SecureCredential -Path $domainCredPath -Key $aesKey
                if (Test-CredentialValid -Credential $testCred) {
                    Write-ColoredMessage "Credenciales de dominio guardadas correctamente" -Type Success
                    Write-Host "Ubicaci\u00f3n: $domainCredPath" -ForegroundColor Gray
                    $domainCredValid = $true
                } else {
                    throw "Error al validar credenciales guardadas"
                }
            } else {
                throw "Error al guardar archivo de credenciales"
            }
        } else {
            Write-ColoredMessage "Credenciales invalidas o canceladas" -Type Warning
            $retry = Read-Host "¿Intentar nuevamente? (S/N)"
            if ($retry -notmatch "^[Ss]") {
                Write-ColoredMessage "Configuracion cancelada por el usuario - faltara cred_domain.json" -Type Warning
                break
            }
        }
    } catch {
        Write-ColoredMessage "Error al procesar credenciales: $_" -Type Error
        $retry = Read-Host "¿Intentar nuevamente? (S/N)"
        if ($retry -notmatch "^[Ss]") {
            Write-ColoredMessage "Configuracion cancelada por el usuario - faltara cred_domain.json" -Type Warning
            break
        }
    }
}

Write-Host ""

# ====================================
# USUARIO LOCAL
# ====================================

Write-ColoredMessage "PASO 2: Autologin durante el proceso (recomendado)" -Type Header
Write-Host ""

$localCredPath = "$SecureConfigPath\cred_local.json"

if (Test-Path $localCredPath) {
    Write-ColoredMessage "Autologin ya configurado - se omite (elimina cred_local.json para reconfigurar)" -Type Info
} else {
    Write-Host "El proceso reinicia el equipo una vez ANTES de unirlo al dominio. Si" -ForegroundColor Gray
    Write-Host "configuras esto, ese reinicio inicia sesion solo (autologin) y podras ver" -ForegroundColor Gray
    Write-Host "el avance sin tener que loguearte a mano. Tras unir al dominio, el autologin" -ForegroundColor Gray
    Write-Host "pasa al usuario de dominio automaticamente, y al terminar se desactiva." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Windows NO permite recuperar la contrasena de tu sesion actual (por" -ForegroundColor Gray
    Write-Host "seguridad), asi que se reutiliza tu MISMO usuario ('$env:USERNAME') y solo" -ForegroundColor Gray
    Write-Host "hace falta que escribas su contrasena una vez." -ForegroundColor Gray
    Write-Host ""

    try {
        $wantAutologin = (Read-Host "Configurar autologin con el usuario '$env:USERNAME'? (S/N)").Trim()
        if ($wantAutologin -match '^[Ss]') {
            # Se reutiliza la cuenta actual (la que usa el tecnico); solo hace falta la
            # contrasena. Windows no expone la contrasena de la sesion actual, por eso
            # hay que pedirla (no se puede "reutilizar" sin resetearla).
            $localCred = Read-AutoConfigCredential -PasswordOnly -FixedUser $env:USERNAME

            if (Test-CredentialValid -Credential $localCred) {
                Export-SecureCredential -Credential $localCred -Path $localCredPath -Key $aesKey
                Protect-CredentialFiles -Path $localCredPath | Out-Null

                if (Test-Path $localCredPath) {
                    Write-ColoredMessage "Credenciales de usuario local guardadas correctamente" -Type Success
                    Write-Host "Ubicación: $localCredPath" -ForegroundColor Gray
                }
            } else {
                Write-ColoredMessage "Contrasena vacia - autologin omitido" -Type Info
            }
        } else {
            Write-ColoredMessage "Autologin omitido (iniciaras sesion a mano en el primer reinicio)" -Type Info
        }
    } catch {
        Write-ColoredMessage "Credenciales de usuario local omitidas" -Type Info
    }
}

Write-Host ""

# ====================================
# CONTRASENA DE WI-FI
# ====================================

Write-ColoredMessage "PASO 3: Contrasena de Red Wi-Fi" -Type Header
Write-Host ""

$wifiCredPath = "$SecureConfigPath\cred_wifi.json"
$wifiCredValid = Test-Path $wifiCredPath

if ($wifiCredValid) {
    Write-ColoredMessage "Contrasena de Wi-Fi ya configurada - se omite (elimina cred_wifi.json para reconfigurar)" -Type Info
} else {
    Write-Host "Ingresa la contrasena de la red Wi-Fi corporativa." -ForegroundColor Gray
    Write-Host "El SSID se configurara en config.ps1" -ForegroundColor Gray
    Write-Host ""
}

while (-not $wifiCredValid) {
    try {
        $wifiCred = Read-AutoConfigCredential -PasswordOnly -FixedUser "WiFi-Password"

        if ($wifiCred -and $wifiCred.Password.Length -gt 0) {
            # Guardar contraseña cifrada con AES
            Export-SecureCredential -Credential $wifiCred -Path $wifiCredPath -Key $aesKey
            Protect-CredentialFiles -Path $wifiCredPath | Out-Null

            if (Test-Path $wifiCredPath) {
                Write-ColoredMessage "Contraseña de Wi-Fi guardada correctamente" -Type Success
                Write-Host "Ubicación: $wifiCredPath" -ForegroundColor Gray
                $wifiCredValid = $true
            }
        } else {
            Write-ColoredMessage "Contrasena invalida o cancelada" -Type Warning
            $retry = Read-Host "¿Intentar nuevamente? (S/N)"
            if ($retry -notmatch "^[Ss]") {
                Write-ColoredMessage "Configuracion de Wi-Fi cancelada" -Type Warning
                Write-ColoredMessage "Deberas configurar la contrasena manualmente en config.ps1" -Type Info
                break
            }
        }
    } catch {
        Write-ColoredMessage "Error al procesar contrasena de Wi-Fi: $_" -Type Error
        $retry = Read-Host "¿Intentar nuevamente? (S/N)"
        if ($retry -notmatch "^[Ss]") {
            break
        }
    }
}

Write-Host ""

# ====================================
# PASO 4: SELECCION DE APLICACIONES (apps.json)
# ====================================

Write-ColoredMessage "PASO 4: Aplicaciones a instalar" -Type Header
Write-Host ""

$appsJsonPath = "$ProjectRoot\apps.json"
$exampleAppsPath = "$ProjectRoot\example-apps.json"

if (Test-Path $appsJsonPath) {
    Write-ColoredMessage "Ya existe 'apps.json' - se omite este paso" -Type Info
    Write-Host "  Para cambiar la lista, edita apps.json o eliminalo para volver a elegir." -ForegroundColor Gray
} else {
    # Catalogo de apps Winget por defecto (leido de example-apps.json)
    $catalog = @()
    if (Test-Path $exampleAppsPath) {
        try {
            $exampleApps = Get-Content -Path $exampleAppsPath -Raw | ConvertFrom-Json
            $catalog = @($exampleApps | Where-Object { $_.Name -and $_.Source -eq 'Winget' })
        } catch {
            Write-ColoredMessage "No se pudo leer el catalogo de example-apps.json: $_" -Type Warning
        }
    }

    $selectedApps = @()

    if ($catalog.Count -gt 0) {
        Write-Host "Aplicaciones disponibles (via Winget):" -ForegroundColor Gray
        for ($i = 0; $i -lt $catalog.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $catalog[$i].Name)
        }
        Write-Host ""
        Write-Host "Numeros a instalar separados por coma (ej: 1,3,4), Enter/'todas' para todas," -ForegroundColor Gray
        Write-Host "o 'ninguna' para no instalar apps de Winget." -ForegroundColor Gray
        $sel = (Read-Host "Seleccion").Trim()

        if ($sel -match '^(?i:ninguna)$') {
            # No se agrega ninguna app de Winget.
        } elseif ($sel -eq '' -or $sel -match '^(?i:todas)$') {
            $selectedApps += $catalog
        } else {
            $indexes = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
            foreach ($idx in $indexes) {
                $n = [int]$idx
                if ($n -ge 1 -and $n -le $catalog.Count) { $selectedApps += $catalog[$n - 1] }
            }
        }
    } else {
        Write-ColoredMessage "No hay catalogo de apps de Winget disponible (example-apps.json)" -Type Warning
    }

    # Apps de red (opcional) - el tecnico decide si instala desde una carpeta de red
    Write-Host ""
    $wantNetwork = (Read-Host "Instalar aplicaciones desde una carpeta de red? (s/N)").Trim()
    if ($wantNetwork -match '^[Ss]') {
        Write-Host ""
        Write-Host "  NOTA: el flag de instalacion silenciosa VARIA por instalador" -ForegroundColor Yellow
        Write-Host "  (ej. /S, /silent, /quiet, /qn, -ms). Si el instalador NO soporta modo" -ForegroundColor Yellow
        Write-Host "  silencioso (ej. FortiClient VPN), abrira su asistente y el tecnico" -ForegroundColor Yellow
        Write-Host "  debera completarlo a mano durante la instalacion." -ForegroundColor Yellow
        Write-Host ""
        $addMore = $true
        while ($addMore) {
            $netName = (Read-Host "  Nombre de la app de red").Trim()
            $netPath = (Read-Host "  Ruta de red al instalador (UNC, ej: \\servidor\ruta\app.exe)").Trim()
            if ($netName -and $netPath) {
                $netArgs = (Read-Host "  Argumentos silenciosos (Enter para /silent; varia por instalador)").Trim()
                if (-not $netArgs) { $netArgs = '/silent' }
                $selectedApps += [PSCustomObject]@{ Name = $netName; Source = 'Network'; Path = $netPath; Arguments = $netArgs; Timeout = 600 }
                Write-ColoredMessage "  Agregada app de red: $netName" -Type Success
            } else {
                Write-ColoredMessage "  Nombre y Ruta son obligatorios - app de red omitida" -Type Warning
            }
            $more = (Read-Host "  Agregar otra app de red? (s/N)").Trim()
            $addMore = ($more -match '^[Ss]')
        }
    }

    # Escribir apps.json (UTF-8 SIN BOM, convencion del proyecto para JSON)
    try {
        $appsOut = @()
        foreach ($a in $selectedApps) {
            $obj = [ordered]@{ Name = $a.Name; Source = $a.Source }
            if ($a.ID) { $obj.ID = $a.ID }
            if ($a.Path) { $obj.Path = $a.Path }
            if ($a.Arguments) { $obj.Arguments = $a.Arguments }
            if ($a.Timeout) { $obj.Timeout = $a.Timeout }
            $appsOut += [PSCustomObject]$obj
        }

        if ($appsOut.Count -eq 0) {
            $json = '[]'
        } else {
            $json = @($appsOut) | ConvertTo-Json -Depth 5
            # ConvertTo-Json en PS 5.1 no envuelve en [] un array de 1 elemento.
            if (-not $json.TrimStart().StartsWith('[')) { $json = "[$([Environment]::NewLine)$json$([Environment]::NewLine)]" }
        }

        [System.IO.File]::WriteAllText($appsJsonPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ""
        Write-ColoredMessage "apps.json generado con $($appsOut.Count) aplicacion(es)" -Type Success
    } catch {
        Write-ColoredMessage "Error al generar apps.json: $_" -Type Error
        Write-Host "  Podes crear apps.json a mano copiando example-apps.json." -ForegroundColor Gray
    }
}

Write-Host ""

# ====================================
# RESUMEN
# ====================================

Write-ColoredMessage "CONFIGURACIoN COMPLETADA" -Type Header
Write-Host ""
Write-ColoredMessage "Resumen de credenciales configuradas:" -Type Info
Write-Host ""

$summary = @()
if (Test-Path $ConfigPath) {
    $summary += "  [OK] Configuracion basica: $ConfigPath"
}
if (Test-Path $domainCredPath) {
    $summary += "  [OK] Credenciales de dominio: $domainCredPath"
}
if (Test-Path $localCredPath) {
    $summary += "  [OK] Credenciales locales: $localCredPath"
}
if (Test-Path $wifiCredPath) {
    $summary += "  [OK] Contrasena Wi-Fi: $wifiCredPath"
}
if (Test-Path $appsJsonPath) {
    $summary += "  [OK] Lista de aplicaciones: $appsJsonPath"
}

if ($summary.Count -eq 0) {
    Write-ColoredMessage "No se configuro nada en esta corrida" -Type Warning
} else {
    $summary | ForEach-Object { Write-Host $_ -ForegroundColor Green }
}

Write-Host ""
Write-ColoredMessage "PROXIMOS PASOS:" -Type Info
Write-Host "  1. Revisa 'config.ps1' por si queres ajustar OU, lista de apps u otros parametros" -ForegroundColor Gray
Write-Host "  2. Ejecuta 'init.bat' para iniciar el proceso de configuracion" -ForegroundColor Gray
Write-Host ""

Write-ColoredMessage "IMPORTANTE: Las credenciales solo funcionaran en este equipo (clave AES local)" -Type Warning
Write-Host ""

Read-Host "Presiona Enter para salir"

# Codigo de salida basado en si quedaron las credenciales minimas
# indispensables (dominio y Wi-Fi) - config.ps1 falla al cargar sin ellas.
# init.bat depende de este codigo en vez de volver a chequear Test-Path el
# mismo: los archivos quedan con ACL restringida a Administrators+SYSTEM, y
# si init.bat llegara a correr sin elevar, "if exist" los veria como
# inexistentes aunque existan (bug real encontrado en pruebas de hardware).
if ((Test-Path $domainCredPath) -and (Test-Path $wifiCredPath)) {
    exit 0
} else {
    Write-Host ""
    Write-ColoredMessage "Faltan credenciales obligatorias (dominio y/o Wi-Fi) - init.bat lo reportara como error" -Type Warning
    exit 1
}
