# 🧪 Guía de Pruebas Piloto - AutoConfigPS

**Documento para validar la nueva arquitectura (orquestador único) en hardware o VM real, antes de un despliegue en producción.**

---

## Tabla de Contenidos

1. [Objetivo y Alcance](#objetivo-y-alcance)
2. [Pre-requisitos](#pre-requisitos)
3. [Preparación del Entorno](#preparación-del-entorno)
4. [Procedimientos de Prueba](#procedimientos-de-prueba)
5. [Matriz de Casos de Prueba](#matriz-de-casos-de-prueba)
6. [Criterios de Aceptación](#criterios-de-aceptación)
7. [Diagnóstico](#diagnóstico)
8. [Rollback y Recuperación](#rollback-y-recuperación)
9. [Checklist de Aprobación](#checklist-de-aprobación)

---

## Objetivo y Alcance

Validar que `Invoke-AutoConfigPS.ps1` completa el pipeline completo (Wi-Fi → nombre
→ dominio → apps → finalización) de forma **desatendida**, incluyendo los reinicios
intermedios, sin quedar nunca bloqueado esperando entrada de teclado, y verificar
en concreto los tres problemas que motivaron el diseño desatendido:

1. Que ningún paso se cuelgue con un prompt cuando corre como SYSTEM sin sesión
   interactiva (reinicios entre pasos).
2. Que un nombre de equipo duplicado en AD se maneje según `$OnDuplicateName`: por
   defecto (`'Halt'`) el proceso se **detiene** sin auto-renombrar; en modo
   `'Alternative'` genera un nombre alternativo **y la unión al dominio realmente
   usa ese alternativo** (no el original).
3. Que la notificación al técnico funcione sin depender de UI lanzada desde el
   contexto SYSTEM (ventana de estado en vivo en la sesión del usuario).

**Equipos recomendados para el piloto:** mínimo 3 — 1 equipo limpio (caso normal),
1 equipo con un objeto de computadora pre-creado en AD con el mismo nombre que
`$HostName` (caso de nombre duplicado), 1 equipo para probar el camino de error
(credenciales de dominio incorrectas a propósito).

**Duración estimada:** medio día por equipo, incluyendo los reinicios.

---

## Pre-requisitos

### Infraestructura

- [ ] Controlador de dominio accesible desde la red de pruebas: `_________________`
- [ ] Usuario con permisos para unir equipos al dominio: `_________________`
- [ ] OU de destino (opcional): `_________________`
- [ ] SSID de red Wi-Fi de pruebas: `_________________` (WPA2-PSK)
- [ ] Winget funcional o acceso a un recurso de red con instaladores de prueba

### Equipos de prueba

- [ ] Windows 10 (1809+) o Windows 11, recién instalado o restaurado a snapshot
- [ ] Adaptador Wi-Fi funcional (o ajustar el paso `ConfigureWifi` si es por cable)
- [ ] 10 GB de espacio libre en disco
- [ ] Sin unir a dominio, sin ejecución previa de AutoConfigPS en ese equipo
- [ ] **Recomendado:** VM restaurable a snapshot — el pipeline reinicia el equipo
  dos veces y une al dominio, así que cada corrida de prueba "gasta" el estado del
  equipo

### PowerShell

- [ ] Confirmar que la prueba corre sobre **Windows PowerShell 5.1** real (`$PSVersionTable.PSVersion`),
  no PowerShell 7.x — el código se escribió para 5.1 pero nunca se ejecutó sobre
  5.1 real durante el desarrollo (ver `CLAUDE.md`)

---

## Preparación del Entorno

### 1. Copiar el proyecto al equipo de prueba

```batch
REM Ubicación recomendada
C:\AutoConfigPS\
```

Checklist de la carpeta copiada:

- [ ] `Invoke-AutoConfigPS.ps1` en la raíz
- [ ] `modules\` con los 4 archivos (`Logging.ps1`, `StateMachine.ps1`, `Preflight.ps1`, `CredentialStore.ps1`)
- [ ] `steps\` con los 6 archivos (`Step-ConfigureWifi.ps1`, `Step-RenameComputer.ps1`, `Step-JoinDomain.ps1`, `Step-InstallApps.ps1`, `Step-Finalize.ps1`, `Show-Notification.ps1`)
- [ ] `scripts\` con `Setup-Credentials.ps1` y `Run-InstallAppsUser.ps1`
- [ ] `init.bat`, `example-config.ps1`, `example-apps.json`

### 2. Configuración inicial: config.ps1 y credenciales cifradas

**Esto es automático:** al ejecutar `init.bat` (Prueba 1), si
`config.ps1` no existe todavía, lanza un asistente elevado (`scripts\Setup-Credentials.ps1`)
que primero pide por consola `$DomainName`, `$HostName` y `$NetworkSSID` y
genera `config.ps1` con esos valores, y a continuación pide las credenciales
(dominio, usuario local opcional, Wi-Fi). Espera (`-Wait`) a que termines todo
el asistente antes de seguir con la pre-validación del orquestador. No hace
falta editar nada a mano — se puede pasar directo a la Prueba 1.

`$AutoRestart`, `$MaxStepAttempts` y `$StepRetryDelaySeconds` no los pide el
asistente a propósito (quedan con su valor por defecto en `example-config.ps1`,
ya pensados para desatendido: `$AutoRestart = $true`) — son parámetros
avanzados para quien necesite ajustarlos, no parte del mínimo viable.

**Caso de prueba específico para el flujo automático (recomendado probarlo al
menos una vez, es la parte menos probada del diseño):** dejar `config.ps1` y
`SecureConfig\` sin crear y arrancar directo con la Prueba 1 — verificar que
el asistente pide primero los 3 valores básicos (con reintento si el nombre de
equipo supera 15 caracteres o el dominio no tiene forma de FQDN), genera
`config.ps1` correctamente, y recién después pide las credenciales.

- [ ] `config.ps1` se genera con `$DomainName`/`$HostName`/`$NetworkSSID` correctos (revisar el archivo)
- [ ] Reintenta si el nombre de equipo ingresado supera 15 caracteres o tiene espacios/caracteres inválidos
- [ ] Se crea `SecureConfig\.aeskey`, `cred_domain.json`, `cred_wifi.json` (y `cred_local.json` si se configuró autologin local opcional)
- [ ] Verificar permisos: `icacls C:\AutoConfigPS\SecureConfig` debe mostrar solo `BUILTIN\Administrators` y `NT AUTHORITY\SYSTEM`

**Alternativa manual** (si preferís no usar los prompts, o necesitás `$OUPath`/`apps.json`/otros parámetros avanzados desde el principio) — hacerlo *antes* de correr `init.bat`, que entonces se salta el asistente por completo:

```powershell
cd C:\AutoConfigPS
Copy-Item .\example-config.ps1 .\config.ps1
notepad .\config.ps1
.\scripts\Setup-Credentials.ps1
```

### 4. (Opcional) `apps.json` con 1-2 apps ligeras para no alargar la prueba

```powershell
Copy-Item .\example-apps.json .\apps.json
```

---

## Procedimientos de Prueba

### Prueba 1 — Primer arranque y pre-validación

```batch
REM Clic derecho > Ejecutar como administrador
init.bat
```

**Verificar:**

- [ ] `init.bat` pide UAC **una sola vez**, al principio (auto-elevación con
  `net session` + relanzarse con `-Verb RunAs`) — no dos ni tres veces
- [ ] Si `config.ps1` no existe, lanza `scripts\Setup-Credentials.ps1` **en la
  misma consola ya elevada** (sin ventana aparte, sin pedir UAC de nuevo), que
  pide primero dominio/nombre de equipo/SSID (Paso 0, genera `config.ps1`) y
  después las credenciales (Pasos 1-3)
- [ ] **Caso crítico (bug real ya encontrado y corregido):** completar el
  asistente con datos válidos hasta el final → `init.bat` debe reconocer el
  éxito (vía el código de salida de `Setup-Credentials.ps1`, no un `Test-Path`
  posterior) y continuar directo al orquestador **sin** mostrar
  "falta cred_domain.json" ni pedir repetir el asistente
- [ ] Si `config.ps1` ya existe pero faltan `SecureConfig\cred_domain.json` o
  `cred_wifi.json`, el mismo asistente se dispara pero salta directo a los
  Pasos 1-3 (no vuelve a pedir dominio/nombre/SSID, ni sobreescribe `config.ps1`)
- [ ] Con credenciales ya configuradas de una corrida anterior, `init.bat` se
  autoeleva, ve los archivos correctamente (porque ya corre elevado) y salta
  el asistente por completo
- [ ] Si invocás `.\scripts\Setup-Credentials.ps1` directo (no vía `init.bat`)
  sin haber habilitado `ExecutionPolicy`, falla con el error estándar de
  Windows — es esperado, `init.bat` es el único camino que no depende de esa
  configuración previa (usa `-ExecutionPolicy Bypass` internamente)
- [ ] Se abre una ventana de PowerShell (ya elevada, heredada de `init.bat`) con `Invoke-AutoConfigPS.ps1`
- [ ] Se imprime el reporte de pre-validación (8 checks) con una barra de progreso (`Write-Progress`)
- [ ] Si todos los checks críticos pasan, continúa automáticamente al paso 1 sin pedir ninguna tecla
- [ ] Se crea `C:\ProgramData\AutoConfigPS\state.json` y `status.json`
- [ ] `Get-ScheduledTask -TaskName AutoConfigPS-Orchestrator` y `AutoConfigPS-Notify` existen

**Caso negativo:** renombrar `config.ps1` temporalmente y volver a correr `init.bat`
→ debe fallar la pre-validación con mensaje claro y `exit 1`, **sin** crear
`state.json` con un pipeline a medias. Restaurar `config.ps1` antes de continuar.

### Prueba 2 — ConfigureWifi

- [ ] Se conecta al SSID **corporativo** configurado (o el paso se marca `Skipped`
  si ya estaba conectado a esa red). La conexión es por auto-connect del perfil +
  bounce del adaptador, sin `netsh wlan connect` (que requiere Servicios de Ubicación)
- [ ] `(Get-NetConnectionProfile).Name` confirma la red activa correcta — NO usar
  `netsh wlan show interfaces` para verificar (puede estar bloqueado por Ubicación)
- [ ] IP asignada no es APIPA (`169.254.x.x`)
- [ ] Si había otras redes guardadas (ej. red de invitados), quedan en modo `manual`
  y solo la corporativa se auto-conecta
- [ ] No hay ningún `Read-Host` en ningún punto de este paso

**Caso negativo:** configurar un SSID inexistente en `config.ps1` → el paso debe
reintentar hasta `$MaxStepAttempts` veces y luego marcar el pipeline `Failed` (no
quedar reintentando por siempre en cada arranque futuro).

### Prueba 3 — RenameComputer + reinicio automático

- [ ] El nombre del equipo se programa correctamente (`Rename-Computer`)
- [ ] El equipo **se reinicia solo** (sin preguntar "¿deseas reiniciar? S/N")
- [ ] Tras el reinicio, la tarea `AutoConfigPS-Orchestrator` se dispara sola
  (~60-90s después de encender) y continúa en `JoinDomain` **sin volver a
  ejecutar `ConfigureWifi` ni `RenameComputer`**
- [ ] `$env:COMPUTERNAME` refleja el nuevo nombre tras el reinicio
- [ ] Si alguien inicia sesión durante la ventana de reinicio, `steps\Show-Notification.ps1`
  muestra "en progreso, no apagues el equipo" (validar el permiso de lectura de
  `status.json` para un usuario sin privilegios de administrador — es la parte más
  nueva y menos probada del diseño)

### Prueba 4 — JoinDomain (caso normal)

- [ ] Valida el controlador de dominio antes de unir (revisar `C:\Logs\setup_success.log`
  para ver cuál de los 3 métodos —DNS SRV, DNS directo, nltest— tuvo éxito)
- [ ] Se une al dominio correctamente
- [ ] Reinicia solo, la tarea retoma en `InstallApps`
- [ ] `(Get-WmiObject Win32_ComputerSystem).Domain` confirma el dominio tras el reinicio

### Prueba 4b — JoinDomain con nombre duplicado en AD

1. En AD, crear manualmente un objeto de equipo con el mismo nombre que `$HostName`
   en `config.ps1` (o usar un `$HostName` que sepas que ya existe).
2. Correr el pipeline hasta llegar a `JoinDomain`.

**Verificar con `$OnDuplicateName = 'Halt'` (valor por defecto):**

- [ ] El log muestra `[CRITICAL]` que se detectó el conflicto y el motivo
- [ ] El paso se **detiene** (`state.json` → `JoinDomain: Failed`), NO auto-renombra
- [ ] NO se limpian credenciales ni `config.ps1` (se conservan para reintentar)
- [ ] La ventana de estado se pone en rojo indicando el fallo
- [ ] Tras borrar el objeto de equipo obsoleto en AD (o cambiar `$HostName`) y
  re-ejecutar `init.bat`, la unión completa correctamente

**Verificar con `$OnDuplicateName = 'Alternative'` (opt-in):**

- [ ] Se genera un nombre alternativo (`<HostName>-NNN`)
- [ ] El equipo se une al dominio **con el nombre alternativo**, confirmado por
  `(Get-WmiObject Win32_ComputerSystem).Name` tras el reinicio
- [ ] **Crítico:** el equipo NO revierte al nombre original duplicado (comportamiento
  ya validado)

### Prueba 5 — InstallApps

- [ ] Autologin (si se configuró) se desactiva al iniciar este paso
- [ ] Las apps se instalan en la **sesión del usuario** (tarea `AutoConfigPS-InstallApps`),
  no como SYSTEM — winget resuelve por ruta y, en un perfil nuevo, se registra solo
- [ ] Barra de progreso animada por app y la app actual visible en la ventana de estado
- [ ] Apps de Winget instalan vía `--source winget` (Chrome, VS Code, Notepad++, etc.)
- [ ] Apps de red: el share se autentica con credenciales de dominio y el instalador
  se copia a un temporal local antes de ejecutarlo
- [ ] App de red sin `Path` configurado (placeholder del template) → se **omite** (no falla)
- [ ] Resumen final con conteo **instaladas / omitidas / fallidas**
- [ ] Una app que falla **no detiene el pipeline** (verificar con una app con
  `Path` inválido en `apps.json`)

### Prueba 6 — Finalize, notificación y limpieza

- [ ] Se crea `C:\ConfiguracionCompleta.txt`
- [ ] `state.json` → `Status: "Completed"`
- [ ] La ventana de estado muestra el resultado final (verde = OK; amarillo =
  "completado con errores" si alguna app falló) y se **congela** en ese estado
- [ ] La tarea `AutoConfigPS-Orchestrator` se elimina sola
  (`Get-ScheduledTask -TaskName AutoConfigPS-Orchestrator` → no existe)
- [ ] **Limpieza final** (`$CleanupOnFinish = $true`, sin apps fallidas): se borran
  `SecureConfig\`, `config.ps1`, `apps.json` y `C:\ProgramData\AutoConfigPS`; los
  logs `C:\Logs\*.log` se conservan
- [ ] Si hubo apps fallidas, la limpieza se **omite** y el log lo indica

### Prueba 7 — Camino de error (reintentos agotados)

1. Configurar credenciales de dominio incorrectas a propósito.
2. Correr el pipeline hasta `JoinDomain`.

**Verificar:**

- [ ] Reintenta hasta `$MaxStepAttempts` veces con `$StepRetryDelaySeconds` de espera
- [ ] Tras agotar los reintentos, `state.json` → `Status: "Failed"`
- [ ] La tarea `AutoConfigPS-Orchestrator` se elimina (no vuelve a intentar en el próximo arranque)
- [ ] `Show-Notification.ps1` muestra "proceso detenido por un error, revisa los logs"
- [ ] Corregir las credenciales y volver a ejecutar `init.bat` (o
  `Invoke-AutoConfigPS.ps1` manualmente, elevado) → **no hace falta borrar
  `state.json` a mano**: al detectar `Status: Failed`, el orquestador
  resetea automáticamente solo el/los paso(s) que fallaron (intentos a 0) y
  retoma — los pasos ya completados con éxito (`ConfigureWifi`/`RenameComputer`
  si ya habían funcionado) quedan intactos, no se repiten
- [ ] Mensaje en consola: `[i] La corrida anterior habia fallado. Reintentando: <paso>`

**Nota:** este reseteo automático es distinto del reseteo completo de
[Rollback y Recuperación](#rollback-y-recuperación) — ese sigue siendo
necesario si querés volver a correr **todo** el pipeline desde cero
(`ConfigureWifi` incluido), no solo reintentar el paso que falló.

---

## Matriz de Casos de Prueba

| # | Caso | Resultado esperado | Estado |
|---|------|---------------------|--------|
| 1 | Primer arranque, config.ps1 válido | Pre-validación OK, pipeline inicia | ⬜ |
| 1b | Primer arranque, config.ps1 ausente | Falla con mensaje claro, exit 1, sin state.json a medias | ⬜ |
| 2 | Wi-Fi con SSID válido | Conecta, valida IP/gateway/DNS | ⬜ |
| 2b | Wi-Fi con SSID inexistente | Reintenta y falla definitivamente (no reintenta por siempre) | ⬜ |
| 3 | Rename + reinicio | Reinicia solo, retoma en JoinDomain sin repetir pasos previos | ⬜ |
| 3b | Logon durante reinicio pendiente | Notificación "en progreso, no apagues" | ⬜ |
| 4 | Join a dominio, nombre disponible | Une correctamente, reinicia, retoma en InstallApps | ⬜ |
| 4b | Join con nombre duplicado en AD | `Halt` (default): se detiene sin renombrar; `Alternative`: usa alternativo sin revertir al original | ⬜ |
| 5 | Instalación de apps, 1 app inválida | El resto se instala, el fallo se reporta (instaladas/omitidas/fallidas) sin detener el pipeline | ⬜ |
| 6 | Finalización | Archivo de confirmación, tarea se autoelimina, ventana de estado en verde, limpieza final | ⬜ |
| 7 | Credenciales de dominio incorrectas | Falla tras N reintentos, no reintenta en arranques futuros, notifica error | ⬜ |
| 7b | Reanudación manual tras corregir el error | Retoma exactamente en el paso fallido | ⬜ |

---

## Criterios de Aceptación

El piloto se considera **aprobado** si:

- [ ] Los 12 casos de la matriz pasan en al menos 1 equipo de cada tipo (limpio,
  nombre duplicado, camino de error)
- [ ] En ningún momento el pipeline queda bloqueado esperando entrada de teclado
  mientras corre sin sesión interactiva
- [ ] El equipo termina unido al dominio con el nombre correcto (original o
  alternativo, según corresponda) y las apps configuradas instaladas
- [ ] `C:\Logs\setup_errors.log` no contiene errores no explicados por los casos
  negativos intencionales de esta guía

---

## Diagnóstico

Para revisar en qué quedó un pipeline sin esperar a que termine:

```powershell
# Estado completo (progreso por paso, intentos, mensajes)
Get-Content C:\ProgramData\AutoConfigPS\state.json | ConvertFrom-Json | ConvertTo-Json -Depth 5

# Resumen legible (lo mismo que lee Show-Notification.ps1)
Get-Content C:\ProgramData\AutoConfigPS\status.json | ConvertFrom-Json

# Tareas programadas activas del pipeline
Get-ScheduledTask -TaskName 'AutoConfigPS-*' | Select-Object TaskName, State

# Logs
Get-Content C:\Logs\setup_errors.log -Tail 50
Get-Content C:\Logs\setup_success.log -Tail 50
```

Para problemas de configuración general (ExecutionPolicy, Wi-Fi, credenciales,
Winget), ver la sección **Solución de Problemas** de `README.md` — esta guía no
duplica ese contenido, se enfoca en el procedimiento de prueba.

---

## Rollback y Recuperación

### Reintentar el pipeline desde cero en el mismo equipo

**Ya no hace falta hacerlo a mano en el caso normal:** `init.bat` detecta si
existe estado de una corrida anterior (`C:\ProgramData\AutoConfigPS`) y lo borra
automáticamente al arrancar, para empezar limpio. Como `init.bat` es el punto de
entrada MANUAL (los reinicios del proceso retoman por la tarea programada, no por
`init.bat`), esto es seguro y nunca borra progreso a mitad del ciclo de
reinicios. Es decir: para reintentar desde cero, basta con volver a correr
`init.bat`.

Si querés forzar la limpieza a mano de todos modos (o desregistrar las tareas):

```powershell
Remove-Item C:\ProgramData\AutoConfigPS -Recurse -Force
Get-ScheduledTask -TaskName 'AutoConfigPS-*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
```

Esto borra el progreso guardado; el próximo `Invoke-AutoConfigPS.ps1` vuelve a
correr la pre-validación y todos los pasos desde `ConfigureWifi`. **No** revierte
cambios ya aplicados al sistema (nombre, dominio, apps) — para eso, ver abajo.

### Sacar el equipo del dominio (tras una prueba)

```powershell
Remove-Computer -UnjoinDomainCredential (Get-Credential) -WorkgroupName WORKGROUP -Restart -Force
```

Y eliminar manualmente el objeto de equipo en AD si quedó registrado.

### Limpieza completa (equipo físico, no VM)

```powershell
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon, DefaultUserName, DefaultPassword -ErrorAction SilentlyContinue
Remove-Item C:\ProgramData\AutoConfigPS -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item C:\ConfiguracionCompleta.txt -Force -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName 'AutoConfigPS-*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
```

Si es una VM, restaurar el snapshot previo es más simple y confiable que la
limpieza manual — se recomienda para todas las corridas de prueba salvo la última
de verificación en hardware físico real.

---

## Checklist de Aprobación

- [ ] Los 12 casos de la [Matriz de Casos de Prueba](#matriz-de-casos-de-prueba) documentados con resultado (OK/Fallo + evidencia)
- [ ] Al menos 1 corrida completa en Windows PowerShell 5.1 real (no 7.x)
- [ ] Logs de las corridas archivados (`C:\Logs\*.log`, `state.json`)
- [ ] Problemas encontrados registrados como issues, con severidad
- [ ] Decisión: ⬜ Aprobado para producción / ⬜ Requiere correcciones / ⬜ Rechazado

**Responsable de la validación:** _________________ **Fecha:** _________________
