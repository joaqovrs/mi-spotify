<#
.SINOPSIS
    Genera el instalador de Mi Music para Windows.
.DESCRIPTION
    Compila la app en modo release y despues la empaqueta con Inno Setup.
    Requiere Inno Setup (winget install --id JRSoftware.InnoSetup -e) y
    Flutter en C:\dev\flutter (la ruta de siempre en esta maquina).
#>

$ErrorActionPreference = "Stop"

$raiz = Split-Path -Parent $PSScriptRoot
$app = Join-Path $raiz "app"
$flutter = "C:\dev\flutter\bin\flutter.bat"
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"

if (-not (Test-Path $iscc)) {
    Write-Error "No se encontro Inno Setup en $iscc. Instalarlo con: winget install --id JRSoftware.InnoSetup -e"
}

Write-Host "Compilando la app en modo release..." -ForegroundColor Cyan
Push-Location $app
try {
    & $flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows fallo (codigo $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

Write-Host "Generando el instalador con Inno Setup..." -ForegroundColor Cyan
& $iscc "$PSScriptRoot\mi_music.iss"
if ($LASTEXITCODE -ne 0) {
    throw "ISCC.exe fallo (codigo $LASTEXITCODE)."
}

Write-Host "Listo: $PSScriptRoot\output\MiMusicSetup.exe" -ForegroundColor Green
