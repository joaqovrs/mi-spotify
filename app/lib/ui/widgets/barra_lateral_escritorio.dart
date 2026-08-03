import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/subsonic_client.dart';
import '../../core/theme.dart';
import '../../models/biblioteca.dart';
import '../../state/playlists_providers.dart';
import '../acciones.dart';
import '../avisos.dart';
import '../navegacion_destinos.dart';
import '../playlist_screen.dart';
import '../shell_screen_escritorio.dart';
import 'estados.dart';
import 'marca.dart';
import 'portada.dart';

/// Barra lateral del shell de escritorio: marca, los 4 destinos de siempre y,
/// debajo, las playlists del usuario — al estilo Spotify de escritorio, en
/// vez de un `NavigationRail` pelado.
///
/// Navega contra [navegadorContenido] (el `Navigator` propio del area de
/// contenido, no el raiz de la app) porque esta barra es hermana de ese
/// `Navigator` en el `Row` del shell, no descendiente — `Navigator.of(context)`
/// desde aca resolveria al raiz y taparia toda la ventana.
class BarraLateralEscritorio extends ConsumerWidget {
  const BarraLateralEscritorio({required this.navegadorContenido, super.key});

  final GlobalKey<NavigatorState> navegadorContenido;

  static const double _ancho = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final indiceSeleccionado = ref.watch(indiceEscritorioProvider);
    final superficie = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      width: _ancho,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: superficie,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    const LogoMarca(tamano: 32),
                    const SizedBox(width: 12),
                    Text('Mi Music', style: textos.titleLarge),
                  ],
                ),
              ),
              for (var i = 0; i < destinosNav.length; i++)
                _FilaDestino(
                  destino: destinosNav[i],
                  seleccionado: i == indiceSeleccionado,
                  onTap: () => _irA(ref, i),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 25),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
                child: Row(
                  children: [
                    Text('Tu biblioteca', style: textos.titleMedium),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Nueva playlist',
                      onPressed: () => _crear(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ref
                    .watch(playlistsProvider)
                    .when(
                      loading: () => const EstadoCargando(alto: 160),
                      error: (e, _) => EstadoError(
                        error: e,
                        onReintentar: () =>
                            ref.read(playlistsProvider.notifier).cargar(),
                      ),
                      data: (playlists) => ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          for (final playlist in playlists)
                            _FilaPlaylistLateral(
                              playlist: playlist,
                              onTap: () => _abrir(playlist),
                            ),
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

  /// Cambia de seccion volviendo primero al fondo de la pila de contenido:
  /// asi tocar "Buscar" con un album abierto vuelve a Buscar, en vez de dejar
  /// el album apilado atras.
  void _irA(WidgetRef ref, int indice) {
    navegadorContenido.currentState?.popUntil((r) => r.isFirst);
    ref.read(indiceEscritorioProvider.notifier).state = indice;
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

      _abrir(creada);
    } on SubsonicException catch (e) {
      avisar(mensajero, e.mensaje);
    } catch (_) {
      avisar(mensajero, 'No se pudo crear la playlist.');
    }
  }

  void _abrir(Playlist playlist) {
    navegadorContenido.currentState?.popUntil((r) => r.isFirst);
    navegadorContenido.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistScreen(playlist: playlist),
      ),
    );
  }
}

class _FilaDestino extends StatelessWidget {
  const _FilaDestino({
    required this.destino,
    required this.seleccionado,
    required this.onTap,
  });

  final DestinoNav destino;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final acento = tema.brightness == Brightness.dark
        ? AppColors.naranja
        : AppColors.naranjaTexto;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: seleccionado
            ? acento.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  seleccionado ? destino.iconoSeleccionado : destino.icono,
                  color: seleccionado ? acento : null,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  destino.etiqueta,
                  style: tema.textTheme.bodyLarge?.copyWith(
                    color: seleccionado ? acento : null,
                    fontWeight: seleccionado
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaPlaylistLateral extends StatelessWidget {
  const _FilaPlaylistLateral({required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Portada(coverArt: playlist.coverArt, lado: 28, radio: 6),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                playlist.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
