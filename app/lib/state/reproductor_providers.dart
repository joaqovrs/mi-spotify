import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../models/descarga.dart';
import '../services/reproductor_handler.dart';
import 'descargas_providers.dart';
import 'sesion_providers.dart';

/// El handler se crea una sola vez, en `main()`, y se inyecta aqui al arrancar.
final reproductorProvider = Provider<ReproductorHandler>((ref) {
  throw UnimplementedError('Se sobreescribe en main() con el handler real.');
});

/// Cancion que suena en este momento. Null si nunca se reprodujo nada.
final cancionActualProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(reproductorProvider).mediaItem;
});

/// Estado del reproductor: sonando, pausado, cargando, y en que posicion.
final estadoReproduccionProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(reproductorProvider).playbackState;
});

/// Cola completa.
final colaProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(reproductorProvider).queue;
});

/// Posicion y duracion juntas, que es como las necesita la barra de progreso.
class ProgresoReproduccion {
  const ProgresoReproduccion({
    required this.posicion,
    required this.duracion,
    required this.buffer,
  });

  final Duration posicion;
  final Duration duracion;
  final Duration buffer;

  /// Fraccion reproducida, acotada entre 0 y 1 para que la barra nunca se
  /// desborde si el servidor informa una duracion distinta a la real.
  double get fraccion {
    if (duracion.inMilliseconds <= 0) return 0;
    final valor = posicion.inMilliseconds / duracion.inMilliseconds;
    return valor.clamp(0.0, 1.0);
  }
}

/// Combina tres flujos distintos en uno solo. Sin esto habria que anidar
/// varios `StreamBuilder` y la barra de progreso se reconstruiria de a saltos.
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
///
/// Si la cancion esta descargada se apunta al archivo del telefono en vez de
/// al servidor — es lo unico que hace falta para que suene sin conexion, porque
/// de aqui para abajo al reproductor le da igual de donde salga el audio.
MediaItem aMediaItem(
  Cancion cancion,
  SubsonicClient cliente, {
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
      (_, final String remota) => cliente.urlPortada(remota, tamano: 512),
      _ => null,
    },
    extras: {
      'url': descarga == null
          ? cliente.urlStream(cancion.id).toString()
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

/// Arranca la reproduccion de una lista de canciones desde una posicion.
///
/// [origen] solo se pasa cuando la cola queda calcada de una lista que despues
/// se puede editar. Cualquier otra reproduccion lo deja en null, y asi una
/// edicion posterior no toca una cola que ya no le corresponde.
Future<void> reproducir(
  WidgetRef ref,
  List<Cancion> canciones,
  int indice, {
  String? origen,
}) async {
  final items = _aMediaItems(ref, canciones);

  await ref
      .read(reproductorProvider)
      .reproducirLista(items, indice, origen: origen);
}

/// Arma los [MediaItem] resolviendo, para cada cancion, si sale del disco o
/// del servidor.
List<MediaItem> _aMediaItems(WidgetRef ref, List<Cancion> canciones) {
  final cliente = ref.read(clienteProvider);
  final descargadas = ref.read(archivosDescargadosProvider);

  return [
    for (final cancion in canciones)
      aMediaItem(cancion, cliente, descarga: descargadas[cancion.id]),
  ];
}

/// Arranca una lista entera desde el boton "Reproducir".
///
/// Con el aleatorio encendido empieza en una cancion al azar. Si arrancara
/// siempre por la primera, tener el aleatorio prendido pareceria no hacer nada
/// hasta que terminara el primer tema.
Future<void> reproducirTodo(
  WidgetRef ref,
  List<Cancion> canciones, {
  String? origen,
}) {
  if (canciones.isEmpty) return Future<void>.value();

  final indice = ref.read(reproductorProvider).aleatorioActivo
      ? Random().nextInt(canciones.length)
      : 0;

  return reproducir(ref, canciones, indice, origen: origen);
}

/// Si el modo aleatorio esta encendido.
///
/// Sale del propio reproductor y no de una variable aparte, asi el boton no
/// puede quedar desfasado de lo que realmente esta haciendo la reproduccion.
final aleatorioProvider = Provider<bool>((ref) {
  final estado = ref.watch(estadoReproduccionProvider).value;
  return estado?.shuffleMode == AudioServiceShuffleMode.all;
});

Future<void> alternarAleatorio(WidgetRef ref) {
  final activo = ref.read(aleatorioProvider);

  return ref
      .read(reproductorProvider)
      .setShuffleMode(
        activo ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
      );
}

/// Suma canciones al final de la cola.
Future<void> agregarACola(WidgetRef ref, List<Cancion> canciones) async {
  await ref.read(reproductorProvider).agregarACola(_aMediaItems(ref, canciones));
}

/// Formatea una duracion como `3:07` o `1:02:33`.
String formatearDuracion(Duration d) {
  final horas = d.inHours;
  final minutos = d.inMinutes.remainder(60);
  final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (horas > 0) {
    return '$horas:${minutos.toString().padLeft(2, '0')}:$segundos';
  }
  return '$minutos:$segundos';
}
