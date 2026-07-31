import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/descargas_providers.dart';
import '../../state/sesion_providers.dart';

/// Portada de album, cancion o artista.
///
/// Cuando el servidor no tiene imagen (o falla la descarga) muestra un
/// marcador con la misma forma, para que las grillas no se descuadren.
class Portada extends ConsumerWidget {
  const Portada({
    required this.coverArt,
    required this.lado,
    this.radio = 16,
    this.circular = false,
    super.key,
  });

  /// Identificador de portada que devolvio Subsonic. Null si no hay.
  final String? coverArt;

  final double lado;
  final double radio;

  /// Los artistas se muestran redondos; los albumes, cuadrados.
  final bool circular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forma = circular
        ? BorderRadius.circular(lado / 2)
        : BorderRadius.circular(radio);

    final id = coverArt;
    if (id == null) {
      return _Marcador(lado: lado, forma: forma);
    }

    // Si el album esta descargado, la caratula sale del telefono. Sin esto la
    // pantalla de descargas se veria con todos los marcadores grises justo
    // cuando no hay servidor, que es cuando mas se usa.
    final local = ref.watch(portadasDescargadasProvider)[id];
    if (local != null) {
      return ClipRRect(
        borderRadius: forma,
        child: Image.file(
          File(local),
          width: lado,
          height: lado,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Marcador(lado: lado, forma: forma),
        ),
      );
    }

    // Se pide al doble del tamaño en pantalla para que no se vea borrosa en
    // pantallas de alta densidad.
    final url = ref
        .read(clienteProvider)
        .urlPortada(id, tamano: (lado * 2).round())
        .toString();

    return ClipRRect(
      borderRadius: forma,
      child: CachedNetworkImage(
        imageUrl: url,
        width: lado,
        height: lado,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, _) => _Marcador(lado: lado, forma: forma),
        errorWidget: (_, _, _) => _Marcador(lado: lado, forma: forma),
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.lado, required this.forma});

  final double lado;
  final BorderRadius forma;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: colores.surfaceContainerHighest,
        borderRadius: forma,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: lado * 0.36,
        color: colores.onSurface.withValues(alpha: 0.28),
      ),
    );
  }
}
