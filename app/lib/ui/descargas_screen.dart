import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/descarga.dart';
import '../state/descargas_providers.dart';
import '../state/reproductor_providers.dart';
import 'acciones.dart';
import 'avisos.dart';
import 'widgets/estados.dart';
import 'widgets/tarjetas.dart';

/// Lo que esta guardado en el telefono.
///
/// Es la unica pantalla que **no toca la red**: los titulos salen del indice
/// local y las caratulas de los archivos bajados. Tiene que servir igual con el
/// servidor apagado, que es justamente para lo que existe.
class DescargasTab extends ConsumerWidget {
  const DescargasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(descargasProvider);
    final sonandoId = ref.watch(cancionActualProvider).value?.id;
    final canciones = [for (final d in estado.guardadas) d.cancion];

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      children: [
        _Encabezado(cantidad: estado.guardadas.length),
        if (estado.hayTrabajo) const _Progreso(),
        if (estado.error != null) _Fallo(estado.error!),
        if (estado.guardadas.isEmpty && !estado.hayTrabajo)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EstadoVacio(
              mensaje:
                  'Nada descargado todavia. Usa "Descargar" en el menu «···» '
                  'de una cancion, o en el de un album o playlist entera.',
              icono: Icons.download_rounded,
            ),
          )
        else
          for (var i = 0; i < canciones.length; i++)
            FilaCancion(
              cancion: canciones[i],
              sonando: canciones[i].id == sonandoId,
              onTap: () => reproducir(ref, canciones, i),
              onAgregarACola: () => encolar(context, ref, [canciones[i]]),
              onGuardarEnPlaylist: () =>
                  agregarAPlaylist(context, ref, [canciones[i]]),
            ),
      ],
    );
  }
}

class _Encabezado extends ConsumerWidget {
  const _Encabezado({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final bytes = ref.watch(espacioDescargadoProvider);

    final temas = cantidad == 1 ? '1 cancion' : '$cantidad canciones';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              cantidad == 0 ? 'Sin descargas' : '$temas · ${formatearTamano(bytes)}',
              style: textos.bodySmall,
            ),
          ),
          if (cantidad > 0)
            TextButton(
              onPressed: () => _borrarTodo(context, ref),
              child: const Text('Borrar todo'),
            ),
        ],
      ),
    );
  }

  Future<void> _borrarTodo(BuildContext context, WidgetRef ref) async {
    final seguro = await confirmar(
      context,
      titulo: 'Borrar descargas',
      mensaje:
          'Se liberan del telefono. La musica sigue en el servidor y puedes '
          'volver a bajarla cuando quieras.',
      aceptar: 'Borrar todo',
    );
    if (!seguro || !context.mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    await ref.read(descargasProvider.notifier).borrarTodo();
    avisar(mensajero, 'Descargas borradas');
  }
}

/// Barra de avance de la descarga en curso.
class _Progreso extends ConsumerWidget {
  const _Progreso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(descargasProvider);
    final bajando = estado.bajando;
    if (bajando == null) return const SizedBox.shrink();

    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bajando.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textos.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            estado.restantes == 1
                ? 'Descargando…'
                : 'Descargando · faltan ${estado.restantes}',
            style: textos.bodySmall,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // Sin avance informado va indeterminada, que es mas honesto que
              // una barra clavada en cero.
              value: estado.avance > 0 ? estado.avance : null,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fallo extends StatelessWidget {
  const _Fallo(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colores.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: textos.bodySmall?.copyWith(color: colores.error),
            ),
          ),
        ],
      ),
    );
  }
}
