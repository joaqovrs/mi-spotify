import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/puente_widget_flotante.dart';
import '../../state/favoritos_providers.dart';
import '../../state/reproductor_providers.dart';
import 'boton_aleatorio.dart';
import 'boton_favorito.dart';
import 'panel_reproduciendo_escritorio.dart';
import 'portada.dart';

/// Barra de reproduccion de escritorio: reemplaza a [MiniReproductor] en
/// [ShellScreenEscritorio]. A diferencia de esa (alto minimo, un toque abre
/// la pantalla completa), esta trae los controles de siempre a la vista todo
/// el tiempo — progreso arrastrable, volumen, anterior/siguiente — porque en
/// una ventana de escritorio hay lugar de sobra para no esconderlos detras
/// de un toque.
class ReproductorBarEscritorio extends ConsumerWidget {
  const ReproductorBarEscritorio({super.key});

  static const double _alto = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancion = ref.watch(cancionActualProvider).value;
    if (cancion == null) return const SizedBox.shrink();

    final textos = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(
          height: _alto,
          child: Row(
            children: [
              SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Portada(
                        coverArt: portadaDe(cancion),
                        lado: 56,
                        radio: 10,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(width: 8),
                      BotonFavorito(
                        id: cancion.id,
                        onAlternar: () => ref
                            .read(favoritosProvider.notifier)
                            .alternarCancion(cancionDe(cancion)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _ControlesEscritorio(),
                    _BarraProgresoEscritorio(),
                  ],
                ),
              ),
              const SizedBox(
                width: 220,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _ControlesDerechaEscritorio(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlesEscritorio extends ConsumerWidget {
  const _ControlesEscritorio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(reproductorProvider);
    final estado = ref.watch(estadoReproduccionProvider).value;

    final sonando = estado?.playing ?? false;
    final cargando =
        estado?.processingState == AudioProcessingState.loading ||
        estado?.processingState == AudioProcessingState.buffering;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BotonAleatorio(),
        IconButton(
          iconSize: 22,
          onPressed: handler.skipToPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        Container(
          height: 38,
          width: 38,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            color: AppColors.naranja,
            shape: BoxShape.circle,
          ),
          child: cargando
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : IconButton(
                  iconSize: 20,
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  onPressed: sonando ? handler.pause : handler.play,
                  icon: Icon(
                    sonando ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
        ),
        IconButton(
          iconSize: 22,
          onPressed: handler.skipToNext,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}

class _BarraProgresoEscritorio extends ConsumerWidget {
  const _BarraProgresoEscritorio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progreso = ref.watch(progresoProvider).value;
    final textos = Theme.of(context).textTheme;

    final posicion = progreso?.posicion ?? Duration.zero;
    final duracion = progreso?.duracion ?? Duration.zero;
    final habilitada = duracion > Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(formatearDuracion(posicion), style: textos.bodySmall),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: AppColors.naranja,
                // Sin esto el tramo sin escuchar se pinta casi del mismo tono
                // que el fondo de la barra y desaparece.
                inactiveTrackColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.18),
                thumbColor: AppColors.naranja,
              ),
              child: Slider(
                value: progreso?.fraccion ?? 0,
                onChanged: habilitada
                    ? (valor) =>
                          ref.read(reproductorProvider).seek(duracion * valor)
                    : null,
              ),
            ),
          ),
          Text(formatearDuracion(duracion), style: textos.bodySmall),
        ],
      ),
    );
  }
}

class _ControlesDerechaEscritorio extends ConsumerWidget {
  const _ControlesDerechaEscritorio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumen = ref.watch(volumenProvider).value ?? 1.0;
    final tema = Theme.of(context);
    final panelAbierto = ref.watch(panelReproduciendoAbiertoProvider);
    final widgetVisible = ref.watch(puenteWidgetFlotanteProvider).visible;
    final acento = tema.brightness == Brightness.dark
        ? AppColors.naranja
        : AppColors.naranjaTexto;

    return Row(
      children: [
        Icon(_iconoVolumen(volumen), size: 20),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.naranja,
              inactiveTrackColor: tema.colorScheme.onSurface.withValues(
                alpha: 0.18,
              ),
              thumbColor: AppColors.naranja,
            ),
            child: Slider(
              value: volumen,
              onChanged: (v) => ref.read(reproductorProvider).setVolume(v),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Fila de reproducción',
          isSelected: panelAbierto,
          style: IconButton.styleFrom(
            backgroundColor: panelAbierto
                ? acento.withValues(alpha: 0.14)
                : null,
          ),
          onPressed: () =>
              ref.read(panelReproduciendoAbiertoProvider.notifier).state =
                  !panelAbierto,
          icon: Icon(
            Icons.queue_music_rounded,
            color: panelAbierto ? acento : null,
          ),
        ),
        IconButton(
          tooltip: 'Widget flotante',
          isSelected: widgetVisible,
          style: IconButton.styleFrom(
            backgroundColor: widgetVisible
                ? acento.withValues(alpha: 0.14)
                : null,
          ),
          onPressed: () =>
              ref.read(puenteWidgetFlotanteProvider.notifier).alternar(),
          icon: Icon(
            Icons.picture_in_picture_alt_rounded,
            color: widgetVisible ? acento : null,
          ),
        ),
      ],
    );
  }

  IconData _iconoVolumen(double volumen) {
    if (volumen <= 0) return Icons.volume_off_rounded;
    if (volumen < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }
}
