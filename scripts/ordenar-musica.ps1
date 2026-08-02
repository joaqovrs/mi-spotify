<#
.SINOPSIS
    Ordena albumes descargados en la estructura Artista/Album que espera /srv/musica.

.DESCRIPCION
    Soulseek guarda las descargas como complete\<usuario>\<carpeta del album>, donde
    <usuario> es el apodo de quien compartia el archivo, no el artista. Este script lee
    las etiquetas de los propios archivos de audio y mueve cada carpeta de album a
    Destino\<Artista>\<Album>, creando las carpetas que hagan falta.

    No necesita nada instalado:
      - FLAC : lector propio del bloque VORBIS_COMMENT.
      - MP3  : Shell.Application (Windows no sabe leer etiquetas FLAC, por eso el lector propio).

    Por defecto solo SIMULA. Para mover de verdad hay que pasar -Aplicar.

.EJEMPLO
    .\ordenar-musica.ps1
    Muestra que haria, sin tocar nada.

.EJEMPLO
    .\ordenar-musica.ps1 -Aplicar
    Mueve las carpetas.
#>

[CmdletBinding()]
param(
    [string] $Origen  = "$env:USERPROFILE\OneDrive\Documentos\Soulseek Downloads\complete",
    [string] $Destino = "$env:USERPROFILE\Music\ordenado",
    [switch] $Aplicar
)

$ErrorActionPreference = 'Stop'

$EXTENSIONES = @('.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wma', '.wav')

# ---------------------------------------------------------------------------
# Lectura de etiquetas
# ---------------------------------------------------------------------------

# Lee el bloque VORBIS_COMMENT de un FLAC. El formato es:
#   "fLaC" y luego una cadena de bloques; cada uno arranca con 4 bytes de cabecera:
#   el bit alto del primero marca "ultimo bloque", los 7 bits restantes son el tipo
#   (4 = VORBIS_COMMENT) y los otros 3 bytes son el largo en big endian.
#   Adentro del bloque los enteros son little endian y cada comentario es "CLAVE=valor".
function Leer-EtiquetasFlac {
    param([string] $Ruta)

    $etiquetas = @{}
    $fs = [System.IO.File]::Open($Ruta, 'Open', 'Read', 'ReadWrite')
    try {
        $br = New-Object System.IO.BinaryReader($fs)

        if ([System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4)) -ne 'fLaC') { return $etiquetas }

        while ($true) {
            $cab = $br.ReadBytes(4)
            if ($cab.Length -lt 4) { break }

            $ultimo = ($cab[0] -band 0x80) -ne 0
            $tipo   = [int]($cab[0] -band 0x7F)
            # Multiplicacion en vez de -shl a proposito: mas dificil de leer mal.
            $largo  = ([int]$cab[1] * 65536) + ([int]$cab[2] * 256) + [int]$cab[3]

            if ($tipo -eq 4) {
                $datos = $br.ReadBytes($largo)
                $p = 0

                $largoVendor = [BitConverter]::ToUInt32($datos, $p)
                $p += 4 + $largoVendor

                $cantidad = [BitConverter]::ToUInt32($datos, $p)
                $p += 4

                for ($i = 0; $i -lt $cantidad; $i++) {
                    if ($p + 4 -gt $datos.Length) { break }
                    $largoComentario = [BitConverter]::ToUInt32($datos, $p)
                    $p += 4
                    if ($p + $largoComentario -gt $datos.Length) { break }

                    $texto = [System.Text.Encoding]::UTF8.GetString($datos, $p, $largoComentario)
                    $p += $largoComentario

                    $igual = $texto.IndexOf('=')
                    if ($igual -gt 0) {
                        $clave = $texto.Substring(0, $igual).ToUpperInvariant()
                        if (-not $etiquetas.ContainsKey($clave)) {
                            $etiquetas[$clave] = $texto.Substring($igual + 1)
                        }
                    }
                }
                break
            }

            $fs.Seek($largo, [System.IO.SeekOrigin]::Current) | Out-Null
            if ($ultimo) { break }
        }
    }
    catch {
        Write-Verbose "No se pudo leer '$Ruta': $($_.Exception.Message)"
    }
    finally {
        $fs.Close()
    }

    return $etiquetas
}

