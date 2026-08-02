import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// El logo de Mi Music: el mismo icono que la app deja en el telefono.
///
/// Antes era una nota generica de Material sobre un cuadrado naranja. Que la
/// pantalla de entrada muestre otra cosa que el icono del lanzador es la unica
/// vez que alguien duda de haber abierto la app correcta.
///
/// Vive aca y no dentro del login porque lo usa tambien el registro.
class LogoMarca extends StatelessWidget {
  const LogoMarca({super.key, this.tamano = 76});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    // El mismo redondeo que trae dibujado el PNG (`rx="115"` sobre 512 en
    // `assets/icono/icono.svg`). Se replica para que la sombra siga el borde
    // del icono y no se asome por las esquinas.
    final forma = BorderRadius.circular(tamano * 0.2246);

    // El icono es oscuro y el fondo del login, en tema claro, es blanco: sin
    // nada abajo queda como un recorte pegado. El halo naranja lo apoya en la
    // pagina y ata el logo al color de marca.
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        height: tamano,
        width: tamano,
        decoration: BoxDecoration(
          borderRadius: forma,
          boxShadow: [
            BoxShadow(
              color: AppColors.naranja.withValues(alpha: oscuro ? 0.30 : 0.24),
              blurRadius: tamano * 0.34,
              offset: Offset(0, tamano * 0.12),
            ),
          ],
        ),
        child: Image.asset(
          'assets/icono/icono.png',
          width: tamano,
          height: tamano,
          // El archivo es de 1024 px y aca se ve a 76: sin este tope se
          // decodificarian 4 MB en memoria para un logo del tamaño de un pulgar.
          cacheWidth: (tamano * MediaQuery.devicePixelRatioOf(context)).round(),
          filterQuality: FilterQuality.medium,
        ),
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
