# Changelog

## [v0.0.3] - 2025-03-06

### Fixed

- Corregido error de tipeo en script1.
- Mejorados los mensajes de salida durante la conexión Wi-Fi.
- Ajuste en la configuración de `DelayTask` para definir el retraso de inicio de la tarea en segundos.
- Eliminado el parámetro `HistoryEnabled` para garantizar compatibilidad con PowerShell 5.1.

## [v0.0.2] - 2025-03-01

### Added

- Implementación de reintentos de conexión a la red Wi-Fi en `script1.ps1` para mejorar la robustez.
- Nuevos parámetros en la creación de tareas programadas en `script1.ps1` y `script2.ps1`.

### Changed

- Refactorización del código para eliminar tareas programadas previas en `script2.ps1` y `script3.ps1`.

### Fixed

- Implementación de actualización de orígenes de Winget en `script3.ps1` para evitar problemas de instalación de paquetes.

## [v0.0.1] - 2025-02-28

### Added

- Scripts básicos para configuración inicial de equipos.
- Soporte para cambio de nombre, unión al dominio y configuración de Wi-Fi.
- Soporte para instalación de aplicaciones desde Winget y red.
- Documentación inicial en `README.md`
