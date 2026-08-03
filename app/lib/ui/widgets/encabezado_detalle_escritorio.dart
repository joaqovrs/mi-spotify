import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'portada.dart';

/// Circulo de reproducir chico (56px), reusado igual en el header de Album y
/// de Playlist de escritorio — la unica pieza de la fila de acciones que es
/// identica entre los dos.
class BotonReproducirGrande extends StatelessWidget {
  const BotonReproducirGrande({
    required this.onPressed,
    this.reproduciendo = false,
    super.key,
  });

  final VoidCallback? onPressed;

  /// Si esta lista (el album o la playlist del header) es la que suena
  /// ahora mismo — para mostrar pausa en vez de reproducir. Quien arma el
  /// widget tambien tiene que cambiar `onPressed` acorde (pausar en vez de
  /// arrancar de nuevo); este boton solo dibuja, no decide la accion.
  final bool reproduciendo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: onPressed == null
            ? AppColors.naranja.withValues(alpha: 0.4)
            : AppColors.naranja,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: 26,
        color: Colors.white,
        onPressed: onPressed,
        icon: Icon(
          reproduciendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ),
      ),
    );
  }
}

/// Banner tipo Spotify para el detalle de un album o una playlist: caratula
/// a la izquierda, una etiqueta chica arriba del titulo, el titulo bien
/// grande, y una linea de datos debajo. Solo la parte visual — la fila de
/// acciones (reproducir, aleatorio, favorito, descargar) la arma cada
/// pantalla, porque los botones difieren entre album y playlist.
class EncabezadoDetalleEscritorio extends StatelessWidget {
  const EncabezadoDetalleEscritorio({
    required this.coverArt,
    required this.etiqueta,
    required this.titulo,
    required this.subtitulo,
    super.key,
  });

  final String? coverArt;
  final String etiqueta;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.naranja.withValues(alpha: 0.35),
            tema.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Portada(coverArt: coverArt, lado: 180, radio: 12),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  etiqueta.toUpperCase(),
                  style: textos.labelLarge?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textos.displaySmall?.copyWith(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(subtitulo, style: textos.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
