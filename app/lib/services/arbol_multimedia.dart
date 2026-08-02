import 'package:audio_service/audio_service.dart';

import '../models/biblioteca.dart';

/// Las cuatro carpetas raiz que ve Android Auto, calcadas de las pestañas de
/// la Biblioteca del telefono.
const String idRaizPlaylists = 'playlists';
const String idRaizAlbumes = 'albumes';
const String idRaizArtistas = 'artistas';
const String idRaizDescargas = 'descargas';

const String _prefijoPlaylist = 'playlist:';
const String _prefijoAlbum = 'album:';
const String _prefijoArtista = 'artista:';

String idDePlaylist(String id) => '$_prefijoPlaylist$id';
String idDeAlbum(String id) => '$_prefijoAlbum$id';
String idDeArtista(String id) => '$_prefijoArtista$id';

/// En que parte del arbol de Android Auto esta parado, a partir del
/// `parentMediaId` que manda `getChildren`.
///
/// Es Dart puro (sin `SubsonicClient` ni Riverpod) para poder testearlo sin
/// instanciar el reproductor real, que trae un `AudioPlayer()` de verdad.
sealed class NodoMultimedia {
  const NodoMultimedia();
}

class NodoRaiz extends NodoMultimedia {
  const NodoRaiz();
}

class NodoListaPlaylists extends NodoMultimedia {
  const NodoListaPlaylists();
}

class NodoListaAlbumes extends NodoMultimedia {
  const NodoListaAlbumes();
}

class NodoListaArtistas extends NodoMultimedia {
  const NodoListaArtistas();
}

class NodoDescargas extends NodoMultimedia {
  const NodoDescargas();
}

class NodoPlaylist extends NodoMultimedia {
  const NodoPlaylist(this.id);
  final String id;
}

class NodoAlbum extends NodoMultimedia {
  const NodoAlbum(this.id);
  final String id;
}

class NodoArtista extends NodoMultimedia {
  const NodoArtista(this.id);
  final String id;
}

/// Cualquier `parentMediaId` que no reconozcamos. `getChildren` lo resuelve
/// en una lista vacia, igual que hace por defecto `BaseAudioHandler`.
class NodoDesconocido extends NodoMultimedia {
  const NodoDesconocido();
}

NodoMultimedia interpretarNodo(String mediaId) {
  if (mediaId == AudioService.browsableRootId) return const NodoRaiz();
  if (mediaId == idRaizPlaylists) return const NodoListaPlaylists();
  if (mediaId == idRaizAlbumes) return const NodoListaAlbumes();
  if (mediaId == idRaizArtistas) return const NodoListaArtistas();
  if (mediaId == idRaizDescargas) return const NodoDescargas();

  if (mediaId.startsWith(_prefijoPlaylist)) {
    return NodoPlaylist(mediaId.substring(_prefijoPlaylist.length));
  }
  if (mediaId.startsWith(_prefijoAlbum)) {
    return NodoAlbum(mediaId.substring(_prefijoAlbum.length));
  }
  if (mediaId.startsWith(_prefijoArtista)) {
    return NodoArtista(mediaId.substring(_prefijoArtista.length));
  }

  return const NodoDesconocido();
}

/// Las cuatro carpetas de la raiz, en el mismo orden que la navegacion
/// inferior de Biblioteca: Playlists, Albumes, Artistas, Descargas.
List<MediaItem> nodosRaiz() => const [
  MediaItem(id: idRaizPlaylists, title: 'Playlists', playable: false),
  MediaItem(id: idRaizAlbumes, title: 'Álbumes', playable: false),
  MediaItem(id: idRaizArtistas, title: 'Artistas', playable: false),
  MediaItem(id: idRaizDescargas, title: 'Descargas', playable: false),
];

/// [portada] ya viene resuelta (firmada) porque esta funcion es Dart puro y
/// no tiene forma de pedirle una URL al `SubsonicClient`.
MediaItem nodoPlaylist(Playlist playlist, {Uri? portada}) => MediaItem(
  id: idDePlaylist(playlist.id),
  title: playlist.nombre,
  displaySubtitle: playlist.resumen,
  artUri: portada,
  playable: false,
);

MediaItem nodoAlbum(Album album, {Uri? portada}) => MediaItem(
  id: idDeAlbum(album.id),
  title: album.nombre,
  artist: album.artista,
  displaySubtitle: album.artista,
  artUri: portada,
  playable: false,
);

MediaItem nodoArtista(Artista artista, {Uri? portada}) => MediaItem(
  id: idDeArtista(artista.id),
  title: artista.nombre,
  artUri: portada,
  playable: false,
);
