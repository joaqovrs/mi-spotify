import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../services/reproductor_handler.dart';
import 'reproductor_providers.dart';
import 'sesion_providers.dart';

/// Las playlists del usuario, tal como las guarda el servidor.
///
/// Igual que con los favoritos, esto es la única fuente de verdad: el servidor
/// manda y la app no inventa listas locales. La diferencia es que acá el
/// contenido de cada playlist vive aparte, en [cancionesDePlaylistProvider],
/// porque `getPlaylists` devuelve los nombres pero no las canciones.
final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, AsyncValue<List<Playlist>>>((ref) {
      return PlaylistsNotifier(ref.watch(clienteProvider), ref)..cargar();
    });

/// Canciones de una playlist concreta, en su orden guardado.
final cancionesDePlaylistProvider =
    StateNotifierProvider.family<
      PlaylistDetalleNotifier,
      AsyncValue<List<Cancion>>,
      String
    >((ref, playlistId) {
      return PlaylistDetalleNotifier(ref.watch(clienteProvider), ref, playlistId)
        ..cargar();
    });

class PlaylistsNotifier extends StateNotifier<AsyncValue<List<Playlist>>> {
  PlaylistsNotifier(this._cliente, this._ref) : super(const AsyncLoading());

  final SubsonicClient _cliente;
  final Ref _ref;

  Future<void> cargar() async {
    state = const AsyncLoading();
    try {
      final lista = await _cliente.playlists();
      if (mounted) state = AsyncData(lista);
    } on SubsonicException catch (e, s) {
      if (mounted) state = AsyncError(e, s);
    }
  }

  /// Vuelve a pedir la lista para que los conteos y duraciones queden al día
  /// después de una edición, sin pasar por el estado de carga.
  ///
  /// Si el refresco falla se dejan los datos viejos a propósito: la edición ya
  /// se guardó en el servidor, sería absurdo tapar la pantalla con un error
  /// por no haber podido actualizar un contador.
  Future<void> sincronizar() async {
    try {
      final lista = await _cliente.playlists();
      if (mounted) state = AsyncData(lista);
    } catch (_) {
      // Se queda lo que había.
    }
  }

  /// Crea la playlist y devuelve la que quedó guardada, ya con su id.
  Future<Playlist> crear({
    required String nombre,
    List<Cancion> canciones = const [],
  }) async {
    final creada = await _cliente.crearPlaylist(
      nombre: nombre,
      cancionIds: [for (final c in canciones) c.id],
    );

    await sincronizar();
    return creada;
  }

  Future<void> agregarCanciones(
    String playlistId,
    List<Cancion> canciones,
  ) async {
    if (canciones.isEmpty) return;

    await _cliente.agregarAPlaylist(
      id: playlistId,
      cancionIds: [for (final c in canciones) c.id],
    );

    // Si es la playlist que está sonando, lo agregado tiene que quedar también
    // al final de la cola, no recién la próxima vez que se toque reproducir.
    final handler = _ref.read(reproductorProvider);
    if (handler.origenCola == origenDePlaylist(playlistId)) {
      await handler.agregarACola([
        for (final c in canciones) aMediaItem(c, _cliente),
      ]);
    }

    // Si la pantalla de esa playlist está abierta detrás, tiene que enterarse.
    _ref.invalidate(cancionesDePlaylistProvider(playlistId));
    await sincronizar();
  }

  /// Renombra mostrando el nombre nuevo en el acto, igual que el corazón de
  /// favoritos: si el servidor rechaza el cambio, vuelve atrás solo.
  Future<void> renombrar(Playlist playlist, String nombre) async {
    final actual = state.value;
    if (actual == null) return;

    state = AsyncData([
      for (final p in actual)
        p.id == playlist.id ? p.copiarCon(nombre: nombre) : p,
    ]);

    try {
      await _cliente.renombrarPlaylist(id: playlist.id, nombre: nombre);
    } catch (_) {
      if (mounted) state = AsyncData(actual);
      rethrow;
    }
  }

