# AutoConfigPS

> Sistema automatizado de configuración inicial para equipos Windows en ambientes corporativos

[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**AutoConfigPS** automatiza completamente la configuración de equipos Windows corporativos, incluyendo cambio de nombre, conexión Wi-Fi, unión al dominio e instalación de aplicaciones — de forma **desatendida**, reanudándose sola a través de los reinicios necesarios sin ninguna intervención manual.

> **v0.1.0 — Nueva arquitectura.** El proyecto pasó de una cadena de scripts
> encadenados por tareas programadas por fase a un **orquestador único con estado
> persistente**, que es siempre idempotente y nunca se bloquea esperando una tecla.
> Ver [Estructura del Proyecto](#-estructura-del-proyecto) y [Flujo de Ejecución](#-flujo-de-ejecución).
> Los scripts de la versión anterior (`Script0`-`Script4.ps1`) ya no están en el
> repositorio; el estado previo a esta migración quedó etiquetado como
> `v0.0.4-legacy` en git por si hace falta compararlo.

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Novedades v0.0.4](#-novedades-v004)
- [Requisitos](#-requisitos)
- [Inicio Rápido](#-inicio-rápido)
- [Configuración](#-configuración)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Flujo de Ejecución](#-flujo-de-ejecución)
- [Seguridad](#-seguridad)
- [Solución de Problemas](#-solución-de-problemas)
- [Changelog](#-changelog)
- [Licencia](#-licencia)

---

## ✨ Características

### Configuración Automatizada

- ✅ Cambio de nombre del equipo
- ✅ Configuración de red Wi-Fi (WPA2-PSK)
- ✅ Unión automática al dominio Active Directory
- ✅ Inicio de sesión automático temporal (desactivado al finalizar)
- ✅ Instalación masiva de aplicaciones (Winget + recursos de red)
- ✅ Sistema de logging robusto con rotación automática
- ✅ Tareas programadas para continuidad post-reinicio

### Seguridad (v0.0.4)

- 🔒 **Credenciales cifradas con DPAPI de Windows**
- 🔒 **Permisos restrictivos en archivos de log**
- 🔒 **Limpieza automática de variables sensibles en memoria**
- 🔒 **Validación de acceso a controlador de dominio**

### Robustez (v0.0.4)

- 🛡️ **Pre-validación de requisitos del sistema**
- 🛡️ **Validación completa de conectividad Wi-Fi**
- 🛡️ **Instalaciones con timeout configurables**
- 🛡️ **Detección y manejo de nombres duplicados**
- 🛡️ **Soporte para Unidades Organizacionales (OU)**
- 🛡️ **Resumen visual de instalaciones**

---

## 🆕 Novedades v0.0.4

### 🔐 Seguridad Mejorada

- **Credenciales cifradas**: Script `Setup-Credentials.ps1` para configurar credenciales usando DPAPI
- **Logs protegidos**: Permisos restrictivos (solo Administradores + SYSTEM)
- **Validación de DC**: Verifica acceso al controlador de dominio antes de unirse

### 🌐 Conectividad Robusta

- **Validación Wi-Fi completa**: IP, gateway, DNS
- **Reintentos inteligentes**: Hasta 5 intentos con delay configurable
- **3 métodos de detección de DC**: DNS SRV, DNS directo, nltest

### 📦 Instalaciones Mejoradas

- **Timeouts configurables**: Por defecto 300s (Winget), 600s (Network)
- **Validación de exit codes**: Detecta instalaciones exitosas y errores
- **Resumen visual**: Estadísticas y duración de cada instalación
- **Soporte para ID de Winget**: Evita ambigüedades

### ✅ Pre-validación

- **Script0.ps1**: Valida 8 requisitos antes de iniciar
  - Privilegios admin, PowerShell 5.1+, Wi-Fi, Winget
  - config.ps1, credenciales, espacio disco, conectividad
- **Instrucciones claras**: Para cada fallo detectado
- **Exit codes**: Bloquea inicio si faltan requisitos críticos

### 🏢 Active Directory

- **Soporte para OU**: Especifica OU de destino (`$OUPath`)
- **Nombres duplicados**: Detección automática y generación de nombre alternativo
- **Validación LDAP**: Sin requerir módulo ActiveDirectory

---

## 📋 Requisitos

### Sistema Operativo

- Windows 10 (1809+) o Windows 11
- PowerShell 5.1 o superior

### Permisos y Acceso

- **Privilegios de administrador local**
- **Usuario de dominio con permisos de unión a equipos**
- **Conectividad Wi-Fi** (o Ethernet)
- **Acceso a Internet** (para instalaciones de Winget)
- **Acceso a red corporativa** (para unión al dominio)

### Herramientas Opcionales

- **Winget** (Windows Package Manager) - para instalaciones desde repositorio
- **Recursos de red UNC** - para instalaciones personalizadas

---

## ⚠️ IMPORTANTE: Habilitar Ejecución de Scripts PowerShell

**PREREQUISITO OBLIGATORIO:** Por defecto, Windows **NO permite** la ejecución de scripts de PowerShell. Debes habilitarlo antes de usar AutoConfigPS.

### Verificar Estado Actual

```powershell
# Abrir PowerShell como Administrador y ejecutar:
Get-ExecutionPolicy
```

**Resultado esperado:**

- `Restricted` → ❌ Scripts bloqueados (configuración por defecto)
- `RemoteSigned` o `Unrestricted` → ✅ Scripts permitidos

### Habilitar Ejecución de Scripts

**Opción A: RemoteSigned (RECOMENDADO - Seguro)**  

```powershell
# Ejecutar en PowerShell como Administrador:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

- ✅ Permite scripts locales
- ✅ Requiere firma digital para scripts descargados
- ✅ Balance entre seguridad y funcionalidad
- ✅ **Recomendado para entornos corporativos**

**Opción B: Bypass (Para pruebas/desarrollo)**  

```powershell
# Ejecutar en PowerShell como Administrador:
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
```

- ⚠️ Permite todos los scripts sin restricción
- ⚠️ Menos seguro, solo para entornos de prueba
- ⚠️ NO recomendado para producción

**Opción C: Ejecución temporal (Sin cambiar configuración)**  

```powershell
# Ejecutar scripts con bypass temporal:
powershell -ExecutionPolicy Bypass -File .\init.bat
```

- ✅ No modifica configuración del sistema
- ✅ Solo aplica a esta ejecución
- ⚠️ Debes usar este comando cada vez

### Verificar Cambio

```powershell
Get-ExecutionPolicy
# Debe mostrar: RemoteSigned (o Bypass si elegiste Opción B)
```

### 🔒 Revertir Cambios (Opcional)

Si deseas restaurar la configuración por defecto después de usar AutoConfigPS:

```powershell
Set-ExecutionPolicy Restricted -Scope CurrentUser -Force
```

### 📖 Más Información sobre Políticas de Ejecución

| Política | Descripción | Seguridad | Uso Recomendado |
| -------- | ----------- | --------- | --------------- |
| `Restricted` | No permite ningún script | 🔒 Máxima | Por defecto en Windows |
| `RemoteSigned` | Scripts locales OK, remotos requieren firma | 🔒 Alta | **Producción/Corporativo** |
| `Unrestricted` | Todos los scripts, advierte sobre remotos | ⚠️ Media | Desarrollo |
| `Bypass` | Todos los scripts sin restricción | ❌ Baja | Solo pruebas |

**Referencia oficial:** [about_Execution_Policies - Microsoft Learn](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.core/about/about_execution_policies)

---

## 🚀 Inicio Rápido

### 1. Obtener el Proyecto en el Equipo de Destino

**Opción A (recomendada para equipos corporativos):** un Windows recién
instalado no trae `git` — no depender de instalarlo es justo el motivo por el
que todo el pipeline está escrito para PowerShell 5.1 sin módulos externos.
Descarga el `.zip` publicado en [GitHub Releases](../../releases) (lo genera
automáticamente `package-release.yml` en cada release) y descomprímelo, o copia
la carpeta completa por USB/recurso de red:

```powershell
Expand-Archive -Path .\AutoConfigPS-vX.Y.Z.zip -DestinationPath C:\AutoConfigPS
```

**Opción B (equipo de desarrollo, con git instalado):**

```bash
git clone https://github.com/usuario/AutoConfigPS.git
cd AutoConfigPS
```

### 2. Configurar Credenciales (Recomendado - Seguro)

```powershell
# IMPORTANTE: Abrir PowerShell como ADMINISTRADOR
# Verificar que ExecutionPolicy esté habilitada (ver sección anterior)

# Ejecutar asistente de credenciales:
.\scripts\Setup-Credentials.ps1
```

Sigue el asistente interactivo para configurar:

- Credenciales de dominio (obligatorio)
- Credenciales de usuario local (opcional)
- Contraseña de Wi-Fi (recomendado)

**Nota:** Si obtienes error de "no se puede cargar el archivo", verifica que ejecutaste `Set-ExecutionPolicy RemoteSigned` como se indica arriba.

### 3. Crear config.ps1

```powershell
# Copiar plantilla
Copy-Item .\example-config.ps1 .\config.ps1

# Editar con tu editor favorito
notepad .\config.ps1
```

### 4. Configurar Parámetros Básicos

Edita `config.ps1` con tu configuración:

```powershell
# Dominio y equipo
$DomainName = "empresa.local"
$HostName = "PC-VENTAS-01"
$ScriptPath = "C:\AutoConfigPS\scripts"

# SSID de red Wi-Fi
$NetworkSSID = "RedCorporativa"

# OU de destino (opcional)
$OUPath = "OU=Workstations,OU=Equipos,DC=empresa,DC=local"
```

### 5. Ejecutar

```batch
# Clic derecho en init.bat > "Ejecutar como administrador"
# O desde CMD/PowerShell ya elevado:
.\init.bat
```

`init.bat` eleva privilegios y lanza `Invoke-AutoConfigPS.ps1`, el orquestador único.
A partir de ahí todo el proceso es automático, incluidos los reinicios necesarios:

1. ✅ Valida requisitos del sistema (una sola vez, en el primer arranque)
2. ⚙️ Configura Wi-Fi
3. 🏷️ Cambia el nombre del equipo → 🔄 reinicia y **retoma solo**
4. 🏢 Une al dominio → 🔄 reinicia y **retoma solo**
5. 📦 Instala aplicaciones
6. ✅ Finaliza y notifica al usuario en su próximo inicio de sesión

No hace falta volver a ejecutar nada manualmente entre reinicios: una tarea
programada (`AutoConfigPS-Orchestrator`) retoma el proceso automáticamente en el
punto exacto donde quedó, y se elimina sola al terminar.

---

## ⚙️ Configuración

### Configuración de Credenciales

#### Opción A: Credenciales Cifradas (Recomendado)

```powershell
# 1. Ejecutar asistente
.\scripts\Setup-Credentials.ps1

# 2. Editar config.ps1 y descomentar líneas de credenciales cifradas
$DomainCredPath = ".\SecureConfig\cred_domain.json"
# Las credenciales se cargan automáticamente con SecureCredentialManager.ps1
```

#### Opción B: Texto Plano (No Recomendado)

```powershell
# config.ps1
$Useradmin = "admin"
$Passadmin = "P@ssw0rd"
```

### Configuración de Aplicaciones

#### Opción 1: En config.ps1

```powershell
$apps = @(
    @{
        Name = "Google Chrome"
        Source = "Winget"
        ID = "Google.Chrome"
        Timeout = 300
    },
    @{
        Name = "Microsoft Office"
        Source = "Network"
        Path = "\\servidor\instaladores\Office2021.exe"
        Arguments = "/silent /norestart"
        Timeout = 900
    }
)
```

#### Opción 2: En apps.json

```json
[
  {
    "Name": "Google Chrome",
    "Source": "Winget",
    "ID": "Google.Chrome",
    "Timeout": 300
  },
  {
    "Name": "Adobe Acrobat Reader",
    "Source": "Winget",
    "ID": "Adobe.Acrobat.Reader.64-bit",
    "Timeout": 360
  }
]
```

**Campos disponibles:**

- `Name` (obligatorio): Nombre de la aplicación
- `Source` (obligatorio): `"Winget"` o `"Network"`
- `ID` (opcional): ID específico de Winget
- `Path` (obligatorio para Network): Ruta UNC al instalador
- `Arguments` (opcional para Network): Argumentos de instalación (default `/silent`)
- `Timeout` (opcional): Timeout en segundos (default 300 para Winget, 600 para Network)

### Configuración de OU (Opcional)

```powershell
# config.ps1
$OUPath = "OU=Workstations,OU=IT,DC=empresa,DC=local"
```

Si no se define, el equipo se une al contenedor "Computers" predeterminado.

---

## 📁 Estructura del Proyecto

```structure
AutoConfigPS/
├── Invoke-AutoConfigPS.ps1     # Orquestador único: punto de entrada de todo el pipeline
│
├── modules/
│   ├── Logging.ps1             # Logging centralizado (antes duplicado en cada script)
│   ├── StateMachine.ps1        # Estado persistente en C:\ProgramData\AutoConfigPS\state.json
│   ├── Preflight.ps1           # Validación de requisitos (antes Script0.ps1)
│   └── CredentialStore.ps1     # Gestión de credenciales cifradas (AES-256)
│
├── steps/                      # Un archivo por paso del pipeline, cada uno idempotente
│   ├── Step-ConfigureWifi.ps1
│   ├── Step-RenameComputer.ps1
│   ├── Step-JoinDomain.ps1
│   ├── Step-InstallApps.ps1
│   ├── Step-Finalize.ps1
│   └── Show-Notification.ps1   # Notificación al usuario (tarea AtLogOn, no SYSTEM)
│
├── scripts/
│   └── Setup-Credentials.ps1   # Asistente interactivo de credenciales cifradas
│
├── config.ps1                  # Configuración principal (crear desde example)
├── apps.json                   # Lista de aplicaciones (opcional)
│
├── example-config.ps1          # Plantilla de configuración
├── example-apps.json           # Plantilla de aplicaciones
│
├── init.bat                    # Eleva privilegios y lanza el orquestador
├── PSScriptAnalyzerSettings.psd1  # Reglas excluidas del lint (con motivo documentado)
├── .github/workflows/          # CI: sintaxis PS5.1 real + BOM + lint (push/PR), empaquetado (release)
├── README.md                   # Esta documentación
├── CHANGELOG.md                # Historial de cambios
├── GUIA_PRUEBAS.md             # Guía de pruebas piloto en hardware real
└── LICENSE                     # Licencia MIT
```

Cada paso en `steps/` sigue el mismo contrato: recibe la configuración ya cargada,
comprueba si su trabajo ya está hecho (idempotencia) y devuelve `Success`, `Skipped`,
`RebootRequired` o `Failed`. El orquestador es el único que decide qué hacer con ese
resultado (reintentar, reiniciar o detener el pipeline) — ningún paso reinicia el
equipo ni pide confirmación por sí mismo.

---

## 🔄 Flujo de Ejecución

```diagram
+-----------------------------------------------------------------+
|        init.bat  ->  Invoke-AutoConfigPS.ps1 (elevado)          |
+----------------------------------+-------------------------------+
                                    |
                                    v  (solo la primera vez: no existe state.json)
+-------------------------------------------------------------------+
|  PRE-VALIDACION (modules/Preflight.ps1)                            |
|  - Privilegios admin - PowerShell 5.1+ - Wi-Fi - config.ps1        |
|  - Winget, credenciales, espacio, conectividad (informativos)      |
+----------------------------------+---------------------------------+
                                    | Si pasa: registra la tarea unica
                                    | 'AutoConfigPS-Orchestrator' (AtStartup, SYSTEM)
                                    v
        +-------------------------------------------------------+
        |   BUCLE DEL ORQUESTADOR (idempotente, sin              |
        |   Read-Host en ningun punto)                           |
        |                                                         |
        |   Por cada paso pendiente en state.json:                |
        |     - Si ya esta hecho -> Skipped, sigue                |
        |     - Ejecuta el paso (con reintentos acotados)         |
        |     - Failed sin mas reintentos -> detiene todo el      |
        |       pipeline y sale (no se reprograma solo)           |
        |     - RebootRequired -> guarda estado y reinicia        |
        |       (o espera reinicio manual si $AutoRestart=$false) |
        +-------------------------------------------------------+
                                    |
   1/5 ConfigureWifi  ------------- conecta y valida IP/gateway/DNS
   2/5 RenameComputer ------------- autologin local opcional + rename -> reinicia
   3/5 JoinDomain     ------------- valida DC, evita nombres duplicados,
                                    une al dominio (con OU opcional) -> reinicia
   4/5 InstallApps    ------------- desactiva autologin, instala Winget/Network
                                    con timeout; no detiene el flujo por app
   5/5 Finalize       ------------- archivo de confirmacion + tarea AtLogOn que
                                    notifica al usuario y se autoelimina
                                    |
                                    v
        state.json: Status = Completed
        tarea 'AutoConfigPS-Orchestrator' se autoelimina
                                    |
                                    v
                            CONFIGURACION
                             COMPLETADA
```

La tarea programada unica retoma el mismo `Invoke-AutoConfigPS.ps1` tras cada
reinicio -- no hay una tarea distinta por fase ni scripts que "adivinen" en que paso
quedaron: todo el progreso vive en `C:\ProgramData\AutoConfigPS\state.json`.

**Tiempo estimado:** 20-40 minutos (dependiendo del número de aplicaciones)

---

## 🔒 Seguridad

### Credenciales Cifradas

Las credenciales se cifran con **AES-256** (`modules/CredentialStore.ps1`), no con
DPAPI: DPAPI en modo usuario no es legible por la cuenta **SYSTEM**, que es quien
ejecuta el pipeline de forma desatendida tras cada reinicio.

- ✅ Clave AES de 256 bits generada una vez por equipo (`SecureConfig\.aeskey`)
- ✅ No requiere gestión manual de claves
- ✅ Almacenamiento en `SecureConfig/` con permisos NTFS restrictivos (Administrators + SYSTEM)
- ⚠️ La protección depende de esas ACL: cualquier administrador local del equipo
  puede descifrar las credenciales, no solo el usuario que las creó. Es una
  protección contra lectura casual del disco, no un secreto por-usuario como DPAPI.

**Configurar:**

```powershell
.\scripts\Setup-Credentials.ps1
```

### Permisos de Archivos de Log

Los archivos de log tienen permisos restrictivos:

- Solo **Administrators** y **SYSTEM** pueden leer/escribir
- Previene exposición de información sensible
- Logs no modificables por usuarios estándar

### Limpieza de Memoria

Las variables con contraseñas se limpian explícitamente:

```powershell
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
Remove-Variable -Name PlainTextPassword
```

### Recomendaciones

1. ✅ **Usar credenciales cifradas** (ejecutar Setup-Credentials.ps1)
2. ✅ **Mantener config.ps1 en .gitignore** (no versionar credenciales)
3. ✅ **Usar OU con GPOs restrictivas** para equipos nuevos
4. ✅ **Revisar logs** después de cada ejecución
5. ✅ **Ejecutar desde recurso de red** con permisos limitados

---

## 🔧 Solución de Problemas

### ⚠️ ERROR: "No se puede cargar el archivo... está deshabilitada la ejecución de scripts"

**Problema:** Al ejecutar cualquier script de PowerShell obtienes error similar a:

```text
No se puede cargar el archivo C:\AutoConfigPS\Invoke-AutoConfigPS.ps1 porque
la ejecución de scripts está deshabilitada en este sistema.
```

**Causa:** Política de ejecución de PowerShell está en `Restricted` (configuración por defecto de Windows)

**Solución:**

```powershell
# Abrir PowerShell como Administrador y ejecutar:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Verificar cambio:
Get-ExecutionPolicy
# Debe mostrar: RemoteSigned
```

**Más información:** Ver sección [Habilitar Ejecución de Scripts PowerShell](#️-importante-habilitar-ejecución-de-scripts-powershell) al inicio de este README.

---

### Falla la pre-validación (primer arranque)

**Problema:** Alguna validación crítica falla y el pipeline no llega a iniciar.

**Soluciones:**

- **Sin privilegios admin**: Ejecutar `init.bat` como administrador
- **PowerShell < 5.1**: Actualizar desde <https://aka.ms/powershell-release>
- **Sin Wi-Fi**: Si usas Ethernet, el paso `ConfigureWifi` fallará; puedes marcarlo
  como completado a mano en `C:\ProgramData\AutoConfigPS\state.json` si no aplica.
- **config.ps1 no existe**: Copiar `example-config.ps1` a `config.ps1`
- **Sin Winget**: Instalar desde Microsoft Store (App Installer)

### Paso `ConfigureWifi` - Falla Conexión Wi-Fi

**Problema:** No se puede conectar a Wi-Fi

**Soluciones:**

1. Verificar SSID y contraseña en config.ps1
2. Verificar que el perfil Wi-Fi no exista previamente:

   ```powershell
   netsh wlan show profiles
   netsh wlan delete profile name="RedCorporativa"
   ```

3. Verificar que el adaptador Wi-Fi esté habilitado:

   ```powershell
   Get-NetAdapter | Where-Object {$_.InterfaceDescription -match "Wi-Fi"}
   ```

4. Revisar logs en `C:\Logs\setup_errors.log`. El paso reintenta automáticamente
   hasta `$MaxStepAttempts` veces (config.ps1) antes de detener el pipeline.

### Paso `JoinDomain` - Falla Unión al Dominio

**Problema:** No se puede unir al dominio

**Soluciones:**

1. **Error "DC no encontrado"**:
   - Verificar conectividad: `Test-Connection -ComputerName dominio.local`
   - Verificar DNS: `nslookup dominio.local`
   - Verificar DC: `nltest /dsgetdc:dominio.local`

2. **Error "Acceso denegado"**:
   - Verificar credenciales de dominio en config.ps1
   - Verificar permisos del usuario para unir equipos al dominio

3. **Error "Nombre duplicado"**:
   - El paso detecta automáticamente el conflicto y usa un nombre alternativo
     (`<HostName>-NNN`) SOLO para la unión al dominio; nunca vuelve a forzar el
     `$HostName` original ya identificado como duplicado.
   - Si no se pudo generar alternativo, el paso falla de forma definitiva
     (no reintenta) e indica que cambies `$HostName` en config.ps1 manualmente.

4. **Error de OU**:
   - Verificar que la OU exista: Abrir "Active Directory Users and Computers"
   - Verificar formato del DN: `OU=Workstations,DC=empresa,DC=local`
   - Verificar permisos del usuario en la OU

### Paso `InstallApps` - Fallan Instalaciones

**Problema:** Instalaciones de aplicaciones fallan o timeout

**Soluciones:**

1. **Timeout de Winget**:
   - Aumentar timeout en config.ps1 o apps.json: `"Timeout": 600`
   - Verificar conectividad a Internet
   - Verificar fuentes de Winget: `winget source list`

2. **App no encontrada en Winget**:
   - Buscar ID exacto: `winget search "nombre app"`
   - Usar campo `ID` en configuración: `"ID": "Google.Chrome"`

3. **Instalación desde red falla**:
   - Verificar acceso a ruta UNC: `Test-Path \\servidor\instaladores\app.exe`
   - Verificar permisos del usuario de dominio
   - Verificar que el instalador sea silencioso

4. **Revisar resumen**:
   - El paso muestra un resumen con apps exitosas/fallidas al terminar
   - Los fallos de apps individuales NO detienen el pipeline (se reportan, nada más)
   - Revisar logs: `C:\Logs\setup_errors.log`

### El pipeline quedó en estado `Failed`

**Problema:** Un paso agotó sus reintentos (`$MaxStepAttempts`) y el pipeline se
detuvo. La tarea programada `AutoConfigPS-Orchestrator` se elimina automáticamente
en este caso (para no reintentar en cada arranque futuro sin que nadie lo note).

**Solución:**

1. Revisa `C:\Logs\setup_errors.log` para el motivo exacto.
2. Corrige el problema (credenciales, config.ps1, conectividad, etc.).
3. Vuelve a ejecutar `.\Invoke-AutoConfigPS.ps1` manualmente (elevado): retoma
   exactamente en el paso que falló, sin repetir los pasos ya completados.

### Logs y Diagnóstico

**Ubicación de logs:**

- `C:\Logs\setup_success.log` - Operaciones exitosas
- `C:\Logs\setup_errors.log` - Errores y advertencias

**Rotación automática:** Archivos mayores a 10MB se renombran automáticamente

**Revisar logs:**

```powershell
# Ver últimas 50 líneas de errores
Get-Content C:\Logs\setup_errors.log -Tail 50

# Buscar errores específicos
Select-String -Path C:\Logs\setup_errors.log -Pattern "Error"

# Ver todo el log de éxito
notepad C:\Logs\setup_success.log
```

### Problemas Comunes

| Problema | Causa | Solución |
| -------- | ----- | -------- |
| **"Ejecución de scripts deshabilitada"** | ExecutionPolicy en Restricted | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` |
| Script no inicia | Sin privilegios admin | Ejecutar como admin |
| Wi-Fi no conecta | SSID/contraseña incorrecta | Verificar config.ps1 |
| Unión al dominio falla | Sin conectividad a DC | Verificar red y DNS |
| Winget no funciona | No instalado | Instalar desde Microsoft Store |
| Instalación cuelga | Sin timeout | Configurable por app en `apps.json`/config.ps1 |
| Nombre duplicado causa error | Equipo ya existe en AD | Se resuelve automáticamente (paso `JoinDomain`) |
| Pipeline no retoma tras reiniciar | Tarea `AutoConfigPS-Orchestrator` no registrada | Revisa `Get-ScheduledTask -TaskName AutoConfigPS-Orchestrator`; vuelve a ejecutar `Invoke-AutoConfigPS.ps1` manualmente |

---

## 📊 Changelog

Ver [CHANGELOG.md](CHANGELOG.md) para el historial completo de cambios.

### Versiones

- **v0.1.0** (2026-07-24) - Nueva arquitectura: orquestador único desatendido
  - 🏗️ Reemplaza la cadena `Script0`-`Script4` (tareas programadas por fase) por
    `Invoke-AutoConfigPS.ps1`: un orquestador único, idempotente, con estado
    persistente en `C:\ProgramData\AutoConfigPS\state.json`
  - 🚫 Elimina todos los `Read-Host` de la ruta desatendida (causaban cuelgues
    indefinidos al ejecutarse como SYSTEM sin sesión interactiva)
  - 🐛 Corrige el bug por el que la unión al dominio revertía un nombre
    alternativo ya resuelto de vuelta al nombre original duplicado
  - 🔔 La notificación final ya no depende de UI lanzada desde SYSTEM (Sesión 0):
    se muestra vía una tarea `AtLogOn` que se autoelimina
  - 🧩 Logging, credenciales y validaciones previas consolidados en `modules/`
    (antes duplicados en cada script)
  - 🔡 Todos los `.ps1` activos se guardan con BOM UTF-8 para prevenir errores
    de parsing por codificación en equipos con code page distinto a UTF-8
  - 📦 Scripts v0.0.4 y documentación de hotfixes puntuales ya incorporados al
    código retirados del repositorio (recuperables con el tag git `v0.0.4-legacy`)

- **v0.0.4** (2026-01-28) - Seguridad y robustez
  - 🔒 Credenciales cifradas con DPAPI
  - 🛡️ Pre-validación de requisitos
  - ⏱️ Instalaciones con timeout
  - 🏢 Soporte para OU y nombres duplicados
  - 🌐 Validación completa de conectividad

- **v0.0.3** (2025-03-06) - Correcciones y mejoras
  - Corregidos errores de tipeo
  - Mejorados mensajes de conexión Wi-Fi
  - Compatibilidad con PowerShell 5.1

- **v0.0.2** (2025-03-01) - Reintentos y refactorización
  - Implementados reintentos de conexión Wi-Fi
  - Actualización de fuentes de Winget

- **v0.0.1** (2025-02-28) - Versión inicial
  - Scripts básicos de configuración
  - Soporte para Winget y recursos de red

---

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

## 👤 Autor

**Json Rivera (JasRockr!)**  

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📞 Soporte

- 📝 **Issues**: [GitHub Issues](https://github.com/usuario/AutoConfigPS/issues)
- 📖 **Guía de pruebas piloto**: Ver [GUIA_PRUEBAS.md](GUIA_PRUEBAS.md)

---

## ⚠️ Advertencias

- ⚠️ Este script realiza cambios significativos en el sistema (renombre, unión a dominio, instalaciones)
- ⚠️ **Probar primero en ambiente de pruebas** antes de usar en producción
- ⚠️ Mantener `config.ps1` seguro y no versionarlo con credenciales
- ⚠️ Revisar logs después de cada ejecución
- ⚠️ Las credenciales cifradas solo funcionan en el equipo donde se crearon

---

**🎉 ¡Disfruta de la automatización con AutoConfigPS v0.0.4!**