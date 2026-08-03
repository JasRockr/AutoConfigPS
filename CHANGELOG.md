# Changelog

Este proyecto se encuentra en **beta**: el flujo completo fue validado end-to-end
en hardware real y este documento describe el conjunto de funcionalidades de ese
estado, que es el punto de partida para las pruebas beta a partir de aquí. No se
usa un esquema de versiones numeradas todavía.

---

## Beta — estado actual (validado en hardware real)

Herramienta CLI de PowerShell 5.1 que prepara equipos Windows 10/11 recién
instalados para un entorno corporativo (Wi-Fi, nombre, unión al dominio AD e
instalación de aplicaciones) de forma **desatendida** y resumible a través de los
reinicios necesarios.

### Arquitectura

- **Orquestador único** (`Invoke-AutoConfigPS.ps1`) con estado persistente en
  `C:\ProgramData\AutoConfigPS\state.json` y una sola tarea programada resumible;
  cada paso es idempotente (reevalúa la postcondición real del equipo).
- **Cero `Read-Host` en la ruta desatendida** — nunca se bloquea esperando teclado
  al correr como SYSTEM tras un reinicio.
- Logging, credenciales, pre-validación y barra de progreso consolidados en
  `modules/`. Todos los `.ps1` se guardan con BOM UTF-8; los `.json` sin BOM.

### Funcionalidades validadas en hardware

- **Wi-Fi** sin depender de Servicios de Ubicación: conecta por auto-connect del
  perfil (bounce del adaptador) y verifica la red corporativa por
  `Get-NetConnectionProfile`; deja los demás perfiles guardados en modo manual.
- **Renombrar + unir al dominio** con autologin temporal a través de los reinicios;
  política configurable ante nombre duplicado en AD (`$OnDuplicateName`: `Halt` o
  `Alternative`) y auto-corrección si las credenciales de dominio son incorrectas.
- **Instalación de aplicaciones** en la sesión del usuario (no como SYSTEM): apps
  de Winget (`--source winget`) y apps de red (share autenticado con credenciales
  de dominio + copia local). Timeouts configurables; los fallos de una app no
  detienen el pipeline (resumen instaladas / omitidas / fallidas).
- **Notificación al técnico** mediante una ventana de estado en vivo que refleja el
  avance, los fallos y el resultado final.
- **Asistente interactivo** (`scripts/Setup-Credentials.ps1`) que genera
  `config.ps1`, guarda credenciales cifradas (AES-256) y selecciona las apps de
  `apps.json`; idempotente. `init.bat` se autoeleva una sola vez.
- **Seguridad e higiene:** ACL por SID (independiente del idioma del sistema),
  logs legibles por el técnico, y limpieza final configurable (`$CleanupOnFinish`)
  que elimina credenciales/estado/config al terminar sin apps fallidas (los logs
  se conservan siempre).

### Compatibilidad

- Windows 10 (1809+) / Windows 11, Windows PowerShell 5.1 puro (sin módulos
  externos). Validación de sintaxis 5.1, BOM y JSON en CI en cada push/PR.
