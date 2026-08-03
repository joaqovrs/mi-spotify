import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/reproductor_providers.dart';
import 'widgets/cola_reproduccion.dart';
import 'widgets/estados.dart';

/// Abre la fila de reproduccion como hoja, encima de *Reproduciendo*.
///
/// Es una hoja y no una pantalla aparte para que la portada de lo que suena
/// siga a la vista por arriba: la fila es una consulta rapida a "que viene
/// ahora", no un lugar al que uno se muda.
Future<void> mostrarFilaDeReproduccion(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Un poco mas arriba de la mitad, como en la referencia: alcanza para ver
    // varias canciones sin tapar del todo lo que se esta reproduciendo.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.66,
    ),
    builder: (_) => const ColaSheet(),
  );
}

/// Fila de reproduccion: lo que suena, lo que viene, y un pie al azar.
///
/// El contenido (`ColaEnCurso`, `EncabezadoSugerenciasAlAzar`,
/// `SugerenciasAlAzar`) vive en `widgets/cola_reproduccion.dart`, compartido
/// con el panel fijo de escritorio — esta hoja solo pone el encabezado y el
/// contenedor scrolleable alrededor.
class ColaSheet extends ConsumerWidget {
  const ColaSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final cola = ref.watch(colaProvider).value ?? const <MediaItem>[];
    final estado = ref.watch(estadoReproduccionProvider).value;

    // `queueIndex` viene del reproductor y no de buscar el id en la lista: una
    // cola admite la misma cancion repetida y por id se encontraria la otra.
    // Igual se acota, porque el estado puede llegar un instante desfasado de
    // una cola recien cambiada y un indice de mas rompe la pantalla.
    final indice = estado?.queueIndex ?? 0;
    final actual = indice < 0 || indice >= cola.length ? 0 : indice;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text('Fila de reproducción', style: textos.displaySmall
                ?.copyWith(fontSize: 24)),
          ),
        ),
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
