import 'package:audio_service/audio_service.dart';

import '../models/biblioteca.dart';
import '../models/descarga.dart';
import 'subsonic_client.dart';

/// Traduce una [Cancion] del servidor al formato que entiende `audio_service`.
///
/// La URL de streaming va en `extras` porque el handler corre aislado y no
/// tiene acceso a las credenciales: necesita la URL ya firmada.
///
/// Si la cancion esta descargada se apunta al archivo del telefono en vez de
/// al servidor — es lo unico que hace falta para que suene sin conexion, porque
/// de aqui para abajo al reproductor le da igual de donde salga el audio.
///
/// [cliente] es nullable a proposito: cuando hay [descarga], la funcion nunca
/// lo toca (ni para la portada ni para la URL), asi que armar el `MediaItem`
/// de una cancion descargada no necesita sesion — lo usa la carpeta de
/// Descargas de Android Auto para listarse sin cliente y sin red.
MediaItem aMediaItem(
  Cancion cancion,
  SubsonicClient? cliente, {
  Descarga? descarga,
}) {
  final portada = cancion.coverArt;
  final portadaLocal = descarga?.portada;

  return MediaItem(
    id: cancion.id,
    title: cancion.titulo,
    artist: cancion.artista,
    album: cancion.album,
    duration: cancion.duracion == null
        ? null
        : Duration(seconds: cancion.duracion!),
    artUri: switch ((portadaLocal, portada)) {
      (final String local, _) => Uri.file(local),
      (_, final String remota) => cliente!.urlPortada(remota, tamano: 512),
      _ => null,
    },
    extras: {
      'url': descarga == null
          ? cliente!.urlStream(cancion.id).toString()
          : Uri.file(descarga.archivo).toString(),
      // Se guarda el id de portada aparte para que la UI pueda rearmar la URL
      // al tamaño que necesite, en vez de adivinarlo desde el id de la cancion.
      'coverArt': portada,
    },
  );
}

/// Id de portada guardado en el [MediaItem], si el servidor informo uno.
String? portadaDe(MediaItem item) => item.extras?['coverArt'] as String?;

/// Camino inverso: rearma la [Cancion] a partir de lo que suena.
///
/// La pantalla de reproduccion solo tiene el [MediaItem], pero para marcar
/// favoritos hace falta el modelo del servidor.
Cancion cancionDe(MediaItem item) => Cancion(
  id: item.id,
  titulo: item.title,
  artista: item.artist ?? 'Artista desconocido',
  album: item.album,
  coverArt: portadaDe(item),
  duracion: item.duration?.inSeconds,
);

/// Etiqueta que identifica a una playlist como origen de la cola.
///
/// Es lo que permite que reordenar la playlist que estas escuchando cambie
/// tambien lo que viene sonando. Ver [ReproductorHandler.origenCola].
String origenDePlaylist(String playlistId) => 'playlist:$playlistId';
