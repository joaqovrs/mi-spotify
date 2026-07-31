import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../state/biblioteca_providers.dart';
import '../state/favoritos_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'album_screen.dart';
import 'artista_screen.dart';
import 'widgets/estados.dart';
import 'widgets/tarjetas.dart';

/// Pantalla de inicio: cuatro pestañas sobre la biblioteca del servidor.
///
/// Todo lo que se ve aqui sale de datos reales de Navidrome. Donde Spotify
/// pondria "exitos globales" o listas curadas, van los equivalentes que un
/// servidor personal si puede sostener: lo ultimo que subiste, lo que mas
/// escuchaste, lo que sono recien y una seleccion al azar.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text('Descubrir', style: textos.displaySmall),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: () => recargarBiblioteca(ref),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Canciones'),
                  Tab(text: 'Albumes'),
                  Tab(text: 'Artistas'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _PestanaResumen(),
                    _PestanaCanciones(),
                    _PestanaAlbumes(),
                    _PestanaArtistas(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Resumen

class _PestanaResumen extends ConsumerWidget {
  const _PestanaResumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => recargarBiblioteca(ref),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          _Carrusel(
            titulo: 'Agregados recientemente',
            provider: albumesRecientesProvider,
            vacio: 'Todavia no subiste musica al servidor.',
          ),
          _Carrusel(
            titulo: 'Tus mas escuchados',
            provider: albumesFrecuentesProvider,
            vacio: 'Cuando escuches musica, aqui aparecen tus favoritos.',
          ),
          _Carrusel(
            titulo: 'Vuelve a escuchar',
            provider: albumesRecienEscuchadosProvider,
            vacio: 'Aca va a quedar lo ultimo que sono.',
          ),
          _Carrusel(
            titulo: 'Al azar de tu biblioteca',
            provider: albumesAlAzarProvider,
            vacio: 'Sin albumes para sortear todavia.',
          ),
        ],
      ),
    );
  }
}

/// Fila horizontal de albumes con su encabezado.
class _Carrusel extends ConsumerWidget {
  const _Carrusel({
    required this.titulo,
    required this.provider,
    required this.vacio,
  });

  final String titulo;
  final ProviderListenable<AsyncValue<List<Album>>> provider;
  final String vacio;

  static const double _lado = 152;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
          child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        ),
        asincrono.when(
          loading: () => const EstadoCargando(alto: _lado + 46),
          error: (e, _) =>
              EstadoError(error: e, onReintentar: () => recargarBiblioteca(ref)),
          data: (albumes) {
            if (albumes.isEmpty) return EstadoVacio(mensaje: vacio);

            return SizedBox(
              height: _lado + 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: albumes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => TarjetaAlbum(
                  album: albumes[i],
                  lado: _lado,
                  onTap: () => abrirAlbum(context, albumes[i]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Canciones

class _PestanaCanciones extends ConsumerWidget {
  const _PestanaCanciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(cancionesAlAzarProvider);
    final sonandoId = ref.watch(cancionActualProvider).value?.id;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cancionesAlAzarProvider),
      child: asincrono.when(
        loading: () => const EstadoCargando(alto: 240),
        error: (e, _) => ListView(
          children: [
            EstadoError(
              error: e,
              onReintentar: () => ref.invalidate(cancionesAlAzarProvider),
            ),
          ],
        ),
        data: (canciones) {
          if (canciones.isEmpty) {
            return ListView(
              children: const [
                EstadoVacio(mensaje: 'No hay canciones en el servidor.'),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            itemCount: canciones.length,
            itemBuilder: (context, i) => FilaCancion(
              cancion: canciones[i],
              sonando: canciones[i].id == sonandoId,
              // La cola pasa a ser la lista entera, arrancando en la que toco.
              onTap: () => reproducir(ref, canciones, i),
              onAgregarACola: () => encolar(context, ref, [canciones[i]]),
              onGuardarEnPlaylist: () =>
                  agregarAPlaylist(context, ref, [canciones[i]]),
              onAlternarFavorito: () => ref
                  .read(favoritosProvider.notifier)
                  .alternarCancion(canciones[i]),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------- Albumes

class _PestanaAlbumes extends ConsumerWidget {
  const _PestanaAlbumes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(todosLosAlbumesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(todosLosAlbumesProvider),
      child: asincrono.when(
        loading: () => const EstadoCargando(alto: 240),
        error: (e, _) => ListView(
          children: [
            EstadoError(
              error: e,
              onReintentar: () => ref.invalidate(todosLosAlbumesProvider),
            ),
          ],
        ),
        data: (albumes) {
          if (albumes.isEmpty) {
            return ListView(
              children: const [
                EstadoVacio(mensaje: 'Todavia no hay albumes en el servidor.'),
              ],
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
              childAspectRatio: 0.74,
            ),
            itemCount: albumes.length,
            itemBuilder: (context, i) => TarjetaAlbum(
              album: albumes[i],
              lado: 160,
              onTap: () => abrirAlbum(context, albumes[i]),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ Artistas

class _PestanaArtistas extends ConsumerWidget {
  const _PestanaArtistas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(artistasProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(artistasProvider),
      child: asincrono.when(
        loading: () => const EstadoCargando(alto: 240),
        error: (e, _) => ListView(
          children: [
            EstadoError(
              error: e,
              onReintentar: () => ref.invalidate(artistasProvider),
            ),
          ],
        ),
        data: (artistas) {
          if (artistas.isEmpty) {
            return ListView(
              children: const [
                EstadoVacio(
                  mensaje: 'Todavia no hay artistas en el servidor.',
                  icono: Icons.person_outline_rounded,
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            itemCount: artistas.length,
            itemBuilder: (context, i) => FilaArtista(
              artista: artistas[i],
              onTap: () => abrirArtista(context, artistas[i]),
            ),
          );
        },
      ),
    );
  }
}

void abrirAlbum(BuildContext context, Album album) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AlbumScreen(album: album)),
  );
}

void abrirArtista(BuildContext context, Artista artista) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ArtistaScreen(artista: artista)),
  );
}
