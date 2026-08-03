@echo off
chcp 65001 >nul
rem ---------------------------------------------------------------------------
rem  Generar instalador - doble clic para usar.
rem
rem  Compila la app en modo release y arma el instalador con Inno Setup.
rem  El resultado queda en installer\output\MiMusicSetup.exe.
rem
rem  Windows no ejecuta los .ps1 con doble clic (los abre en el Bloc de notas),
rem  por eso este .bat es el que se puede clickear.
rem ---------------------------------------------------------------------------

setlocal
title Generar instalador de Mi Music

set "SCRIPT=%~dp0generar-instalador.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
pause
endlocal
