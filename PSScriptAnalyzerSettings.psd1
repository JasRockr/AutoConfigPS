@{
    # Reglas excluidas a proposito para todo el proyecto (usadas por
    # .github/workflows/validate-scripts.yml y localmente con
    # `Invoke-ScriptAnalyzer -Settings .\PSScriptAnalyzerSettings.psd1`).
    # Cada exclusion tiene un motivo documentado - no es un silenciado generico.
    ExcludeRules = @(
        # El proyecto NO usa DPAPI (modules/CredentialStore.ps1 usa AES con clave
        # propia, ver CLAUDE.md/README seccion Seguridad, porque DPAPI en modo
        # usuario no es legible por SYSTEM). Convertir una contrasena ya
        # descifrada -o el fallback legacy de texto plano documentado en
        # config.ps1- a SecureString es necesario para pasarla a APIs de Windows
        # (PSCredential, Add-Computer, registro de autologin), no un descuido.
        'PSAvoidUsingConvertToSecureStringWithPlainText',

        # Falso positivo: el "ComputerName hardcodeado" es 8.8.8.8 (DNS publico
        # de Google) usado unicamente en Preflight.ps1 para una prueba basica de
        # conectividad a Internet - no es informacion sensible del sistema.
        'PSAvoidUsingComputerNameHardcoded'
    )
}
