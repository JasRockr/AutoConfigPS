# Changelog

## [v0.0.4] - 2025-03-06

### Added [v0.0.4]

- Configuración de logs y definición de funciones de logging (`Write-Log`, `Write-SuccessLog`, `Write-ErrorLog`).
- Validación de ejecución del script con permisos de administrador.
- Validación y creación de directorios y archivos de logs (éxito y errores) si no existen.
- Implementación de límite de tamaño de archivo de log y renombrado automático.
- Implementación de permisos de escritura para todos los archivos de log.
- Nuevo script `script4.ps1` para notificaciones por ventana de terminal y toast.
- Inicio de PowerShell con `Start-Process` desde `script3.ps1` para confirmación final de configuración al usuario.

### Changed [v0.0.4]

- Ajuste de parámetros para la creación de tareas programadas.
- Implementación de mensajes de log en las operaciones de configuración.
- Validación de la tarea programada antes de reiniciar el equipo.
- Implementación de confirmación de reinicio automático si no está definido en la configuración.

### Fixed [v0.0.4]

- Validación de variables de configuración de logs (valores por defecto si no están definidos).

## [v0.0.3] - 2025-03-06

### Fixed [v0.0.3]

- Corregido error de tipeo en script1.
- Mejorados los mensajes de salida durante la conexión Wi-Fi.
- Ajuste en la configuración de `DelayTask` para definir el retraso de inicio de la tarea en segundos.
- Eliminado el parámetro `HistoryEnabled` para garantizar compatibilidad con PowerShell 5.1.

## [v0.0.2] - 2025-03-01

### Added [v0.0.2]

- Implementación de reintentos de conexión a la red Wi-Fi en `script1.ps1` para mejorar la robustez.
- Nuevos parámetros en la creación de tareas programadas en `script1.ps1` y `script2.ps1`.

### Changed [v0.0.2]

- Refactorización del código para eliminar tareas programadas previas en `script2.ps1` y `script3.ps1`.

### Fixed [v0.0.2]

- Implementación de actualización de orígenes de Winget en `script3.ps1` para evitar problemas de instalación de paquetes.

## [v0.0.1] - 2025-02-28

### Added [v0.0.1]

- Scripts básicos para configuración inicial de equipos.
- Soporte para cambio de nombre, unión al dominio y configuración de Wi-Fi.
- Soporte para instalación de aplicaciones desde Winget y red.
- Documentación inicial en `README.md`.
