import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/subsonic_client.dart';
import '../../core/theme.dart';
import '../../state/favoritos_providers.dart';

/// Corazón que marca y desmarca favoritos.
///
/// Consulta el conjunto de ids marcados, así sirve igual para una canción, un
/// álbum o un artista sin tener que decirle de qué tipo se trata.
class BotonFavorito extends ConsumerWidget {
  const BotonFavorito({
    required this.id,
    required this.onAlternar,
    this.tamano = 24,
    super.key,
  });

  final String id;
  final Future<void> Function() onAlternar;
  final double tamano;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esFavorito = ref.watch(idsFavoritosProvider).contains(id);

    return IconButton(
      iconSize: tamano,
      tooltip: esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
      onPressed: () => _alternar(context),
      icon: Icon(
        esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: esFavorito ? AppColors.naranja : null,
      ),
    );
  }

  Future<void> _alternar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);

    try {
      await onAlternar();
    } on SubsonicException catch (e) {
      // El estado ya volvió atrás solo; acá solo hay que contar qué pasó.
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.mensaje)));
    } catch (_) {
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el favorito.')),
        );
    }
  }
}
