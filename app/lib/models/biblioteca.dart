/// Modelos de la biblioteca, mapeados desde las respuestas de Subsonic.
///
/// Navidrome omite los campos vacios en vez de mandarlos en null, asi que
/// todos los parseos toleran ausencias.
library;

/// Los tres tipos que Subsonic permite marcar como favoritos.
enum TipoFavorito { cancion, album, artista }

class Album {
  const Album({
    required this.id,
    required this.nombre,
    required this.artista,
    this.artistaId,
    this.coverArt,
    this.anio,
    this.cantidadCanciones,
  });

  final String id;
  final String nombre;
  final String artista;
  final String? artistaId;
  final String? coverArt;
  final int? anio;
  final int? cantidadCanciones;

  factory Album.desdeJson(Map<String, dynamic> json) {
    return Album(
      id: '${json['id']}',
      nombre: json['name'] as String? ?? json['album'] as String? ?? 'Sin titulo',
      artista: json['artist'] as String? ?? 'Artista desconocido',
      artistaId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      anio: json['year'] as int?,
      cantidadCanciones: json['songCount'] as int?,
    );
  }
}

class Cancion {
  const Cancion({
    required this.id,
    required this.titulo,
    required this.artista,
    this.album,
    this.albumId,
    this.coverArt,
    this.duracion,
    this.sufijo,
  });

  final String id;
  final String titulo;
  final String artista;
  final String? album;
  final String? albumId;
  final String? coverArt;

  /// Duracion en segundos.
  final int? duracion;

  /// Extension del archivo original en el servidor (`mp3`, `flac`, `m4a`).
  /// Se usa al descargar, para que el archivo local conserve su formato en el
  /// nombre y el reproductor no tenga que adivinarlo.
  final String? sufijo;

  factory Cancion.desdeJson(Map<String, dynamic> json) {
    return Cancion(
      id: '${json['id']}',
      titulo: json['title'] as String? ?? 'Sin titulo',
      artista: json['artist'] as String? ?? 'Artista desconocido',
      album: json['album'] as String?,
      albumId: json['albumId'] as String?,
      coverArt: json['coverArt'] as String?,
      duracion: json['duration'] as int?,
      sufijo: json['suffix'] as String?,
    );
  }

  /// Vuelve a la forma en que la manda Subsonic, para poder guardarla en el
  /// telefono y releerla con [Cancion.desdeJson] sin un segundo formato.
  ///
  /// Solo se escriben los campos que hay: asi el archivo guardado se parece a
  /// lo que devuelve el servidor, que tambien omite lo vacio.
  Map<String, dynamic> aJson() => {
    'id': id,
    'title': titulo,
    'artist': artista,
    if (album != null) 'album': album,
    if (albumId != null) 'albumId': albumId,
    if (coverArt != null) 'coverArt': coverArt,
    if (duracion != null) 'duration': duracion,
    if (sufijo != null) 'suffix': sufijo,
  };

  /// `3:07`, o guion cuando el servidor no informo la duracion.
  String get duracionFormateada {
    final segundos = duracion;
    if (segundos == null) return '—';
    final minutos = segundos ~/ 60;
    final resto = (segundos % 60).toString().padLeft(2, '0');
    return '$minutos:$resto';
  }
}

/// Lo que devuelve una busqueda: los tres tipos juntos, como los entrega
/// `search3` en una sola llamada.
class ResultadoBusqueda {
  const ResultadoBusqueda({
    required this.canciones,
    required this.albumes,
    required this.artistas,
  });

  const ResultadoBusqueda.vacio()
    : canciones = const [],
      albumes = const [],
      artistas = const [];

  final List<Cancion> canciones;
  final List<Album> albumes;
  final List<Artista> artistas;

  bool get estaVacio =>
      canciones.isEmpty && albumes.isEmpty && artistas.isEmpty;
}

/// Todo lo que marcaste como favorito, tal como lo devuelve `getStarred2`.
class Favoritos {
  const Favoritos({
    required this.canciones,
    required this.albumes,
    required this.artistas,
  });

  const Favoritos.vacio()
    : canciones = const [],
      albumes = const [],
      artistas = const [];

  final List<Cancion> canciones;
  final List<Album> albumes;
  final List<Artista> artistas;

  bool get estaVacio =>
      canciones.isEmpty && albumes.isEmpty && artistas.isEmpty;

  /// Ids de todo lo marcado, sin importar el tipo. Es lo que consultan los
  /// corazones de la interfaz para saber si tienen que estar rellenos.
  ///
  /// Los ids de Subsonic son unicos entre tipos, asi que un solo conjunto
  /// alcanza y evita tener que saber de que tipo es cada cosa al preguntar.
  Set<String> get ids => {
    for (final c in canciones) c.id,
    for (final a in albumes) a.id,
    for (final a in artistas) a.id,
  };

  Favoritos copiarCon({
    List<Cancion>? canciones,
    List<Album>? albumes,
    List<Artista>? artistas,
  }) {
    return Favoritos(
      canciones: canciones ?? this.canciones,
      albumes: albumes ?? this.albumes,
      artistas: artistas ?? this.artistas,
    );
  }
}

/// Una playlist del servidor.
///
/// A diferencia de los favoritos, el orden importa: es lo que distingue una
/// playlist de una bolsa de canciones marcadas. Subsonic lo guarda por
/// posicion, asi que todas las operaciones de edicion hablan de indices.
class Playlist {
  const Playlist({
    required this.id,
    required this.nombre,
    this.comentario,
    this.coverArt,
    this.cantidadCanciones,
    this.duracion,
  });

  final String id;
  final String nombre;
  final String? comentario;
  final String? coverArt;
  final int? cantidadCanciones;

  /// Duracion total en segundos.
  final int? duracion;

  factory Playlist.desdeJson(Map<String, dynamic> json) {
    return Playlist(
      id: '${json['id']}',
      nombre: json['name'] as String? ?? 'Sin nombre',
      comentario: json['comment'] as String?,
      coverArt: json['coverArt'] as String?,
      cantidadCanciones: json['songCount'] as int?,
      duracion: json['duration'] as int?,
    );
  }

  /// `12 canciones · 48 min`, para el subtitulo de la fila y de la pantalla.
  ///
  /// Omite la duracion cuando el servidor no la informa (una playlist recien
  /// creada, todavia vacia) en vez de mostrar un `0 min` que confunde.
  String get resumen {
    final cantidad = cantidadCanciones ?? 0;
    final temas = cantidad == 1 ? '1 cancion' : '$cantidad canciones';

    final total = duracion;
    if (total == null || total <= 0) return temas;

    final minutos = (total / 60).round();
    return '$temas · $minutos min';
  }

  Playlist copiarCon({String? nombre}) => Playlist(
    id: id,
    nombre: nombre ?? this.nombre,
    comentario: comentario,
    coverArt: coverArt,
    cantidadCanciones: cantidadCanciones,
    duracion: duracion,
  );
}

class Artista {
  const Artista({
    required this.id,
    required this.nombre,
    this.coverArt,
    this.cantidadAlbumes,
  });

  final String id;
  final String nombre;
  final String? coverArt;
  final int? cantidadAlbumes;

  factory Artista.desdeJson(Map<String, dynamic> json) {
    return Artista(
      id: '${json['id']}',
      nombre: json['name'] as String? ?? 'Artista desconocido',
      coverArt: json['coverArt'] as String?,
      cantidadAlbumes: json['albumCount'] as int?,
    );
  }
}
