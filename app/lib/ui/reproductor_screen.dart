import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/favoritos_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'cola_sheet.dart';
import 'widgets/boton_favorito.dart';
import 'widgets/portada.dart';

/// Pantalla completa de reproduccion.
class ReproductorScreen extends ConsumerWidget {
  const ReproductorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancion = ref.watch(cancionActualProvider).value;
    final textos = Theme.of(context).textTheme;

    if (cancion == null) {
      return const Scaffold(
        body: Center(child: Text('No hay nada sonando.')),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final ladoPortada = (ancho - 96).clamp(180.0, 320.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Reproduciendo'),
        actions: [
          IconButton(
            tooltip: 'Fila de reproducción',
            onPressed: () => mostrarFilaDeReproduccion(context),
            icon: const Icon(Icons.queue_music_rounded),
          ),
          PopupMenuButton<void>(
            tooltip: 'Más opciones',
            itemBuilder: (_) => [
              PopupMenuItem<void>(
                onTap: () =>
                    agregarAPlaylist(context, ref, [cancionDe(cancion)]),
                child: const Row(
                  children: [
                    Icon(Icons.playlist_add_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Guardar en playlist'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // El album va arriba de la caratula y no abajo con el artista:
              // es el contexto de lo que suena, igual que el "reproduciendo
              // desde" de otras apps.
              if (cancion.album != null) ...[
                Text(
                  cancion.album!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textos.labelLarge?.copyWith(
                    color: textos.bodySmall?.color,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Portada(
                coverArt: portadaDe(cancion),
                lado: ladoPortada,
                radio: 28,
              ),
              const Spacer(flex: 2),
              Row(
                children: [
                  // Un hueco del mismo ancho que el corazon, para que el
                  // titulo quede centrado de verdad y no corrido hacia la
                  // izquierda.
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      cancion.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textos.displaySmall?.copyWith(fontSize: 25),
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
              const SizedBox(height: 6),
              Text(
                cancion.artist ?? 'Artista desconocido',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textos.bodyLarge?.copyWith(
                  color: textos.bodySmall?.color,
                ),
              ),
              const Spacer(),
              const _BarraProgreso(),
              const SizedBox(height: 12),
              const _Controles(),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraProgreso extends ConsumerWidget {
  const _BarraProgreso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progreso = ref.watch(progresoProvider).value;
    final textos = Theme.of(context).textTheme;

    final posicion = progreso?.posicion ?? Duration.zero;
    final duracion = progreso?.duracion ?? Duration.zero;
    final habilitada = duracion > Duration.zero;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.naranja,
            thumbColor: AppColors.naranja,
          ),
          child: Slider(
            value: progreso?.fraccion ?? 0,
            onChanged: habilitada
                ? (valor) => ref
                      .read(reproductorProvider)
                      .seek(duracion * valor)
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatearDuracion(posicion), style: textos.bodySmall),
              Text(formatearDuracion(duracion), style: textos.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controles extends ConsumerWidget {
  const _Controles();

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
        IconButton(
          iconSize: 38,
          onPressed: handler.skipToPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        const SizedBox(width: 22),
        Container(
          height: 68,
          width: 68,
          decoration: const BoxDecoration(
            color: AppColors.naranja,
            shape: BoxShape.circle,
          ),
          child: cargando
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : IconButton(
                  iconSize: 36,
                  color: Colors.white,
                  onPressed: sonando ? handler.pause : handler.play,
                  icon: Icon(
                    sonando ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
        ),
        const SizedBox(width: 22),
        IconButton(
          iconSize: 38,
          onPressed: handler.skipToNext,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
