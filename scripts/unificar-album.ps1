<#
.SINOPSIS
    Unifica las etiquetas de una carpeta para que Navidrome la vea como un solo álbum.

.DESCRIPCIÓN
    Navidrome no agrupa por carpeta: identifica un álbum por la dupla
    AlbumArtist + Album que traen las etiquetas de cada archivo. Una recopilación
    armada a mano trae el álbum original de cada canción, así que el servidor la
    parte en tantos álbumes como valores distintos haya.

    Este script reescribe esas dos etiquetas (y opcionalmente el número de pista
    y la marca de recopilación) dejando el audio intacto: ffmpeg copia el flujo
    tal cual, sin recomprimir, así que no se pierde calidad. La carátula
    incrustada y el resto de las etiquetas se conservan.

    Por defecto solo SIMULA. Para escribir de verdad hay que pasar -Aplicar.

.EJEMPLO
    .\unificar-album.ps1 -Carpeta "C:\dev\musica\Chris Cornell Covers" -AlbumArtist "Chris Cornell"
    Muestra qué haría, sin tocar nada. El álbum toma el nombre de la carpeta.

.EJEMPLO
    .\unificar-album.ps1 -Carpeta "C:\dev\musica\Chris Cornell Covers" `
        -Album "Chris Cornell Covers" -AlbumArtist "Chris Cornell" `
        -Compilacion -NumerarPorNombre -Aplicar
    Escribe las etiquetas.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Carpeta,

    # Si no se pasa, se usa el nombre de la carpeta.
    [string] $Album,

    # Si no se pasa, se propone el intérprete que más se repite en la carpeta.
    [string] $AlbumArtist,

    # Marca la carpeta como recopilación. Evita que cada intérprete invitado
    # aparezca como un artista suelto en la biblioteca.
    [switch] $Compilacion,

    # Toma el número de pista del principio del nombre del archivo ("01. Tema").
    [switch] $NumerarPorNombre,

    [switch] $Aplicar
)

$ErrorActionPreference = 'Stop'

$EXTENSIONES = @('.mp3', '.flac', '.m4a', '.ogg', '.opus')

# ---------------------------------------------------------------------------
# Herramientas
# ---------------------------------------------------------------------------

# winget deja ffmpeg en el PATH, pero recién a partir de la próxima consola. Por
# eso, si no está a mano, se lo busca donde winget lo instala.
function Buscar-Herramienta {
    param([string] $Nombre)

    $enPath = Get-Command $Nombre -ErrorAction SilentlyContinue
    if ($enPath) { return $enPath.Source }

    $paquetes = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path $paquetes) {
        $hallado = Get-ChildItem $paquetes -Recurse -Filter "$Nombre.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hallado) { return $hallado.FullName }
    }

    return $null
}

$FFMPEG  = Buscar-Herramienta 'ffmpeg'
$FFPROBE = Buscar-Herramienta 'ffprobe'

if (-not $FFMPEG -or -not $FFPROBE) {
    Write-Host ''
    Write-Host '  No encontré ffmpeg. Se instala con:' -ForegroundColor Red
    Write-Host '      winget install Gyan.FFmpeg' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

# ---------------------------------------------------------------------------
# Lectura de etiquetas
# ---------------------------------------------------------------------------

function Leer-Etiquetas {
    param([string] $Ruta)

    $json = & $FFPROBE -v quiet -print_format json -show_format -- "$Ruta" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return @{} }

    $datos = $json | ConvertFrom-Json
    $tags = $datos.format.tags
    if (-not $tags) { return @{} }

    # ffprobe devuelve las claves con la capitalización del archivo, que varía
    # entre formatos (ALBUM en FLAC, album en MP3). Se normaliza a minúsculas.
    $normalizadas = @{}
    foreach ($p in $tags.PSObject.Properties) {
        $normalizadas[$p.Name.ToLowerInvariant()] = $p.Value
    }
    return $normalizadas
}

function Valor-O-Vacio {
    param($Tabla, [string] $Clave)
    if ($Tabla.ContainsKey($Clave) -and $Tabla[$Clave]) { return [string]$Tabla[$Clave] }
    return ''
}

