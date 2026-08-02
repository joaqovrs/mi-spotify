@echo off
chcp 65001 >nul
rem ---------------------------------------------------------------------------
rem  Unificar album - doble clic para usar.
rem
rem  Deja una carpeta con las etiquetas que Navidrome necesita para verla como
rem  UN solo album. Muestra primero que haria y recien escribe si se confirma.
rem
rem  Windows no ejecuta los .ps1 con doble clic (los abre en el Bloc de notas),
rem  por eso este .bat es el que se puede clickear.
rem ---------------------------------------------------------------------------

setlocal
title Unificar album

set "SCRIPT=%~dp0unificar-album.ps1"

if not exist "%SCRIPT%" (
    echo No se encontro el script: "%SCRIPT%"
    goto :fin
)

echo.
echo   Arrastra aqui la carpeta del album y presiona Enter.
echo.
set "CARPETA="
set /p "CARPETA=Carpeta: "

rem Al arrastrar, Windows agrega comillas. Se sacan para no duplicarlas.
set CARPETA=%CARPETA:"=%

if "%CARPETA%"=="" (
    echo.
    echo   No indicaste ninguna carpeta.
    goto :fin
)

echo.
echo   Nombre del album. Enter = usar el nombre de la carpeta.
set "ALBUM="
set /p "ALBUM=Album: "

echo.
echo   Artista del album. Enter = usar el que mas se repita.
set "ARTISTA="
set /p "ARTISTA=Artista del album: "

set "OPCIONES=-Compilacion -NumerarPorNombre"
if not "%ALBUM%"=="" set "OPCIONES=%OPCIONES% -Album "%ALBUM%""
if not "%ARTISTA%"=="" set "OPCIONES=%OPCIONES% -AlbumArtist "%ARTISTA%""

echo.
echo   Esto es solo una vista previa. Todavia no se escribe nada.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Carpeta "%CARPETA%" %OPCIONES%

rem Codigo 1 = error, codigo 2 = no habia audio. En ambos casos no se pregunta.
if errorlevel 1 goto :fin

echo.
set "RESP="
set /p "RESP=Escribir las etiquetas ahora? (S/N): "
if /i not "%RESP%"=="S" (
    echo.
    echo   Cancelado. No se modifico ningun archivo.
    goto :fin
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Carpeta "%CARPETA%" %OPCIONES% -Aplicar

:fin
echo.
pause
endlocal
