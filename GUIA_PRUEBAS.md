# 🧪 Guía de Pruebas - AutoConfigPS v0.0.4

**Documento para Pruebas Piloto en Entorno Real**

---

## 📋 Tabla de Contenidos

1. [Información General](#información-general)
2. [Pre-requisitos](#pre-requisitos)
3. [Preparación del Entorno](#preparación-del-entorno)
4. [Procedimientos de Prueba](#procedimientos-de-prueba)
5. [Matriz de Casos de Prueba](#matriz-de-casos-de-prueba)
6. [Validación y Criterios de Aceptación](#validación-y-criterios-de-aceptación)
7. [Problemas Comunes y Soluciones](#problemas-comunes-y-soluciones)
8. [Rollback y Recuperación](#rollback-y-recuperación)
9. [Checklist de Aprobación](#checklist-de-aprobación)

---

## Información General

### Objetivo de las Pruebas

Validar la funcionalidad completa de AutoConfigPS v0.0.4 en un entorno de producción controlado, verificando:

- ✅ Seguridad de credenciales cifradas (DPAPI)
- ✅ Conectividad de red Wi-Fi robusta
- ✅ Unión al dominio con validación de DC
- ✅ Instalación de aplicaciones con timeouts
- ✅ Pre-validación de requisitos del sistema
- ✅ Manejo de nombres duplicados en AD
- ✅ Soporte para Unidades Organizacionales (OU)

### Alcance

**Equipos a Probar**: Mínimo 5 equipos con diferentes configuraciones:

- 2 equipos nuevos (Windows 10/11 Pro)
- 2 equipos reformateados
- 1 equipo con nombre duplicado en AD (prueba específica)

**Duración Estimada**: 2-3 días laborales

**Responsables**:

- Administrador de Sistemas: _____________________
- Técnico de Soporte: _____________________
- Validador de Seguridad: _____________________

---

## Pre-requisitos

### Infraestructura Requerida

#### 1. Active Directory

- [ ] Controlador de dominio accesible: `_________________`
- [ ] Usuario con permisos para unir equipos: `_________________`
- [ ] OU de destino creada (opcional): `_________________`
- [ ] DNS configurado correctamente en DC

#### 2. Red Wi-Fi Corporativa

- [ ] SSID de red Wi-Fi: `_________________`
- [ ] Protocolo de seguridad: WPA2-PSK o superior
- [ ] Contraseña de red conocida
- [ ] Alcance Wi-Fi en área de pruebas

#### 3. Repositorio de Aplicaciones

- [ ] Winget funcional (Windows 11 o App Installer actualizado)
- [ ] Acceso a recursos de red para instaladores (si aplica): `\\__________\`
- [ ] Permisos de lectura en recursos de red

#### 4. Equipos de Prueba

**Especificaciones mínimas por equipo**:

- [ ] Windows 10 Pro 1909+ o Windows 11 Pro
- [ ] Adaptador Wi-Fi funcional
- [ ] 10 GB de espacio libre en disco
- [ ] Memoria RAM: 4 GB mínimo
- [ ] Usuario local con privilegios de administrador

**Estado inicial**:

- [ ] Windows activado
- [ ] Sin unir a dominio
- [ ] Sin configuración previa de AutoConfigPS

### Materiales de Prueba

- [ ] USB con AutoConfigPS v0.0.4 completo
- [ ] Archivo `config.ps1` configurado para entorno de prueba
- [ ] Archivo `apps.json` con lista de aplicaciones aprobadas (opcional)
- [ ] Credenciales de administrador de dominio
- [ ] Credenciales de usuario local para autologin
- [ ] Contraseña de red Wi-Fi

---

## Preparación del Entorno

### Paso 1: Preparación de Archivos de Configuración

#### 1.1. Copiar AutoConfigPS al Equipo de Prueba

```batch
# Ubicación recomendada
C:\AutoConfigPS\
```

**Checklist**:

- [ ] Carpeta `scripts\` con todos los scripts (Script0.ps1 - Script3.ps1, Setup-Credentials.ps1)
- [ ] Archivo `init.bat` en raíz
- [ ] Archivo `example-config.ps1` en raíz
- [ ] Archivo `example-apps.json` en raíz (opcional)

#### 1.2. Configurar Credenciales Cifradas (Recomendado)

**Ejecutar desde PowerShell con privilegios de administrador**:

```powershell
cd C:\AutoConfigPS
.\scripts\Setup-Credentials.ps1
```

**Validaciones**:

- [ ] Script solicita credenciales de dominio
- [ ] Script solicita credenciales de usuario local
- [ ] Script solicita contraseña de Wi-Fi
- [ ] Se crea directorio `SecureConfig\`
- [ ] Se crean archivos:
  - `SecureConfig\cred_domain.xml`
  - `SecureConfig\cred_local.xml`
  - `SecureConfig\cred_wifi.xml`
- [ ] Permisos en `SecureConfig\`: solo Administrators y SYSTEM

**Verificación de permisos**:

```powershell
icacls C:\AutoConfigPS\SecureConfig
# Debe mostrar:
# BUILTIN\Administrators:(OI)(CI)(F)
# NT AUTHORITY\SYSTEM:(OI)(CI)(F)
```

#### 1.3. Crear archivo config.ps1

**Opción A: Con credenciales cifradas (RECOMENDADO)**

Copiar `example-config.ps1` a `config.ps1` y editar:

```powershell
# Configuración general
$DomainName = "tu-dominio.local"
$HostName = "EQUIPO-PRUEBA-01"
$Delay = 5
$ScriptPath = "C:\AutoConfigPS\scripts"

# Credenciales de dominio (CIFRADAS)
$DomainCredPath = "$PSScriptRoot\SecureConfig\cred_domain.xml"
$DomainCredential = Import-Clixml -Path $DomainCredPath
$Useradmin = $DomainCredential.UserName
$SecurePassadmin = $DomainCredential.Password

# Credenciales de usuario local (CIFRADAS)
$LocalCredPath = "$PSScriptRoot\SecureConfig\cred_local.xml"
if (Test-Path $LocalCredPath) {
    $LocalCredential = Import-Clixml -Path $LocalCredPath
    $Username = $LocalCredential.UserName
    $SecurePassword = $LocalCredential.Password
}

# Configuración de red Wi-Fi
$NetworkSSID = "WiFi-Corporativa"
$WifiCredPath = "$PSScriptRoot\SecureConfig\cred_wifi.xml"
$WifiCredential = Import-Clixml -Path $WifiCredPath
$SecureNetworkPass = $WifiCredential.Password

# Unidad Organizacional (OPCIONAL)
$OUPath = "OU=Pruebas,OU=Workstations,DC=tu-dominio,DC=local"

# Configuración logging
$errorLog = "C:\Logs\setup_errors.log"
$successLog = "C:\Logs\setup_success.log"
```

**Opción B: Con credenciales en texto plano (SOLO RECOMENDADO PARA PRUEBAS)**

```powershell
# Credenciales de dominio (TEXTO PLANO)
$Useradmin = "administrador"
$Passadmin = "P@ssw0rd123"
$SecurePassadmin = ConvertTo-SecureString $Passadmin -AsPlainText -Force

# Credenciales de usuario local (TEXTO PLANO)
$Username = "usuario"
$Password = "P@ssw0rd123"
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

# Wi-Fi (TEXTO PLANO)
$NetworkSSID = "WiFi-Corporativa"
$NetworkPass = "ContraseñaWiFi123"
$SecureNetworkPass = ConvertTo-SecureString $NetworkPass -AsPlainText -Force
```

**Checklist de configuración**:

- [ ] `$DomainName` coincide con dominio real
- [ ] `$HostName` sigue convención de nombres (max 15 caracteres)
- [ ] `$ScriptPath` apunta a directorio correcto
- [ ] `$NetworkSSID` coincide con red Wi-Fi disponible
- [ ] `$OUPath` existe en Active Directory (si se usa)
- [ ] Credenciales son correctas

#### 1.4. Configurar Aplicaciones (Opcional)

**Opción A: Usar archivo apps.json**

Crear `apps.json` basado en `example-apps.json`:

```json
[
  {
    "Name": "Google Chrome",
    "Source": "Winget",
    "ID": "Google.Chrome",
    "Timeout": 300
  },
  {
    "Name": "Microsoft Visual Studio Code",
    "Source": "Winget",
    "ID": "Microsoft.VisualStudioCode",
    "Timeout": 240
  },
  {
    "Name": "Adobe Acrobat Reader",
    "Source": "Winget",
    "ID": "Adobe.Acrobat.Reader.64-bit",
    "Timeout": 360
  }
]
```

**Opción B: Definir en config.ps1**

Ver sección `$apps` en `example-config.ps1`.

**Checklist**:

- [ ] IDs de Winget son correctos (verificar con `winget search <app>`)
- [ ] Timeouts son apropiados (300s para apps pequeñas, 600s+ para grandes)
- [ ] Rutas de red para instaladores son accesibles (si aplica)

---

## Procedimientos de Prueba

### 🔍 Prueba 0: Pre-validación de Requisitos

**Objetivo**: Verificar que Script0.ps1 detecta correctamente requisitos faltantes.

#### Caso de Prueba 0.1: Validación Exitosa

**Precondiciones**:

- Equipo cumple todos los requisitos
- Usuario es administrador
- Adaptador Wi-Fi presente
- `config.ps1` existe

**Pasos**:

1. Abrir PowerShell como Administrador
2. Ejecutar:

   ```powershell
   cd C:\AutoConfigPS
   .\scripts\Script0.ps1
   ```

**Resultados Esperados**:

- [ ] Banner de inicio se muestra
- [ ] 8 validaciones se ejecutan:
  1. ✓ Privilegios de administrador: `OK`
  2. ✓ Versión de PowerShell: `OK` (≥5.1)
  3. ✓ Adaptador Wi-Fi: `OK` (nombre detectado)
  4. ✓ Winget instalado: `OK` o `ADVERTENCIA` (opcional)
  5. ✓ Archivo config.ps1: `OK`
  6. ✓ Credenciales cifradas: `OK` o `ADVERTENCIA` (opcional)
  7. ✓ Espacio en disco: `OK` (≥10GB)
  8. ✓ Conectividad de red: `OK` o `ADVERTENCIA` (opcional)
- [ ] Resumen muestra: `Total: 8 | Exitosas: X | Advertencias: Y | Errores: 0`
- [ ] Mensaje final: `✓ PUEDE CONTINUAR - Todas las validaciones críticas pasaron`
- [ ] Exit code: `0`

**Registro**:

- Fecha/Hora: _______________
- Equipo: _______________
- Resultado: PASS / FAIL
- Observaciones: _______________________________

#### Caso de Prueba 0.2: Validación con Errores Críticos

**Precondiciones**:

- Renombrar temporalmente `config.ps1` a `config.ps1.bak`

**Pasos**:

1. Ejecutar `.\scripts\Script0.ps1`

**Resultados Esperados**:

- [ ] Validación 5 falla: `✗ ERROR - Archivo config.ps1 no existe`
- [ ] Instrucciones específicas se muestran:

  ```
  Copie example-config.ps1 a config.ps1 y edite la configuración
  ```

- [ ] Resumen muestra: `Errores: 1`
- [ ] Mensaje final: `✗ NO PUEDE CONTINUAR - Debe resolver los errores críticos`
- [ ] Exit code: `1`

**Limpieza**:

- Restaurar `config.ps1`

**Registro**:

- Fecha/Hora: _______________
- Resultado: PASS / FAIL

---

### 📶 Prueba 1: Conexión Wi-Fi y Renombrado

**Objetivo**: Verificar conexión Wi-Fi robusta y renombrado del equipo.

#### Caso de Prueba 1.1: Conexión Wi-Fi Normal

**Precondiciones**:

- Red Wi-Fi disponible con buena señal
- Credenciales Wi-Fi correctas en `config.ps1`
- Equipo no conectado a Wi-Fi

**Pasos**:

1. Ejecutar `init.bat` como Administrador
2. Observar salida de Script1.ps1

**Resultados Esperados**:

**Pre-validación (Script0)**:

- [ ] Script0.ps1 se ejecuta correctamente
- [ ] Exit code 0

**Script1.ps1 - Conexión Wi-Fi**:

- [ ] Log muestra: `Intentando conectar a Wi-Fi: [SSID]`
- [ ] Perfil XML se crea correctamente
- [ ] Comando `netsh wlan add profile` exitoso
- [ ] Comando `netsh wlan connect` exitoso
- [ ] `Test-NetworkConnectivity` inicia con 5 validaciones:
  1. ✓ Adaptador Wi-Fi activo detectado
  2. ✓ IP válida asignada (no 169.254.x.x)
  3. ✓ Gateway predeterminado configurado
  4. ✓ Ping a gateway exitoso
  5. ✓ Servidores DNS configurados
- [ ] Log muestra: `Conectividad validada correctamente`
- [ ] Mensaje: `Wi-Fi conectado exitosamente`

**Script1.ps1 - Renombrado**:

- [ ] Log muestra: `Renombrando equipo a: [HOSTNAME]`
- [ ] Comando `Rename-Computer` exitoso
- [ ] Tarea programada `Script2Task` creada
- [ ] Tarea configurada para ejecutar al inicio
- [ ] Cuenta de tarea: `SYSTEM`
- [ ] Log en: `C:\Logs\setup_success.log`
- [ ] Equipo se reinicia automáticamente después de [Delay] segundos

**Validación Post-Reinicio**:

- [ ] Equipo reinicia correctamente
- [ ] Nombre del equipo cambió (verificar en `Acerca de` o `sysdm.cpl`)
- [ ] Conexión Wi-Fi se mantiene

**Verificación de Logs**:

```powershell
Get-Content C:\Logs\setup_success.log | Select-String "Wi-Fi|conectado|Renombr"
```

**Permisos de Logs**:

```powershell
icacls C:\Logs\setup_success.log
# Debe mostrar solo: Administrators y SYSTEM
```

**Registro**:

- Fecha/Hora: _______________
- Equipo: _______________
- SSID conectado: _______________
- Nuevo nombre: _______________
- Tiempo de conexión: ___________ segundos
- Resultado: PASS / FAIL
- Observaciones: _______________________________

#### Caso de Prueba 1.2: Conexión Wi-Fi con Reintentos

**Precondiciones**:

- Red Wi-Fi con señal intermitente o débil

**Pasos**:

1. Ejecutar `init.bat`
2. Observar reintentos de conexión

**Resultados Esperados**:

- [ ] Si primera conexión falla, `Test-NetworkConnectivity` reintenta
- [ ] Log muestra: `Intento X de 5 - Esperando X segundos...`
- [ ] Hasta 5 reintentos con delay de 5 segundos
- [ ] Si finalmente conecta: proceso continúa
- [ ] Si falla todos los reintentos: error registrado

**Registro**:

- Fecha/Hora: _______________
- Número de reintentos: _______________
- Resultado: PASS / FAIL

---

### 🏢 Prueba 2: Unión al Dominio

**Objetivo**: Verificar unión al dominio con validación de DC y manejo de nombres duplicados.

#### Caso de Prueba 2.1: Unión al Dominio Normal (Sin OU)

**Precondiciones**:

- Script1 completado (equipo renombrado y reiniciado)
- Equipo conectado a red con acceso a DC
- Credenciales de dominio correctas
- `$OUPath` NO definido en `config.ps1`
- Nombre del equipo NO existe en AD

**Pasos**:

1. Equipo reinicia y ejecuta Script2Task automáticamente
2. Observar logs en `C:\Logs\setup_success.log`

**Resultados Esperados**:

**Validación de Dominio**:

- [ ] `Test-DomainController` inicia
- [ ] Método 1 (DNS SRV): búsqueda de `_ldap._tcp.dc._msdcs.[dominio]` exitosa
- [ ] Log muestra: `Controlador de dominio encontrado: [nombre_dc]`
- [ ] O si falla método 1: intenta método 2 (DNS directo)
- [ ] O si falla método 2: intenta método 3 (nltest)
- [ ] Al menos un método retorna DC válido

**Validación de Nombre**:

- [ ] `Test-ComputerNameInAD` inicia
- [ ] Búsqueda LDAP de nombre de equipo
- [ ] Log muestra: `Nombre '[hostname]' está disponible en AD`
- [ ] No se requiere nombre alternativo

**Unión al Dominio**:

- [ ] Comando `Add-Computer` se ejecuta
- [ ] Parámetros correctos: `-DomainName`, `-Credential`, `-Force`
- [ ] NO se usa parámetro `-OUPath` (debe unirse a "Computers" predeterminado)
- [ ] Log muestra: `Equipo unido al dominio exitosamente`
- [ ] AutoLogin configurado para usuario local
- [ ] Tarea programada `Script3Task` creada
- [ ] Equipo se reinicia automáticamente

**Validación Post-Reinicio**:

- [ ] Equipo reinicia correctamente
- [ ] AutoLogin funciona (usuario local inicia sesión automáticamente)
- [ ] Equipo está unido al dominio (verificar con `systeminfo` o `Get-ComputerInfo`)
- [ ] Equipo aparece en contenedor "Computers" en AD Users and Computers

**Verificación en Active Directory**:

```powershell
# Desde DC o equipo con módulo AD
Get-ADComputer -Identity [HOSTNAME]
# Debe mostrar:
# DistinguishedName: CN=[HOSTNAME],CN=Computers,DC=dominio,DC=local
```

**Registro**:

- Fecha/Hora: _______________
- Equipo: _______________
- Dominio: _______________
- DC detectado: _______________
- Contenedor AD: CN=Computers (default)
- Tiempo de unión: ___________ segundos
- Resultado: PASS / FAIL
- Observaciones: _______________________________

#### Caso de Prueba 2.2: Unión al Dominio con OU Específica

**Precondiciones**:

- `$OUPath` definido en `config.ps1`
- OU existe en AD: `OU=Pruebas,OU=Workstations,DC=dominio,DC=local`
- Usuario de dominio tiene permisos en OU

**Pasos**:

1. Editar `config.ps1`:

   ```powershell
   $OUPath = "OU=Pruebas,OU=Workstations,DC=dominio,DC=local"
   ```

2. Ejecutar proceso completo (Script1 → Script2)

**Resultados Esperados**:

- [ ] Log muestra: `OU configurada: [ruta_completa_OU]`
- [ ] `Add-Computer` usa parámetro `-OUPath`
- [ ] Unión exitosa
- [ ] Equipo aparece en OU especificada (no en "Computers")

**Verificación en Active Directory**:

```powershell
Get-ADComputer -Identity [HOSTNAME]
# DistinguishedName debe ser:
# CN=[HOSTNAME],OU=Pruebas,OU=Workstations,DC=dominio,DC=local
```

**Registro**:

- Fecha/Hora: _______________
- OU configurada: _______________
- Contenedor AD verificado: _______________
- Resultado: PASS / FAIL

#### Caso de Prueba 2.3: Manejo de Nombre Duplicado

**Precondiciones**:

- Crear manualmente un equipo en AD con nombre "EQUIPO-DUP"
- Configurar `config.ps1` con `$HostName = "EQUIPO-DUP"`

**Pasos**:

1. Ejecutar proceso completo (Script1 → Script2)
2. Observar detección de duplicado

**Resultados Esperados**:

**Detección de Duplicado**:

- [ ] `Test-ComputerNameInAD` detecta nombre existente
- [ ] Log muestra: `ADVERTENCIA: El nombre 'EQUIPO-DUP' ya existe en Active Directory`
- [ ] Función genera nombre alternativo: `EQUIPO-DUP-XXX` (XXX = número aleatorio 100-999)
- [ ] Se valida que nombre alternativo no existe
- [ ] Si alternativo también existe: reintenta hasta 10 veces
- [ ] Log muestra: `Se usará el nombre alternativo: EQUIPO-DUP-XXX`

**Renombrado Automático**:

- [ ] Equipo se renombra a nombre alternativo
- [ ] Unión al dominio usa nombre alternativo
- [ ] Proceso continúa normalmente

**Validación**:

- [ ] Equipo en AD tiene nombre alternativo (no original)
- [ ] No hay conflictos
- [ ] Log registra decisión de cambio de nombre

**Registro**:

- Fecha/Hora: _______________
- Nombre original: _______________
- Nombre alternativo generado: _______________
- Número de reintentos: _______________
- Resultado: PASS / FAIL

#### Caso de Prueba 2.4: Fallo de Validación de DC

**Precondiciones**:

- Desconectar equipo de red (simular DC inaccesible)
- O configurar `$DomainName` con dominio inexistente

**Pasos**:

1. Ejecutar Script2

**Resultados Esperados**:

- [ ] `Test-DomainController` falla en los 3 métodos
- [ ] Log muestra: `ERROR: No se pudo contactar con el controlador de dominio`
- [ ] Script aborta la unión al dominio
- [ ] Error registrado en `C:\Logs\setup_errors.log`
- [ ] Script NO continúa (no crea Script3Task)

**Registro**:

- Fecha/Hora: _______________
- Error detectado: _______________
- Resultado: PASS / FAIL

---

### 📦 Prueba 3: Instalación de Aplicaciones

**Objetivo**: Verificar instalación de aplicaciones con timeouts y manejo de errores.

#### Caso de Prueba 3.1: Instalación Winget Normal

**Precondiciones**:

- Script2 completado (equipo unido al dominio)
- Winget instalado y funcional
- `apps.json` o `$apps` configurado con 3 aplicaciones de Winget:

  ```json
  [
    {"Name": "Google Chrome", "Source": "Winget", "ID": "Google.Chrome", "Timeout": 300},
    {"Name": "Notepad++", "Source": "Winget", "ID": "Notepad++.Notepad++", "Timeout": 180},
    {"Name": "7-Zip", "Source": "Winget", "ID": "7zip.7zip", "Timeout": 120}
  ]
  ```

**Pasos**:

1. Equipo reinicia después de Script2
2. Script3Task se ejecuta automáticamente
3. Observar proceso de instalación

**Resultados Esperados**:

**Preparación**:

- [ ] Script3 inicia
- [ ] Log muestra: `Iniciando instalación de aplicaciones...`
- [ ] Winget fuentes se actualizan: `winget source update`
- [ ] Actualización exitosa o advertencia si falla (no crítico)

**Instalación de Aplicaciones**:

Para cada aplicación:

- [ ] Log muestra: `Instalando [AppName] desde Winget...`
- [ ] `Install-WingetApp` se ejecuta con timeout configurado
- [ ] Proceso de Winget se inicia
- [ ] Log muestra progreso (si disponible)
- [ ] Instalación completa antes del timeout
- [ ] Exit code válido: `0` (instalado) o `-1978335189` (ya instalado)
- [ ] Log muestra: `✓ [AppName] instalado correctamente ([XX]s)`
- [ ] Duración se registra

**Resumen Visual**:

- [ ] Al final se muestra resumen:

  ```
  ========================================
   RESUMEN DE INSTALACIONES
  ========================================
  ✓ Google Chrome - Instalado correctamente (45s)
  ✓ Notepad++ - Instalado correctamente (23s)
  ✓ 7-Zip - Instalado correctamente (15s)

  Total: 3 | Exitosas: 3 | Fallidas: 0
  Tiempo total: 83 segundos
  ========================================
  ```

**Validación de Instalación**:

```powershell
# Verificar que apps se instalaron
winget list | Select-String "Chrome|Notepad|7-Zip"
# Deben aparecer las 3 aplicaciones
```

**Registro**:

- Fecha/Hora: _______________
- Aplicaciones instaladas: _______________
- Aplicaciones fallidas: _______________
- Tiempo total: ___________ segundos
- Resultado: PASS / FAIL
- Observaciones: _______________________________

#### Caso de Prueba 3.2: Instalación con Timeout

**Precondiciones**:

- Configurar aplicación con timeout muy corto (30s) y app grande (ej. Visual Studio Code)

**Pasos**:

1. Editar apps.json:

   ```json
   [
     {"Name": "Visual Studio Code", "Source": "Winget", "ID": "Microsoft.VisualStudioCode", "Timeout": 30}
   ]
   ```

2. Ejecutar Script3

**Resultados Esperados**:

- [ ] Instalación inicia
- [ ] Después de 30 segundos, timeout se alcanza
- [ ] Proceso de Winget se termina (kill)
- [ ] Log muestra: `TIMEOUT: La instalación excedió X segundos`
- [ ] Log muestra: `✗ [AppName] - Error en instalación (TIMEOUT)`
- [ ] Proceso continúa con siguiente aplicación (no aborta)
- [ ] Resumen muestra fallo: `Exitosas: 0 | Fallidas: 1`

**Registro**:

- Fecha/Hora: _______________
- Timeout configurado: ___________ segundos
- Resultado: PASS / FAIL

#### Caso de Prueba 3.3: Instalación desde Red

**Precondiciones**:

- Instalador disponible en red: `\\SERVER\Apps\CustomApp.exe`
- Configuración en apps.json:

  ```json
  [
    {
      "Name": "CustomApp",
      "Source": "Network",
      "Path": "\\\\SERVER\\Apps\\CustomApp.exe",
      "Arguments": "/silent /norestart",
      "Timeout": 600
    }
  ]
  ```

**Pasos**:

1. Ejecutar Script3

**Resultados Esperados**:

- [ ] `Install-NetworkApp` se ejecuta
- [ ] Verificación de ruta de red exitosa
- [ ] Instalador se ejecuta con argumentos especificados
- [ ] Timeout de 600s se respeta
- [ ] Exit code válido: `0` (instalado) o `3010` (requiere reinicio)
- [ ] Log muestra: `✓ CustomApp instalado correctamente desde red`

**Validación**:

- Verificar aplicación instalada en `Programs and Features` o registro

**Registro**:

- Fecha/Hora: _______________
- Ruta de red: _______________
- Resultado: PASS / FAIL

#### Caso de Prueba 3.4: Manejo de Errores Mixtos

**Precondiciones**:

- Configurar 5 aplicaciones:
  - 2 válidas
  - 1 con ID incorrecto
  - 1 con timeout muy corto
  - 1 de red con ruta inválida

**Pasos**:

1. Ejecutar Script3
2. Observar manejo de errores

**Resultados Esperados**:

- [ ] Aplicaciones válidas se instalan correctamente
- [ ] Aplicación con ID incorrecto falla con error de Winget
- [ ] Aplicación con timeout falla después del timeout
- [ ] Aplicación de red con ruta inválida falla con error de acceso
- [ ] Cada error se registra individualmente
- [ ] Proceso NO aborta, continúa con todas las apps
- [ ] Resumen muestra: `Exitosas: 2 | Fallidas: 3`
- [ ] Log detalla cada fallo específicamente

**Registro**:

- Fecha/Hora: _______________
- Errores detectados: _______________
- Resultado: PASS / FAIL

---

## Matriz de Casos de Prueba

| ID | Módulo | Caso de Prueba | Prioridad | Estado | Responsable | Fecha | Resultado | Notas |
|----|--------|----------------|-----------|--------|-------------|-------|-----------|-------|
| PT-0.1 | Script0 | Validación exitosa | Alta | ⬜ Pendiente | | | | |
| PT-0.2 | Script0 | Validación con errores críticos | Media | ⬜ Pendiente | | | | |
| PT-1.1 | Script1 | Conexión Wi-Fi normal | Alta | ⬜ Pendiente | | | | |
| PT-1.2 | Script1 | Conexión Wi-Fi con reintentos | Media | ⬜ Pendiente | | | | |
| PT-2.1 | Script2 | Unión al dominio sin OU | Alta | ⬜ Pendiente | | | | |
| PT-2.2 | Script2 | Unión al dominio con OU | Alta | ⬜ Pendiente | | | | |
| PT-2.3 | Script2 | Manejo de nombre duplicado | Media | ⬜ Pendiente | | | | |
| PT-2.4 | Script2 | Fallo de validación DC | Media | ⬜ Pendiente | | | | |
| PT-3.1 | Script3 | Instalación Winget normal | Alta | ⬜ Pendiente | | | | |
| PT-3.2 | Script3 | Instalación con timeout | Media | ⬜ Pendiente | | | | |
| PT-3.3 | Script3 | Instalación desde red | Media | ⬜ Pendiente | | | | |
| PT-3.4 | Script3 | Manejo de errores mixtos | Alta | ⬜ Pendiente | | | | |
| PT-SEC.1 | Seguridad | Credenciales cifradas | Alta | ⬜ Pendiente | | | | |
| PT-SEC.2 | Seguridad | Permisos de logs | Media | ⬜ Pendiente | | | | |
| PT-INT.1 | Integración | Flujo completo sin errores | Crítica | ⬜ Pendiente | | | | |

**Leyenda de Estado**:

- ⬜ Pendiente
- 🔄 En Progreso
- ✅ PASS
- ❌ FAIL
- ⚠️ BLOQUEADO

---

## Validación y Criterios de Aceptación

### Criterios Generales

El piloto se considera **EXITOSO** si cumple:

#### Funcionalidad Core (Obligatorio)

- [ ] **100%** de equipos renombrados correctamente (PT-1.1)
- [ ] **100%** de equipos conectados a Wi-Fi (PT-1.1)
- [ ] **100%** de equipos unidos al dominio (PT-2.1 o PT-2.2)
- [ ] **≥80%** de aplicaciones instaladas exitosamente (PT-3.1)

#### Seguridad (Obligatorio)

- [ ] Credenciales cifradas funcionan correctamente (PT-SEC.1)
- [ ] Logs tienen permisos restrictivos (PT-SEC.2)
- [ ] No hay exposición de credenciales en logs

#### Robustez (Deseable)

- [ ] Pre-validación detecta requisitos faltantes (PT-0.1, PT-0.2)
- [ ] Sistema maneja reintentos de Wi-Fi correctamente (PT-1.2)
- [ ] Sistema detecta DC antes de unir (PT-2.1)
- [ ] Timeouts de instalación funcionan (PT-3.2)
- [ ] Nombres duplicados se manejan automáticamente (PT-2.3)

#### Usabilidad (Deseable)

- [ ] Proceso completo toma <30 minutos por equipo
- [ ] Logs son claros y útiles para troubleshooting
- [ ] Resúmenes visuales son informativos

### Criterios de Aceptación por Módulo

#### Script0 - Pre-validación

- [ ] Detecta al menos 7 de 8 validaciones correctamente
- [ ] Distingue validaciones críticas de opcionales
- [ ] Exit codes correctos (0 o 1)
- [ ] Instrucciones de resolución son claras

#### Script1 - Wi-Fi y Renombrado

- [ ] Conexión Wi-Fi exitosa en ≤60 segundos (condiciones normales)
- [ ] Reintentos funcionan correctamente (al menos 3 de 5 exitosos en pruebas)
- [ ] Renombrado respeta límite de 15 caracteres NetBIOS
- [ ] Reinicio automático funciona

#### Script2 - Unión al Dominio

- [ ] Validación de DC usa al menos 2 de 3 métodos correctamente
- [ ] Unión sin OU: equipo aparece en CN=Computers
- [ ] Unión con OU: equipo aparece en OU especificada
- [ ] Nombres duplicados generan alternativas válidas
- [ ] AutoLogin funciona después de unir

#### Script3 - Instalación de Aplicaciones

- [ ] Instalaciones Winget: ≥80% de éxito
- [ ] Instalaciones de red: 100% de éxito (con rutas válidas)
- [ ] Timeouts se respetan (±5 segundos)
- [ ] Resumen muestra estadísticas correctas
- [ ] Errores no detienen proceso completo

### Métricas de Rendimiento

| Métrica | Objetivo | Aceptable | Inaceptable |
|---------|----------|-----------|-------------|
| Tiempo total (sin apps) | <10 min | <15 min | ≥20 min |
| Tiempo total (con 5 apps) | <25 min | <35 min | ≥45 min |
| Tasa de éxito Wi-Fi | 100% | ≥90% | <90% |
| Tasa de éxito unión AD | 100% | ≥95% | <95% |
| Tasa de éxito apps Winget | ≥90% | ≥80% | <80% |
| Falsos positivos Script0 | 0% | ≤5% | >5% |

---

## Problemas Comunes y Soluciones

### Script0 - Pre-validación

#### ❌ Error: "No se tienen privilegios de administrador"

**Causa**: PowerShell no se ejecutó como administrador

**Solución**:

```powershell
# Cerrar y reabrir PowerShell con click derecho → "Ejecutar como administrador"
```

#### ⚠️ Advertencia: "Winget no está instalado"

**Causa**: Winget no está presente (Windows 10 antiguo)

**Solución**:

```powershell
# Instalar App Installer desde Microsoft Store
# O descargar desde: https://github.com/microsoft/winget-cli/releases
```

#### ❌ Error: "Adaptador Wi-Fi no detectado"

**Causa**: Drivers de Wi-Fi no instalados

**Solución**:

```powershell
# Instalar drivers de Wi-Fi del fabricante
# Verificar en Device Manager que adaptador esté habilitado
```

---

### Script1 - Wi-Fi y Renombrado

#### ❌ Error: "No se pudo conectar a Wi-Fi después de 5 reintentos"

**Causa**: SSID incorrecto, contraseña incorrecta, o señal débil

**Solución**:

1. Verificar SSID en `config.ps1` coincide exactamente (case-sensitive)
2. Verificar contraseña de Wi-Fi es correcta
3. Acercar equipo al punto de acceso
4. Verificar que red use WPA2-PSK (no WPA3 solo, no WEP)

**Validación manual**:

```powershell
netsh wlan show networks
# Debe mostrar el SSID configurado
```

#### ❌ Error: "IP asignada es APIPA (169.254.x.x)"

**Causa**: DHCP no está respondiendo

**Solución**:

1. Verificar servidor DHCP está activo
2. Intentar renovar IP manualmente:

   ```powershell
   ipconfig /release
   ipconfig /renew
   ```

3. Verificar que red Wi-Fi tiene DHCP habilitado

#### ⚠️ Advertencia: "No se puede alcanzar el gateway"

**Causa**: Gateway configurado pero no responde a ping

**Solución**:

1. Verificar firewall del gateway permite ICMP
2. Verificar ruta de red:

   ```powershell
   route print
   Test-Connection -ComputerName [gateway_ip] -Count 4
   ```

#### ❌ Error: "Rename-Computer falló"

**Causa**: Nombre supera 15 caracteres o contiene caracteres inválidos

**Solución**:

1. Verificar `$HostName` en `config.ps1`:
   - Max 15 caracteres
   - Solo alfanuméricos y guiones
   - No puede empezar/terminar con guión
2. Cambiar a nombre válido

---

### Script2 - Unión al Dominio

#### ❌ Error: "No se pudo contactar con el controlador de dominio"

**Causa**: DC inaccesible, DNS incorrecto, o firewall bloqueando

**Solución**:

1. Verificar conectividad de red:

   ```powershell
   Test-Connection -ComputerName [dominio.local] -Count 4
   ```

2. Verificar DNS apunta a DC:

   ```powershell
   Get-DnsClientServerAddress -InterfaceAlias Wi-Fi
   # Debe mostrar IP del DC como DNS primario
   ```

3. Configurar DNS manualmente si necesario:

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses "192.168.1.10"
   ```

4. Verificar puertos abiertos:
   - TCP 389 (LDAP)
   - TCP 88 (Kerberos)
   - TCP 53 (DNS)

#### ❌ Error: "Credenciales de dominio inválidas"

**Causa**: Usuario/contraseña incorrectos o cuenta bloqueada

**Solución**:

1. Verificar credenciales manualmente en otro equipo
2. Verificar cuenta no está bloqueada en AD
3. Si usa credenciales cifradas, re-ejecutar `Setup-Credentials.ps1`
4. Si usa texto plano, verificar `$Useradmin` y `$Passadmin` en `config.ps1`

#### ❌ Error: "No se encontró la ruta de acceso a la OU"

**Causa**: `$OUPath` tiene formato incorrecto o OU no existe

**Solución**:

1. Verificar formato Distinguished Name:

   ```powershell
   # Correcto:
   $OUPath = "OU=Workstations,OU=Computers,DC=dominio,DC=local"

   # Incorrecto:
   $OUPath = "Workstations/Computers"
   ```

2. Verificar OU existe en AD:

   ```powershell
   # Desde DC
   Get-ADOrganizationalUnit -Identity "OU=Workstations,OU=Computers,DC=dominio,DC=local"
   ```

3. Verificar usuario tiene permisos en OU

#### ⚠️ Advertencia: "Nombre de equipo ya existe, usando alternativo"

**Causa**: Nombre duplicado en AD (comportamiento esperado)

**Validación**:

- Script debe generar nombre alternativo automáticamente
- Log debe mostrar nuevo nombre usado
- Proceso debe continuar sin intervención

---

### Script3 - Instalación de Aplicaciones

#### ❌ Error: "Winget no está disponible"

**Causa**: Winget no instalado o no en PATH

**Solución**:

1. Verificar instalación:

   ```powershell
   winget --version
   ```

2. Si falta, instalar App Installer desde Microsoft Store
3. Reiniciar PowerShell después de instalar

#### ❌ Error: "No se encontró el paquete [AppName]"

**Causa**: ID de Winget incorrecto o app no disponible

**Solución**:

1. Buscar ID correcto:

   ```powershell
   winget search [AppName]
   # Copiar ID exacto de la columna "Id"
   ```

2. Actualizar `apps.json` o `$apps` con ID correcto

#### ⏱️ Timeout: "La instalación excedió X segundos"

**Causa**: Timeout muy corto para aplicación grande o red lenta

**Solución**:

1. Aumentar timeout en `apps.json`:

   ```json
   {"Name": "Visual Studio", "Source": "Winget", "ID": "...", "Timeout": 1200}
   ```

2. Valores recomendados:
   - Apps pequeñas (Chrome, Notepad++): 180-300s
   - Apps medianas (VS Code, Office): 300-600s
   - Apps grandes (Visual Studio, AutoCAD): 900-1800s

#### ❌ Error: "No se puede acceder a la ruta de red"

**Causa**: Ruta de red inválida, sin permisos, o servidor apagado

**Solución**:

1. Verificar ruta manualmente:

   ```powershell
   Test-Path "\\SERVER\Apps\Installer.exe"
   # Debe retornar $true
   ```

2. Verificar permisos de lectura en recurso compartido
3. Verificar formato de ruta usa `\\` (doble backslash) en JSON

#### ⚠️ Exit code -1978335189

**Causa**: Aplicación ya está instalada (NO es error)

**Validación**:

- Log debe mostrar: "App ya instalada, continuando..."
- Resumen debe contar como exitosa
- Proceso debe continuar

---

### Logs y Troubleshooting

#### 📂 Archivos de Log

```powershell
# Logs principales
C:\Logs\setup_success.log   # Eventos exitosos
C:\Logs\setup_errors.log    # Errores

# Logs de scripts individuales (si se configuraron)
C:\Logs\script0_precheck.log
C:\Logs\script1_wifi.log
C:\Logs\script2_domain.log
C:\Logs\script3_apps.log
```

#### 🔍 Comandos Útiles de Troubleshooting

```powershell
# Ver últimas 50 líneas de log de éxito
Get-Content C:\Logs\setup_success.log -Tail 50

# Buscar errores en logs
Get-Content C:\Logs\*.log | Select-String "ERROR|FAIL|Exception"

# Verificar tareas programadas
Get-ScheduledTask | Where-Object {$_.TaskName -like "Script*Task"}

# Verificar estado de dominio
Get-ComputerInfo | Select-Object CsDomain, CsDomainRole

# Verificar conexión Wi-Fi
Get-NetAdapter | Where-Object {$_.Name -like "*Wi-Fi*"}
Get-NetIPAddress | Where-Object {$_.InterfaceAlias -like "*Wi-Fi*"}

# Verificar apps instaladas
winget list

# Ver permisos de archivos de log
icacls C:\Logs\setup_success.log
```

---

## Rollback y Recuperación

### Procedimientos de Rollback

#### Rollback después de Script1 (Renombrado)

Si el equipo fue renombrado pero necesita revertirse:

```powershell
# 1. Eliminar tarea programada
Unregister-ScheduledTask -TaskName "Script2Task" -Confirm:$false

# 2. Restaurar nombre original
Rename-Computer -NewName "NOMBRE-ORIGINAL" -Force -Restart
```

#### Rollback después de Script2 (Unión al Dominio)

Si el equipo fue unido al dominio pero necesita revertirse:

```powershell
# 1. Quitar del dominio
Remove-Computer -UnjoinDomainCredential (Get-Credential) -Force -Restart

# 2. Eliminar tarea programada
Unregister-ScheduledTask -TaskName "Script3Task" -Confirm:$false

# 3. Deshabilitar AutoLogin
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -ErrorAction SilentlyContinue

# 4. Eliminar equipo de AD (desde DC)
Remove-ADComputer -Identity "NOMBRE-EQUIPO" -Confirm:$false
```

#### Rollback después de Script3 (Aplicaciones)

Si necesita desinstalar aplicaciones instaladas:

```powershell
# Desinstalar apps de Winget
winget uninstall "Google.Chrome"
winget uninstall "Microsoft.VisualStudioCode"

# Listar todas las apps instaladas por Winget
winget list

# Desinstalar apps de red (usar panel de control o)
Get-Package -Name "CustomApp" | Uninstall-Package
```

### Recuperación ante Fallos

#### Fallo durante ejecución

Si un script falla a mitad de ejecución:

1. **Revisar logs**:

   ```powershell
   Get-Content C:\Logs\setup_errors.log -Tail 100
   ```

2. **Identificar punto de fallo**:
   - Script0: Resolver requisitos faltantes y re-ejecutar
   - Script1: Verificar Wi-Fi y renombrado manual si necesario
   - Script2: Verificar DC y credenciales, unir manualmente si necesario
   - Script3: Instalar apps faltantes manualmente

3. **Re-ejecutar desde punto de fallo**:

   ```powershell
   # Ejemplo: Si Script2 falló, ejecutar manualmente
   powershell -NoProfile -ExecutionPolicy Bypass -File "C:\AutoConfigPS\scripts\Script2.ps1"
   ```

#### Equipo no reinicia automáticamente

```powershell
# Verificar tarea programada se creó
Get-ScheduledTask -TaskName "Script2Task" # o Script3Task

# Si no existe, crearla manualmente o ejecutar script siguiente directamente
```

#### AutoLogin no funciona

```powershell
# Verificar configuración de registro
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Debe mostrar:
# DefaultUserName: [usuario]
# DefaultPassword: [contraseña]
# AutoAdminLogon: 1
```

### Limpieza Completa

Para eliminar completamente toda configuración de AutoConfigPS:

```powershell
# 1. Eliminar tareas programadas
Unregister-ScheduledTask -TaskName "Script2Task" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "Script3Task" -Confirm:$false -ErrorAction SilentlyContinue

# 2. Eliminar logs
Remove-Item -Path "C:\Logs\setup_*.log" -Force -ErrorAction SilentlyContinue

# 3. Eliminar archivos de configuración
Remove-Item -Path "C:\AutoConfigPS\SecureConfig" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\AutoConfigPS\config.ps1" -Force -ErrorAction SilentlyContinue

# 4. Deshabilitar AutoLogin
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -ErrorAction SilentlyContinue

# 5. Eliminar perfiles Wi-Fi (opcional)
netsh wlan delete profile name="[SSID]"
```

---

## Checklist de Aprobación

### ✅ Checklist de Preparación

- [ ] Infraestructura validada (DC, Wi-Fi, recursos de red)
- [ ] Credenciales de prueba creadas y validadas
- [ ] Archivos de configuración preparados
- [ ] Equipos de prueba identificados y preparados
- [ ] Equipo de pruebas capacitado en procedimientos
- [ ] Cronograma de pruebas definido
- [ ] Plan de rollback documentado

### ✅ Checklist de Ejecución

- [ ] Pre-validación (Script0) ejecutada: _____ de _____ equipos PASS
- [ ] Wi-Fi y renombrado (Script1) ejecutado: _____ de _____ equipos PASS
- [ ] Unión al dominio (Script2) ejecutado: _____ de _____ equipos PASS
- [ ] Instalación de apps (Script3) ejecutado: _____ de _____ equipos PASS
- [ ] Tasa de éxito general: ≥90% ✅ / <90% ❌

### ✅ Checklist de Validación

#### Funcionalidad

- [ ] Todos los equipos renombrados correctamente
- [ ] Todos los equipos conectados a Wi-Fi
- [ ] Todos los equipos unidos al dominio
- [ ] ≥80% de aplicaciones instaladas exitosamente
- [ ] Proceso completo toma <30 minutos por equipo

#### Seguridad

- [ ] Credenciales cifradas funcionan correctamente
- [ ] No hay credenciales expuestas en logs
- [ ] Permisos de logs son restrictivos (solo Administrators+SYSTEM)
- [ ] Archivos de configuración tienen permisos apropiados

#### Robustez

- [ ] Pre-validación detecta requisitos faltantes
- [ ] Reintentos de Wi-Fi funcionan correctamente
- [ ] Validación de DC previene fallos de unión
- [ ] Timeouts de instalación se respetan
- [ ] Nombres duplicados se manejan automáticamente
- [ ] Errores no detienen proceso completo

#### Logs y Trazabilidad

- [ ] Logs registran todos los eventos importantes
- [ ] Logs tienen formato legible y útil
- [ ] Resúmenes visuales son informativos
- [ ] Errores se registran con detalle suficiente

### ✅ Checklist de Problemas

**Problemas Críticos Encontrados**: _____ (deben ser 0 para aprobar)

- [ ] Problema 1: _________________________ Estado: __________
- [ ] Problema 2: _________________________ Estado: __________
- [ ] Problema 3: _________________________ Estado: __________

**Problemas No Críticos Encontrados**: _____ (pueden tener algunos)

- [ ] Problema 1: _________________________ Estado: __________
- [ ] Problema 2: _________________________ Estado: __________

### ✅ Decisión Final

**Fecha de Evaluación**: _____________________

**Resultado General**:

- [ ] ✅ **APROBADO** - Listo para producción
- [ ] ⚠️ **APROBADO CON OBSERVACIONES** - Listo con ajustes menores
- [ ] ❌ **RECHAZADO** - Requiere correcciones mayores

**Firmantes**:

| Rol | Nombre | Firma | Fecha |
|-----|--------|-------|-------|
| Administrador de Sistemas | | | |
| Técnico de Soporte | | | |
| Validador de Seguridad | | | |
| Gerente de TI | | | |

**Notas Adicionales**:
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________

---

## 📞 Contactos de Soporte

**Equipo de Desarrollo**:

- Desarrollador Principal: _____________________
- Email: _____________________

**Equipo de Infraestructura**:

- Administrador de AD: _____________________
- Email: _____________________
- Administrador de Red: _____________________
- Email: _____________________

**Escalamiento**:

- Gerente de TI: _____________________
- Email: _____________________

---

## 📚 Referencias

- [README.md](README.md) - Documentación general del proyecto
- [CHANGELOG.md](CHANGELOG.md) - Historial de cambios
- [LOG_IMPLEMENTACION.md](LOG_IMPLEMENTACION.md) - Detalles de implementación de v0.0.4
- [example-config.ps1](example-config.ps1) - Plantilla de configuración
- [example-apps.json](example-apps.json) - Plantilla de aplicaciones

---

**Versión del Documento**: 1.0
**Fecha de Creación**: 2026-01-28
**Última Actualización**: 2026-01-28
**AutoConfigPS**: v0.0.4
