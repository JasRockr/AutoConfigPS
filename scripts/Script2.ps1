# PowerShell Script - PowerShell 5.1
# JasRockr!
# Script Inicial P2
# Parte2: Unir equipo al dominio y preparar sistema para el reinicio.

# Configurar titulo de ventana
# ----------------------------------------------------------------
$tituloPredeterminado = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Configuraciones iniciales - 2/4"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SCRIPT #2 - UNION AL DOMINIO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fecha/Hora de inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# ----------------------------------------------------------------
# # Flujo de ejecución del script # 2
# 0. Cargar archivo de configuración.
# 1. Configurar inicio de sesión automático con usuario administrador.
# 2. Unir equipo al dominio.
# 3. Crear una tarea programada para ejecutar la tercera parte del script tras el reinicio.
# 4. Eliminar la tarea creada en el script anterior.
# 5. Reiniciar el equipo.
# ----------------------------------------------------------------

# # ----------------------------------------------------------------
# # Flujo principal
# # ----------------------------------------------------------------

# @param $Useradmin Usuario de dominio con permisos de administrador
# @param $Passadmin Contraseña de usuario de dominio
# @param $DomainName Nombre del dominio
# @param $Delay Tiempo de espera en segundos
# @param $ScriptPath Ruta del script de la tercera parte

# 0. Cargar archivo de configuración
# ----------------------------------------------------------------
Write-Host "Cargando archivo de config..." -ForegroundColor Cyan
$ConfigPath = "$PSScriptRoot\..\config.ps1"

# Validar si el archivo de configuración se cargó correctamente
# TODO: Migrar funcion al modulo de validación
if (Test-Path $ConfigPath) {
    try {
        # Importar archivo de configuración
        . $ConfigPath
        Write-Host "Archivo 'config' cargado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "ERROR al cargar el archivo de configuración:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        exit 1
    }
} else {
    Write-Host "Parece que hubo un error importando las configuraciones." -ForegroundColor DarkRed
    Write-Host "Confirma que el archivo 'config.ps1' exista en la carpeta raíz del script." -ForegroundColor DarkRed
    Write-Host "Ruta esperada: $ConfigPath" -ForegroundColor Yellow
    # TODO: Crear archivo (config-default.ps1) de configuración predeterminado si no se encuentra
    Start-Sleep -Seconds 30
    exit 1
}

#! ---------------------------------------------------------------
# @param [string] $logDirectory - Directorio de logs
# @param [string] $successLog - Archivo de log de éxito
# @param [string] $errorLog - Archivo de log de errores
# @param [int] $maxSize - Tamaño máximo del archivo de log (10MB por defecto)

# @function Write-Log - Función principal de logging
# @function Write-SuccessLog - Función de log de éxito
# @function Write-ErrorLog - Función de log de errores

# @param [string] $message - Mensaje a registrar en el log
# @param [string] $logFile - Archivo de log donde se registrará el mensaje

# @output [string] $log - Mensaje de log formateado con fecha y hora

# @output [string] $date - Fecha y hora actual formateada
# @output [int] $fileSize - Tamaño del archivo de log
# @output [string] $timestamp - Marca de tiempo para renombrar el archivo de log

# @output [string] $logDirectory - Directorio de logs por defecto
# @output [string] $successLog - Archivo de log de éxito por defecto
# @output [string] $errorLog - Archivo de log de errores por defecto
# @output [int] $maxSize - Tamaño máximo del archivo de log por defecto

# ----------------------------------------------------------------

# Directorio por defecto de logs
if (-not $logDirectory) { $logDirectory = "C:\Logs" } else { $logDirectory } 
# Archivo de log de éxito
if (-not $successLog) { $successLog = "$logDirectory\setup_success.log" } else { $successLog }
# Archivo de log de errores
if (-not $errorLog) { $errorLog = "$logDirectory\setup_errors.log" } else { $errorLog }

#! Funciones de Logging
function Write-Log {
    param (
        [string]$message,
        [string]$logFile
    )
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $log = "[LOG][$date] $message"
    
    # Si el archivo de log supera los 10 MB, se renombra con timestamp
    $maxSize = 10 * 1024 * 1024 # 10MB
    if (Test-Path $logFile) {
        $fileSize = (Get-Item $logFile).Length
        if ($fileSize -gt $maxSize) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            Rename-Item -Path $logFile -NewName "$logFile-$timestamp.bak"
        }
    }

    Add-Content -Path $logFile -Value $log
}

# Función success log
function Write-SuccessLog { param ( [string]$message ) Write-Log -message "[SUCCESS] $message" -logFile $successLog }

# Función error log
function Write-ErrorLog { param ( [string]$message ) Write-Log -message "[!ERROR] $message" -logFile $errorLog }

# TODO: Ajustar la lógica, basado en el tipo de log (errores o exito) y el tamaño del archivo de log

