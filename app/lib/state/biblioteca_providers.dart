import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import 'sesion_providers.dart';

/// Secciones de la pantalla de inicio.
///
/// Todas salen de datos reales del servidor. No hay rankings globales ni listas
/// curadas porque un Navidrome de un solo usuario no tiene de dónde sacarlos:
/// lo que se muestra es tu propia biblioteca y tus propias escuchas.

/// Lo último que agregaste a `/srv/musica`.
final albumesRecientesProvider = FutureProvider<List<Album>>((ref) async {
  return ref.watch(clienteProvider).albumes(tipo: 'newest', cantidad: 20);
});

/// Los álbumes que más veces reprodujiste.
final albumesFrecuentesProvider = FutureProvider<List<Album>>((ref) async {
  return ref.watch(clienteProvider).albumes(tipo: 'frequent', cantidad: 20);
});

/// Los últimos que sonaron, para retomar.
final albumesRecienEscuchadosProvider = FutureProvider<List<Album>>((ref) async {
  return ref.watch(clienteProvider).albumes(tipo: 'recent', cantidad: 20);
});

/// Una selección al azar, que cambia en cada recarga.
final albumesAlAzarProvider = FutureProvider<List<Album>>((ref) async {
  return ref.watch(clienteProvider).albumes(tipo: 'random', cantidad: 20);
});

/// Catálogo completo de álbumes, ordenado alfabéticamente.
final todosLosAlbumesProvider = FutureProvider<List<Album>>((ref) async {
  return ref
      .watch(clienteProvider)
      .albumes(tipo: 'alphabeticalByName', cantidad: 500);
});

final artistasProvider = FutureProvider<List<Artista>>((ref) async {
  return ref.watch(clienteProvider).artistas();
});

/// Canciones sueltas para la pestaña Canciones.
///
/// Subsonic no tiene un endpoint que devuelva *todas* las canciones, así que
/// se usa una muestra al azar. Con una biblioteca chica alcanza para verlas
/// todas; cuando crezca, la vía real para llegar a una canción puntual es el
/// buscador o entrar por su álbum.
final cancionesAlAzarProvider = FutureProvider<List<Cancion>>((ref) async {
  return ref.watch(clienteProvider).cancionesAlAzar(cantidad: 100);
});

/// Texto que se está buscando. Lo actualiza la pantalla de búsqueda con un
/// retardo, para no disparar una consulta por cada tecla.
final consultaProvider = StateProvider<String>((ref) => '');

/// Resultados de la búsqueda actual.
final busquedaProvider = FutureProvider<ResultadoBusqueda>((ref) async {
  final consulta = ref.watch(consultaProvider);
  if (consulta.trim().isEmpty) return const ResultadoBusqueda.vacio();

  return ref.watch(clienteProvider).buscar(consulta);
});

/// Canciones de un álbum concreto.
final cancionesDeAlbumProvider = FutureProvider.family<List<Cancion>, String>((
  ref,
  albumId,
) async {
  return ref.watch(clienteProvider).cancionesDeAlbum(albumId);
});

/// Álbumes de un artista concreto.
final albumesDeArtistaProvider = FutureProvider.family<List<Album>, String>((
  ref,
  artistaId,
) async {
  return ref.watch(clienteProvider).albumesDeArtista(artistaId);
});

/// Rehace todas las consultas de la biblioteca. Lo usa el gesto de "deslizar
/// para actualizar" de la pantalla de inicio.
void recargarBiblioteca(WidgetRef ref) {
  ref.invalidate(albumesRecientesProvider);
  ref.invalidate(albumesFrecuentesProvider);
  ref.invalidate(albumesRecienEscuchadosProvider);
  ref.invalidate(albumesAlAzarProvider);
  ref.invalidate(todosLosAlbumesProvider);
  ref.invalidate(artistasProvider);
  ref.invalidate(cancionesAlAzarProvider);
}
