import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../services/reproductor_handler.dart';
import 'sesion_providers.dart';

/// El handler se crea una sola vez, en `main()`, y se inyecta acá al arrancar.
final reproductorProvider = Provider<ReproductorHandler>((ref) {
  throw UnimplementedError('Se sobreescribe en main() con el handler real.');
});

/// Canción que suena en este momento. Null si nunca se reprodujo nada.
final cancionActualProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(reproductorProvider).mediaItem;
});

/// Estado del reproductor: sonando, pausado, cargando, y en qué posición.
final estadoReproduccionProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(reproductorProvider).playbackState;
});

/// Cola completa.
final colaProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(reproductorProvider).queue;
});

/// Posición y duración juntas, que es como las necesita la barra de progreso.
class ProgresoReproduccion {
  const ProgresoReproduccion({
    required this.posicion,
    required this.duracion,
    required this.buffer,
  });

  final Duration posicion;
  final Duration duracion;
  final Duration buffer;

  /// Fracción reproducida, acotada entre 0 y 1 para que la barra nunca se
  /// desborde si el servidor informa una duración distinta a la real.
  double get fraccion {
    if (duracion.inMilliseconds <= 0) return 0;
    final valor = posicion.inMilliseconds / duracion.inMilliseconds;
    return valor.clamp(0.0, 1.0);
  }
}

/// Combina tres flujos distintos en uno solo. Sin esto habría que anidar
/// varios `StreamBuilder` y la barra de progreso se reconstruiría de a saltos.
final progresoProvider = StreamProvider<ProgresoReproduccion>((ref) {
  final handler = ref.watch(reproductorProvider);

  return Rx.combineLatest3<Duration, PlaybackState, MediaItem?,
      ProgresoReproduccion>(
    AudioService.position,
    handler.playbackState,
    handler.mediaItem,
    (posicion, estado, item) => ProgresoReproduccion(
      posicion: posicion,
      duracion: item?.duration ?? Duration.zero,
      buffer: estado.bufferedPosition,
    ),
  );
});

/// Traduce una [Cancion] del servidor al formato que entiende `audio_service`.
///
/// La URL de streaming va en `extras` porque el handler corre aislado y no
/// tiene acceso a las credenciales: necesita la URL ya firmada.
MediaItem aMediaItem(Cancion cancion, SubsonicClient cliente) {
  final portada = cancion.coverArt;

  return MediaItem(
    id: cancion.id,
    title: cancion.titulo,
    artist: cancion.artista,
    album: cancion.album,
    duration: cancion.duracion == null
        ? null
        : Duration(seconds: cancion.duracion!),
    artUri: portada == null ? null : cliente.urlPortada(portada, tamano: 512),
    extras: {
      'url': cliente.urlStream(cancion.id).toString(),
      // Se guarda el id de portada aparte para que la UI pueda rearmar la URL
      // al tamaño que necesite, en vez de adivinarlo desde el id de la canción.
      'coverArt': portada,
    },
  );
}

/// Id de portada guardado en el [MediaItem], si el servidor informó uno.
String? portadaDe(MediaItem item) => item.extras?['coverArt'] as String?;

/// Camino inverso: rearma la [Cancion] a partir de lo que suena.
///
/// La pantalla de reproducción solo tiene el [MediaItem], pero para marcar
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
/// Es lo que permite que reordenar la playlist que estás escuchando cambie
/// también lo que viene sonando. Ver [ReproductorHandler.origenCola].
String origenDePlaylist(String playlistId) => 'playlist:$playlistId';

/// Arranca la reproducción de una lista de canciones desde una posición.
///
/// [origen] solo se pasa cuando la cola queda calcada de una lista que después
/// se puede editar. Cualquier otra reproducción lo deja en null, y así una
/// edición posterior no toca una cola que ya no le corresponde.
Future<void> reproducir(
  WidgetRef ref,
  List<Cancion> canciones,
  int indice, {
  String? origen,
}) async {
  final cliente = ref.read(clienteProvider);
  final items = [for (final c in canciones) aMediaItem(c, cliente)];

  await ref
      .read(reproductorProvider)
      .reproducirLista(items, indice, origen: origen);
}

/// Reproduce una lista en orden al azar.
///
/// Mezcla una copia y la carga como cola, así el orden aleatorio queda visible
/// en la cola en vez de ser un estado invisible del reproductor.
///
/// A propósito no lleva [origen]: la cola quedó en un orden que ya no es el de
/// la lista, así que reordenar la lista después no puede aplicarse por índice.
Future<void> reproducirAleatorio(WidgetRef ref, List<Cancion> canciones) {
  final mezclado = [...canciones]..shuffle();
  return reproducir(ref, mezclado, 0);
}

/// Suma canciones al final de la cola.
Future<void> agregarACola(WidgetRef ref, List<Cancion> canciones) async {
  final cliente = ref.read(clienteProvider);
  final items = [for (final c in canciones) aMediaItem(c, cliente)];

  await ref.read(reproductorProvider).agregarACola(items);
}

/// Formatea una duración como `3:07` o `1:02:33`.
String formatearDuracion(Duration d) {
  final horas = d.inHours;
  final minutos = d.inMinutes.remainder(60);
  final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (horas > 0) {
    return '$horas:${minutos.toString().padLeft(2, '0')}:$segundos';
  }
  return '$minutos:$segundos';
}
