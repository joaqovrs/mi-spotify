import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../state/favoritos_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'album_screen.dart';
import 'artista_screen.dart';
import 'widgets/estados.dart';
import 'widgets/tarjetas.dart';

/// Tu biblioteca: todo lo que marcaste con el corazón.
class BibliotecaScreen extends ConsumerWidget {
  const BibliotecaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final asincrono = ref.watch(favoritosProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text('Tu biblioteca', style: textos.displaySmall),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: () =>
                          ref.read(favoritosProvider.notifier).cargar(),
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
                  Tab(text: 'Canciones'),
                  Tab(text: 'Álbumes'),
                  Tab(text: 'Artistas'),
                ],
              ),
              Expanded(
                child: asincrono.when(
                  loading: () => const EstadoCargando(alto: 240),
                  error: (e, _) => EstadoError(
                    error: e,
                    onReintentar: () =>
                        ref.read(favoritosProvider.notifier).cargar(),
                  ),
                  data: (favoritos) => TabBarView(
                    children: [
                      _Canciones(favoritos.canciones),
                      _Albumes(favoritos.albumes),
                      _Artistas(favoritos.artistas),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Canciones extends ConsumerWidget {
  const _Canciones(this.canciones);

  final List<Cancion> canciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (canciones.isEmpty) {
      return const _Vacio(
        mensaje: 'Tocá el corazón en una canción para guardarla acá.',
        icono: Icons.favorite_border_rounded,
      );
    }

    final sonandoId = ref.watch(cancionActualProvider).value?.id;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      itemCount: canciones.length,
      itemBuilder: (context, i) => FilaCancion(
        cancion: canciones[i],
        sonando: canciones[i].id == sonandoId,
        onTap: () => reproducir(ref, canciones, i),
        onAgregarACola: () => encolar(context, ref, [canciones[i]]),
      ),
    );
  }
}

class _Albumes extends StatelessWidget {
  const _Albumes(this.albumes);

  final List<Album> albumes;

  @override
  Widget build(BuildContext context) {
    if (albumes.isEmpty) {
      return const _Vacio(
        mensaje: 'Los álbumes que marques aparecen acá.',
        icono: Icons.album_outlined,
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlbumScreen(album: albumes[i]),
          ),
        ),
      ),
    );
  }
}

class _Artistas extends StatelessWidget {
  const _Artistas(this.artistas);

  final List<Artista> artistas;

  @override
  Widget build(BuildContext context) {
    if (artistas.isEmpty) {
      return const _Vacio(
        mensaje: 'Los artistas que sigas aparecen acá.',
        icono: Icons.person_outline_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      itemCount: artistas.length,
      itemBuilder: (context, i) => FilaArtista(
        artista: artistas[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArtistaScreen(artista: artistas[i]),
          ),
        ),
      ),
    );
  }
}

/// Los vacíos van dentro de un scroll para que el gesto de tirar hacia abajo
/// siga funcionando aunque no haya contenido.
class _Vacio extends StatelessWidget {
  const _Vacio({required this.mensaje, required this.icono});

  final String mensaje;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 60),
        EstadoVacio(mensaje: mensaje, icono: icono),
      ],
    );
  }
}
