REM Description: Punto de entrada de AutoConfigPS - se autoeleva, configura
REM              credenciales cifradas si hace falta, y lanza el orquestador
REM              unico Invoke-AutoConfigPS.ps1.
REM Author: Json Rivera (JasRockr!)
REM Requirements: Windows 10 / 11, PowerShell 5.1+
REM
REM Changelog v2.2 (autoelevacion de init.bat):
REM   - BUG ENCONTRADO EN HARDWARE REAL: init.bat corria SIN elevar (solo
REM     elevaba a los procesos hijos con -Verb RunAs). Los archivos de
REM     credenciales quedan con ACL restringida a Administrators+SYSTEM, y un
REM     cmd.exe sin elevar (token filtrado por UAC, aunque la cuenta sea
REM     administradora) no puede ver esos archivos ni para comprobar que
REM     existen - "if exist" los reporta como inexistentes SIEMPRE, generando
REM     un loop infinito: el asistente guardaba las credenciales bien, pero
REM     init.bat nunca podia confirmarlo.
REM   - Fix: init.bat se autoeleva al inicio (net session + relanzarse con
REM     Start-Process -Verb RunAs si no esta elevado). Con todo el script ya
REM     corriendo elevado, "if exist" ve los archivos correctamente, y ya no
REM     hace falta -Verb RunAs en cada proceso hijo (baja de hasta 3 prompts
REM     de UAC a 1 solo, al principio).
REM
REM Changelog v2.1 (asistente de credenciales automatico):
REM   - Si no existen credenciales cifradas (SecureConfig\), lanza
REM     scripts\Setup-Credentials.ps1 y espera a que termine antes de
REM     continuar. Antes habia que ejecutarlo a mano por separado, y al
REM     invocarlo directo (sin -ExecutionPolicy Bypass) fallaba con el error
REM     estandar de Windows "la ejecucion de scripts esta deshabilitada".
REM
REM   El orquestador Invoke-AutoConfigPS.ps1 hace la pre-validacion y todo el
REM   pipeline internamente, reanudandose solo tras cada reinicio.

@echo off
title AutoConfigPS
color 0A
cls

:: Autoelevarse si hace falta. "net session" solo funciona (errorlevel 0) si
:: el proceso ya tiene privilegios de administrador - es el chequeo estandar
:: para detectar elevacion en batch. Si no esta elevado, se relanza este
:: mismo .bat con UAC y la instancia actual (sin elevar) se cierra sin hacer
:: nada mas: todo el resto del script solo debe correr ya elevado.
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando privilegios de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b 0
)

:: Ruta raiz del proyecto (donde vive este .bat)
SET ROOT=%~dp0
SET ORCHESTRATOR=%ROOT%Invoke-AutoConfigPS.ps1
SET SETUP_CREDENTIALS=%ROOT%scripts\Setup-Credentials.ps1
SET CONFIG_PS1=%ROOT%config.ps1
SET DOMAIN_CRED=%ROOT%SecureConfig\cred_domain.json
SET WIFI_CRED=%ROOT%SecureConfig\cred_wifi.json
SET APPS_JSON=%ROOT%apps.json

:: Validar que el orquestador existe
if not exist "%ORCHESTRATOR%" (
    powershell -Command "Write-Host '[!ERROR] No se encontro Invoke-AutoConfigPS.ps1 en: "%ROOT%". Valida la ruta e intenta nuevamente.' -ForegroundColor Red"
    pause
    exit /b 1
)

:: Si faltan las credenciales cifradas obligatorias (dominio y Wi-Fi), lanzar
:: el asistente ANTES del orquestador. Ya estamos elevados (ver arriba), asi
:: que corre directo en esta misma ventana - sin -Verb RunAs, sin ventana
:: aparte, y su codigo de salida (no un Test-Path posterior) es lo que decide
:: si continuar: %ERRORLEVEL% no tiene el problema de visibilidad de ACL que
:: si tiene "if exist" sobre archivos restringidos.
if not exist "%CONFIG_PS1%" goto :RUN_CREDENTIALS
if not exist "%DOMAIN_CRED%" goto :RUN_CREDENTIALS
if not exist "%WIFI_CRED%" goto :RUN_CREDENTIALS
if not exist "%APPS_JSON%" goto :RUN_CREDENTIALS
goto :SKIP_CREDENTIALS

:RUN_CREDENTIALS
if not exist "%SETUP_CREDENTIALS%" (
    powershell -Command "Write-Host '[!ERROR] Faltan credenciales cifradas y no se encontro scripts\Setup-Credentials.ps1 para configurarlas.' -ForegroundColor Red"
    pause
    exit /b 1
)

echo.
echo ========================================
echo   ASISTENTE DE CONFIGURACION INICIAL
echo ========================================
echo.
echo Falta configuracion (config, credenciales o lista de apps). El asistente
echo te guiara por los pasos que falten (los ya configurados se omiten).
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_CREDENTIALS%"

if %ERRORLEVEL% neq 0 (
    powershell -Command "Write-Host '[!ERROR] La configuracion de credenciales no se completo o fue cancelada. Ejecuta init.bat nuevamente cuando quieras reintentar.' -ForegroundColor Red"
    pause
    exit /b 1
)

:SKIP_CREDENTIALS

:: Reset de estado para arrancar limpio. init.bat es el punto de entrada MANUAL:
:: los reinicios del proceso NO pasan por aca, retoman via la tarea programada
:: AutoConfigPS-Orchestrator (que llama al orquestador directamente). Por eso es
:: seguro borrar aca el estado de una corrida anterior: nunca se ejecuta durante
:: el ciclo de reinicios. Esto evita que un paso que quedo Skipped/Completed con
:: datos viejos (ej. Wi-Fi conectado a la red equivocada, o un fallo previo)
:: impida un reintento correcto - todos los pasos son idempotentes, asi que
:: re-ejecutar reevalua cada uno contra el estado real del equipo. En la PRIMERA
:: corrida el directorio no existe todavia, asi que no se borra nada.
SET STATE_DIR=C:\ProgramData\AutoConfigPS
if exist "%STATE_DIR%" (
    echo.
    echo Se detecto estado de una corrida anterior - limpiando para empezar desde cero...
    rmdir /s /q "%STATE_DIR%"
    if exist "%STATE_DIR%" (
        powershell -Command "Write-Host '[!] No se pudo borrar del todo %STATE_DIR% (puede haber un proceso usandolo). El orquestador reintentara igual.' -ForegroundColor Yellow"
    ) else (
        powershell -Command "Write-Host '[OK] Estado anterior limpiado. Se iniciara el pipeline desde cero.' -ForegroundColor Green"
    )
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

:: Ya estamos elevados, asi que el hijo hereda la elevacion sin necesitar
:: -Verb RunAs (evita un segundo prompt de UAC). Se abre en ventana aparte
:: (-NoExit) para que el progreso siga visible aunque esta consola se cierre.
powershell -Command "Start-Process powershell -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File \"%ORCHESTRATOR%\"'"

if %ERRORLEVEL% neq 0 (
    powershell -Command "Write-Host '[!ERROR] No se pudo iniciar el orquestador.' -ForegroundColor Red"
    pause
    exit /b 1
) else (
    powershell -Command "Write-Host '[OK] Orquestador iniciado en una ventana aparte. Sigue el progreso alli o en C:\Logs\.' -ForegroundColor Green"
)

color 07
timeout /t 5
exit /b 0
