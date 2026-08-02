import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../state/biblioteca_providers.dart';
import '../state/favoritos_providers.dart';
import 'album_screen.dart';
import 'widgets/boton_favorito.dart';
import 'widgets/estados.dart';
import 'widgets/mini_reproductor.dart';
import 'widgets/portada.dart';
import 'widgets/tarjetas.dart';

/// Detalle de un artista: sus albumes en el servidor.
class ArtistaScreen extends ConsumerWidget {
  const ArtistaScreen({required this.artista, super.key});

  final Artista artista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(albumesDeArtistaProvider(artista.id));
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(artista.nombre),
        actions: [
          BotonFavorito(
            id: artista.id,
            onAlternar: () =>
                ref.read(favoritosProvider.notifier).alternarArtista(artista),
          ),
        ],
      ),
      bottomNavigationBar: const MiniReproductor(),
      body: asincrono.when(
        loading: () => const EstadoCargando(alto: 280),
        error: (e, _) => EstadoError(
          error: e,
          onReintentar: () =>
              ref.invalidate(albumesDeArtistaProvider(artista.id)),
        ),
        data: (albumes) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Portada(
                      coverArt: artista.coverArt,
                      lado: 140,
                      circular: true,
                    ),
                    const SizedBox(height: 16),
                    Text(artista.nombre, style: textos.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      albumes.length == 1
                          ? '1 álbum'
                          : '${albumes.length} álbumes',
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (albumes.isEmpty)
              const SliverToBoxAdapter(
                child: EstadoVacio(mensaje: 'Sin álbumes de este artista.'),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.74,
                      ),
                  itemCount: albumes.length,
                  itemBuilder: (context, i) => TarjetaAlbum(
                    album: albumes[i],
                    lado: 160,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlbumScreen(album: albumes[i]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