# Validar si el directorio de logs existe
if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    Write-Host "Directorio de logs creado: $logDirectory" -ForegroundColor Green
    Write-SuccessLog "Directorio de logs creado correctamente: $logDirectory"
} else {
    Write-Host "Directorio de logs ya existe: $logDirectory" -ForegroundColor Yellow
    Write-SuccessLog "Se ha encontrado el directorio de logs: $logDirectory"
}

# Validar si el log de errores existe : $errorLog = "C:\Logs\setup_errors.log"
if (-not (Test-Path $errorLog)) {
    Write-Host "Creando archivo de log de errores..." -ForegroundColor Yellow
    New-Item -Path $errorLog -ItemType File -Force | Out-Null

    # Establecer permisos restrictivos (solo Administrators y SYSTEM)
    icacls $errorLog /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null
    Write-Host "Archivo de log de errores creado correctamente con permisos restrictivos." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de errores creado correctamente: $errorLog (permisos: Administrators+SYSTEM)"
} else {
    Write-Host "El archivo de log de errores ya existe." -ForegroundColor Yellow
    Write-ErrorLog "El archivo de log de errores ya existe: $errorLog"
}

# Validar si el log de éxito existe : $successLog = "C:\Logs\setup_success.log"
if (-not (Test-Path $successLog)) {
    Write-Host "Creando archivo de log de éxito..." -ForegroundColor Yellow
    New-Item -Path $successLog -ItemType File -Force | Out-Null

    # Establecer permisos restrictivos (solo Administrators y SYSTEM)
    icacls $successLog /inheritance:r /grant "BUILTIN\Administrators:(F)" /grant "SYSTEM:(F)" | Out-Null
    Write-Host "Archivo de log de éxito creado correctamente con permisos restrictivos." -ForegroundColor Green
    Write-SuccessLog "Archivo de log de éxito creado correctamente: $successLog (permisos: Administrators+SYSTEM)"
} else {
    Write-Host "El archivo de log de éxito ya existe." -ForegroundColor Yellow
    Write-SuccessLog "El archivo de log de éxito ya existe: $successLog"
}

# Registrar inicio de ejecución del Script2
Write-SuccessLog "=========================================="
Write-SuccessLog "INICIANDO SCRIPT #2 - UNION AL DOMINIO"
Write-SuccessLog "Fecha/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-SuccessLog "Ejecutado por: $env:USERNAME"
Write-SuccessLog "Nombre del equipo: $env:COMPUTERNAME"
Write-SuccessLog "Dominio actual: $((Get-WmiObject -Class Win32_ComputerSystem).Domain)"
Write-SuccessLog "=========================================="

#! ---------------------------------------------------------------

