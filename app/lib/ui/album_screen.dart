import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../state/biblioteca_providers.dart';
import '../state/favoritos_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'widgets/boton_favorito.dart';
import 'widgets/estados.dart';
import 'widgets/mini_reproductor.dart';
import 'widgets/portada.dart';
import 'widgets/tarjetas.dart';

/// Detalle de un álbum: portada, datos y lista de temas.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({required this.album, super.key});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(cancionesDeAlbumProvider(album.id));
    final textos = Theme.of(context).textTheme;

    // Se mira acá y se pasa a cada fila, en vez de que cada fila lo observe por
    // su cuenta: así al cambiar de tema se reconstruye la lista una sola vez.
    final sonandoId = ref.watch(cancionActualProvider).value?.id;

    final canciones = asincrono.value ?? const <Cancion>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(album.nombre),
        actions: [
          BotonFavorito(
            id: album.id,
            onAlternar: () =>
                ref.read(favoritosProvider.notifier).alternarAlbum(album),
          ),
          if (canciones.isNotEmpty)
            PopupMenuButton<void>(
              tooltip: 'Más opciones',
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => encolar(context, ref, canciones),
                  child: const Row(
                    children: [
                      Icon(Icons.queue_music_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Agregar álbum a la cola'),
                    ],
                  ),
                ),
                PopupMenuItem<void>(
                  onTap: () => agregarAPlaylist(context, ref, canciones),
                  child: const Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Guardar álbum en playlist'),
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
          onReintentar: () => ref.invalidate(cancionesDeAlbumProvider(album.id)),
        ),
        data: (canciones) => ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Portada(coverArt: album.coverArt, lado: 200, radio: 22),
                  const SizedBox(height: 18),
                  Text(
                    album.nombre,
                    textAlign: TextAlign.center,
                    style: textos.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(album.artista, style: textos.bodySmall),
                  const SizedBox(height: 4),
                  Text(_subtitulo(canciones.length), style: textos.bodySmall),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canciones.isEmpty
                              ? null
                              : () => reproducir(ref, canciones, 0),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Reproducir'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: canciones.isEmpty
                              ? null
                              : () => reproducirAleatorio(ref, canciones),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Aleatorio'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canciones.isEmpty)
              const EstadoVacio(mensaje: 'Este álbum no tiene canciones.')
            else
              for (var i = 0; i < canciones.length; i++)
                FilaCancion(
                  cancion: canciones[i],
                  sonando: canciones[i].id == sonandoId,
                  onTap: () => reproducir(ref, canciones, i),
                  onAgregarACola: () =>
                      encolar(context, ref, [canciones[i]]),
                  onGuardarEnPlaylist: () =>
                      agregarAPlaylist(context, ref, [canciones[i]]),
                  onAlternarFavorito: () => ref
                      .read(favoritosProvider.notifier)
                      .alternarCancion(canciones[i]),
                ),
          ],
        ),
      ),
    );
  }

  String _subtitulo(int cantidad) {
    final temas = cantidad == 1 ? '1 canción' : '$cantidad canciones';
    return album.anio == null ? temas : '${album.anio} · $temas';
  }
}
