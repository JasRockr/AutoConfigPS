# Solución: Error "Los datos del nivel de raíz no son válidos"

## 📋 Descripción del Problema

El error **"Los datos del nivel de raíz no son válidos. línea 1, posición 1"** ocurre cuando PowerShell intenta leer archivos JSON que tienen:

1. **BOM UTF-8** (Byte Order Mark) - PowerShell 5.1 agrega esto automáticamente con `Out-File -Encoding UTF8`
2. **Archivos corruptos o vacíos**
3. **Codificación incorrecta**

## ✅ Soluciones Implementadas

### 1. **Corrección en SecureCredentialManager.ps1**

**Cambio en Export-SecureCredential:**
```powershell
# ANTES (causaba BOM)
$credObject | ConvertTo-Json | Out-File -FilePath $Path -Encoding UTF8 -Force

# AHORA (sin BOM)
$jsonContent = $credObject | ConvertTo-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Path, $jsonContent, $utf8NoBom)
```

**Cambio en Import-SecureCredential:**
```powershell
# AHORA incluye:
# - Validación de archivo existente
# - Remoción automática de BOM si existe
# - Validación de estructura JSON
# - Manejo de errores detallado
```

### 2. **Mejoras en config.ps1**

Ahora tiene manejo de errores robusto que muestra:
- Mensaje de error claro
- Ruta del archivo problemático
- Soluciones sugeridas

### 3. **Script de Diagnóstico**

Creado: `DIAGNOSTICO_CREDENCIALES.ps1`

## 🔧 Pasos para Resolver

### Opción A: Regenerar Credenciales (RECOMENDADO)

En el equipo de pruebas, ejecuta:

```powershell
# 1. Eliminar credenciales antiguas (opcional)
Remove-Item -Path ".\SecureConfig\*.json" -Force

# 2. Regenerar credenciales con la versión corregida
.\scripts\Setup-Credentials.ps1

# 3. Verificar que se crearon correctamente
.\DIAGNOSTICO_CREDENCIALES.ps1
```

### Opción B: Reparar Archivos Existentes

Si deseas mantener las credenciales actuales:

```powershell
# 1. Ejecutar diagnóstico con reparación automática
.\DIAGNOSTICO_CREDENCIALES.ps1 -FixBOM

# 2. Verificar resultado
.\DIAGNOSTICO_CREDENCIALES.ps1
```

### Opción C: Verificación Manual

```powershell
# Ver contenido del archivo (primeros bytes)
$bytes = [System.IO.File]::ReadAllBytes(".\SecureConfig\cred_domain.json")
$bytes[0..5]  # Si ves: 239, 187, 191 = tiene BOM

# Parsear JSON
$content = [System.IO.File]::ReadAllText(".\SecureConfig\cred_domain.json", [System.Text.Encoding]::UTF8)
$content = $content.TrimStart([char]0xFEFF)  # Remover BOM
$content | ConvertFrom-Json
```

## 🧪 Verificación Post-Corrección

Después de aplicar la solución, ejecuta:

```powershell
# 1. Diagnóstico completo
.\DIAGNOSTICO_CREDENCIALES.ps1

# 2. Prueba de carga de config
. .\config.ps1

# 3. Si todo está bien, ejecuta init
.\init.bat
```

## 📊 Salida Esperada del Diagnóstico

### ✅ Salida Correcta:
```
Verificando: cred_domain.json
  [OK] Archivo existe
  [i] Tamaño: 245 bytes
  [OK] Sin BOM
  [OK] Estructura JSON válida
  [i] Usuario: admin@dominio.local

========================================
  RESULTADO: TODO CORRECTO
========================================
```

### ❌ Salida con Problemas:
```
Verificando: cred_domain.json
  [OK] Archivo existe
  [i] Tamaño: 248 bytes
  [!] PROBLEMA: Archivo tiene BOM UTF-8
  [!] PROBLEMA: No se puede parsear JSON
  [!] Error: Los datos del nivel de raíz no son válidos...

========================================
  RESULTADO: PROBLEMAS DETECTADOS
========================================

SOLUCIONES:
  1. Regenerar credenciales: .\scripts\Setup-Credentials.ps1
  2. Reparar archivos BOM: .\DIAGNOSTICO_CREDENCIALES.ps1 -FixBOM
```

## 📝 Notas Técnicas

### Por qué ocurre el BOM en PowerShell 5.1

PowerShell 5.1 tiene comportamientos diferentes a PowerShell 7+:

| Comando | PS 5.1 | PS 7+ |
|---------|--------|-------|
| `Out-File -Encoding UTF8` | UTF-8 **CON BOM** ❌ | UTF-8 sin BOM ✅ |
| `[System.IO.File]::WriteAllText()` | Depende del Encoding ✅ | Depende del Encoding ✅ |

**Solución**: Usar `System.Text.UTF8Encoding($false)` para forzar sin BOM.

### BOM (Byte Order Mark)

- **Con BOM**: `EF BB BF` (3 bytes al inicio)
- **Sin BOM**: Inicio directo con `{` (JSON)

El BOM no es parte del estándar JSON y causa errores en parsers estrictos.

## 🔍 Debugging Adicional

Si el problema persiste:

```powershell
# Ver logs detallados
Get-Content C:\Logs\setup_errors.log -Tail 20
Get-Content C:\Logs\setup_success.log | Select-String "ERROR|DEBUG-CONFIG"

# Verificar ubicación
Get-Location  # Debe estar en la raíz del proyecto

# Verificar permisos
icacls .\SecureConfig
```

## 🆘 Soporte

Si necesitas ayuda adicional, proporciona:

1. Salida completa de `.\DIAGNOSTICO_CREDENCIALES.ps1`
2. Últimas líneas de `C:\Logs\setup_errors.log`
3. Versión de PowerShell: `$PSVersionTable.PSVersion`
4. Sistema operativo: `[System.Environment]::OSVersion`

---

**Fecha de corrección:** 18 de febrero de 2026  
**Versión:** 0.0.4.1  
**Archivos modificados:**
- `scripts/SecureCredentialManager.ps1`
- `config.ps1`
- Nuevo: `DIAGNOSTICO_CREDENCIALES.ps1`
