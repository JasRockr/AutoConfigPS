# AutoConfigPS

> Sistema automatizado de configuración inicial para equipos Windows en ambientes corporativos

[![Estado](https://img.shields.io/badge/estado-beta%20validado%20en%20hardware-orange.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**AutoConfigPS** automatiza completamente la configuración de equipos Windows corporativos, incluyendo cambio de nombre, conexión Wi-Fi, unión al dominio e instalación de aplicaciones — de forma **desatendida**, reanudándose sola a través de los reinicios necesarios sin ninguna intervención manual.

> **Estado: beta.** El proyecto está construido sobre un **orquestador único con
> estado persistente**, siempre idempotente y que nunca se bloquea esperando una
> tecla — probado end-to-end en hardware real (Windows recién instalado uniéndose a
> un dominio corporativo). Ver [Estructura del Proyecto](#-estructura-del-proyecto)
> y [Flujo de Ejecución](#-flujo-de-ejecución).

---

## 📋 Tabla de Contenidos

- [Características](#-características)
- [Requisitos](#-requisitos)
- [Inicio Rápido](#-inicio-rápido)
- [Configuración](#-configuración)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Flujo de Ejecución](#-flujo-de-ejecución)
- [Seguridad](#-seguridad)
- [Solución de Problemas](#-solución-de-problemas)
- [Estado y cambios](#-estado-y-cambios)
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

### Seguridad

- 🔒 **Credenciales cifradas con AES-256** (clave local por equipo, legible por SYSTEM)
- 🔒 **Permisos restrictivos en archivos de log** (escritura solo Administrators + SYSTEM; lectura para usuarios estándar)
- 🔒 **Limpieza automática de variables sensibles en memoria**
- 🔒 **Validación de acceso a controlador de dominio**
- 🔒 **Limpieza final configurable** (`$CleanupOnFinish`): al terminar borra las credenciales cifradas, el estado y `config.ps1`; los logs se conservan siempre

### Robustez

- 🛡️ **Pre-validación de requisitos del sistema**
- 🛡️ **Conexión Wi-Fi sin depender de Servicios de Ubicación** (auto-connect por perfil, no `netsh`)
- 🛡️ **Instalaciones con timeout configurables** (se ejecutan en la sesión del usuario, no como SYSTEM)
- 🛡️ **Política configurable ante nombres duplicados en AD** (`$OnDuplicateName`: detener o alternativo)
- 🛡️ **Soporte para Unidades Organizacionales (OU)**
- 🛡️ **Ventana de estado en vivo** para el técnico durante todo el proceso
- 🛡️ **Resumen de instalaciones** (instaladas / omitidas / fallidas)

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

### 2. Ejecutar init.bat

```batch
# Doble clic en init.bat (se autoeleva solo, un unico prompt de UAC)
.\init.bat
```

`init.bat` es el único punto de entrada — no hace falta editar nada a mano de
antemano, ni ejecutarlo "como Administrador" manualmente: se autoeleva al
inicio (un solo prompt de UAC para toda la corrida) y todo lo que sigue —
incluida la verificación de si ya hay credenciales cargadas — corre con ese
mismo privilegio. En el primer arranque:

1. 🧙 **Si `config.ps1` no existe todavía**, lanza un asistente que te
   pide por consola los 3 valores mínimos (dominio, nombre del equipo, SSID de
   Wi-Fi) y genera `config.ps1` con eso — el resto de los parámetros (OU, lista
   de apps, timeouts) queda con su valor por defecto para que los ajuste
   después quien necesite algo más avanzado (ver [Configuración](#-configuración)).
2. 🔒 **Si faltan las credenciales cifradas**, el mismo asistente las pide a
   continuación (dominio, usuario local opcional, Wi-Fi) y las guarda cifradas
   con AES-256.
3. ⏳ Espera a que termines el asistente y recién ahí arranca el pipeline —
   nunca hace falta volver a correr nada a mano entre estos pasos.

A partir de ahí todo el proceso es automático, incluidos los reinicios necesarios:

1. ✅ Valida requisitos del sistema
2. ⚙️ Configura Wi-Fi
3. 🏷️ Cambia el nombre del equipo → 🔄 reinicia y **retoma solo**
4. 🏢 Une al dominio → 🔄 reinicia y **retoma solo**
5. 📦 Instala aplicaciones (en la sesión del usuario, no como SYSTEM)
6. ✅ Finaliza, muestra el resultado en la ventana de estado y limpia los artefactos del proceso

No hace falta volver a ejecutar nada manualmente entre reinicios: una tarea
programada (`AutoConfigPS-Orchestrator`) retoma el proceso automáticamente en el
punto exacto donde quedó, y se elimina sola al terminar. Si `config.ps1` y las
credenciales ya existen (por ejemplo, en una segunda corrida), `init.bat` se
salta el asistente por completo y va directo al pipeline.

### 3. (Opcional / usuarios avanzados) Configurar de antemano sin el asistente

Si preferís no usar los prompts interactivos — por ejemplo, para dejar varios
equipos listos sin supervisión, o para configurar de una `$OUPath` o la lista
de aplicaciones desde el principio — podés seguir el camino manual de siempre,
**antes** de correr `init.bat`:

```powershell
# 1. Copiar plantilla y editar
Copy-Item .\example-config.ps1 .\config.ps1
notepad .\config.ps1
```

```powershell
$DomainName = "empresa.local"
$HostName = "PC-VENTAS-01"
$NetworkSSID = "RedCorporativa"
$OUPath = "OU=Workstations,OU=Equipos,DC=empresa,DC=local"   # opcional
```

```powershell
# 2. Credenciales cifradas (requiere ADMINISTRADOR y ExecutionPolicy habilitada, ver arriba)
.\scripts\Setup-Credentials.ps1
```

Con `config.ps1` y las credenciales ya presentes, `init.bat` (paso 2) se salta
el asistente automáticamente y arranca el pipeline directo.

---

## ⚙️ Configuración

### Configuración de Credenciales

#### Opción A: Credenciales Cifradas (Recomendado, por defecto)

```powershell
# Ejecutar el asistente (o dejar que init.bat lo haga en el primer arranque)
.\scripts\Setup-Credentials.ps1
```

Genera `SecureConfig\` con la clave AES y las credenciales cifradas. `config.ps1`
las carga automáticamente vía `modules\CredentialStore.ps1` — es el comportamiento
por defecto de `example-config.ps1`, no hay que descomentar nada.

#### Opción B: Texto Plano (No Recomendado, solo pruebas)

En `config.ps1`, cada sección de credenciales trae comentada una "Opción B"; para
usarla, comentá el bloque de la Opción A correspondiente y descomentá el de la B:

```powershell
$Useradmin = "admin"
$Passadmin = "P@ssw0rd"
$SecurePassadmin = ConvertTo-SecureString $Passadmin -AsPlainText -Force
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

> **Instalación silenciosa por tipo de fuente:**
>
> - **Winget**: el modo silencioso lo maneja winget automáticamente (`--silent
>   --disable-interactivity`); no hay que configurar el flag por app — winget
>   conoce el modificador de cada paquete.
> - **Network**: el flag silencioso **varía por instalador** y no se puede
>   autodetectar de forma fiable, así que lo configurás vos en `Arguments`
>   (ej. `/S` NSIS, `/silent` InstallShield, `/qn` MSI, `-ms` otros). Si un
>   instalador **no soporta** modo silencioso (ej. FortiClient VPN), abrirá su
>   asistente y un técnico debe completarlo a mano — el proceso muestra un aviso
>   en la consola y en la ventana de estado indicándolo.

> **Sobre `Timeout` (segundos):** es el tiempo máximo que se espera a que un
> instalador termine antes de darlo por fallado y pasar a la siguiente app (no
> detiene el pipeline). No es un retardo fijo: si la app termina antes, se sigue de
> inmediato — poner un valor holgado no alarga la corrida, solo evita cortar una
> instalación lenta a mitad. Defínelo según el **tamaño de la app y la velocidad de
> red/disco**:
>
> - Apps chicas (Notepad++, 7-Zip): **120-180 s**
> - Apps medianas (Chrome, VS Code): **240-300 s**
> - Apps grandes (Acrobat, Office, runtimes): **600-900 s**
>
> Si no lo especificás, el default es 300 s (Winget) / 600 s (Network). Si en los
> logs ves que una app falló por *timeout* pero en realidad seguía instalando,
> **subí su `Timeout`** (fue exactamente el caso de Acrobat Reader → 600 s).

#### Encontrar el `ID` de una app de Winget y agregar apps a medida

El `ID` es el identificador exacto del paquete en Winget (ej. `Google.Chrome`,
`Microsoft.VisualStudioCode`). Usarlo en vez del `Name` evita ambigüedades cuando
varios paquetes coinciden por nombre. Dos formas de obtenerlo:

- **Catálogo web (recomendado para explorar):** [winstall.app](https://winstall.app/)
  es una biblioteca navegable de todos los paquetes del repositorio oficial de
  Winget (`winget-pkgs`). Buscá la app, abrí su ficha y copiá el **Package ID** —
  ese valor es el que va en el campo `ID`. Útil para que un técnico descubra qué
  hay disponible y arme una lista de apps a medida.
- **Línea de comandos (fuente autoritativa):** el propio Winget confirma el ID exacto
  y la disponibilidad:

  ```powershell
  winget search "nombre de la app"     # lista coincidencias con su Id
  winget show --id Google.Chrome       # verifica un Id concreto y sus detalles
  ```

Con el `ID` en mano, extender el instalador es agregar un objeto más a `apps.json`
(o a `$apps` en `config.ps1`):

```json
{
  "Name": "7-Zip",
  "Source": "Winget",
  "ID": "7zip.7zip",
  "Timeout": 180
}
```

> Nota: verificá que el paquete tenga un instalador silencioso soportado por Winget
> (la mayoría lo tiene). Para instaladores propios que no están en Winget, usá una
> entrada `"Source": "Network"` apuntando al `.exe`/`.msi` en tu recurso de red.

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
│   ├── Preflight.ps1           # Validación de requisitos previa al pipeline
│   └── CredentialStore.ps1     # Gestión de credenciales cifradas (AES-256)
│
├── steps/                      # Un archivo por paso del pipeline, cada uno idempotente
│   ├── Step-ConfigureWifi.ps1
│   ├── Step-RenameComputer.ps1
│   ├── Step-JoinDomain.ps1
│   ├── Step-InstallApps.ps1
│   ├── Step-Finalize.ps1
│   └── Show-Notification.ps1   # Ventana de estado en vivo (corre en la sesión del usuario)
│
├── scripts/
│   ├── Setup-Credentials.ps1   # Asistente interactivo (config + credenciales + apps)
│   └── Run-InstallAppsUser.ps1 # Runner que instala apps en la sesión del usuario
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
   1/5 ConfigureWifi  ------------- conecta al SSID corporativo por auto-connect
                                    (sin netsh/Ubicacion) y valida IP/gateway
   2/5 RenameComputer ------------- autologin local + rename -> reinicia
   3/5 JoinDomain     ------------- valida DC; si el nombre ya existe en AD aplica
                                    $OnDuplicateName (detener o alternativo);
                                    une al dominio (con OU opcional) -> reinicia
   4/5 InstallApps    ------------- desactiva autologin; instala Winget/Network en
                                    la sesion del usuario con timeout; no detiene
                                    el flujo por app
   5/5 Finalize       ------------- archivo de confirmacion; limpieza final
                                    ($CleanupOnFinish) si no hubo apps fallidas
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

Los archivos de log tienen permisos restrictivos (por SID, independiente del idioma del sistema):

- **Escritura** solo para **Administrators** y **SYSTEM**
- **Lectura** para usuarios estándar (`BUILTIN\Users:(R)`), para que el técnico pueda abrirlos
- Logs no modificables por usuarios estándar

### Limpieza Final (`$CleanupOnFinish`)

Al completar el pipeline **sin apps fallidas**, se eliminan los artefactos del proceso
que no aportan valor al equipo ya configurado y que representan un riesgo si quedan:

- `SecureConfig\` (credenciales cifradas + clave AES) — **el más importante por seguridad**
- `C:\ProgramData\AutoConfigPS\` (estado), `config.ps1`, `apps.json`, marcador de fin

Los **logs (`C:\Logs\*.log`) siempre se conservan** como auditoría. Con
`$CleanupOnFinish = $false` no se borra nada y el log deja registradas las rutas
exactas que quedaron, para borrarlas a mano tras la depuración. Si alguna app falló,
la limpieza se omite automáticamente para poder reintentar sin re-configurar.

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

3. **"Nombre duplicado" (equipo ya existe en AD)**:
   - Comportamiento según `$OnDuplicateName` en `config.ps1`:
     - `'Halt'` (por defecto): el paso se **detiene** (no auto-renombra ni limpia),
       loguea la causa y espera que un humano borre el objeto de equipo obsoleto en
       AD o cambie `$HostName`. Tras resolverlo, volvé a ejecutar `init.bat`.
     - `'Alternative'`: genera un nombre alternativo (`<HostName>-NNN`) y une con ese
       nombre (nunca revierte al original duplicado). Deja el objeto viejo en AD.

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
   - El share se autentica con las credenciales de dominio y el instalador se copia
     a un temporal local antes de ejecutarlo (resuelve rutas con espacios/permisos)
   - Verificar el flag silencioso en `Arguments` (varía por instalador; ver
     [Configuración de Aplicaciones](#configuración-de-aplicaciones)). Si el
     instalador no soporta silencioso, abrirá su asistente para completar a mano

4. **Revisar resumen**:
   - El paso muestra un resumen con apps **instaladas / omitidas / fallidas** al terminar
   - Los fallos de apps individuales NO detienen el pipeline (se reportan, nada más)
   - Si alguna app falla, la limpieza final se omite para conservar config/credenciales
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
| Nombre duplicado en AD | Equipo ya existe en AD | Por defecto (`$OnDuplicateName='Halt'`) se detiene; borrá el objeto en AD o cambiá `$HostName` y re-ejecutá `init.bat` |
| Pipeline no retoma tras reiniciar | Tarea `AutoConfigPS-Orchestrator` no registrada | Revisa `Get-ScheduledTask -TaskName AutoConfigPS-Orchestrator`; vuelve a ejecutar `Invoke-AutoConfigPS.ps1` manualmente |

---

## 📊 Estado y cambios

Este es el **estado beta** del proyecto: el flujo completo fue validado
end-to-end en hardware real y es el punto de partida para pruebas beta más
amplias. Ver [CHANGELOG.md](CHANGELOG.md) para el resumen del conjunto de
funcionalidades validado.

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

**🎉 ¡Disfruta de la automatización con AutoConfigPS!**
