# 🧪 Guía de Pruebas Piloto - AutoConfigPS v0.1.0

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
en concreto los tres bugs que motivaron el rediseño de arquitectura (ver
`CHANGELOG.md` → `v0.1.0`):

1. Que ningún paso se cuelgue con un prompt cuando corre como SYSTEM sin sesión
   interactiva (reinicios entre pasos).
2. Que un nombre de equipo duplicado en AD se resuelva con un nombre alternativo
   **y la unión al dominio realmente use ese alternativo** (no el original).
3. Que la notificación al usuario funcione sin depender de UI lanzada desde el
   contexto SYSTEM.

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
- [ ] `scripts\Setup-Credentials.ps1`
- [ ] `init.bat`, `example-config.ps1`, `example-apps.json`

### 2. Configurar credenciales cifradas

```powershell
cd C:\AutoConfigPS
.\scripts\Setup-Credentials.ps1
```

- [ ] Se crea `SecureConfig\.aeskey`, `cred_domain.json`, `cred_wifi.json` (y `cred_local.json` si se configuró autologin local opcional)
- [ ] Verificar permisos: `icacls C:\AutoConfigPS\SecureConfig` debe mostrar solo `BUILTIN\Administrators` y `NT AUTHORITY\SYSTEM`

### 3. Crear `config.ps1`

```powershell
Copy-Item .\example-config.ps1 .\config.ps1
notepad .\config.ps1
```

Configurar como mínimo: `$DomainName`, `$HostName`, `$NetworkSSID`. Para el piloto,
dejar explícito (no depender del valor por defecto):

```powershell
$AutoRestart = $true   # Necesario para que el pipeline sea realmente desatendido
$MaxStepAttempts = 3
$StepRetryDelaySeconds = 30
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

- [ ] Se abre una ventana de PowerShell elevada (UAC) con `Invoke-AutoConfigPS.ps1`
- [ ] Se imprime el reporte de pre-validación (8 checks) con una barra de progreso (`Write-Progress`)
- [ ] Si todos los checks críticos pasan, continúa automáticamente al paso 1 sin pedir ninguna tecla
- [ ] Se crea `C:\ProgramData\AutoConfigPS\state.json` y `status.json`
- [ ] `Get-ScheduledTask -TaskName AutoConfigPS-Orchestrator` y `AutoConfigPS-Notify` existen

**Caso negativo:** renombrar `config.ps1` temporalmente y volver a correr `init.bat`
→ debe fallar la pre-validación con mensaje claro y `exit 1`, **sin** crear
`state.json` con un pipeline a medias. Restaurar `config.ps1` antes de continuar.

### Prueba 2 — ConfigureWifi

- [ ] Se conecta al SSID configurado (o el paso se marca `Skipped` si ya estaba conectado)
- [ ] `netsh wlan show interfaces` confirma el SSID activo
- [ ] IP asignada no es APIPA (`169.254.x.x`)
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

### Prueba 4b — JoinDomain con nombre duplicado (caso crítico)

Este es el caso que verifica el fix del bug de v0.0.4.

1. En AD, crear manualmente un objeto de equipo con el mismo nombre que `$HostName`
   en `config.ps1` (o usar un `$HostName` que sepas que ya existe).
2. Correr el pipeline hasta llegar a `JoinDomain`.

**Verificar:**

- [ ] El log muestra que se detectó el conflicto (`Nombre de equipo '...' ya existe en AD`)
- [ ] Se genera un nombre alternativo (`<HostName>-NNN`)
- [ ] El equipo se une al dominio **con el nombre alternativo**, confirmado por
  `(Get-WmiObject Win32_ComputerSystem).Name` tras el reinicio
- [ ] **Crítico:** el equipo NO termina con el nombre original duplicado ni falla
  la unión por el conflicto — este era exactamente el bug corregido

### Prueba 5 — InstallApps

- [ ] Autologin (si se configuró) se desactiva al iniciar este paso
- [ ] Barra de progreso por app (`Write-Progress -Id 2`) y tiempo transcurrido
  durante cada instalación individual (`Write-Progress -Id 3`)
- [ ] Resumen final con conteo de exitosas/fallidas
- [ ] Una app que falla **no detiene el pipeline** (verificar con una app con
  `Path` inválido en `apps.json`)

### Prueba 6 — Finalize y notificación

- [ ] Se crea `C:\ConfiguracionCompleta.txt`
- [ ] `state.json` → `Status: "Completed"`
- [ ] La tarea `AutoConfigPS-Orchestrator` se elimina sola
  (`Get-ScheduledTask -TaskName AutoConfigPS-Orchestrator` → no existe)
- [ ] Al iniciar sesión un usuario, aparece el toast "configuración completada"
- [ ] Tras mostrarse, la tarea `AutoConfigPS-Notify` se elimina sola

### Prueba 7 — Camino de error (reintentos agotados)

1. Configurar credenciales de dominio incorrectas a propósito.
2. Correr el pipeline hasta `JoinDomain`.

**Verificar:**

- [ ] Reintenta hasta `$MaxStepAttempts` veces con `$StepRetryDelaySeconds` de espera
- [ ] Tras agotar los reintentos, `state.json` → `Status: "Failed"`
- [ ] La tarea `AutoConfigPS-Orchestrator` se elimina (no vuelve a intentar en el próximo arranque)
- [ ] `Show-Notification.ps1` muestra "proceso detenido por un error, revisa los logs"
- [ ] Corregir las credenciales y volver a ejecutar `Invoke-AutoConfigPS.ps1`
  manualmente (elevado) → retoma exactamente en `JoinDomain`, sin repetir
  `ConfigureWifi`/`RenameComputer`

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
| 4b | Join con nombre duplicado en AD | Usa nombre alternativo, une correctamente (no revierte al original) | ⬜ |
| 5 | Instalación de apps, 1 app inválida | El resto se instala, el fallo se reporta sin detener el pipeline | ⬜ |
| 6 | Finalización | Archivo de confirmación, tarea se autoelimina, toast "completado" | ⬜ |
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
