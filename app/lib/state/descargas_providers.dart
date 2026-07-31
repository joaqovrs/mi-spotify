import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/descargas_storage.dart';
import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../models/descarga.dart';
import 'sesion_providers.dart';

/// Qué hay guardado y qué se está bajando.
class EstadoDescargas {
  const EstadoDescargas({
    this.guardadas = const [],
    this.pendientes = const [],
    this.bajando,
    this.avance = 0,
    this.error,
  });

  /// Lo que ya está en el teléfono.
  final List<Descarga> guardadas;

  /// Lo que espera turno. Se baja de a una: saturar la subida de casa con
  /// veinte descargas en paralelo hace que ninguna termine y encima corta la
  /// reproducción que esté sonando.
  final List<Cancion> pendientes;

  /// La que se está bajando ahora, si hay alguna.
  final Cancion? bajando;

  /// Avance de [bajando], entre 0 y 1.
  final double avance;

  /// Motivo de la última descarga que falló. Se limpia al empezar una tanda
  /// nueva.
  final String? error;

  bool get hayTrabajo => bajando != null || pendientes.isNotEmpty;

  /// Cuántas faltan, contando la que está en curso.
  int get restantes => pendientes.length + (bajando == null ? 0 : 1);

  EstadoDescargas copiarCon({
    List<Descarga>? guardadas,
    List<Cancion>? pendientes,
    Cancion? bajando,
    bool limpiarBajando = false,
    double? avance,
    String? error,
    bool limpiarError = false,
  }) {
    return EstadoDescargas(
      guardadas: guardadas ?? this.guardadas,
      pendientes: pendientes ?? this.pendientes,
      bajando: limpiarBajando ? null : (bajando ?? this.bajando),
      avance: avance ?? this.avance,
      error: limpiarError ? null : (error ?? this.error),
    );
  }
}

final descargasProvider =
    StateNotifierProvider<DescargasNotifier, EstadoDescargas>((ref) {
      return DescargasNotifier(
        ref.watch(clienteProvider),
        const DescargasStorage(),
      )..cargar();
    });

/// Lo guardado, aislado del resto del estado.
///
/// Todos los derivados miran esto y no el estado entero: el avance de una
/// descarga cambia varias veces por segundo, y sin este recorte cada tick
/// reconstruiría todas las portadas y todas las filas en pantalla.
final _guardadasProvider = Provider<List<Descarga>>((ref) {
  return ref.watch(descargasProvider.select((estado) => estado.guardadas));
});

/// Descargas por id de canción, que es como las consulta el reproductor antes
/// de decidir si reproduce del disco o del servidor.
final archivosDescargadosProvider = Provider<Map<String, Descarga>>((ref) {
  return {for (final d in ref.watch(_guardadasProvider)) d.cancion.id: d};
});

/// Carátulas guardadas, por id de portada. Las comparten todos los temas del
/// mismo álbum, así que una sola imagen sirve para muchas canciones.
final portadasDescargadasProvider = Provider<Map<String, String>>((ref) {
  return {
    for (final d in ref.watch(_guardadasProvider))
      if (d.cancion.coverArt != null && d.portada != null)
        d.cancion.coverArt!: d.portada!,
  };
});

/// Ids esperando turno o bajando, para que la fila muestre que está en camino.
final idsEnDescargaProvider = Provider<Set<String>>((ref) {
  final bajando = ref.watch(
    descargasProvider.select((estado) => estado.bajando?.id),
  );
  final pendientes = ref.watch(
    descargasProvider.select((estado) => estado.pendientes),
  );

  return {?bajando, for (final cancion in pendientes) cancion.id};
});

/// Espacio total ocupado por las descargas, en bytes.
final espacioDescargadoProvider = Provider<int>((ref) {
  var total = 0;
  for (final descarga in ref.watch(_guardadasProvider)) {
    total += descarga.bytes;
  }
  return total;
});

class DescargasNotifier extends StateNotifier<EstadoDescargas> {
  DescargasNotifier(this._cliente, this._storage)
    : super(const EstadoDescargas());

  final SubsonicClient _cliente;
  final DescargasStorage _storage;

  /// Evita que dos llamadas seguidas a [descargar] arranquen dos recorridos de
  /// la cola en paralelo.
  bool _trabajando = false;

