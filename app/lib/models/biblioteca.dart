/// Modelos de la biblioteca, mapeados desde las respuestas de Subsonic.
///
/// Navidrome omite los campos vacíos en vez de mandarlos en null, así que
/// todos los parseos toleran ausencias.
library;

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
      nombre: json['name'] as String? ?? json['album'] as String? ?? 'Sin título',
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
  });

  final String id;
  final String titulo;
  final String artista;
  final String? album;
  final String? albumId;
  final String? coverArt;

  /// Duración en segundos.
  final int? duracion;

  factory Cancion.desdeJson(Map<String, dynamic> json) {
    return Cancion(
      id: '${json['id']}',
      titulo: json['title'] as String? ?? 'Sin título',
      artista: json['artist'] as String? ?? 'Artista desconocido',
      album: json['album'] as String?,
      albumId: json['albumId'] as String?,
      coverArt: json['coverArt'] as String?,
      duracion: json['duration'] as int?,
    );
  }

  /// `3:07`, o guion cuando el servidor no informó la duración.
  String get duracionFormateada {
    final segundos = duracion;
    if (segundos == null) return '—';
    final minutos = segundos ~/ 60;
    final resto = (segundos % 60).toString().padLeft(2, '0');
    return '$minutos:$resto';
  }
}

/// Lo que devuelve una búsqueda: los tres tipos juntos, como los entrega
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