# ----------------------------------------------------------------
# Función de validación de controlador de dominio
# ----------------------------------------------------------------
function Test-DomainController {
    <#
    .SYNOPSIS
        Valida acceso al controlador de dominio antes de intentar unión

    .DESCRIPTION
        Verifica:
        - Resolución DNS del dominio
        - Acceso al controlador de dominio
        - Puertos requeridos accesibles (opcional)

    .PARAMETER DomainName
        FQDN del dominio (ejemplo: dominio.local)

    .PARAMETER MaxRetries
        Número máximo de intentos de validación (por defecto 3)

    .RETURNS
        $true si el DC es accesible, $false si falla
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName,

        [int]$MaxRetries = 3
    )

    Write-Host "Validando acceso al controlador de dominio..." -ForegroundColor Cyan
    Write-SuccessLog "Iniciando validación de controlador de dominio: $DomainName"

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Host "  Intento $attempt/$MaxRetries..." -ForegroundColor Gray

        try {
            # Método 1: Intentar resolver el dominio mediante DNS
            Write-Host "  → Resolviendo dominio via DNS..." -ForegroundColor Gray

            try {
                # Buscar registros SRV de LDAP para el dominio
                $dcRecords = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop

                if ($dcRecords -and $dcRecords.Count -gt 0) {
                    $dcName = $dcRecords[0].NameTarget
                    Write-Host "  [OK] Controlador de dominio encontrado via DNS: $dcName" -ForegroundColor Green
                    Write-SuccessLog "DC encontrado via DNS SRV: $dcName"

                    # Intentar hacer ping al DC
                    Write-Host "  → Verificando conectividad con DC..." -ForegroundColor Gray
                    if (Test-Connection -ComputerName $dcName -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                        Write-Host "  [OK] DC alcanzable: $dcName" -ForegroundColor Green
                        Write-SuccessLog "DC alcanzable: $dcName"

                        # Validación exitosa
                        Write-Host "✅ Validación de DC completada exitosamente" -ForegroundColor Green
                        Write-SuccessLog "Validación de DC exitosa - Dominio: $DomainName, DC: $dcName"
                        return $true
                    } else {
                        Write-Host "  [!] DC encontrado pero no responde a ping" -ForegroundColor Yellow
                        Write-ErrorLog "DC encontrado pero no responde: $dcName (intento $attempt/$MaxRetries)"
                    }
                }
            } catch {
                Write-Host "  [!] No se pudo resolver DC via DNS SRV" -ForegroundColor Yellow
                Write-ErrorLog "Error en resolución DNS SRV: $($_.Exception.Message)"
            }

            # Método 2: Intentar resolver el dominio directamente
            Write-Host "  → Resolviendo dominio directo..." -ForegroundColor Gray
            try {
                $domainIP = Resolve-DnsName -Name $DomainName -ErrorAction Stop |
                    Where-Object { $_.Type -eq 'A' } |
                    Select-Object -First 1

                if ($domainIP) {
                    Write-Host "  [OK] Dominio resuelto a: $($domainIP.IPAddress)" -ForegroundColor Green

                    if (Test-Connection -ComputerName $domainIP.IPAddress -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                        Write-Host "  [OK] Servidor de dominio alcanzable" -ForegroundColor Green
                        Write-SuccessLog "Dominio alcanzable via IP: $($domainIP.IPAddress)"

                        Write-Host "✅ Validación de DC completada (método alternativo)" -ForegroundColor Green
                        return $true
                    }
                }
            } catch {
                Write-Host "  [!] No se pudo resolver dominio directamente" -ForegroundColor Yellow
                Write-ErrorLog "Error en resolución DNS directa: $($_.Exception.Message)"
            }

            # Método 3: Usar nltest (si está disponible)
            Write-Host "  → Intentando localizar DC con nltest..." -ForegroundColor Gray
            try {
                $nltestResult = nltest /dsgetdc:$DomainName 2>&1
                if ($LASTEXITCODE -eq 0 -and $nltestResult -match "DC:") {
                    $dcFromNltest = $nltestResult | Select-String -Pattern "DC: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

                    if ($dcFromNltest) {
                        Write-Host "  [OK] DC encontrado con nltest: $dcFromNltest" -ForegroundColor Green
                        Write-SuccessLog "DC encontrado con nltest: $dcFromNltest"

                        if (Test-Connection -ComputerName $dcFromNltest -Count 2 -Quiet -ErrorAction SilentlyContinue) {
                            Write-Host "  [OK] DC alcanzable via nltest" -ForegroundColor Green
                            Write-Host "✅ Validación de DC completada (nltest)" -ForegroundColor Green
                            return $true
                        }
                    }
                }
            } catch {
                Write-Host "  [!] nltest no disponible o falló" -ForegroundColor Yellow
            }

        } catch {
            Write-Host "  [!] Error en validación: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-ErrorLog "Error en validación de DC (intento $attempt/$MaxRetries): $($_.Exception.Message)"
        }

        if ($attempt -lt $MaxRetries) {
            Write-Host "  Esperando 10 segundos antes del siguiente intento..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    }

    # Si llegamos aquí, todas las validaciones fallaron
    Write-Host "❌ No se pudo validar acceso al DC después de $MaxRetries intentos" -ForegroundColor Red
    Write-Host "Posibles causas:" -ForegroundColor Yellow
    Write-Host "  - Problema de conectividad de red" -ForegroundColor Yellow
    Write-Host "  - Configuración DNS incorrecta" -ForegroundColor Yellow
    Write-Host "  - Controlador de dominio inaccesible" -ForegroundColor Yellow
    Write-Host "  - Firewall bloqueando conexiones" -ForegroundColor Yellow
    Write-ErrorLog "Fallo en validación de DC después de $MaxRetries intentos - Dominio: $DomainName"

    return $false
}

#! ---------------------------------------------------------------

