# Script de diagnostico para archivos de credenciales
# Ayuda a identificar problemas con archivos JSON corruptos o con BOM

param(
    [switch]$FixBOM  # Si se especifica, intenta reparar archivos con BOM
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTICO DE CREDENCIALES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determinar rutas de forma robusta (igual que otros scripts del proyecto)
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$SecureConfigPath = "$ScriptDir\SecureConfig"

Write-Host "[i] Directorio del script: $ScriptDir" -ForegroundColor Gray
Write-Host "[i] Ruta SecureConfig: $SecureConfigPath" -ForegroundColor Gray
Write-Host ""

$files = @(
    "$SecureConfigPath\cred_domain.json",
    "$SecureConfigPath\cred_local.json",
    "$SecureConfigPath\cred_wifi.json",
    "$SecureConfigPath\.aeskey"
)

$hasIssues = $false

foreach ($file in $files) {
    $fileName = Split-Path -Leaf $file
    Write-Host "Verificando: $fileName" -ForegroundColor Yellow
    
    if (-not (Test-Path $file)) {
        Write-Host "  [!] Archivo NO existe" -ForegroundColor Red
        $hasIssues = $true
        continue
    }
    
    Write-Host "  [OK] Archivo existe" -ForegroundColor Green
    
    # Verificar tamano
    $fileSize = (Get-Item $file).Length
    Write-Host "  [i] Tamano: $fileSize bytes" -ForegroundColor Gray
    
    if ($fileSize -eq 0) {
        Write-Host "  [!] PROBLEMA: Archivo vacio" -ForegroundColor Red
        $hasIssues = $true
        continue
    }
    
    # Solo para archivos JSON
    if ($file -match "\.json$") {
        # Leer primeros bytes para detectar BOM
        $bytes = [System.IO.File]::ReadAllBytes($file)
        
        $hasBOM = $false
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Write-Host "  [!] PROBLEMA: Archivo tiene BOM UTF-8" -ForegroundColor Red
            $hasBOM = $true
            $hasIssues = $true
        } else {
            Write-Host "  [OK] Sin BOM" -ForegroundColor Green
        }
        
        # Intentar parsear JSON
        try {
            $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
            $content = $content.TrimStart([char]0xFEFF)  # Remover BOM si existe
            $json = $content | ConvertFrom-Json
            
            # Verificar estructura
            if ($json.UserName -or $json.EncryptedPassword) {
                Write-Host "  [OK] Estructura JSON valida" -ForegroundColor Green
                Write-Host "  [i] Usuario: $($json.UserName)" -ForegroundColor Gray
            } else {
                Write-Host "  [!] PROBLEMA: Estructura JSON incompleta" -ForegroundColor Red
                $hasIssues = $true
            }
            
        } catch {
            Write-Host "  [!] PROBLEMA: No se puede parsear JSON" -ForegroundColor Red
            Write-Host "  [!] Error: $($_.Exception.Message)" -ForegroundColor Red
            $hasIssues = $true
        }
        
        # Opcion de reparar BOM
        if ($hasBOM -and $FixBOM) {
            Write-Host "  [i] Intentando reparar (remover BOM)..." -ForegroundColor Yellow
            
            try {
                $backupFile = "$file.bak"
                Copy-Item -Path $file -Destination $backupFile -Force
                Write-Host "  [i] Backup creado: $backupFile" -ForegroundColor Gray
                
                # Leer, remover BOM y reescribir
                $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
                $content = $content.TrimStart([char]0xFEFF)
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($file, $content, $utf8NoBom)
                
                Write-Host "  [OK] Archivo reparado" -ForegroundColor Green
            } catch {
                Write-Host "  [!] Error al reparar: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host ""
}

# Verificar permisos del directorio
Write-Host "Verificando permisos de SecureConfig..." -ForegroundColor Yellow
if (Test-Path $SecureConfigPath) {
    $acl = Get-Acl $SecureConfigPath
    Write-Host "  [i] Propietario: $($acl.Owner)" -ForegroundColor Gray
    Write-Host "  [i] Accesos configurados:" -ForegroundColor Gray
    foreach ($access in $acl.Access) {
        Write-Host "    - $($access.IdentityReference): $($access.FileSystemRights)" -ForegroundColor Gray
    }
} else {
    Write-Host "  [!] Directorio SecureConfig no existe" -ForegroundColor Red
    $hasIssues = $true
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($hasIssues) {
    Write-Host "  RESULTADO: PROBLEMAS DETECTADOS" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SOLUCIONES:" -ForegroundColor Yellow
    Write-Host "  1. Regenerar credenciales: .\scripts\Setup-Credentials.ps1" -ForegroundColor Gray
    Write-Host "  2. Reparar archivos BOM: .\DIAGNOSTICO_CREDENCIALES.ps1 -FixBOM" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "  RESULTADO: TODO CORRECTO" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}
