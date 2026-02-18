# Corrección: Gestión de Rutas en Archivos de Credenciales

## 📋 Problema Identificado

El script de diagnóstico no detectaba los archivos de credenciales ni el directorio `SecureConfig` a pesar de que existían físicamente.

**Causa raíz:** Uso inconsistente de rutas relativas vs. absolutas.

## 🔍 Análisis del Proyecto

### Patrón Correcto en Scripts del Proyecto

**Scripts dentro de `scripts/` (suben un nivel):**

```powershell
# Setup-Credentials.ps1, Script0.ps1, etc.
$SecureConfigPath = "$PSScriptRoot\..\SecureConfig"
```

**Scripts en la raíz del proyecto:**

```powershell
# config.ps1
$keyPath = "$PSScriptRoot\SecureConfig\.aeskey"
$DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.json"
```

**Método robusto para determinar ubicación:**

```powershell
# Usado en Script1.ps1, Script2.ps1, etc.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
```

### ❌ Problema en Archivos con Rutas Relativas

```powershell
# INCORRECTO - Depende del directorio de trabajo actual
$SecureConfigPath = ".\SecureConfig"
$DomainCredPath = ".\SecureConfig\cred_domain.json"
```

**Comportamiento problemático:**

- ✅ Funciona si ejecutas desde: `C:\AutoConfigPS\`
- ❌ Falla si ejecutas desde: `C:\Users\Admin\` o cualquier otro directorio
- ❌ Falla si el script se invoca remotamente
- ❌ Falla en tareas programadas con diferente working directory

## ✅ Correcciones Implementadas

### 1. DIAGNOSTICO_CREDENCIALES.ps1

**Antes:**

```powershell
$SecureConfigPath = ".\SecureConfig"
$files = @(
    "$SecureConfigPath\cred_domain.json",
    ...
)
```

**Después:**

```powershell
# Determinar rutas de forma robusta (igual que otros scripts del proyecto)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$SecureConfigPath = "$ScriptDir\SecureConfig"

Write-Host "[i] Directorio del script: $ScriptDir" -ForegroundColor Gray
Write-Host "[i] Ruta SecureConfig: $SecureConfigPath" -ForegroundColor Gray

$files = @(
    "$SecureConfigPath\cred_domain.json",
    "$SecureConfigPath\cred_local.json",
    "$SecureConfigPath\cred_wifi.json",
    "$SecureConfigPath\.aeskey"
)
```

### 2. config.ps1

**Antes:**

```powershell
$DomainCredPath = ".\SecureConfig\cred_domain.json"
$LocalCredPath = ".\SecureConfig\cred_local.json"
$WifiCredPath = ".\SecureConfig\cred_wifi.json"
```

**Después:**

```powershell
$DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.json"
$LocalCredPath = "$PSScriptRoot\SecureConfig\cred_local.json"
$WifiCredPath = "$PSScriptRoot\SecureConfig\cred_wifi.json"

# + Debug logging adicional
Add-Content -Path $debugLog -Value "[LOG][$timestamp] [DEBUG-CONFIG] PSScriptRoot: $PSScriptRoot" -ErrorAction SilentlyContinue
```

### 3. example-config.ps1

**Antes:**

```powershell
# $DomainCredPath = ".\SecureConfig\cred_domain.json"
# $LocalCredPath = ".\SecureConfig\cred_local.json"
# $WifiCredPath = ".\SecureConfig\cred_wifi.json"
```

**Después:**

```powershell
# Importar módulo de gestión segura de credenciales
# . "$PSScriptRoot\scripts\SecureCredentialManager.ps1"
# 
# Cargar clave AES compartida
# $keyPath = "$PSScriptRoot\SecureConfig\.aeskey"
# $aesKey = [System.IO.File]::ReadAllBytes($keyPath)
# 
# Credenciales de dominio
# $DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.json"
# $DomainCredential = Import-SecureCredential -Path $DomainCredPath -Key $aesKey
# $Useradmin = $DomainCredential.UserName
# $SecurePassadmin = $DomainCredential.Password
```

## 🎯 Beneficios

### Antes de la Corrección

```text
Usuario ejecuta desde: C:\Users\Admin\Desktop\
Script busca: C:\Users\Admin\Desktop\SecureConfig\
Resultado: ❌ No encuentra los archivos
```

### Después de la Corrección

```powershell
Script está en: C:\AutoConfigPS\DIAGNOSTICO_CREDENCIALES.ps1
$PSScriptRoot = C:\AutoConfigPS
$SecureConfigPath = C:\AutoConfigPS\SecureConfig\
Resultado: ✅ Encuentra los archivos SIEMPRE
```

## 📝 Reglas de Rutas en el Proyecto

### ✅ RECOMENDADO - Usar `$PSScriptRoot`

```powershell
# Para scripts en la raíz del proyecto
$SecureConfigPath = "$PSScriptRoot\SecureConfig"
$ConfigPath = "$PSScriptRoot\config.ps1"

