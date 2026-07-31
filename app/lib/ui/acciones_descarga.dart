import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/biblioteca.dart';
import '../models/descarga.dart';
import '../state/descargas_providers.dart';
import 'avisos.dart';

/// Manda canciones a la cola de descarga y confirma con un aviso.
///
/// No espera a que terminen: la cola avanza sola de a una y el progreso se ve
/// en la pestaña Descargas. Bloquear la pantalla hasta bajar un disco entero
/// por el túnel de Tailscale no sería usable.
void descargar(
  BuildContext context,
  WidgetRef ref,
  List<Cancion> canciones,
) {
  if (canciones.isEmpty) return;

  final notifier = ref.read(descargasProvider.notifier);
  final yaEstan = {
    ...ref.read(archivosDescargadosProvider).keys,
    ...notifier.idsEnCola,
  };
  final nuevas = canciones.where((c) => !yaEstan.contains(c.id)).length;

  notifier.descargar(canciones);

  avisar(ScaffoldMessenger.of(context), switch (nuevas) {
    0 => 'Ya estaba en el teléfono',
    1 => 'Descargando…',
    final n => 'Descargando $n canciones…',
  });
}

/// Borra del teléfono lo descargado de una canción.
Future<void> quitarDescarga(
  BuildContext context,
  WidgetRef ref,
  Descarga descarga,
) async {
  final mensajero = ScaffoldMessenger.of(context);

  await ref.read(descargasProvider.notifier).borrar(descarga);
  avisar(mensajero, 'Borrada del teléfono');
}
