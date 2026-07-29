import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../state/biblioteca_providers.dart';
import '../state/reproductor_providers.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(album.nombre)),
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
                  FilledButton.icon(
                    onPressed: canciones.isEmpty
                        ? null
                        : () => reproducir(ref, canciones, 0),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Reproducir'),
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
