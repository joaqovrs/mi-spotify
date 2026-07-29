import 'dart:async';

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
import 'widgets/portada.dart';
import 'widgets/tarjetas.dart';

/// Buscador sobre toda la biblioteca del servidor.
class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  final _controlador = TextEditingController();
  Timer? _retardo;

  @override
  void dispose() {
    _retardo?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  /// Espera a que dejes de escribir antes de consultar.
  ///
  /// Sin esto, "beatles" dispararía siete búsquedas contra el servidor, y
  /// desde fuera de casa cada una viaja por el túnel de Tailscale.
  void _alEscribir(String texto) {
    _retardo?.cancel();
    _retardo = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(consultaProvider.notifier).state = texto;
    });
  }

  void _limpiar() {
    _retardo?.cancel();
    _controlador.clear();
    ref.read(consultaProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final consulta = ref.watch(consultaProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buscar', style: textos.displaySmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controlador,
                    onChanged: _alEscribir,
                    autocorrect: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Canciones, álbumes o artistas',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _controlador.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _limpiar();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: consulta.trim().isEmpty
                  ? const EstadoVacio(
                      mensaje: 'Escribí para buscar en tu biblioteca.',
                      icono: Icons.search_rounded,
                    )
                  : const _Resultados(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(busquedaProvider);
    final sonandoId = ref.watch(cancionActualProvider).value?.id;
    final textos = Theme.of(context).textTheme;

    return asincrono.when(
      loading: () => const EstadoCargando(alto: 200),
      error: (e, _) => EstadoError(
        error: e,
        onReintentar: () => ref.invalidate(busquedaProvider),
      ),
      data: (resultado) {
        if (resultado.estaVacio) {
          return const EstadoVacio(
            mensaje: 'No encontré nada con ese nombre.',
            icono: Icons.search_off_rounded,
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (resultado.canciones.isNotEmpty) ...[
              _Encabezado('Canciones', textos),
              for (var i = 0; i < resultado.canciones.length; i++)
                FilaCancion(
                  cancion: resultado.canciones[i],
                  sonando: resultado.canciones[i].id == sonandoId,
                  onTap: () => reproducir(ref, resultado.canciones, i),
                  onAgregarACola: () =>
                      encolar(context, ref, [resultado.canciones[i]]),
                  onAlternarFavorito: () => ref
                      .read(favoritosProvider.notifier)
                      .alternarCancion(resultado.canciones[i]),
                ),
            ],
            if (resultado.albumes.isNotEmpty) ...[
              _Encabezado('Álbumes', textos),
              for (final album in resultado.albumes)
                _FilaAlbum(album: album),
            ],
            if (resultado.artistas.isNotEmpty) ...[
              _Encabezado('Artistas', textos),
              for (final artista in resultado.artistas)
                FilaArtista(
                  artista: artista,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ArtistaScreen(artista: artista),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto, this.textos);

  final String texto;
  final TextTheme textos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Text(texto, style: textos.titleLarge),
    );
  }
}

/// Álbum en formato fila, que es lo que corresponde en una lista de resultados
/// mezclada con canciones y artistas.
class _FilaAlbum extends StatelessWidget {
  const _FilaAlbum({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Portada(coverArt: album.coverArt, lado: 52, radio: 12),
      title: Text(
        album.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textos.titleMedium,
      ),
      subtitle: Text(
        album.artista,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textos.bodySmall,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AlbumScreen(album: album)),
      ),
    );
  }
}
