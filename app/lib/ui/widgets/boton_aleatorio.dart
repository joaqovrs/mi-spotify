import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/reproductor_providers.dart';

/// Interruptor del modo aleatorio.
///
/// Va al lado de "Reproducir" pero deliberadamente callado: es un ajuste que
/// se deja puesto, no la acción principal de la pantalla. Encendido se pinta de
/// naranja sobre un fondo tenue; apagado es un ícono gris más.
class BotonAleatorio extends ConsumerWidget {
  const BotonAleatorio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(aleatorioProvider);
    final tema = Theme.of(context);

    // El naranja de marca no contrasta lo suficiente sobre blanco.
    final acento = tema.brightness == Brightness.dark
        ? AppColors.naranja
        : AppColors.naranjaTexto;

    return IconButton(
      onPressed: () => alternarAleatorio(ref),
      tooltip: activo ? 'Aleatorio activado' : 'Aleatorio desactivado',
      isSelected: activo,
      iconSize: 22,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(54),
        backgroundColor: activo ? acento.withValues(alpha: 0.14) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(
        Icons.shuffle_rounded,
        color: activo ? acento : tema.textTheme.bodySmall?.color,
      ),
    );
  }
}