# Los indices de propiedad de Shell.Application cambian segun version e idioma de Windows,
# asi que se resuelven por nombre una sola vez en lugar de clavarlos en el codigo.
$script:shell   = New-Object -ComObject Shell.Application
$script:indices = $null

function Resolver-IndicesShell {
    param($Carpeta)

    if ($null -ne $script:indices) { return }

    $buscados = @{
        AlbumArtist = @('Intérprete del álbum', 'Album artist', 'Contributing album artist')
        Artist      = @('Intérpretes colaboradores', 'Autores', 'Contributing artists', 'Artists', 'Authors')
        Album       = @('Álbum', 'Album')
    }

    $script:indices = @{ AlbumArtist = 243; Artist = 13; Album = 14 }  # respaldo

    foreach ($clave in @($buscados.Keys)) {
        foreach ($i in 0..350) {
            $nombre = $Carpeta.GetDetailsOf($null, $i)
            if ($nombre -and ($buscados[$clave] -contains $nombre)) {
                $script:indices[$clave] = $i
                break
            }
        }
    }
}

# Recibe el FileInfo y no una ruta suelta a proposito: en PowerShell 5.1 el juego de
# parametros de Split-Path deja -LiteralPath incompatible con -Parent y -Leaf, y usar
# -Path se rompe con las carpetas que traen corchetes, como "[CD, FLAC, 44-16]".
function Leer-EtiquetasShell {
    param([System.IO.FileInfo] $Archivo)

    $etiquetas = @{}
    $carpeta = $script:shell.Namespace($Archivo.DirectoryName)
    if (-not $carpeta) { return $etiquetas }

    Resolver-IndicesShell -Carpeta $carpeta

    $item = $carpeta.ParseName($Archivo.Name)
    if (-not $item) { return $etiquetas }

    $etiquetas['ALBUMARTIST'] = $carpeta.GetDetailsOf($item, $script:indices.AlbumArtist)
    $etiquetas['ARTIST']      = $carpeta.GetDetailsOf($item, $script:indices.Artist)
    $etiquetas['ALBUM']       = $carpeta.GetDetailsOf($item, $script:indices.Album)

    return $etiquetas
}

function Leer-Etiquetas {
    param([System.IO.FileInfo] $Archivo)

    if ($Archivo.Extension -ieq '.flac') { return Leer-EtiquetasFlac -Ruta $Archivo.FullName }
    return Leer-EtiquetasShell -Archivo $Archivo
}

# ---------------------------------------------------------------------------
# Nombres de carpeta
# ---------------------------------------------------------------------------

# Deja un nombre usable como carpeta en Windows y tambien en el ext4 del servidor.
# Los caracteres prohibidos se reemplazan por un guion en vez de borrarse, para que
# "AC/DC" quede "AC-DC" y no "ACDC".
function Limpiar-Nombre {
    param([string] $Texto)

    if ([string]::IsNullOrWhiteSpace($Texto)) { return '' }

    # Los dos puntos van aparte porque casi siempre separan titulo y subtitulo:
    # "POST HUMAN: NeX GEn" queda "POST HUMAN - NeX GEn" y no "POST HUMAN- NeX GEn".
    $limpio = $Texto.Replace(':', ' -')
    foreach ($c in @('<', '>', '"', '/', '\', '|', '?', '*')) {
        $limpio = $limpio.Replace($c, '-')
    }
    $limpio = [regex]::Replace($limpio, '\s{2,}', ' ')
    # Caracteres de control
    $limpio = [regex]::Replace($limpio, '[\x00-\x1f]', '')
    # Windows no tolera puntos ni espacios al final del nombre de una carpeta
    $limpio = $limpio.Trim().TrimEnd('.', ' ').Trim()

    if ($limpio.Length -gt 120) { $limpio = $limpio.Substring(0, 120).Trim() }

    return $limpio
}

function Valor-Mas-Comun {
    param([string[]] $Valores)

    $utiles = @($Valores | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($utiles.Count -eq 0) { return '' }

    return ($utiles | Group-Object | Sort-Object Count, Name -Descending | Select-Object -First 1).Name
}

# ---------------------------------------------------------------------------
# Recorrido
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Origen)) {
    Write-Error "No existe la carpeta de origen: $Origen"
    exit 1
}

