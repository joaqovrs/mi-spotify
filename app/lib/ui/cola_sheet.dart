import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/biblioteca.dart';
import '../state/biblioteca_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'widgets/estados.dart';
import 'widgets/portada.dart';
import 'widgets/tarjetas.dart';

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
/// Se muestra **desde la cancion actual hacia adelante**. Lo ya escuchado no
/// pinta nada aca: para eso esta el boton de anterior. Por eso, al tocar una
/// cancion de mas abajo, las que quedaron arriba salen de la lista — la que
/// suena vuelve a quedar primera.
///
/// Salen de la vista, pero **no** de la cola: el boton de anterior tiene que
/// seguir pudiendo volver. Borrarlas de verdad haria que retroceder no
/// encontrara nada.
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
          _Cola(cola: cola, actual: actual),
        const _EncabezadoAlAzar(),
        const _SugerenciasAlAzar(),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _Cola extends ConsumerWidget {
  const _Cola({required this.cola, required this.actual});

  final List<MediaItem> cola;
  final int actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(reproductorProvider);

    // Donde arranca lo que viene: los indices de la lista de abajo estan
    // corridos por esto respecto de los de la cola real.
    final inicio = actual + 1;
    final siguientes = cola.sublist(inicio);

    return SliverMainAxisGroup(
      slivers: [
        const _Encabezado('Reproduciendo'),
        SliverToBoxAdapter(child: _FilaCola(item: cola[actual], sonando: true)),
        const _Encabezado('A continuación'),
        if (siguientes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 2, 24, 0),
              child: _SinSiguientes(),
            ),
          )
        else
          SliverReorderableList(
            itemCount: siguientes.length,
            onReorderItem: (desde, hasta) =>
                handler.moverEnCola(desde + inicio, hasta + inicio),
            itemBuilder: (context, i) => _FilaCola(
              // Por instancia y no por id: la misma cancion puede estar
              // repetida en la cola y las claves tienen que ser unicas.
              key: ObjectKey(siguientes[i]),
              item: siguientes[i],
              indiceArrastre: i,
              onTap: () => handler.skipToQueueItem(i + inicio),
            ),
          ),
      ],
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _SinSiguientes extends StatelessWidget {
  const _SinSiguientes();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Es la última de la fila. Agrega más deslizando una canción, o desde el '
      'bloque de acá abajo.',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Fila de la cola: portada, titulo, artista y el asa para arrastrar.
///
/// No lleva duracion: en la fila importa el orden, no cuanto dura cada tema.
class _FilaCola extends StatelessWidget {
  const _FilaCola({
    required this.item,
    this.onTap,
    this.sonando = false,
    this.indiceArrastre,
    super.key,
  });

  final MediaItem item;
  final VoidCallback? onTap;

  /// La que esta sonando: se pinta con el acento y no se puede arrastrar.
  final bool sonando;

  /// Posicion dentro de la lista reordenable. Null en la fila de arriba, que
  /// esta fuera de esa lista.
  final int? indiceArrastre;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;

    // El naranja de marca no tiene contraste suficiente sobre blanco, asi que
    // en tema claro se usa la variante oscurecida.
    final acento = tema.brightness == Brightness.dark
        ? AppColors.naranja
        : AppColors.naranjaTexto;

    final indice = indiceArrastre;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: sonando ? acento.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Portada(coverArt: portadaDe(item), lado: 48, radio: 10),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.titleMedium?.copyWith(
                      color: sonando ? acento : null,
                      fontWeight: sonando ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.artist ?? 'Artista desconocido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (sonando)
              Icon(Icons.graphic_eq_rounded, size: 20, color: acento)
            else if (indice != null)
              // El arrastre sale del asa y no de la fila entera: asi tocar la
              // fila sigue saltando a esa cancion sin pelearse con el gesto.
              ReorderableDragStartListener(
                index: indice,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: textos.bodySmall?.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Al azar

class _EncabezadoAlAzar extends ConsumerWidget {
  const _EncabezadoAlAzar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 12, 2),
        child: Row(
          children: [
            Icon(
              Icons.shuffle_rounded,
              size: 18,
              color: textos.bodySmall?.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Al azar de tu biblioteca', style: textos.titleMedium),
            ),
            IconButton(
              tooltip: 'Sortear otras',
              onPressed: () => ref.invalidate(sugerenciasAlAzarProvider),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Canciones sueltas sacadas al azar de todo el servidor.
///
/// Es un pozo del que sacar cosas para la fila, no la continuacion de lo que
/// suena: deslizar una la manda a continuacion y tocarla la reproduce ya. En
/// los dos casos el bloque se sortea de nuevo, para que no quede a la vista lo
/// que uno acaba de usar.
class _SugerenciasAlAzar extends ConsumerWidget {
  const _SugerenciasAlAzar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(sugerenciasAlAzarProvider);
    final sonandoId = ref.watch(cancionActualProvider).value?.id;

    return switch (asincrono) {
      AsyncError(:final error) => SliverToBoxAdapter(
        child: EstadoError(
          error: error,
          onReintentar: () => ref.invalidate(sugerenciasAlAzarProvider),
        ),
      ),
      AsyncData(:final value) when value.isEmpty => const SliverToBoxAdapter(
        child: EstadoVacio(
          mensaje: 'No hay canciones en el servidor todavía.',
          icono: Icons.library_music_outlined,
        ),
      ),
      AsyncData(:final value) => SliverList.builder(
        itemCount: value.length,
        itemBuilder: (context, i) => FilaCancion(
          cancion: value[i],
          sonando: value[i].id == sonandoId,
          onTap: () => _reproducir(context, ref, value[i]),
          // Con esto la fila trae puesto el deslizar hacia la derecha para
          // mandarla a continuacion, igual que en el resto de la app.
          onAgregarACola: () => _encolar(context, ref, value[i]),
          onGuardarEnPlaylist: () => agregarAPlaylist(context, ref, [value[i]]),
          onAlternarFavorito: () => alternarFavorito(context, ref, value[i]),
        ),
      ),
      _ => const SliverToBoxAdapter(child: EstadoCargando(alto: 160)),
    };
  }

  Future<void> _encolar(
    BuildContext context,
    WidgetRef ref,
    Cancion cancion,
  ) async {
    await encolar(context, ref, [cancion]);
    ref.invalidate(sugerenciasAlAzarProvider);
  }

  /// Toca una sugerencia: suena en el acto y el bloque se renueva.
  ///
  /// Se mete a continuacion y se salta, en vez de arrancar una cola nueva: asi
  /// escuchar algo sugerido no borra la fila que venias armando.
  Future<void> _reproducir(
    BuildContext context,
    WidgetRef ref,
    Cancion cancion,
  ) async {
    final colaVacia = ref.read(colaProvider).value?.isEmpty ?? true;

    await agregarComoSiguiente(ref, [cancion]);

    // Con la cola vacia, agregar ya arranca la reproduccion; saltar ahi ademas
    // la pasaria de largo.
    if (!colaVacia) await ref.read(reproductorProvider).skipToNext();

    ref.invalidate(sugerenciasAlAzarProvider);
  }
}
