import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/reproductor_providers.dart';
import '../reproductor_screen.dart';
import 'portada.dart';

/// Barra compacta con lo que suena, fija encima de la navegación.
///
/// No está en la referencia de diseño, pero sin ella hay que volver a la
/// pantalla completa cada vez que se quiere pausar: es la pieza que hace que
/// la app se sienta cómoda.
class MiniReproductor extends ConsumerWidget {
  const MiniReproductor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancion = ref.watch(cancionActualProvider).value;

    // Antes de la primera reproducción no ocupa espacio.
    if (cancion == null) return const SizedBox.shrink();

    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Material(
      color: colores.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ReproductorScreen()),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LineaProgreso(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Portada(
                    coverArt: portadaDe(cancion),
                    lado: 44,
                    radio: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cancion.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.titleMedium,
                        ),
                        Text(
                          cancion.artist ?? 'Artista desconocido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const _BotonPlay(),
                  IconButton(
                    onPressed: ref.read(reproductorProvider).skipToNext,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineaProgreso extends ConsumerWidget {
  const _LineaProgreso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progreso = ref.watch(progresoProvider).value;

    return LinearProgressIndicator(
      value: progreso?.fraccion ?? 0,
      minHeight: 2,
      backgroundColor: Colors.transparent,
      valueColor: const AlwaysStoppedAnimation(AppColors.naranja),
    );
  }
}

class _BotonPlay extends ConsumerWidget {
  const _BotonPlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(reproductorProvider);
    final estado = ref.watch(estadoReproduccionProvider).value;

    final sonando = estado?.playing ?? false;
    final cargando =
        estado?.processingState == AudioProcessingState.loading ||
        estado?.processingState == AudioProcessingState.buffering;

    if (cargando) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    return IconButton(
      iconSize: 30,
      onPressed: sonando ? handler.pause : handler.play,
      icon: Icon(sonando ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}
