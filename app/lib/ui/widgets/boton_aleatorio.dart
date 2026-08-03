import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/reproductor_providers.dart';
import '../avisos.dart';

/// Interruptor del modo aleatorio.
///
/// Va al lado de "Reproducir" pero deliberadamente callado: es un ajuste que
/// se deja puesto, no la accion principal de la pantalla. Encendido se pinta de
/// naranja sobre un fondo tenue; apagado es un icono gris mas.
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
      onPressed: () => _alternar(context, ref),
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

  /// En la build de escritorio, `just_audio_media_kit` (el reproductor que
  /// usa Windows) no tiene implementado el orden aleatorio y tira
  /// `UnimplementedError`. Antes esto quedaba sin capturar: el boton no
  /// reaccionaba y el error solo se veia en la consola. Ahora se avisa.
  Future<void> _alternar(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await alternarAleatorio(ref);
    } catch (_) {
      avisar(
        mensajero,
        'El aleatorio no está disponible en esta versión de escritorio.',
      );
    }
  }
}