# ----------------------------------------------------------------
# Función de validación de nombre de equipo en Active Directory
# ----------------------------------------------------------------
function Test-ComputerNameInAD {
    <#
    .SYNOPSIS
        Verifica si un nombre de equipo ya existe en Active Directory

    .DESCRIPTION
        Busca el nombre del equipo en AD para evitar conflictos.
        Si existe, puede generar un nombre alternativo.

    .PARAMETER ComputerName
        Nombre del equipo a verificar

    .PARAMETER DomainName
        FQDN del dominio

    .PARAMETER GenerateAlternative
        Si es $true, genera nombre alternativo si existe conflicto

    .RETURNS
        Objeto con Available (bool), AlternativeName (string|null), Message (string)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,

        [Parameter(Mandatory=$true)]
        [string]$DomainName,

        [bool]$GenerateAlternative = $true
    )

    Write-Host "Verificando disponibilidad del nombre '$ComputerName' en AD..." -ForegroundColor Cyan
    Write-SuccessLog "Verificando disponibilidad del nombre: $ComputerName"

    try {
        # Método 1: Intentar con DirectorySearcher (no requiere módulo AD)
        try {
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
            $searcher.Filter = "(&(objectClass=computer)(cn=$ComputerName))"
            $searcher.SearchRoot = [ADSI]"LDAP://$DomainName"
            $result = $searcher.FindOne()

            if ($result) {
                Write-Host "  [!] Nombre '$ComputerName' ya existe en AD" -ForegroundColor Yellow
                Write-Host "    DN: $($result.Properties['distinguishedname'])" -ForegroundColor Gray
                Write-ErrorLog "Nombre de equipo '$ComputerName' ya existe en AD"

                $nameExists = $true
            } else {
                Write-Host "  [OK] Nombre '$ComputerName' disponible" -ForegroundColor Green
                Write-SuccessLog "Nombre '$ComputerName' disponible en AD"

                return @{
                    Available = $true
                    AlternativeName = $null
                    Message = "Nombre disponible"
                }
            }
        } catch {
            Write-Host "  [!] No se pudo verificar con DirectorySearcher" -ForegroundColor Yellow
            Write-ErrorLog "Error en DirectorySearcher: $($_.Exception.Message)"
            $nameExists = $false  # Asumimos que está disponible si no podemos verificar
        }

        # Si el nombre existe y se solicita alternativa
        if ($nameExists -and $GenerateAlternative) {
            Write-Host ""
            Write-Host "Generando nombre alternativo..." -ForegroundColor Cyan

            # Estrategia: Agregar sufijo numérico aleatorio
            $maxAttempts = 10
            $alternativeName = $null

            for ($i = 1; $i -le $maxAttempts; $i++) {
                # Generar sufijo (ej: PC001, PC002, etc. o aleatorio)
                $suffix = Get-Random -Minimum 100 -Maximum 999
                $testName = "$ComputerName-$suffix"

                # Limitar a 15 caracteres (límite NetBIOS)
                if ($testName.Length -gt 15) {
                    # Recortar nombre base y agregar sufijo
                    $maxBaseLength = 15 - 4  # 4 para "-999"
                    $testName = "$($ComputerName.Substring(0, $maxBaseLength))-$suffix"
                }

                # Verificar si el nombre alternativo existe
                $searcherAlt = New-Object System.DirectoryServices.DirectorySearcher
                $searcherAlt.Filter = "(&(objectClass=computer)(cn=$testName))"
                $searcherAlt.SearchRoot = [ADSI]"LDAP://$DomainName"
                $resultAlt = $searcherAlt.FindOne()

                if (-not $resultAlt) {
                    $alternativeName = $testName
                    Write-Host "  [OK] Nombre alternativo generado: $alternativeName" -ForegroundColor Green
                    Write-SuccessLog "Nombre alternativo generado: $alternativeName"
                    break
                } else {
                    Write-Host "  [!] Intento $i`/${maxAttempts}: $testName también existe" -ForegroundColor Yellow
                }
            }

            if ($alternativeName) {
                return @{
                    Available = $false
                    AlternativeName = $alternativeName
                    Message = "Nombre original existe, usando alternativo: $alternativeName"
                }
            } else {
                Write-ErrorLog "No se pudo generar nombre alternativo después de $maxAttempts intentos"
                return @{
                    Available = $false
                    AlternativeName = $null
                    Message = "Nombre existe y no se pudo generar alternativo"
                }
            }
        }

        # Si el nombre existe pero no se solicita alternativa
        if ($nameExists) {
            return @{
                Available = $false
                AlternativeName = $null
                Message = "Nombre ya existe en AD"
            }
        }

        # Si no pudimos verificar, asumimos que está disponible
        Write-Host "  [!] No se pudo verificar nombre en AD - continuando" -ForegroundColor Yellow
        Write-SuccessLog "Verificación de nombre omitida - continuando con nombre actual"

        return @{
            Available = $true
            AlternativeName = $null
            Message = "No se pudo verificar (asumiendo disponible)"
        }

    } catch {
        Write-Host "  [!] Error en validación: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-ErrorLog "Error en Test-ComputerNameInAD: $($_.Exception.Message)"

        # En caso de error, permitir continuar
        return @{
            Available = $true
            AlternativeName = $null
            Message = "Error en validación (permitiendo continuar)"
        }
    }
}

#! ---------------------------------------------------------------

# 1. Configurar actualización de inicio de sesión automático (usuario de dominio por defecto 'administrador')
# ----------------------------------------------------------------

# Soporte para credenciales cifradas y texto plano
if (Get-Variable -Name 'SecurePassadmin' -ErrorAction SilentlyContinue) {
    # Ya se proporcionó SecureString (credenciales cifradas)
    Write-Host "Usando credenciales de dominio cifradas" -ForegroundColor Green
    Write-SuccessLog "Credenciales de dominio: usando formato cifrado"
    $DomainSecurePass = $SecurePassadmin
} elseif (Get-Variable -Name 'Passadmin' -ErrorAction SilentlyContinue) {
    # Texto plano proporcionado (método legacy)
    Write-Host "ADVERTENCIA: Usando contraseña de dominio en texto plano" -ForegroundColor Yellow
    Write-SuccessLog "Credenciales de dominio: usando texto plano (no recomendado)"
    $DomainSecurePass = ConvertTo-SecureString $Passadmin -AsPlainText -Force
} else {
    Write-ErrorLog "No se proporcionaron credenciales de dominio"
    throw "Error: Faltan credenciales de dominio"
}

