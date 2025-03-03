# AutoConfigPS

Este proyecto automatiza la configuración de equipos corporativos mediante scripts de PowerShell.

## Índice

- [AutoConfigPS](#autoconfigps)
  - [Índice](#índice)
  - [**Documentación Técnica**](#documentación-técnica)
    - [**1. Descripción del Proyecto**](#1-descripción-del-proyecto)
    - [**2. Estructura del Proyecto**](#2-estructura-del-proyecto)
    - [**3. Archivos de Configuración**](#3-archivos-de-configuración)
    - [**4. Funcionamiento de los Scripts**](#4-funcionamiento-de-los-scripts)
    - [**5. Requisitos del Sistema**](#5-requisitos-del-sistema)
  - [**Guía de Usuario**](#guía-de-usuario)
    - [**1. Preparación**](#1-preparación)
    - [**2. Ejecución de los Scripts**](#2-ejecución-de-los-scripts)
    - [**3. Verificación**](#3-verificación)
    - [**4. Solución de Problemas**](#4-solución-de-problemas)
  - [**Ejemplo de Uso**](#ejemplo-de-uso)
    - [**1. Configurar `config.ps1`**](#1-configurar-configps1)
    - [**2. Ejecutar los Scripts**](#2-ejecutar-los-scripts)

## **Documentación Técnica**

### **1. Descripción del Proyecto**

Este proyecto consiste en un conjunto de scripts de PowerShell para automatizar la configuración inicial de equipos en una red corporativa. Los scripts realizan tareas como:

- Cambiar el nombre del equipo.
- Configurar la conexión Wi-Fi.
- Unir el equipo a un dominio.
- Configurar el inicio de sesión automático (temporal).
- Instalar aplicaciones.

### **2. Estructura del Proyecto**

El proyecto está organizado de la siguiente manera:

```powershell
/AutoConfigPS
│
├── /scripts
│   ├── script1.ps1       # Parte 1: Configuraciones básicas y preparación del sistema.
│   ├── script2.ps1       # Parte 2: Unir el equipo al dominio y preparar el sistema.
│   └── script3.ps1       # Parte 3: Validar cambios, instalar aplicaciones y confirmar configuración.
│
├── config.ps1            # Archivo de configuración principal.
├── apps.json             # Lista de aplicaciones a instalar (opcional).
├── .gitignore            # Lista de archivos ignorados por Git.
├── CHANGELOG.md          # Documentacion de logs del proyecto
└── README.md             # Documentación del proyecto.
```

### **3. Archivos de Configuración**

**`config.ps1`**

Este archivo contiene las variables de configuración necesarias para ejecutar los scripts.  
**Ejemplo:**

```powershell
# Configuración general
$DomainName = "dominio.local"   # Nombre del dominio
$Useradmin = "admin"    # Usuario de dominio
$Passadmin = "P@ssw0rd" # Contraseña de usuario de dominio
$HostName = "NuevoNombreEquipo" # Nombre del equipo
$Delay = 5  # Tiempo en segundos para reinicio
$ScriptPath = "C:\Ruta\De\Los\Scripts"  # Ruta al segundo script (crear en el próximo paso)

# Configurar inicio de sesión local
$Username = "usuario"   # Usuario local
$Password = 'P@ssw0rd'  # Contraseña de usuario local

# Configuración de red Wi-Fi
$NetworkSSID = "Red WiFi"   # Usuario de red Wi-Fi
$NetworkPass = "ContraseñaWiFi" # Contraseña de usuario local

# Lista de aplicaciones a instalar (nombre, origen, ruta de red, parametros)
    # Winget: Instalación mediante winget
    # Network: Instalación desde una ruta de red (requiere acceso a la carpeta de red
$apps = @(
    @{ Name = "Google Chrome"; Source = "Winget" },
    @{ Name = "Notepad++"; Source = "Winget" },
    @{ Name = "Adobe.Acrobat.Reader.64-bit"; Source = "Winget" },
    @{ Name = "CustomApp"; Source = "Network"; Path = "\\NetworkPath\Installer.exe"; Arguments = "/silent /norestart" }
)

# Configuración logging
$errorLog = "C:\Logs\setup_errors.log"  # Ruta para el log de errores
$successLog = "C:\Logs\setup_success.log"  # Ruta para el log de éxito
```

**`apps.json` (Opcional)**

Si prefieres usar un archivo JSON para la lista de aplicaciones, este es un ejemplo:

```json
[
  {
    "_content": "Este es un archivo JSON de ejemplo que contiene una lista de aplicaciones para instalar."
  },
  {
    "Name": "Google Chrome",
    "Source": "Winget"
  },
  {
    "Name": "Notepad++",
    "Source": "Winget"
  },
  {
    "Name": "CustomApp",
    "Source": "Network",
    "Path": "\\\\NetworkPath\\Installer.exe",
    "Arguments": "/silent /norestart"
  }
]
```

### **4. Funcionamiento de los Scripts**

**`script1.ps1`**

- **Objetivo:** Configuraciones básicas y preparación del sistema.
- **Tareas:**
    1. Cambiar el nombre del equipo.
    2. Configurar la conexión Wi-Fi.
    3. Configurar el inicio de sesión automático.
    4. Crear una tarea programada para ejecutar `script2.ps1` después del reinicio.

**`script2.ps1`**

- **Objetivo:** Unir el equipo al dominio y preparar el sistema.
- **Tareas:**
    1. Unir el equipo al dominio.
    2. Crear una tarea programada para ejecutar `script3.ps1` después del reinicio.
    3. Eliminar la tarea programada anterior (`Exec-Join-Domain`).

**`script3.ps1`**

- **Objetivo:** Validar cambios, instalar aplicaciones y confirmar la configuración.
- **Tareas:**
    1. Validar que el equipo esté unido al dominio.
    2. Instalar aplicaciones desde Winget o una unidad de red.
    3. Confirmar la configuración automática.

### **5. Requisitos del Sistema**

- **PowerShell 5.1 o superior.**
- **Permisos de administrador** para ejecutar los scripts.
- **Conexión a Internet** (para instalar aplicaciones desde Winget).
- **Acceso a la red** (para instalar aplicaciones desde una unidad de red).

## **Guía de Usuario**

### **1. Preparación**

1. **Descargar el proyecto:** Clona o descarga el repositorio del proyecto.
2. **Editar la configuración:** Modifica el archivo `config.ps1` con los valores adecuados para tu entorno.

### **2. Ejecución de los Scripts**

1. **Ejecutar `script1.ps1`:**
    - Abre PowerShell como administrador.
    - Navega a la carpeta donde se encuentra el script.
    - Ejecuta el siguiente comando:

        ```powershell
        .\script1.ps1
        ```

    - El equipo se reiniciará automáticamente después de completar las tareas.
2. **Ejecutar `script2.ps1`:**
    - Después del reinicio, el script se ejecutará automáticamente.
    - Si no se ejecuta, abre PowerShell como administrador y ejecuta:

        ```powershell
        .\script2.ps1
        ```

    - El equipo se reiniciará nuevamente.
3. **Ejecutar `script3.ps1`:**
    - Después del segundo reinicio, el script se ejecutará automáticamente.
    - Si no se ejecuta, abre PowerShell como administrador y ejecuta:

        ```powershell
        .\script3.ps1
        ```

### **3. Verificación**

- **Archivo de confirmación:** Después de ejecutar `script3.ps1`, se creará un archivo en `C:\ConfiguracionCompleta.txt` para confirmar que la configuración se completó correctamente.
- **Logs:** Revisa los logs generados por los scripts para verificar que todas las tareas se completaron sin errores.

### **4. Solución de Problemas**

- **Errores comunes:**
  - **Falta de permisos:** Asegúrate de ejecutar los scripts como administrador.
  - **Archivo de configuración incorrecto:** Verifica que `config.ps1` esté correctamente configurado.
  - **Problemas de red:** Asegúrate de que el equipo tenga acceso a Internet y a la red corporativa.

---

## **Ejemplo de Uso**

### **1. Configurar `config.ps1`**

```powershell
# Configuración general
$DomainName = "dominio.local"   # Nombre del dominio
$Useradmin = "admin"    # Usuario de dominio
$Passadmin = "P@ssw0rd" # Contraseña de usuario de dominio
$HostName = "NuevoNombreEquipo" # Nombre del equipo
$Delay = 5  # Tiempo en segundos para reinicio
$ScriptPath = "C:\Ruta\De\Los\Scripts"  # Ruta al segundo script (crear en el próximo paso)

# Configurar inicio de sesión local
$Username = "usuario"   # Usuario local
$Password = 'P@ssw0rd'  # Contraseña de usuario local

# Configuración de red Wi-Fi
$NetworkSSID = "Red WiFi"   # Usuario de red Wi-Fi
$NetworkPass = "ContraseñaWiFi" # Contraseña de usuario local

# Lista de aplicaciones a instalar (nombre, origen, ruta de red, parametros)
$apps = @(
    @{ Name = "Google Chrome"; Source = "Winget" },
    @{ Name = "Notepad++"; Source = "Winget" },
    @{ Name = "Adobe.Acrobat.Reader.64-bit"; Source = "Winget" },
    @{ Name = "CustomApp"; Source = "Network"; Path = "\\NetworkPath\Installer.exe"; Arguments = "/silent /norestart" }
)

# Configuración logging
$errorLog = "C:\Logs\setup_errors.log"  # Ruta para el log de errores
$successLog = "C:\Logs\setup_success.log"  # Ruta para el log de éxito
```

### **2. Ejecutar los Scripts**

1. **Primer script:**

    ```powershell
    .\script1.ps1
    ```

2. **Segundo script:**

    ```powershell
    .\script2.ps1
    ```

3. **Tercer script:**

    ```powershell
    .\script3.ps1
    ```

---
