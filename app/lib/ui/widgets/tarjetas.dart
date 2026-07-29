import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/biblioteca.dart';
import 'portada.dart';

/// Tarjeta vertical de álbum para los carruseles y la grilla.
class TarjetaAlbum extends StatelessWidget {
  const TarjetaAlbum({
    required this.album,
    required this.lado,
    this.onTap,
    super.key,
  });

  final Album album;
  final double lado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: lado,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Portada(coverArt: album.coverArt, lado: lado),
            const SizedBox(height: 10),
            Text(
              album.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              album.artista,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de canción: portada chica, título, artista y duración.
///
/// Con [sonando] en true se pinta de naranja y cambia la duración por un
/// ícono de ecualizador, para que se vea de un golpe cuál de la lista está
/// reproduciéndose.
class FilaCancion extends StatelessWidget {
  const FilaCancion({
    required this.cancion,
    this.onTap,
    this.sonando = false,
    super.key,
  });

  final Cancion cancion;
  final VoidCallback? onTap;
  final bool sonando;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;

    // El naranja de marca no tiene contraste suficiente sobre blanco, así que
    // en tema claro se usa la variante oscurecida.
    final acento = tema.brightness == Brightness.dark
        ? AppColors.naranja
        : AppColors.naranjaTexto;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: sonando ? acento.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Portada(coverArt: cancion.coverArt, lado: 52, radio: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cancion.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.titleMedium?.copyWith(
                      color: sonando ? acento : null,
                      fontWeight: sonando ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cancion.artista,
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
            else
              Text(cancion.duracionFormateada, style: textos.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Fila de artista, con la portada redonda.
class FilaArtista extends StatelessWidget {
  const FilaArtista({required this.artista, this.onTap, super.key});

  final Artista artista;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final albumes = artista.cantidadAlbumes;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Portada(coverArt: artista.coverArt, lado: 56, circular: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artista.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.titleMedium,
                  ),
                  if (albumes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      albumes == 1 ? '1 álbum' : '$albumes álbumes',
                      style: textos.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