$Credential = New-Object System.Management.Automation.PSCredential ($Useradmin, $DomainSecurePass)

# Ruta de la clave del registro para el inicio de sesión automático
$AutoLoginKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Convertir SecureString a texto plano ([!]️ Requerido por registro de Windows)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
$PlainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Habilitar el inicio de sesión automático
Set-ItemProperty -Path $AutoLoginKey -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $AutoLoginKey -Name "DefaultUserName" -Value $Credential.UserName
Set-ItemProperty -Path $AutoLoginKey -Name "DefaultPassword" -Value $PlainTextPassword
Write-Host "Inicio de sesion automático configurado para el usuario '$Useradmin'." -ForegroundColor Green
Write-SuccessLog "Inicio de sesion automático configurado para el usuario '$Useradmin'."

# Limpiar la variable de texto plano después de su uso
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
Remove-Variable -Name PlainTextPassword -ErrorAction SilentlyContinue
Remove-Variable -Name DomainSecurePass -ErrorAction SilentlyContinue

Start-Sleep -Seconds $Delay

# 2. Unir el equipo al dominio
# ----------------------------------------------------------------
try {
    # Verificar si el equipo ya está unido al dominio
    $currentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($currentDomain -eq $DomainName) {
        Write-Host "El equipo ya está unido al dominio '$DomainName'." -ForegroundColor Yellow
        Write-SuccessLog "El equipo ya está unido al dominio '$DomainName'."
    } else {
        # Validar acceso al controlador de dominio antes de intentar unión (nuevo en v0.0.4)
        Write-Host ""
        Write-SuccessLog "Iniciando validación de controlador de dominio antes de unión"
        $dcValid = Test-DomainController -DomainName $DomainName -MaxRetries 3
        Write-Host ""

        if (-not $dcValid) {
            Write-Host "❌ No se pudo validar el acceso al controlador de dominio" -ForegroundColor Red
            Write-ErrorLog "[CRITICAL] No se pudo validar acceso al controlador de dominio: $DomainName"
            Write-ErrorLog "  Se intentaron 3 validaciones sin éxito"
            Write-ErrorLog "  Verifique conectividad de red y configuración DNS"
            throw "Error: No se puede acceder al controlador de dominio '$DomainName'"
        }

        # Validar nombre de equipo en AD y generar alternativo si es necesario (nuevo en v0.0.4)
        Write-Host ""
        $currentComputerName = (Get-WmiObject -Class Win32_ComputerSystem).Name
        $nameCheck = Test-ComputerNameInAD -ComputerName $currentComputerName -DomainName $DomainName -GenerateAlternative $true
        Write-Host ""

        if (-not $nameCheck.Available -and $nameCheck.AlternativeName) {
            # Nombre existe, usar alternativo
            Write-Host "IMPORTANTE: Se usará nombre alternativo para evitar conflicto" -ForegroundColor Yellow
            Write-Host "  Nombre original: $currentComputerName" -ForegroundColor Gray
            Write-Host "  Nombre nuevo: $($nameCheck.AlternativeName)" -ForegroundColor Cyan
            Write-SuccessLog "Cambiando nombre de '$currentComputerName' a '$($nameCheck.AlternativeName)' por conflicto en AD"

            try {
                Rename-Computer -NewName $nameCheck.AlternativeName -Force -PassThru | Out-Null
                Write-Host "  [OK] Nombre del equipo cambiado a: $($nameCheck.AlternativeName)" -ForegroundColor Green
                Write-SuccessLog "[SUCCESS] Nombre cambiado exitosamente de '$currentComputerName' a '$($nameCheck.AlternativeName)'"
                $currentComputerName = $nameCheck.AlternativeName
            } catch {
                Write-Host "  [ERROR] No se pudo cambiar el nombre del equipo" -ForegroundColor Red
                Write-Host "  Mensaje: $($_.Exception.Message)" -ForegroundColor Gray
                Write-ErrorLog "[ERROR] Fallo al cambiar nombre del equipo"
                Write-ErrorLog "  Nombre original: $currentComputerName"
                Write-ErrorLog "  Nombre destino: $($nameCheck.AlternativeName)"
                Write-ErrorLog "  Mensaje: $($_.Exception.Message)"
                throw "Error: No se pudo cambiar el nombre del equipo a alternativo"
            }

            Write-Host ""
        } elseif (-not $nameCheck.Available -and -not $nameCheck.AlternativeName) {
            # Nombre existe pero no se pudo generar alternativo
            Write-Host "ADVERTENCIA: El nombre '$currentComputerName' ya existe en AD" -ForegroundColor Yellow
            Write-Host "No se pudo generar nombre alternativo automáticamente." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Opciones:" -ForegroundColor Cyan
            Write-Host "  1. Continuar de todas formas (puede fallar la unión)" -ForegroundColor Gray
            Write-Host "  2. Cancelar y cambiar manualmente el nombre en config.ps1" -ForegroundColor Gray
            Write-Host ""

            $response = Read-Host "¿Deseas continuar de todas formas? (S/N)"
            if ($response -notmatch "^[Ss]") {
                Write-Host "Unión al dominio cancelada por el usuario." -ForegroundColor Yellow
                Write-ErrorLog "Unión cancelada - nombre duplicado sin alternativo"
                exit 0
            }
            Write-Host ""
        }

        # Proceder con la unión al dominio
        Write-Host "Uniendo equipo al dominio '$DomainName'..." -ForegroundColor Cyan
        Write-Host "  Nombre del equipo: $currentComputerName" -ForegroundColor Gray

        # Preparar parámetros para Add-Computer
        $addComputerParams = @{
            DomainName = $DomainName
            Credential = $Credential
            Force = $true
        }

        # Agregar OUPath si está definido (nuevo en v0.0.4)
        if (Get-Variable -Name 'OUPath' -ErrorAction SilentlyContinue) {
            if (-not [string]::IsNullOrWhiteSpace($OUPath)) {
                Write-Host "Uniendo a OU específica: $OUPath" -ForegroundColor Cyan
                Write-SuccessLog "Uniendo equipo a OU: $OUPath"
                $addComputerParams.Add('OUPath', $OUPath)
            }
        } else {
            Write-Host "No se especificó OU - usando contenedor predeterminado (Computers)" -ForegroundColor Gray
            Write-SuccessLog "Unión al dominio sin OU específica (contenedor Computers predeterminado)"
        }

        # Ejecutar unión al dominio
        Write-Host ""
        Write-Host "Ejecutando unión al dominio..." -ForegroundColor Cyan
        Write-SuccessLog "Iniciando proceso de unión al dominio: $DomainName (Equipo: $currentComputerName)"
        
        try {
            Add-Computer @addComputerParams -ErrorAction Stop
            
            Write-Host ""
            Write-Host "✅ El equipo se unió correctamente al dominio '$DomainName'" -ForegroundColor Green
            Write-SuccessLog "[SUCCESS] Equipo unido exitosamente al dominio: $DomainName (Equipo: $currentComputerName)"
            Write-Host ""
            Write-Host "IMPORTANTE: El equipo debe reiniciarse para completar la unión al dominio." -ForegroundColor Yellow
            Write-SuccessLog "Unión al dominio completada - reinicio pendiente para aplicar cambios"
            
        } catch {
            Write-Host ""
            Write-Host "❌ Error al unir el equipo al dominio" -ForegroundColor Red
            Write-Host ""
            Write-Host "Detalles del error:" -ForegroundColor Yellow
            Write-Host "  Mensaje: $($_.Exception.Message)" -ForegroundColor Gray
            Write-Host "  Categoría: $($_.CategoryInfo.Category)" -ForegroundColor Gray
            if ($_.FullyQualifiedErrorId) {
                Write-Host "  ErrorID: $($_.FullyQualifiedErrorId)" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "Posibles causas:" -ForegroundColor Yellow
            Write-Host "  - Credenciales de dominio incorrectas o sin permisos" -ForegroundColor Gray
            Write-Host "  - Nombre del equipo ya existe en AD" -ForegroundColor Gray
            Write-Host "  - No se puede contactar el controlador de dominio" -ForegroundColor Gray
            Write-Host "  - OU especificada no existe o sin permisos" -ForegroundColor Gray
            Write-Host ""
            
            # Registrar error detallado en el log
            Write-ErrorLog "[CRITICAL] Error al unir equipo al dominio"
            Write-ErrorLog "  Dominio: $DomainName"
            Write-ErrorLog "  Equipo: $currentComputerName"
            Write-ErrorLog "  Usuario: $Useradmin"
            if ($OUPath) { Write-ErrorLog "  OU: $OUPath" }
            Write-ErrorLog "  Mensaje: $($_.Exception.Message)"
            Write-ErrorLog "  Categoría: $($_.CategoryInfo.Category)"
            if ($_.FullyQualifiedErrorId) { Write-ErrorLog "  ErrorID: $($_.FullyQualifiedErrorId)" }
            Write-ErrorLog "  StackTrace: $($_.ScriptStackTrace)"
            
            throw
        }
        
        Start-Sleep -Seconds $Delay
    }
} catch {
    Write-Host ""
    Write-Host "❌ FALLO CRÍTICO en el proceso de unión al dominio" -ForegroundColor Red
    Write-Host "El script se detendrá." -ForegroundColor Red
    Write-Host ""
    
    Write-ErrorLog "[FATAL] Fallo crítico en proceso de unión al dominio"
    Write-ErrorLog "  Mensaje: $($_.Exception.Message)"
    if ($_.InvocationInfo.ScriptLineNumber) {
        Write-ErrorLog "  Línea: $($_.InvocationInfo.ScriptLineNumber)"
    }
    Write-ErrorLog "  StackTrace: $($_.ScriptStackTrace)"
    
    Start-Sleep -Seconds $Delay
    exit 1
}

# 3. Crear tarea programada post-reinicio
# ----------------------------------------------------------------

# Nombre de tarea programada para confirmar cambios aplicados en el equipo
$TaskName = "Exec-Check-Continue"
$Script = "$ScriptPath\Script3.ps1"
$DelayTask = 60 # Retardo en segundos para iniciar la tarea programada

# Verificar si existe el script
if (-Not (Test-Path $Script)) {
    Write-Error "El script '$Script' no existe en la ruta especificada."
    Write-ErrorLog "El script '$Script' no existe en la ruta especificada."  
    exit 1
}
Write-SuccessLog "Siguiente script '$Script' programado para ejecutarse al inicio."

# Configurar retraso de la tarea programada
$DelaySeconds = 30 # Retardo en segundos para iniciar la tarea programada
$DelayTask = New-TimeSpan -Seconds $DelaySeconds

# -- Crear tarea programada
# Usar SYSTEM para evitar problemas de permisos y dependencia de sesión de usuario
$Action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$Script`" *>> `"$successLog`" 2>> `"$errorLog`"" # Ejecutar el siguiente script

# TRIGGER PRINCIPAL: AtStartup (se ejecuta al reiniciar)
$TriggerStartup = New-ScheduledTaskTrigger -AtStartup

# TRIGGER RESPALDO: OneTime en 2 minutos (garantiza ejecución inmediata si AtStartup falla)
$TriggerBackup = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2)