  Future<void> cargar() async {
    final guardadas = await _storage.leer();
    if (mounted) state = state.copiarCon(guardadas: guardadas);
  }

  /// Suma canciones a la cola, salteando las que ya están o ya esperan.
  ///
  /// No es asincrónico a propósito: quien toca "descargar álbum" tiene que ver
  /// la respuesta en el acto, no cuando termine de bajarse el disco.
  void descargar(List<Cancion> canciones) {
    final yaEstan = {
      ...state.guardadas.map((d) => d.cancion.id),
      ...idsEnCola,
    };

    final nuevas = [
      for (final cancion in canciones)
        if (!yaEstan.contains(cancion.id)) cancion,
    ];
    if (nuevas.isEmpty) return;

    state = state.copiarCon(
      pendientes: [...state.pendientes, ...nuevas],
      limpiarError: true,
    );

    _procesarCola();
  }

  Set<String> get idsEnCola => {
    if (state.bajando != null) state.bajando!.id,
    for (final cancion in state.pendientes) cancion.id,
  };

  Future<void> _procesarCola() async {
    if (_trabajando) return;
    _trabajando = true;

    try {
      while (mounted && state.pendientes.isNotEmpty) {
        final cancion = state.pendientes.first;
        state = state.copiarCon(
          pendientes: state.pendientes.sublist(1),
          bajando: cancion,
          avance: 0,
        );

        try {
          final descarga = await _bajar(cancion);
          if (!mounted) return;

          final guardadas = [...state.guardadas, descarga];
          await _storage.guardar(guardadas);
          if (mounted) state = state.copiarCon(guardadas: guardadas);
        } on SubsonicException catch (e) {
          // Una que falle no cancela el resto de la tanda: se anota y sigue.
          await _storage.borrarArchivo(await _storage.rutaDeAudio(cancion));
          if (mounted) state = state.copiarCon(error: e.mensaje);
        } catch (_) {
          await _storage.borrarArchivo(await _storage.rutaDeAudio(cancion));
          if (mounted) {
            state = state.copiarCon(
              error: 'No se pudo descargar «${cancion.titulo}».',
            );
          }
        }
      }
    } finally {
      _trabajando = false;
      if (mounted) state = state.copiarCon(limpiarBajando: true, avance: 0);
    }
  }

  Future<Descarga> _bajar(Cancion cancion) async {
    final ruta = await _storage.rutaDeAudio(cancion);

    final bytes = await _cliente.descargarCancion(
      cancion.id,
      ruta,
      onProgreso: (avance) {
        if (mounted) state = state.copiarCon(avance: avance);
      },
    );

    return Descarga(
      cancion: cancion,
      archivo: ruta,
      portada: await _bajarPortada(cancion),
      bytes: bytes,
    );
  }

  /// La carátula es un extra: si falla, la canción igual quedó descargada y se
  /// muestra con el marcador genérico.
  Future<String?> _bajarPortada(Cancion cancion) async {
    final coverArt = cancion.coverArt;
    if (coverArt == null) return null;

    final ruta = await _storage.rutaDePortada(coverArt);
    // Ya la bajó otro tema del mismo álbum.
    if (await File(ruta).exists()) return ruta;

    try {
      await _cliente.descargarPortada(coverArt, ruta);
      return ruta;
    } catch (_) {
      await _storage.borrarArchivo(ruta);
      return null;
    }
  }

  Future<void> borrar(Descarga descarga) async {
    final quedan = [
      for (final d in state.guardadas)
        if (d.cancion.id != descarga.cancion.id) d,
    ];

    await _storage.borrarArchivo(descarga.archivo);

    // La carátula la comparten los temas del mismo álbum: se borra solo cuando
    // no queda ninguno que la esté usando.
    final portada = descarga.portada;
    if (portada != null && !quedan.any((d) => d.portada == portada)) {
      await _storage.borrarArchivo(portada);
    }

    await _storage.guardar(quedan);
    if (mounted) state = state.copiarCon(guardadas: quedan);
  }

  Future<void> borrarTodo() async {
    for (final descarga in state.guardadas) {
      await _storage.borrarArchivo(descarga.archivo);
      await _storage.borrarArchivo(descarga.portada);
    }

    await _storage.guardar(const []);
    if (mounted) {
      state = state.copiarCon(guardadas: const [], limpiarError: true);
    }
  }
}