Write-Host ""
Write-Host "Origen : $Origen"
Write-Host "Destino: $Destino"
if ($Aplicar) {
    Write-Host "Modo   : APLICAR (se mueven las carpetas)" -ForegroundColor Yellow
} else {
    Write-Host "Modo   : simulacion (no se toca nada; agrega -Aplicar para mover)" -ForegroundColor Cyan
}
Write-Host ""

# Un album es cualquier carpeta que contenga archivos de audio directos, a cualquier
# profundidad. Asi da igual si Soulseek dejo complete\usuario\album o un nivel mas.
$carpetas = @(Get-ChildItem -LiteralPath $Origen -Directory -Recurse -ErrorAction SilentlyContinue) |
    Where-Object {
        @(Get-ChildItem -LiteralPath $_.FullName -File -ErrorAction SilentlyContinue |
            Where-Object { $EXTENSIONES -contains $_.Extension.ToLowerInvariant() }).Count -gt 0
    }

if ($carpetas.Count -eq 0) {
    Write-Host "No se encontro ninguna carpeta con audio." -ForegroundColor Yellow
    # Codigo 2 = "no habia nada que hacer". Lo usa ordenar-musica.bat para no preguntar
    # si queres mover cuando no hay ni una carpeta para mover.
    exit 2
}

$movidas = 0
$saltadas = 0
$problemas = @()

# Los destinos ya planificados se recuerdan aparte de Test-Path: en simulacion no se crea
# nada, asi que sin esto dos carpetas con el mismo album (bajadas de distintos usuarios de
# Soulseek) se contarian las dos como movibles y el resumen mentiria.
$planificados = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

foreach ($carpeta in $carpetas) {

    $audio = @(Get-ChildItem -LiteralPath $carpeta.FullName -File |
        Where-Object { $EXTENSIONES -contains $_.Extension.ToLowerInvariant() })

    $artistasAlbum = @()
    $artistas      = @()
    $albumes       = @()

    foreach ($archivo in $audio) {
        $t = Leer-Etiquetas -Archivo $archivo
        $artistasAlbum += $t['ALBUMARTIST']
        $artistas      += $t['ARTIST']
        $albumes       += $t['ALBUM']
    }

    # El artista de album es el que manda: en un disco con invitados, ARTIST cambia
    # tema a tema pero ALBUMARTIST se mantiene, que es justo lo que nombra la carpeta.
    $artista = Valor-Mas-Comun $artistasAlbum
    if (-not $artista) { $artista = Valor-Mas-Comun $artistas }

    # Si ni siquiera hay un artista predominante, es una recopilacion.
    $distintos = @($artistas | Where-Object { $_ } | Sort-Object -Unique).Count
    if (-not $artista -and $distintos -gt 1) { $artista = 'Varios Artistas' }

    $album = Valor-Mas-Comun $albumes
    if (-not $album) { $album = $carpeta.Name }

    $artista = Limpiar-Nombre $artista
    $album   = Limpiar-Nombre $album

    if (-not $artista) {
        $problemas += "SIN ARTISTA  $($carpeta.FullName)"
        $saltadas++
        continue
    }

    $rutaDestino = Join-Path (Join-Path $Destino $artista) $album

    if ((Test-Path -LiteralPath $rutaDestino) -or $planificados.Contains($rutaDestino)) {
        $problemas += "REPETIDO     $artista\$album  <-  $($carpeta.FullName)"
        $saltadas++
        continue
    }
    $planificados.Add($rutaDestino) | Out-Null

    Write-Host ("  {0,-28} -> {1}\{2}" -f $carpeta.Name, $artista, $album)

    if ($Aplicar) {
        $padre = [System.IO.Path]::GetDirectoryName($rutaDestino)
        if (-not (Test-Path -LiteralPath $padre)) {
            New-Item -ItemType Directory -Path $padre -Force | Out-Null
        }
        Move-Item -LiteralPath $carpeta.FullName -Destination $rutaDestino
    }

    $movidas++
}

Write-Host ""
if ($Aplicar) {
    Write-Host "Listo: $movidas carpetas movidas, $saltadas saltadas." -ForegroundColor Green
} else {
    Write-Host "Simulacion: $movidas se moverian, $saltadas se saltarian." -ForegroundColor Cyan
}

if ($problemas.Count -gt 0) {
    Write-Host ""
    Write-Host "Revisar a mano:" -ForegroundColor Yellow
    $problemas | ForEach-Object { Write-Host "  $_" }
}
Write-Host ""
