import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../state/reproductor_providers.dart';

/// Encola canciones y confirma con un aviso.
///
/// El aviso importa: agregar al final de una cola larga no produce ningún
/// cambio visible, así que sin confirmación parece que el botón no hizo nada.
Future<void> encolar(
  BuildContext context,
  WidgetRef ref,
  List<Cancion> canciones,
) async {
  if (canciones.isEmpty) return;

  final arrancaAhora = ref.read(colaProvider).value?.isEmpty ?? true;
  await agregarACola(ref, canciones);

  if (!context.mounted) return;

  final texto = switch ((arrancaAhora, canciones.length)) {
    (true, _) => 'Reproduciendo',
    (false, 1) => 'Agregada a la cola',
    (false, final n) => '$n canciones agregadas a la cola',
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 2)),
    );
}