# Para scripts dentro de subcarpetas (scripts/)
$SecureConfigPath = "$PSScriptRoot\..\SecureConfig"
$ConfigPath = "$PSScriptRoot\..\config.ps1"

# Robusto para tareas programadas
$ScriptDir = if ($PSScriptRoot) { 
    $PSScriptRoot 
} else { 
    Split-Path -Parent $MyInvocation.MyCommand.Path 
}
```

### ❌ EVITAR - Rutas relativas al directorio actual

```powershell
# NO USAR - Depende de Get-Location
$SecureConfigPath = ".\SecureConfig"
$ConfigPath = ".\config.ps1"
```

### ⚠️ ACEPTABLE - Con cambio explícito de directorio

```powershell
# Usado en Script1.ps1, Script2.ps1, etc.
# Solo cuando se cambia directorio explícitamente
Set-Location -Path $ProjectRoot
. $ConfigPath  # Ahora las rutas relativas en config.ps1 funcionan
```

## 🧪 Verificación en Equipo de Pruebas

Después del pull, ejecutar:

```powershell
# 1. Verificar que el diagnóstico funciona desde cualquier ubicación
cd C:\
C:\AutoConfigPS\DIAGNOSTICO_CREDENCIALES.ps1

# 2. Debería mostrar:
# [i] Directorio del script: C:\AutoConfigPS
# [i] Ruta SecureConfig: C:\AutoConfigPS\SecureConfig
# Verificando: cred_domain.json
#   [OK] Archivo existe...

# 3. Ejecutar desde la carpeta del proyecto
cd C:\AutoConfigPS
.\DIAGNOSTICO_CREDENCIALES.ps1

# 4. Regenerar credenciales (usará rutas corregidas)
.\scripts\Setup-Credentials.ps1

# 5. Probar configuración
.\init.bat
```

## 📊 Resumen de Cambios

| Archivo | Líneas Modificadas | Cambio |
| ------- | ----------------- | ------ |
| DIAGNOSTICO_CREDENCIALES.ps1 | 14-22 | Agregado manejo robusto de rutas con `$PSScriptRoot` |
| config.ps1 | 60, 73, 114, 143 | Cambiado `.\SecureConfig\*` → `$PSScriptRoot\SecureConfig\*` |
| example-config.ps1 | 50-52, 66-72, 91-95 | Actualizado ejemplo con patrón correcto |

## 🔄 Consistencia Lograda

Ahora **TODOS** los archivos del proyecto usan el mismo patrón:

- ✅ Scripts en `scripts/`: `$PSScriptRoot\..\SecureConfig`
- ✅ Scripts en raíz: `$PSScriptRoot\SecureConfig`
- ✅ Funcionan independientemente del directorio de ejecución
- ✅ Compatibles con tareas programadas
- ✅ Rutas absolutas basadas en ubicación del script

---

**Fecha:** 18 de febrero de 2026  
**Versión:** 0.0.4.2  
**Tipo de cambio:** Corrección de bugs + Mejora de robustez
