# Changelog

Todos los cambios notables del proyecto AutoConfigPS se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [v0.0.4] - 2026-01-28

### 🔒 Seguridad

#### Added
- **Sistema de credenciales cifradas**: Nuevo script `Setup-Credentials.ps1` para configurar credenciales usando DPAPI de Windows
  - Cifrado automático de credenciales de dominio, usuario local y Wi-Fi
  - Almacenamiento seguro en directorio `SecureConfig/` con permisos restrictivos
  - Retrocompatibilidad con credenciales en texto plano
- **Permisos restrictivos en archivos de log**: Cambio de `Everyone:F` a `Administrators+SYSTEM` en todos los scripts
  - Protección de información sensible en logs
  - Prevención de modificación/eliminación por usuarios no autorizados

#### Changed
- Modificado `example-config.ps1` para soportar credenciales cifradas y texto plano
- Actualizado `Script1.ps1`, `Script2.ps1` y `Script3.ps1` para usar credenciales cifradas cuando estén disponibles
- Mejorado manejo de credenciales en memoria con limpieza explícita de variables

### 🌐 Red y Conectividad

#### Added
- **Validación robusta de conectividad Wi-Fi** en `Script1.ps1`
  - Nueva función `Test-NetworkConnectivity` con 5 validaciones:
    - Adaptador Wi-Fi activo
    - IP válida asignada (no APIPA)
    - Gateway predeterminado configurado
    - Gateway alcanzable (ping)
    - Servidores DNS configurados
  - Hasta 5 reintentos con delay configurable
  - Logging detallado de cada validación
- **Validación de controlador de dominio** en `Script2.ps1`
  - Nueva función `Test-DomainController` con 3 métodos de detección:
    - Búsqueda DNS SRV (`_ldap._tcp.dc._msdcs`)
    - Resolución DNS directa del dominio
    - Detección con `nltest` (fallback)
  - Hasta 3 reintentos con delay de 10 segundos
  - Validación antes de intentar unión al dominio

### 📦 Instalación de Aplicaciones

#### Added
- **Sistema de instalación con timeout** en `Script3.ps1`
  - Nueva función `Install-WingetApp` con timeout configurable (default 300s)
  - Nueva función `Install-NetworkApp` con timeout configurable (default 600s)
  - Validación de exit codes (0, -1978335189 para Winget, 3010 para instaladores)
  - Control de procesos con `System.Diagnostics.Process`
  - Kill automático de procesos que excedan timeout
- **Resumen visual de instalaciones**
  - Estadísticas de instalaciones exitosas/fallidas
  - Duración de cada instalación
  - Lista detallada de resultados con iconos coloridos
  - Logging exhaustivo de todos los eventos
- **Nuevos campos en configuración de aplicaciones**
  - `ID`: ID específico de Winget (evita ambigüedades)
  - `Timeout`: Timeout personalizado por aplicación en segundos

#### Changed
- Actualizado `example-apps.json` con estructura mejorada y ejemplos completos
- Mejorado manejo de errores en instalaciones (no detiene proceso completo)
- Actualización de fuentes Winget con manejo de errores robusto

### ✅ Pre-validación

#### Added
- **Nuevo script de pre-validación**: `Script0.ps1` (470 líneas)
  - 8 validaciones de requisitos del sistema:
    1. Privilegios de administrador (crítica)
    2. Versión de PowerShell ≥5.1 (crítica)
    3. Adaptador Wi-Fi disponible (crítica)
    4. Winget instalado (opcional)
    5. Archivo config.ps1 existe (crítica)
    6. Credenciales cifradas configuradas (opcional)
    7. Espacio en disco ≥10GB (opcional)
    8. Conectividad de red (opcional)
  - Interfaz colorida con banners y símbolos (✓/✗)
  - Instrucciones específicas para cada fallo
  - Resumen final con estadísticas
  - Distingue validaciones críticas de opcionales
  - Exit codes: 0 (puede continuar), 1 (debe resolver críticos)
- **Integración con init.bat v1.1**
  - Ejecuta Script0.ps1 antes de Script1.ps1
  - Aborta proceso si pre-validación falla
  - Retrocompatible (continúa sin Script0 si no existe)

### 🏢 Active Directory

#### Added
- **Soporte para Unidad Organizacional (OU)**
  - Nuevo parámetro opcional `$OUPath` en `config.ps1`
  - Unión a OU específica en lugar de contenedor "Computers" predeterminado
  - Formato: Distinguished Name (DN) completo
  - Ejemplo: `OU=Workstations,OU=Computers,DC=dominio,DC=local`
  - Validación automática por `Add-Computer`
- **Manejo de nombres de equipo duplicados**
  - Nueva función `Test-ComputerNameInAD` en `Script2.ps1`
  - Búsqueda LDAP con `DirectorySearcher` (sin módulo AD)
  - Generación automática de nombres alternativos con sufijo aleatorio
  - Hasta 10 reintentos para encontrar nombre disponible
  - Respeto de límite NetBIOS (15 caracteres)
  - Renombrado automático si se detecta conflicto
  - Confirmación interactiva si no se puede generar alternativo

#### Changed
- Modificado `Script2.ps1` para usar parámetro `-OUPath` con splatting
- Mejorado logging de unión al dominio con información de OU

### 📝 Documentación

#### Added
- `LOG_IMPLEMENTACION.md`: Documentación exhaustiva de implementación
  - Detalle de todas las mejoras de Fase 1 y Fase 2
  - Decisiones de diseño y justificaciones técnicas
  - Casos de uso y ejemplos prácticos
  - Estadísticas de código y tiempo invertido
- Comentarios inline mejorados en todos los scripts
- Documentación de nuevos parámetros en `example-config.ps1`

#### Changed
- Mejorada documentación de credenciales en `example-config.ps1`
- Agregadas instrucciones de uso para nuevas características

### 🔧 Mejoras Técnicas

#### Changed
- Refactorización de funciones de logging (replicadas en Script3.ps1)
- Uso de splatting para parámetros opcionales en `Add-Computer`
- Validación de existencia de variables con `Get-Variable -ErrorAction SilentlyContinue`
- Limpieza mejorada de variables sensibles en memoria
- Manejo de errores más robusto con try-catch específicos

#### Fixed
- Corrección de permisos de logs en Script3.ps1 (estaban pendientes)
- Validación de cadenas vacías con `[string]::IsNullOrWhiteSpace`
- Compatibilidad mejorada con PowerShell 5.1

### 📊 Estadísticas de la Versión

- **Líneas de código agregadas**: ~1837 líneas
- **Funciones nuevas**: 5 funciones
- **Archivos nuevos**: 3 archivos
- **Archivos modificados**: 6 archivos
- **Tiempo de desarrollo**: ~4.5 horas
- **Mejoras de seguridad**: 4 críticas
- **Mejoras de robustez**: 4 importantes

---

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
