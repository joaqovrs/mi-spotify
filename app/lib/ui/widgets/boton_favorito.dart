import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/subsonic_client.dart';
import '../../core/theme.dart';
import '../../state/favoritos_providers.dart';

/// Corazon que marca y desmarca favoritos.
///
/// Consulta el conjunto de ids marcados, asi sirve igual para una cancion, un
/// album o un artista sin tener que decirle de que tipo se trata.
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
      // El estado ya volvio atras solo; aqui solo hay que contar que paso.
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
