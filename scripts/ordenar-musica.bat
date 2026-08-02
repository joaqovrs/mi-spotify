@echo off
rem ---------------------------------------------------------------------------
rem  Ordenar musica - doble clic para usar.
rem
rem  Windows no ejecuta los .ps1 con doble clic (los abre en el Bloc de notas),
rem  asi que este .bat es el que se puede clickear: muestra primero que haria y
rem  recien mueve las carpetas si se lo confirma.
rem
rem  Para cambiar la carpeta de destino, editar la linea DESTINO de abajo.
rem ---------------------------------------------------------------------------

setlocal
title Ordenar musica

set "SCRIPT=%~dp0ordenar-musica.ps1"
set "DESTINO=C:\dev\musica"

if not exist "%SCRIPT%" (
    echo No se encontro el script: "%SCRIPT%"
    goto :fin
)

echo.
echo   Esto es solo una vista previa. Todavia no se mueve nada.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Destino "%DESTINO%"

rem Codigo 1 = error, codigo 2 = no habia nada para mover. En ambos casos no se pregunta.
if errorlevel 1 goto :fin

echo.
set "RESP="
set /p "RESP=Mover las carpetas ahora? (S/N): "
if /i not "%RESP%"=="S" (
    echo.
    echo   Cancelado. No se movio nada.
    goto :fin
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Destino "%DESTINO%" -Aplicar
if errorlevel 1 goto :fin

echo.
echo   Ya se puede subir "%DESTINO%" por WinSCP a /srv/musica
echo.

:fin
echo.
pause
endlocal