  Future<void> borrar(Playlist playlist) async {
    final actual = state.value;
    if (actual == null) return;

    state = AsyncData([
      for (final p in actual)
        if (p.id != playlist.id) p,
    ]);

    try {
      await _cliente.borrarPlaylist(playlist.id);
    } catch (_) {
      if (mounted) state = AsyncData(actual);
      rethrow;
    }
  }
}

/// Contenido de una playlist, con las ediciones aplicadas primero en pantalla.
///
/// Quitar y reordenar tienen que sentirse instantáneos — se hacen arrastrando
/// o tocando, y esperar el viaje al servidor delata la demora del túnel.
class PlaylistDetalleNotifier extends StateNotifier<AsyncValue<List<Cancion>>> {
  PlaylistDetalleNotifier(this._cliente, this._ref, this.playlistId)
    : super(const AsyncLoading());

  final SubsonicClient _cliente;
  final Ref _ref;
  final String playlistId;

  Future<void> cargar() async {
    state = const AsyncLoading();
    try {
      final canciones = await _cliente.cancionesDePlaylist(playlistId);
      if (mounted) state = AsyncData(canciones);
    } on SubsonicException catch (e, s) {
      if (mounted) state = AsyncError(e, s);
    }
  }

  /// Saca la canción que está en [indice].
  ///
  /// Va por posición y no por id porque una playlist admite la misma canción
  /// repetida: por id se borraría también la otra.
  Future<void> quitar(int indice) async {
    final actual = state.value;
    if (actual == null || indice < 0 || indice >= actual.length) return;

    state = AsyncData([
      for (var i = 0; i < actual.length; i++)
        if (i != indice) actual[i],
    ]);

    try {
      await _cliente.quitarDePlaylist(id: playlistId, indices: [indice]);
      if (_esLaQueSuena) await _handler.quitarDeCola(indice);
      _refrescarLista();
    } catch (_) {
      if (mounted) state = AsyncData(actual);
      rethrow;
    }
  }

  /// Mueve la canción de [desde] a [hasta], con los índices ya definitivos
  /// que entrega `onReorderItem`.
  Future<void> reordenar(int desde, int hasta) async {
    final actual = state.value;
    if (actual == null) return;

    final nuevo = reordenada(actual, desde, hasta);
    state = AsyncData(nuevo);

    try {
      await _cliente.reemplazarCancionesDePlaylist(
        id: playlistId,
        cancionIds: [for (final c in nuevo) c.id],
      );
      if (_esLaQueSuena) await _handler.moverEnCola(desde, hasta);
    } catch (_) {
      if (mounted) state = AsyncData(actual);
      rethrow;
    }
  }

  /// True cuando lo que está sonando salió justamente de esta playlist, y por
  /// lo tanto la cola es un calco de la lista que se está editando.
  ///
  /// Sin este control, reordenar una playlist cualquiera mientras suena otra
  /// mezclaría la cola equivocada.
  bool get _esLaQueSuena =>
      _handler.origenCola == origenDePlaylist(playlistId);

  ReproductorHandler get _handler => _ref.read(reproductorProvider);

  /// La cantidad de canciones cambió, así que el listado de playlists quedó
  /// desactualizado.
  void _refrescarLista() {
    _ref.read(playlistsProvider.notifier).sincronizar();
  }
}

/// Devuelve una copia con el elemento de [desde] movido a [hasta].
///
/// Los índices son los de `onReorderItem`, que ya vienen compensados por el
/// hueco que deja el elemento arrastrado. (El viejo `onReorder`, deprecado en
/// Flutter 3.44, informaba el destino sin ese ajuste y había que restarle uno.)
List<T> reordenada<T>(List<T> original, int desde, int hasta) {
  final copia = [...original];
  copia.insert(hasta, copia.removeAt(desde));
  return copia;
}
