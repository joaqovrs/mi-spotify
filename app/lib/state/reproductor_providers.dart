import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../core/media_items.dart';
import '../models/biblioteca.dart';
import '../services/reproductor_handler.dart';
import 'descargas_providers.dart';
import 'sesion_providers.dart';

export '../core/media_items.dart';

/// El handler se crea una sola vez, en `main()`, y se inyecta aqui al arrancar.
final reproductorProvider = Provider<ReproductorHandler>((ref) {
  throw UnimplementedError('Se sobrescribe en main() con el handler real.');
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

/// Mete canciones justo despues de la que suena.
///
/// El equivalente que agrega al final ([ReproductorHandler.agregarACola]) queda
/// para la sincronizacion con la playlist que suena, donde el orden de la cola
/// tiene que seguir siendo el de la lista.
Future<void> agregarComoSiguiente(
  WidgetRef ref,
  List<Cancion> canciones,
) async {
  await ref
      .read(reproductorProvider)
      .agregarComoSiguiente(_aMediaItems(ref, canciones));
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