# Combinar ambos triggers
$Triggers = @($TriggerStartup, $TriggerBackup)

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest # Ejecutar como SYSTEM
$Task = New-ScheduledTask -Action $Action -Trigger $Triggers -Settings $Settings -Principal $Principal

Write-Host "Tarea configurada con 2 triggers: AtStartup + Respaldo en 2min" -ForegroundColor Cyan
Write-SuccessLog "Tarea programada: Trigger1=AtStartup, Trigger2=OneTime(+2min) como SYSTEM"

try {
    # Verificar si la tarea ya existe
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "La tarea '$TaskName' ya existe. Eliminando tarea existente..." -ForegroundColor Yellow
        Write-SuccessLog "Tarea programada existente encontrada: $TaskName"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Tarea '$TaskName' eliminada correctamente." -ForegroundColor Green
        Write-SuccessLog "Tarea programada eliminada correctamente: $TaskName" 
    }
    # Crear la tarea programada (forzar habilitación)
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force | Out-Null
    
    # CRÍTICO: Habilitar explícitamente la tarea
    Enable-ScheduledTask -TaskName $TaskName | Out-Null
    
    Write-Host "Se ha creado la tarea '$TaskName' para ejecutarse al inicio."
    Write-SuccessLog "Tarea programada creada correctamente: $TaskName" 

    #! Verificar si la tarea se creó correctamente
    $checkTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue 
    if ($checkTask) {
        Write-Host "La tarea programada '$TaskName' se ha creado correctamente." -ForegroundColor Green
        Write-SuccessLog "Confirmación: Tarea programada '$TaskName' creada correctamente."
        
        # Registrar detalles de la tarea para debugging
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        $triggerCount = ($checkTask.Triggers | Measure-Object).Count
        Write-SuccessLog "Detalles tarea: Usuario='SYSTEM', Triggers=$triggerCount (AtStartup + OneTime), Script='$Script'"
        Write-SuccessLog "Estado tarea: $($checkTask.State), Habilitada: $($checkTask.Settings.Enabled), UltimaEjecución: $($taskInfo.LastRunTime), ProximaEjecución: $($taskInfo.NextRunTime)"
        
        # CRÍTICO: Si NextRunTime está vacío, forzar inicio de la tarea como respaldo
        if (-not $taskInfo.NextRunTime -or $taskInfo.NextRunTime -eq $null) {
            Write-Host "  ⚠ Próxima ejecución no programada. Forzando inicio de tarea como respaldo..." -ForegroundColor Yellow
            Write-SuccessLog "ADVERTENCIA: NextRunTime vacío. Iniciando tarea manualmente como respaldo."
            
            # Iniciar la tarea ahora (se ejecutará en segundo plano)
            Start-ScheduledTask -TaskName $TaskName
            Start-Sleep -Seconds 2
            
            # Verificar si se inició
            $taskInfoAfter = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
            Write-SuccessLog "Estado después de inicio forzado: UltimaEjecución: $($taskInfoAfter.LastRunTime), ProximaEjecución: $($taskInfoAfter.NextRunTime)"
        }
        
        Write-Host "  → La tarea se ejecutará automáticamente al reiniciar" -ForegroundColor Gray
        Write-Host "  → Usuario: SYSTEM" -ForegroundColor Gray
        Write-Host "  → Script: $Script" -ForegroundColor Gray
    } else {
        Write-Error "Error al crear la tarea programada '$TaskName'."
        Write-ErrorLog "Error al crear la tarea programada '$TaskName'." 
        # exit 1
    }

} catch {
    Write-Error "Error al crear la tarea programada '$TaskName': $($_.Exception.Message)"
    Write-ErrorLog "Error al crear la tarea programada '$TaskName': $($_.Exception.Message)"
    # Start-Sleep -Seconds $Delay
    exit 1
}
# --

