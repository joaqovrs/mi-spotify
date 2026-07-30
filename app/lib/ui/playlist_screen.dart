import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../state/favoritos_providers.dart';
import '../state/playlists_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'widgets/boton_aleatorio.dart';
import 'widgets/estados.dart';
import 'widgets/mini_reproductor.dart';
import 'widgets/portada.dart';
import 'widgets/tarjetas.dart';

/// Detalle de una playlist: sus temas en orden, y las ediciones encima.
///
/// El orden se cambia arrastrando; quitar y renombrar salen de los menús. Todo
/// se aplica primero en pantalla y se confirma contra el servidor después.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({required this.playlist, super.key});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = _vigente(ref);
    final asincrono = ref.watch(cancionesDePlaylistProvider(playlist.id));
    final canciones = asincrono.value ?? const <Cancion>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(actual.nombre),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'Más opciones',
            itemBuilder: (_) => [
              PopupMenuItem<void>(
                onTap: () => _renombrar(context, ref, actual),
                child: const Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Renombrar'),
                  ],
                ),
              ),
              if (canciones.isNotEmpty)
                PopupMenuItem<void>(
                  onTap: () => encolar(context, ref, canciones),
                  child: const Row(
                    children: [
                      Icon(Icons.queue_music_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Agregar todo a la cola'),
                    ],
                  ),
                ),
              PopupMenuItem<void>(
                onTap: () => _borrar(context, ref, actual),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Borrar playlist'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MiniReproductor(),
      body: asincrono.when(
        loading: () => const EstadoCargando(alto: 280),
        error: (e, _) => EstadoError(
          error: e,
          onReintentar: () => ref
              .read(cancionesDePlaylistProvider(playlist.id).notifier)
              .cargar(),
        ),
        data: (canciones) => _Contenido(playlist: actual, canciones: canciones),
      ),
    );
  }

  /// La versión más fresca de la playlist.
  ///
  /// La que llega por constructor es la que se tocó en el listado: si desde
  /// acá se la renombra, esa copia queda con el nombre viejo.
  Playlist _vigente(WidgetRef ref) {
    final lista = ref.watch(playlistsProvider).value ?? const <Playlist>[];
    for (final p in lista) {
      if (p.id == playlist.id) return p;
    }
    return playlist;
  }

  Future<void> _renombrar(
    BuildContext context,
    WidgetRef ref,
    Playlist actual,
  ) async {
    final nombre = await pedirNombrePlaylist(
      context,
      titulo: 'Renombrar playlist',
      aceptar: 'Guardar',
      inicial: actual.nombre,
    );
    if (nombre == null || nombre == actual.nombre || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(playlistsProvider.notifier).renombrar(actual, nombre);
    } on SubsonicException catch (e) {
      avisar(mensajero, e.mensaje);
    } catch (_) {
      avisar(mensajero, 'No se pudo renombrar la playlist.');
    }
  }

  Future<void> _borrar(
    BuildContext context,
    WidgetRef ref,
    Playlist actual,
  ) async {
    final seguro = await confirmar(
      context,
      titulo: 'Borrar playlist',
      mensaje:
          '«${actual.nombre}» se borra del servidor. Las canciones siguen '
          'en tu biblioteca.',
      aceptar: 'Borrar',
    );
    if (!seguro || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    try {
      await ref.read(playlistsProvider.notifier).borrar(actual);
      navegador.pop();
      avisar(mensajero, 'Playlist borrada');
    } on SubsonicException catch (e) {
      avisar(mensajero, e.mensaje);
    } catch (_) {
      avisar(mensajero, 'No se pudo borrar la playlist.');
    }
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.playlist, required this.canciones});

  final Playlist playlist;
  final List<Cancion> canciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final sonandoId = ref.watch(cancionActualProvider).value?.id;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              children: [
                Portada(coverArt: playlist.coverArt, lado: 200, radio: 22),
                const SizedBox(height: 18),
                Text(
                  playlist.nombre,
                  textAlign: TextAlign.center,
                  style: textos.titleLarge,
                ),
                const SizedBox(height: 4),
                // El resumen se arma con lo que hay en pantalla y no con el
                // conteo del servidor: si acabás de sacar un tema, el número
                // tiene que bajar en el acto.
                Text(_resumen(), style: textos.bodySmall),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canciones.isEmpty
                            ? null
                            : () => reproducirTodo(
                                ref,
                                canciones,
                                origen: origenDePlaylist(playlist.id),
                              ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Reproducir'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const BotonAleatorio(),
                  ],
                ),
                if (canciones.length > 1) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Mantené presionada una canción para cambiarla de lugar.',
                    textAlign: TextAlign.center,
                    style: textos.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (canciones.isEmpty)
          const SliverToBoxAdapter(
            child: EstadoVacio(
              mensaje:
                  'Esta playlist está vacía. Guardá canciones desde el menú '
                  '"···" de cualquier tema.',
              icono: Icons.queue_music_rounded,
            ),
          )
        else
          SliverReorderableList(
            itemCount: canciones.length,
            onReorderItem: (desde, hasta) => _mover(context, ref, desde, hasta),
            itemBuilder: (context, i) {
              final cancion = canciones[i];

              return ReorderableDelayedDragStartListener(
                // La clave va por instancia y no por id: una playlist admite
                // la misma canción repetida y las claves tienen que ser únicas.
                key: ObjectKey(cancion),
                index: i,
                child: FilaCancion(
                  cancion: cancion,
                  sonando: cancion.id == sonandoId,
                  onTap: () => _reproducirDesde(ref, i),
                  onAgregarACola: () => encolar(context, ref, [cancion]),
                  onGuardarEnPlaylist: () =>
                      agregarAPlaylist(context, ref, [cancion]),
                  onAlternarFavorito: () => ref
                      .read(favoritosProvider.notifier)
                      .alternarCancion(cancion),
                  onQuitarDePlaylist: () => _quitar(context, ref, i),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  /// Reproduce marcando de dónde salió la cola, para que reordenar o quitar
  /// temas después se aplique también a lo que está sonando.
  Future<void> _reproducirDesde(WidgetRef ref, int indice) {
    return reproducir(
      ref,
      canciones,
      indice,
      origen: origenDePlaylist(playlist.id),
    );
  }

  String _resumen() {
    final cantidad = canciones.length;
    final temas = cantidad == 1 ? '1 canción' : '$cantidad canciones';

    var total = 0;
    for (final c in canciones) {
      total += c.duracion ?? 0;
    }
    if (total <= 0) return temas;

    return '$temas · ${(total / 60).round()} min';
  }

  Future<void> _mover(
    BuildContext context,
    WidgetRef ref,
    int desde,
    int hasta,
  ) async {
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(cancionesDePlaylistProvider(playlist.id).notifier)
          .reordenar(desde, hasta);
    } on SubsonicException catch (e) {
      avisar(mensajero, e.mensaje);
    } catch (_) {
      avisar(mensajero, 'No se pudo guardar el nuevo orden.');
    }
  }

  Future<void> _quitar(BuildContext context, WidgetRef ref, int indice) async {
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(cancionesDePlaylistProvider(playlist.id).notifier)
          .quitar(indice);
      avisar(mensajero, 'Quitada de la playlist');
    } on SubsonicException catch (e) {
      avisar(mensajero, e.mensaje);
    } catch (_) {
      avisar(mensajero, 'No se pudo quitar la canción.');
    }
  }
}
