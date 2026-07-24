REM Description: Punto de entrada de AutoConfigPS - eleva privilegios y lanza el
REM              orquestador unico Invoke-AutoConfigPS.ps1 (arquitectura v0.1.0).
REM Author: Json Rivera (JasRockr!)
REM Requirements: Windows 10 / 11, PowerShell 5.1+
REM
REM Changelog v2.0 (migracion a orquestador):
REM   - Ya NO llama a scripts\Script0.ps1 / Script1.ps1 por separado: el
REM     orquestador Invoke-AutoConfigPS.ps1 hace la pre-validacion y todo el
REM     pipeline internamente, reanudandose solo tras cada reinicio.

@echo off
title AutoConfigPS
color 0A
cls

:: Ruta raiz del proyecto (donde vive este .bat)
SET ROOT=%~dp0
SET ORCHESTRATOR=%ROOT%Invoke-AutoConfigPS.ps1

:: Validar que el orquestador existe
if not exist "%ORCHESTRATOR%" (
    powershell -Command "Write-Host '[!ERROR] No se encontro Invoke-AutoConfigPS.ps1 en: "%ROOT%". Valida la ruta e intenta nuevamente.' -ForegroundColor Red"
    pause
    exit /b 1
)

echo.
echo ========================================
echo   INICIANDO AUTOCONFIGPS
echo ========================================
echo.
echo El orquestador validara los requisitos del sistema y ejecutara el
echo pipeline completo de configuracion. Si hace falta reiniciar, el
echo equipo continuara solo al arrancar de nuevo (sin intervencion manual).
echo.

:: Ejecutar el orquestador elevado. La ventana queda abierta (-NoExit) en el
:: primer arranque para que se vea el resultado de la pre-validacion; en las
:: reanudaciones automaticas tras reinicio, el orquestador corre en segundo
:: plano via la tarea programada 'AutoConfigPS-Orchestrator' (SYSTEM), no por
:: este .bat.
powershell -Command "Start-Process powershell -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File \"%ORCHESTRATOR%\"' -Verb RunAs"

if %ERRORLEVEL% neq 0 (
    powershell -Command "Write-Host '[!ERROR] No se pudo iniciar el orquestador (¿se cancelo la solicitud de elevacion?).' -ForegroundColor Red"
    pause
    exit /b 1
) else (
    powershell -Command "Write-Host '[OK] Orquestador iniciado en una ventana elevada. Sigue el progreso alli o en C:\Logs\.' -ForegroundColor Green"
)

color 07
timeout /t 5
exit /b 0
