# AutoConfigPS

> Sistema automatizado de configuración inicial para equipos Windows en ambientes corporativos

[![Version](https://img.shields.io/badge/version-0.0.4-blue.svg)](CHANGELOG.md)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**AutoConfigPS** automatiza completamente la configuración de equipos Windows corporativos, incluyendo cambio de nombre, conexión Wi-Fi, unión al dominio e instalación de aplicaciones.

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
|----------|-------------|-----------|-----------------|
| `Restricted` | No permite ningún script | 🔒 Máxima | Por defecto en Windows |
| `RemoteSigned` | Scripts locales OK, remotos requieren firma | 🔒 Alta | **Producción/Corporativo** |
| `Unrestricted` | Todos los scripts, advierte sobre remotos | ⚠️ Media | Desarrollo |
| `Bypass` | Todos los scripts sin restricción | ❌ Baja | Solo pruebas |

**Referencia oficial:** [about_Execution_Policies - Microsoft Learn](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.core/about/about_execution_policies)

---

## 🚀 Inicio Rápido

### 1. Descargar el Proyecto

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
# Hacer doble clic en init.bat
# O desde CMD/PowerShell:
.\init.bat
```

El script:
1. ✅ Valida requisitos (Script0.ps1)
2. ⚙️ Configura Wi-Fi y renombra equipo (Script1.ps1)
3. 🔄 Reinicia
4. 🏢 Une al dominio (Script2.ps1)
5. 🔄 Reinicia
6. 📦 Instala aplicaciones (Script3.ps1)
7. ✅ Confirma completado (Script4.ps1)

---

## ⚙️ Configuración

### Configuración de Credenciales

#### Opción A: Credenciales Cifradas (Recomendado)

```powershell
# 1. Ejecutar asistente
.\scripts\Setup-Credentials.ps1

# 2. Editar config.ps1 y descomentar líneas de credenciales cifradas
$DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.xml"
$DomainCredential = Import-Clixml -Path $DomainCredPath
$Useradmin = $DomainCredential.UserName
$SecurePassadmin = $DomainCredential.Password
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

```
AutoConfigPS/
├── scripts/
│   ├── Setup-Credentials.ps1  # Asistente de credenciales cifradas
│   ├── Script0.ps1             # Pre-validación de requisitos
│   ├── Script1.ps1             # Configuración básica (Wi-Fi, nombre)
│   ├── Script2.ps1             # Unión al dominio
│   ├── Script3.ps1             # Instalación de aplicaciones
│   └── Script4.ps1             # Confirmación y notificación
│
├── config.ps1                  # Configuración principal (crear desde example)
├── apps.json                   # Lista de aplicaciones (opcional)
│
├── example-config.ps1          # Plantilla de configuración
├── example-apps.json           # Plantilla de aplicaciones
│
├── init.bat                    # Script de inicio
├── README.md                   # Esta documentación
├── CHANGELOG.md                # Historial de cambios
├── LOG_IMPLEMENTACION.md       # Documentación técnica de implementación
└── LICENSE                     # Licencia MIT
```

---

## 🔄 Flujo de Ejecución

```
┌─────────────────────────────────────────────────────────────┐
│                      INICIO (init.bat)                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Script0.ps1 (v0.0.4)                       │
│               PRE-VALIDACIÓN DE REQUISITOS                   │
│  ✓ Privilegios admin                                         │
│  ✓ PowerShell 5.1+                                           │
│  ✓ Adaptador Wi-Fi                                           │
│  ✓ config.ps1 existe                                         │
│  ℹ Winget, credenciales, espacio, conectividad               │
└────────────────────────┬────────────────────────────────────┘
                         │ Si pasa
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Script1.ps1 (1/4)                       │
│             CONFIGURACIÓN BÁSICA DEL SISTEMA                 │
│  1. Configurar red Wi-Fi (con validación completa)          │
│  2. Configurar autologin (usuario local)                    │
│  3. Cambiar nombre del equipo                               │
│  4. Crear tarea programada (Exec-Join-Domain)               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼ REINICIO #1
                         │
┌─────────────────────────────────────────────────────────────┐
│                      Script2.ps1 (2/4)                       │
│                   UNIÓN AL DOMINIO                           │
│  1. Actualizar autologin (usuario de dominio)               │
│  2. Validar acceso a DC (v0.0.4)                             │
│  3. Verificar nombre duplicado (v0.0.4)                      │
│  4. Unir equipo al dominio (con OU opcional)                 │
│  5. Crear tarea programada (Exec-Check-Continue)            │
│  6. Eliminar tarea anterior                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼ REINICIO #2
                         │
┌─────────────────────────────────────────────────────────────┐
│                      Script3.ps1 (3/4)                       │
│           INSTALACIÓN DE APLICACIONES                        │
│  1. Validar cambios aplicados                               │
│  2. Eliminar tarea anterior                                  │
│  3. Desactivar autologin                                     │
│  4. Instalar aplicaciones:                                   │
│     ├─ Winget (con timeout v0.0.4)                           │
│     └─ Network (con timeout v0.0.4)                          │
│  5. Mostrar resumen de instalaciones (v0.0.4)                │
│  6. Crear archivo de confirmación                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Script4.ps1 (4/4)                       │
│            CONFIRMACIÓN Y NOTIFICACIÓN                       │
│  • Mensaje en consola con resumen                            │
│  • Notificación Toast al usuario                             │
│  • Referencias a logs                                        │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
                   CONFIGURACIÓN
                    COMPLETADA ✅
```

**Tiempo estimado:** 20-40 minutos (dependiendo del número de aplicaciones)

---

## 🔒 Seguridad

### Credenciales Cifradas (v0.0.4)

Las credenciales se cifran usando **DPAPI (Data Protection API)** de Windows:

- ✅ Cifrado automático por usuario y máquina
- ✅ No requiere gestión manual de claves
- ✅ Solo legibles por el usuario que las creó en el equipo específico
- ✅ Almacenamiento en `SecureConfig/` con permisos restrictivos

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
```
No se puede cargar el archivo C:\AutoConfigPS\scripts\Script0.ps1 porque
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

### Script0.ps1 Falla (Pre-validación)

**Problema:** Validación crítica falla

**Soluciones:**
- **Sin privilegios admin**: Ejecutar `init.bat` como administrador
- **PowerShell < 5.1**: Actualizar desde https://aka.ms/powershell-release
- **Sin Wi-Fi**: Si usas Ethernet, modificar Script1.ps1 para omitir configuración Wi-Fi
- **config.ps1 no existe**: Copiar `example-config.ps1` a `config.ps1`
- **Sin Winget**: Instalar desde Microsoft Store (App Installer)

### Script1.ps1 - Falla Conexión Wi-Fi

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
4. Revisar logs en `C:\Logs\setup_errors.log`

### Script2.ps1 - Falla Unión al Dominio

**Problema:** No se puede unir al dominio

**Soluciones:**
1. **Error "DC no encontrado"**:
   - Verificar conectividad: `Test-Connection -ComputerName dominio.local`
   - Verificar DNS: `nslookup dominio.local`
   - Verificar DC: `nltest /dsgetdc:dominio.local`

2. **Error "Acceso denegado"**:
   - Verificar credenciales de dominio en config.ps1
   - Verificar permisos del usuario para unir equipos al dominio

3. **Error "Nombre duplicado"** (v0.0.4):
   - Script detecta automáticamente y genera nombre alternativo
   - Si falla generación, cambiar manualmente `$HostName` en config.ps1

4. **Error de OU** (v0.0.4):
   - Verificar que la OU exista: Abrir "Active Directory Users and Computers"
   - Verificar formato del DN: `OU=Workstations,DC=empresa,DC=local`
   - Verificar permisos del usuario en la OU

### Script3.ps1 - Fallan Instalaciones

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

4. **Revisar resumen** (v0.0.4):
   - Script3 muestra resumen con apps exitosas/fallidas
   - Revisar logs: `C:\Logs\setup_errors.log`

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
|----------|-------|----------|
| **"Ejecución de scripts deshabilitada"** | ExecutionPolicy en Restricted | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` |
| Script no inicia | Sin privilegios admin | Ejecutar como admin |
| Wi-Fi no conecta | SSID/contraseña incorrecta | Verificar config.ps1 |
| Unión al dominio falla | Sin conectividad a DC | Verificar red y DNS |
| Winget no funciona | No instalado | Instalar desde Microsoft Store |
| Instalación cuelga (v0.0.3) | Sin timeout | Actualizar a v0.0.4 |
| Nombre duplicado causa error | Equipo ya existe en AD | v0.0.4 resuelve automáticamente |

---

## 📊 Changelog

Ver [CHANGELOG.md](CHANGELOG.md) para el historial completo de cambios.

### Versiones

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
- 📚 **Documentación técnica**: Ver [LOG_IMPLEMENTACION.md](LOG_IMPLEMENTACION.md)
- 📖 **Guía de pruebas**: Ver [GUIA_PRUEBAS.md](GUIA_PRUEBAS.md) (próximamente)

---

## ⚠️ Advertencias

- ⚠️ Este script realiza cambios significativos en el sistema (renombre, unión a dominio, instalaciones)
- ⚠️ **Probar primero en ambiente de pruebas** antes de usar en producción
- ⚠️ Mantener `config.ps1` seguro y no versionarlo con credenciales
- ⚠️ Revisar logs después de cada ejecución
- ⚠️ Las credenciales cifradas solo funcionan en el equipo donde se crearon

---

**🎉 ¡Disfruta de la automatización con AutoConfigPS v0.0.4!**
