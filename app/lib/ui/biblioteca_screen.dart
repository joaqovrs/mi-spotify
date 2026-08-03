import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/plataforma.dart';
import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../state/favoritos_providers.dart';
import '../state/playlists_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'album_screen.dart';
import 'avisos.dart';
import 'artista_screen.dart';
import 'descargas_screen.dart';
import 'playlist_screen.dart';
import 'widgets/estados.dart';
import 'widgets/tarjetas.dart';

/// Tu biblioteca: tus playlists y todo lo que marcaste con el corazon.
class BibliotecaScreen extends ConsumerWidget {
  const BibliotecaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 5,
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
                      onPressed: () {
                        ref.read(favoritosProvider.notifier).cargar();
                        ref.read(playlistsProvider.notifier).cargar();
                      },
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
                  Tab(text: 'Playlists'),
                  Tab(text: 'Canciones'),
                  Tab(text: 'Álbumes'),
                  Tab(text: 'Artistas'),
                  Tab(text: 'Descargas'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _Playlists(),
                    // Los tres favoritos salen de una sola consulta, asi que
                    // cada pestaña se sirve de la misma respuesta.
                    _DesdeFavoritos(_Canciones.desde),
                    _DesdeFavoritos(_Albumes.desde),
                    _DesdeFavoritos(_Artistas.desde),
                    DescargasTab(),
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

// ------------------------------------------------------------------ Playlists

class _Playlists extends ConsumerWidget {
  const _Playlists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(playlistsProvider);
    final textos = Theme.of(context).textTheme;

    final nueva = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: const Icon(Icons.add_rounded),
      title: Text('Nueva playlist', style: textos.titleMedium),
      onTap: () => _crear(context, ref),
    );

    return asincrono.when(
      loading: () => const EstadoCargando(alto: 240),
      error: (e, _) => EstadoError(
        error: e,
        onReintentar: () => ref.read(playlistsProvider.notifier).cargar(),
      ),
      data: (playlists) => ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          nueva,
          if (playlists.isEmpty)
            const EstadoVacio(
              mensaje: 'Todavía no tienes playlists.',
              icono: Icons.queue_music_rounded,
            )
          else
            for (final playlist in playlists)
              FilaPlaylist(
                playlist: playlist,
                onTap: () => _abrir(context, playlist),
              ),
        ],
      ),
    );
  }

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final nombre = await pedirNombrePlaylist(
      context,
      titulo: 'Nueva playlist',
      aceptar: 'Crear',
    );
    if (nombre == null || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);

    try {
      final creada = await ref
          .read(playlistsProvider.notifier)
          .crear(nombre: nombre);

      // Se abre recien creada: es lo que uno quiere hacer a continuacion.
      if (context.mounted) _abrir(context, creada);
    } on SubsonicException catch (e) {
      avisar(mensajero, e.mensaje);
    } catch (_) {
      avisar(mensajero, 'No se pudo crear la playlist.');
    }
  }

  void _abrir(BuildContext context, Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlist: playlist)),
    );
  }
}

// ------------------------------------------------------------------ Favoritos

/// Envoltorio que resuelve la carga de favoritos una sola vez por pestaña.
class _DesdeFavoritos extends ConsumerWidget {
  const _DesdeFavoritos(this.contenido);

  final Widget Function(Favoritos) contenido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(favoritosProvider)
        .when(
          loading: () => const EstadoCargando(alto: 240),
          error: (e, _) => EstadoError(
            error: e,
            onReintentar: () => ref.read(favoritosProvider.notifier).cargar(),
          ),
          data: contenido,
        );
  }
}

class _Canciones extends ConsumerWidget {
  const _Canciones(this.canciones);

  static Widget desde(Favoritos favoritos) => _Canciones(favoritos.canciones);

  final List<Cancion> canciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (canciones.isEmpty) {
      return const _Vacio(
        mensaje: 'Toca el corazón en una canción para guardarla aquí.',
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
        onGuardarEnPlaylist: () =>
            agregarAPlaylist(context, ref, [canciones[i]]),
        // Esta es la unica lista donde sacar el corazon ademas saca la fila:
        // sin esta opcion habia que ir a buscar la cancion a su album para
        // poder desmarcarla.
        onAlternarFavorito: () => alternarFavorito(context, ref, canciones[i]),
      ),
    );
  }
}

class _Albumes extends StatelessWidget {
  const _Albumes(this.albumes);

  static Widget desde(Favoritos favoritos) => _Albumes(favoritos.albumes);

  final List<Album> albumes;

  @override
  Widget build(BuildContext context) {
    if (albumes.isEmpty) {
      return const _Vacio(
        mensaje: 'Los álbumes que marques aparecen aquí.',
        icono: Icons.album_outlined,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      gridDelegate: esEscritorio
          ? gridDelegateAlbumesEscritorio
          : gridDelegateAlbumesMovil,
      itemCount: albumes.length,
      itemBuilder: (context, i) => TarjetaAlbum(
        album: albumes[i],
        lado: esEscritorio ? ladoTarjetaAlbumEscritorio : ladoTarjetaAlbumMovil,
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

  static Widget desde(Favoritos favoritos) => _Artistas(favoritos.artistas);

  final List<Artista> artistas;

  @override
  Widget build(BuildContext context) {
    if (artistas.isEmpty) {
      return const _Vacio(
        mensaje: 'Los artistas que sigas aparecen aquí.',
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

/// Los vacios van dentro de un scroll para que el gesto de tirar hacia abajo
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
