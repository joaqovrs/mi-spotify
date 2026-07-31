import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// El logo de Mi Music.
///
/// Vive aca y no dentro del login porque lo usan tambien el registro y, cuando
/// llegue el arte definitivo, va a ser el unico lugar a cambiar.
class LogoMarca extends StatelessWidget {
  const LogoMarca({super.key, this.tamano = 76});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tamano,
      width: tamano,
      decoration: BoxDecoration(
        color: AppColors.naranja,
        borderRadius: BorderRadius.circular(tamano / 3.2),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: tamano * 0.53,
      ),
    );
  }
}

/// Cartel rojo de error. Compartido por el login y el registro.
class MensajeError extends StatelessWidget {
  const MensajeError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colores.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colores.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