# 4. Eliminar la tarea programada previamente creada
# ----------------------------------------------------------------
Write-Host "Eliminando tarea programada anterior..." -ForegroundColor Cyan

# Eliminar tarea programada 'Exec-Join-Domain' 
$DelTaskName = "Exec-Join-Domain"

try {
    # Verificar si la tarea existe antes de eliminarla
    $existingTask = Get-ScheduledTask -TaskName $DelTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $DelTaskName -Confirm:$false
        Write-Host "Tarea programada '$DelTaskName' eliminada correctamente." -ForegroundColor Green
        Write-SuccessLog "[SUCCESS] Tarea programada '$DelTaskName' eliminada correctamente"
    } else {
        Write-Host "La tarea programada '$DelTaskName' no existe." -ForegroundColor Yellow
        Write-SuccessLog "INFO: La tarea programada '$DelTaskName' no existe (posiblemente ya eliminada)"
    }
} catch {
    Write-Host "⚠️ Error al eliminar la tarea programada '$DelTaskName'" -ForegroundColor Yellow
    Write-Host "Mensaje: $($_.Exception.Message)" -ForegroundColor Gray
    Write-ErrorLog "[WARNING] Error al eliminar tarea programada anterior"
    Write-ErrorLog "  Tarea: $DelTaskName"
    Write-ErrorLog "  Mensaje: $($_.Exception.Message)"
    Write-ErrorLog "  Continuando ejecución del script..."
    Start-Sleep -Seconds $Delay
    # No salir con error, continuar
}
# --

