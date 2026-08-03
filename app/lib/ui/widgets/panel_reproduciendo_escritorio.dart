import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/favoritos_providers.dart';
import '../../state/reproductor_providers.dart';
import 'boton_favorito.dart';
import 'cola_reproduccion.dart';
import 'estados.dart';
import 'portada.dart';

/// Si el panel de "reproduciendo ahora / cola" esta abierto, en el shell de
/// escritorio. Vive aca (no en un archivo de providers aparte) porque es un
/// solo booleano y no amerita mas ceremonia.
final panelReproduciendoAbiertoProvider = StateProvider<bool>((ref) => false);

/// Panel fijo de escritorio con la portada grande de lo que suena y la fila
/// de reproduccion debajo — el equivalente de escritorio a abrir
/// `ColaSheet` (la hoja modal de movil), pero anclado al costado en vez de
/// taparlo todo.
class PanelReproduciendoEscritorio extends ConsumerWidget {
  const PanelReproduciendoEscritorio({super.key});

  static const double _ancho = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancion = ref.watch(cancionActualProvider).value;
    final textos = Theme.of(context).textTheme;
    final superficie = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      width: _ancho,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: superficie,
          child: CustomScrollView(
            slivers: [
              if (cancion != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      children: [
                        Portada(
                          coverArt: portadaDe(cancion),
                          lado: 280,
                          radio: 20,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cancion.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textos.titleLarge,
                              ),
                            ),
                            BotonFavorito(
                              id: cancion.id,
                              onAlternar: () => ref
                                  .read(favoritosProvider.notifier)
                                  .alternarCancion(cancionDe(cancion)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cancion.artist ?? 'Artista desconocido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textos.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _ContenidoCola(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separado en su propio widget para leer `colaProvider`/`estadoReproduccionProvider`
/// con un `ConsumerWidget` chico, igual que hace `ColaSheet`.
class _ContenidoCola extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cola = ref.watch(colaProvider).value ?? const [];
    final estado = ref.watch(estadoReproduccionProvider).value;

    final indice = estado?.queueIndex ?? 0;
    final actual = indice < 0 || indice >= cola.length ? 0 : indice;

    return SliverMainAxisGroup(
      slivers: [
        if (cola.isEmpty)
          const SliverToBoxAdapter(
            child: EstadoVacio(
              mensaje: 'No hay nada en la fila.',
              icono: Icons.queue_music_rounded,
            ),
          )
        else
          ColaEnCurso(cola: cola, actual: actual),
        const EncabezadoSugerenciasAlAzar(),
        const SugerenciasAlAzar(),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}
