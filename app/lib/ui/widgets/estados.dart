import 'package:flutter/material.dart';

import '../../core/subsonic_client.dart';

/// Mensaje de error con opcion de reintentar.
class EstadoError extends StatelessWidget {
  const EstadoError({required this.error, this.onReintentar, super.key});

  final Object error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    final mensaje = error is SubsonicException
        ? (error as SubsonicException).mensaje
        : 'No se pudo cargar la música.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: colores.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(mensaje, textAlign: TextAlign.center, style: textos.bodyMedium),
          if (onReintentar != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hueco para cuando una seccion no tiene nada que mostrar.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({required this.mensaje, this.icono, super.key});

  final String mensaje;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono ?? Icons.library_music_outlined,
            size: 38,
            color: colores.onSurface.withValues(alpha: 0.32),
          ),
          const SizedBox(height: 12),
          Text(mensaje, textAlign: TextAlign.center, style: textos.bodySmall),
        ],
      ),
    );
  }
}

/// Bloque de carga con la altura de la seccion, para que el contenido no
/// pegue un salto cuando terminan de llegar los datos.
class EstadoCargando extends StatelessWidget {
  const EstadoCargando({this.alto = 120, super.key});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
