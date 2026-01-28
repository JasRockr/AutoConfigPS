REM Description: Script de inicio para ejecutar un script de PowerShell como Admin
REM Author: Json
REM Date: 2025-03-20
REM Version: 1.1
REM Usage: init.bat
REM Requirements: Windows 10 / 11
REM
REM Changelog v1.1 (2026-01-28):
REM   - Agregada pre-validación con Script0.ps1
REM   - Solo continúa si pasa todas las validaciones críticas

@echo off
title Inicio
color 0A
cls

:: Definir la carpeta de scripts (relativa a la ruta raíz)
SET SCRIPTS_DIR=scripts
SET SCRIPT_PRECHECK=script0.ps1
SET SCRIPT_INIT=script1.ps1

:: Crear o Limpiar el archivo de log
SET LOG=C:\Logs\LogExec.log
:: echo. > %LOG%


:: Obtener la ruta raíz del script
SET ROOT=%~dp0

:: Definir la ruta completa de la carpeta de scripts
SET FULL_PATH=%ROOT%%SCRIPTS_DIR%


:: Validar si la carpeta de scripts existe
:: echo [%DATE% %TIME%] Validando carpeta de scripts: %FULL_PATH% >> %LOG%
if not exist "%FULL_PATH%" (
    powershell -Command "Write-Host '[!ERROR] La carpeta de scripts no existe: "%FULL_PATH%". Valida la ruta e intenta nuevamente.' -ForegroundColor Red"
    pause
    exit /b 1
)

:: Validar si el script de pre-validación existe
:: echo [%DATE% %TIME%] Validando script de pre-validación: %FULL_PATH%\%SCRIPT_PRECHECK% >> %LOG%
if not exist "%FULL_PATH%\%SCRIPT_PRECHECK%" (
    powershell -Command "Write-Host '[!WARN] Script de pre-validación no encontrado. Continuando sin validación...' -ForegroundColor Yellow"
    goto :SKIP_PRECHECK
)

:: Ejecutar pre-validación
:: echo [%DATE% %TIME%] Ejecutando pre-validación: %FULL_PATH%\%SCRIPT_PRECHECK% >> %LOG%
echo.
echo ========================================
echo   EJECUTANDO PRE-VALIDACION
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%FULL_PATH%\%SCRIPT_PRECHECK%"

:: Validar el código de salida de pre-validación
if %ERRORLEVEL% neq 0 (
    echo.
    powershell -Command "Write-Host '[!ERROR] Pre-validación falló. No se puede continuar con la configuración.' -ForegroundColor Red"
    echo.
    echo Resuelve los problemas críticos y ejecuta este script nuevamente.
    pause
    exit /b 1
)

:SKIP_PRECHECK

:: Validar si el script principal existe
:: echo [%DATE% %TIME%] Validando script principal: %FULL_PATH%\%SCRIPT_INIT% >> %LOG%
if not exist "%FULL_PATH%\%SCRIPT_INIT%" (
    powershell -Command "Write-Host '[!ERROR] El script %SCRIPT_INIT% no existe en: "%FULL_PATH%". Valida la ruta e intenta nuevamente.' -ForegroundColor Red"
    pause
    exit /b 1
)

echo.
echo ========================================
echo   INICIANDO CONFIGURACION AUTOMATICA
echo ========================================
echo.

:: Ejecutar el script principal como Admin
:: echo [%DATE% %TIME%] Ejecutando script principal: %FULL_PATH%\%SCRIPT_INIT% >> %LOG%
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%FULL_PATH%\%SCRIPT_INIT%\"' -Verb RunAs"

:: Validar el código de salida
:: echo [%DATE% %TIME%] Validando código de salida: %ERRORLEVEL% >> %LOG%
if %ERRORLEVEL% neq 0 (
    powershell -Command "Write-Host '[!ERROR] Ha ocurrido un error al ejecutar el script "%SCRIPT_INIT%" en: "%FULL_PATH%".' -ForegroundColor Red"
    pause
    exit /b 1
) else (
    powershell -Command "Write-Host '[SUCCESS] Script "%SCRIPT_INIT%" ejecutado correctamente en: "%FULL_PATH%".' -ForegroundColor Green"
)

:: Restaurar el color de la consola
color 07

:: Esperar 5 segundos
timeout /t 5

:: Salir
:: echo [%DATE% %TIME%] Saliendo del script de inicio... >> %LOG%
exit /b 0