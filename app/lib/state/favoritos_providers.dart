import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import 'sesion_providers.dart';

/// Estado de los favoritos, con una unica fuente de verdad.
///
/// Los objetos que llegan de otros endpoints tambien traen si estan marcados,
/// pero mezclar ambas fuentes lleva a incoherencias — desmarcas algo y el dato
/// viejo del listado sigue diciendo que es favorito. Asi que manda esto y solo
/// esto.
final favoritosProvider =
    StateNotifierProvider<FavoritosNotifier, AsyncValue<Favoritos>>((ref) {
      return FavoritosNotifier(ref.watch(clienteProvider))..cargar();
    });

/// Ids marcados, para que los corazones de la interfaz no tengan que esperar
/// ni conocer el tipo de lo que muestran.
final idsFavoritosProvider = Provider<Set<String>>((ref) {
  return ref.watch(favoritosProvider).value?.ids ?? const {};
});

class FavoritosNotifier extends StateNotifier<AsyncValue<Favoritos>> {
  FavoritosNotifier(this._cliente) : super(const AsyncLoading());

  final SubsonicClient _cliente;

  Future<void> cargar() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _cliente.favoritos());
    } on SubsonicException catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> alternarCancion(Cancion cancion) => _alternar(
    id: cancion.id,
    tipo: TipoFavorito.cancion,
    quitar: (f) => f.copiarCon(
      canciones: f.canciones.where((c) => c.id != cancion.id).toList(),
    ),
    agregar: (f) => f.copiarCon(canciones: [cancion, ...f.canciones]),
  );

  Future<void> alternarAlbum(Album album) => _alternar(
    id: album.id,
    tipo: TipoFavorito.album,
    quitar: (f) =>
        f.copiarCon(albumes: f.albumes.where((a) => a.id != album.id).toList()),
    agregar: (f) => f.copiarCon(albumes: [album, ...f.albumes]),
  );

  Future<void> alternarArtista(Artista artista) => _alternar(
    id: artista.id,
    tipo: TipoFavorito.artista,
    quitar: (f) => f.copiarCon(
      artistas: f.artistas.where((a) => a.id != artista.id).toList(),
    ),
    agregar: (f) => f.copiarCon(artistas: [artista, ...f.artistas]),
  );

  /// Actualiza la pantalla primero y confirma contra el servidor despues.
  ///
  /// El corazon tiene que responder al toque en el acto; esperar el viaje de
  /// ida y vuelta al servidor se siente roto. Si la peticion falla, se
  /// devuelve el estado anterior y se propaga el error.
  Future<void> _alternar({
    required String id,
    required TipoFavorito tipo,
    required Favoritos Function(Favoritos) quitar,
    required Favoritos Function(Favoritos) agregar,
  }) async {
    final actual = state.value;
    if (actual == null) return;

    final eraFavorito = actual.ids.contains(id);
    final optimista = eraFavorito ? quitar(actual) : agregar(actual);

    state = AsyncData(optimista);

    try {
      await _cliente.marcarFavorito(
        id: id,
        tipo: tipo,
        favorito: !eraFavorito,
      );
    } catch (_) {
      if (mounted) state = AsyncData(actual);
      rethrow;
    }
  }
}