function Acortar {
    param([string] $Texto, [int] $Largo)
    if ([string]::IsNullOrEmpty($Texto)) { return '' }
    if ($Texto.Length -le $Largo) { return $Texto }
    return $Texto.Substring(0, $Largo - 1) + '…'
}

# ---------------------------------------------------------------------------
# Preparación
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Carpeta -PathType Container)) {
    Write-Host ''
    Write-Host "  No existe la carpeta: $Carpeta" -ForegroundColor Red
    Write-Host ''
    exit 1
}

$Carpeta = (Resolve-Path -LiteralPath $Carpeta).Path

$archivos = Get-ChildItem -LiteralPath $Carpeta -File |
    Where-Object { $EXTENSIONES -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object Name

if ($archivos.Count -eq 0) {
    Write-Host ''
    Write-Host "  No hay archivos de audio en: $Carpeta" -ForegroundColor Yellow
    Write-Host ''
    exit 2
}

Write-Host ''
Write-Host "  Leyendo $($archivos.Count) archivos..." -ForegroundColor DarkGray

$actuales = @()
foreach ($a in $archivos) {
    $t = Leer-Etiquetas $a.FullName
    $actuales += [pscustomobject]@{
        Archivo     = $a
        Album       = Valor-O-Vacio $t 'album'
        AlbumArtist = Valor-O-Vacio $t 'album_artist'
        Artista     = Valor-O-Vacio $t 'artist'
        Titulo      = Valor-O-Vacio $t 'title'
        Pista       = Valor-O-Vacio $t 'track'
    }
}

# Valores por omisión: el álbum sale del nombre de la carpeta y el intérprete
# del álbum, del que más se repite. Son suposiciones razonables, y por eso se
# muestran antes de escribir nada.
if (-not $Album) { $Album = Split-Path $Carpeta -Leaf }

if (-not $AlbumArtist) {
    $frecuente = $actuales |
        Where-Object { $_.Artista } |
        Group-Object Artista |
        Sort-Object Count -Descending |
        Select-Object -First 1
    if ($frecuente) { $AlbumArtist = $frecuente.Name }
}

if (-not $AlbumArtist) {
    Write-Host ''
    Write-Host '  No pude deducir el intérprete del álbum. Pasalo con -AlbumArtist.' -ForegroundColor Red
    Write-Host ''
    exit 1
}

# ---------------------------------------------------------------------------
# Vista previa
# ---------------------------------------------------------------------------

$distintos = $actuales | Group-Object Album | Sort-Object Count -Descending

Write-Host ''
Write-Host '  ANTES' -ForegroundColor Cyan
Write-Host "  $($distintos.Count) álbum(es) distinto(s) en las etiquetas:"
foreach ($g in $distintos) {
    $nombre = if ($g.Name) { $g.Name } else { '(sin álbum)' }
    Write-Host ("    {0,3}  {1}" -f $g.Count, (Acortar $nombre 60)) -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  DESPUÉS' -ForegroundColor Cyan
Write-Host "    Álbum ............. $Album"
Write-Host "    Artista del álbum . $AlbumArtist"
Write-Host "    Recopilación ...... $(if ($Compilacion) { 'sí' } else { 'no se toca' })"
Write-Host "    Número de pista ... $(if ($NumerarPorNombre) { 'desde el nombre del archivo' } else { 'no se toca' })"
Write-Host '    El intérprete de cada canción NO se toca.' -ForegroundColor DarkGray

if ($NumerarPorNombre) {
    $sinNumero = $actuales | Where-Object { $_.Archivo.Name -notmatch '^\s*\d+' }
    if ($sinNumero) {
        Write-Host ''
        Write-Host "    Ojo: $($sinNumero.Count) archivo(s) no empiezan con un número. A esos se les deja la pista que ya tenían:" -ForegroundColor Yellow
        foreach ($s in ($sinNumero | Select-Object -First 5)) {
            Write-Host "      $(Acortar $s.Archivo.Name 64)" -ForegroundColor DarkGray
        }
    }
}

if (-not $Aplicar) {
    Write-Host ''
    Write-Host '  Esto fue una simulación. Nada se modificó.' -ForegroundColor Yellow
    Write-Host '  Agregá -Aplicar para escribir las etiquetas.' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

# ---------------------------------------------------------------------------
# Escritura
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '  Escribiendo...' -ForegroundColor Cyan

$total   = $actuales.Count
$hechos  = 0
$fallos  = @()
$indice  = 0

foreach ($item in $actuales) {
    $indice++
    $origen = $item.Archivo.FullName
    $ext    = $item.Archivo.Extension.ToLowerInvariant()

    # ffmpeg no puede escribir sobre el archivo que está leyendo. Se genera un
    # temporal al lado y recién se reemplaza el original si todo salió bien:
    # así un corte a mitad de camino no deja el archivo mutilado.
    $temporal = Join-Path $item.Archivo.DirectoryName ("$([guid]::NewGuid().ToString('N')).tmp$ext")

    $pista = $item.Pista
    if ($NumerarPorNombre -and $item.Archivo.Name -match '^\s*(\d+)') {
        $pista = "$([int]$Matches[1])/$total"
    }

    $argumentos = @(
        '-v', 'error',
        '-y',
        '-i', $origen,
        # -map 0 arrastra todos los flujos, que es lo que conserva la carátula
        # incrustada; -c copy los pasa tal cual, sin recomprimir el audio.
        '-map', '0',
        '-c', 'copy',
        '-map_metadata', '0',
        '-metadata', "album=$Album",
        '-metadata', "album_artist=$AlbumArtist"
    )

    if ($pista)       { $argumentos += @('-metadata', "track=$pista") }
    if ($Compilacion) { $argumentos += @('-metadata', 'compilation=1') }

    # ID3v2.3 es el que mejor leen Windows y los reproductores viejos; ffmpeg
    # por defecto escribe 2.4. Solo aplica a MP3.
    if ($ext -eq '.mp3') { $argumentos += @('-id3v2_version', '3', '-write_id3v1', '1') }

    $argumentos += $temporal

    $salida = & $FFMPEG @argumentos 2>&1
    $codigo = $LASTEXITCODE

    if ($codigo -ne 0 -or -not (Test-Path -LiteralPath $temporal) -or (Get-Item -LiteralPath $temporal).Length -eq 0) {
        $fallos += [pscustomobject]@{ Archivo = $item.Archivo.Name; Motivo = ($salida | Out-String).Trim() }
        if (Test-Path -LiteralPath $temporal) { Remove-Item -LiteralPath $temporal -Force -ErrorAction SilentlyContinue }
        Write-Host ("    [{0}/{1}] FALLÓ  {2}" -f $indice, $total, (Acortar $item.Archivo.Name 52)) -ForegroundColor Red
        continue
    }

    try {
        Move-Item -LiteralPath $temporal -Destination $origen -Force
        $hechos++
        Write-Host ("    [{0}/{1}] ok     {2}" -f $indice, $total, (Acortar $item.Archivo.Name 52)) -ForegroundColor DarkGray
    } catch {
        $fallos += [pscustomobject]@{ Archivo = $item.Archivo.Name; Motivo = $_.Exception.Message }
        if (Test-Path -LiteralPath $temporal) { Remove-Item -LiteralPath $temporal -Force -ErrorAction SilentlyContinue }
        Write-Host ("    [{0}/{1}] FALLÓ  {2}" -f $indice, $total, (Acortar $item.Archivo.Name 52)) -ForegroundColor Red
    }
}

Write-Host ''
Write-Host "  Listo: $hechos de $total archivos." -ForegroundColor Green

if ($fallos.Count -gt 0) {
    Write-Host ''
    Write-Host "  $($fallos.Count) fallaron y quedaron como estaban:" -ForegroundColor Red
    foreach ($f in $fallos) {
        Write-Host "    $($f.Archivo)" -ForegroundColor Red
        if ($f.Motivo) { Write-Host "      $(Acortar $f.Motivo 100)" -ForegroundColor DarkGray }
    }
}

Write-Host ''
Write-Host '  Ahora hay que subir la carpeta por WinSCP a /srv/musica y rescanear en Navidrome.' -ForegroundColor Cyan
Write-Host ''

if ($fallos.Count -gt 0) { exit 1 }
exit 0
