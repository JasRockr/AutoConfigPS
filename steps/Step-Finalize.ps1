# steps/Step-Finalize.ps1
# Paso 5 (ultimo): crear el archivo de confirmacion. La tarea de notificacion
# 'AutoConfigPS-Notify' ya fue registrada por el orquestador desde el primer
# arranque (ver Invoke-AutoConfigPS.ps1) - lee status.json en cada logon, asi que
# no necesita registrarse aqui: ya viene mostrando "en progreso" en logons
# anteriores y ahora mostrara "completado" automaticamente en el proximo.

function Invoke-StepFinalize {
    <#
    .SYNOPSIS
        Cierra el pipeline: crea el archivo de confirmacion final.
    .RETURNS
        Hashtable con Status ('Success'|'Failed'), Message, Retryable.
    #>

    try {
        $confirmationFile = Join-Path $env:SystemDrive 'ConfiguracionCompleta.txt'
        Set-Content -Path $confirmationFile -Value "Configuracion automatica completada el $(Get-Date)."
        Write-SuccessLog "Archivo de confirmacion creado: $confirmationFile"

        return @{ Status = 'Success'; Message = 'Configuracion finalizada'; Retryable = $false }
    } catch {
        Write-ErrorLog "Error al finalizar la configuracion: $($_.Exception.Message)"
        return @{ Status = 'Failed'; Message = $_.Exception.Message; Retryable = $true }
    }
}