# 5. Reiniciar el equipo
# ----------------------------------------------------------------
# Verificar si el reinicio automático está habilitado en la configuración
if (-not (Get-Variable -Name 'AutoRestart' -ErrorAction SilentlyContinue)) {
    # Variable no definida en config, preguntar al usuario
    $confirmation = Read-Host "¿Estás seguro de que deseas reiniciar el equipo? (S/N)"
    # Validar entrada del usuario
    while ($confirmation -ne 'S' -and $confirmation -ne 'N') {
        Write-Host "Opción no válida. Por favor, introduce 'S' para Sí o 'N' para No." -ForegroundColor Yellow
        Write-ErrorLog "Registro de opción no válida: $confirmation"
        $confirmation = Read-Host "¿Estás seguro de que deseas reiniciar el equipo? (S/N)"
    }
} else {
    # Usar la configuración predefinida
    $confirmation = if ($AutoRestart) { 'S' } else { 'N' }
    Write-Host "Reinicio automático configurado: $(if ($AutoRestart) { 'Sí' } else { 'No' })" -ForegroundColor Cyan
    Write-SuccessLog "Modo de reinicio automático configurado: $($confirmation)"
}

# Verificar si se debe proceder con el reinicio
if ($confirmation -eq 'S') {
    Write-Host "Iniciando reinicio del sistema..." -ForegroundColor Yellow
    Write-SuccessLog "Iniciando reinicio del sistema para aplicar cambios"

    # Verificar que las tareas programadas se crearon correctamente antes de reiniciar
    $taskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "¡ADVERTENCIA! La tarea programada '$TaskName' no se encuentra." -ForegroundColor Red
        Write-ErrorLog "Advertencia pre-reinicio: Tarea programada '$TaskName' no encontrada"
        
        $forceRestart = Read-Host "¿Deseas continuar con el reinicio de todas formas? (S/N)"
        if ($forceRestart -ne 'S') {
            Write-Host "Reinicio cancelado." -ForegroundColor Yellow
            Write-ErrorLog "Reinicio cancelado - Tarea programada no encontrada"
            exit 0
        }
    }

    # Esperar antes de reiniciar
    Start-Sleep -Seconds $Delay

    # Reiniciar el equipo
    try {
        Restart-Computer -Force -ErrorAction Stop
    } catch {
        Write-Host "Error al intentar reiniciar el equipo: $_" -ForegroundColor Red
        Write-ErrorLog "Error al reiniciar el equipo: $_"
        exit 1
    }
} else {
    Write-Host "Reinicio cancelado por el usuario." -ForegroundColor Yellow
    Write-Host "Los cambios no serán aplicados hasta el reinicio del sistema!" -ForegroundColor Yellow
    Write-ErrorLog "Reinicio cancelado - Los cambios requieren reinicio para ser aplicados completamente"
    exit 0
}
# --

# Restablecer titulo de ventana al valor predeterminado
# ----------------------------------------------------------------
#
$Host.UI.RawUI.WindowTitle = $tituloPredeterminado
Write-SuccessLog "Script #2 finalizado."
Write-ErrorLog "Script #2 finalizado."

# Fin del script