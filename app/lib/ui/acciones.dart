import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import '../state/playlists_providers.dart';
import '../state/reproductor_providers.dart';
import 'avisos.dart';
import 'widgets/estados.dart';
import 'widgets/tarjetas.dart';

/// Encola canciones y confirma con un aviso.
///
/// El aviso importa: agregar al final de una cola larga no produce ningun
/// cambio visible, asi que sin confirmacion parece que el boton no hizo nada.
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

  avisar(ScaffoldMessenger.of(context), texto);
}

// --------------------------------------------------------------- A playlists

/// Lo que se eligio en la hoja de playlists.
sealed class _Eleccion {
  const _Eleccion();
}

class _Existente extends _Eleccion {
  const _Existente(this.playlist);

  final Playlist playlist;
}

class _Nueva extends _Eleccion {
  const _Nueva();
}

/// Abre la hoja para mandar canciones a una playlist.
///
/// Sirve tanto para una cancion suelta como para un album entero, y permite
/// crear la playlist en el momento: obligar a ir hasta la biblioteca a crearla
/// primero rompe el hilo de lo que estabas haciendo.
Future<void> agregarAPlaylist(
  BuildContext context,
  WidgetRef ref,
  List<Cancion> canciones,
) async {
  if (canciones.isEmpty) return;

  final eleccion = await showModalBottomSheet<_Eleccion>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _HojaPlaylists(),
  );

  if (eleccion == null || !context.mounted) return;

  final mensajero = ScaffoldMessenger.of(context);
  final notifier = ref.read(playlistsProvider.notifier);

  try {
    switch (eleccion) {
      case _Nueva():
        final nombre = await pedirNombrePlaylist(
          context,
          titulo: 'Nueva playlist',
          aceptar: 'Crear',
        );
        if (nombre == null) return;

        final creada = await notifier.crear(
          nombre: nombre,
          canciones: canciones,
        );
        avisar(mensajero, '${_cuantas(canciones.length)} en «${creada.nombre}»');

      case _Existente(:final playlist):
        await notifier.agregarCanciones(playlist.id, canciones);
        avisar(
          mensajero,
          '${_cuantas(canciones.length)} en «${playlist.nombre}»',
        );
    }
  } on SubsonicException catch (e) {
    avisar(mensajero, e.mensaje);
  } catch (_) {
    avisar(mensajero, 'No se pudo guardar en la playlist.');
  }
}

String _cuantas(int cantidad) =>
    cantidad == 1 ? 'Cancion guardada' : '$cantidad canciones guardadas';

class _HojaPlaylists extends ConsumerWidget {
  const _HojaPlaylists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final asincrono = ref.watch(playlistsProvider);

    return SafeArea(
      child: ConstrainedBox(
        // Sin tope, con muchas playlists la hoja taparia toda la pantalla.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Text('Guardar en playlist', style: textos.titleLarge),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.add_rounded),
              title: Text('Nueva playlist', style: textos.titleMedium),
              onTap: () => Navigator.of(context).pop(const _Nueva()),
            ),
            const Divider(height: 1),
            Flexible(
              child: asincrono.when(
                loading: () => const EstadoCargando(alto: 120),
                error: (e, _) => EstadoError(
                  error: e,
                  onReintentar: () =>
                      ref.read(playlistsProvider.notifier).cargar(),
                ),
                data: (playlists) {
                  if (playlists.isEmpty) {
                    return const EstadoVacio(
                      mensaje: 'Todavia no tienes playlists. Crea la primera.',
                      icono: Icons.queue_music_rounded,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    itemCount: playlists.length,
                    itemBuilder: (context, i) => FilaPlaylist(
                      playlist: playlists[i],
                      onTap: () =>
                          Navigator.of(context).pop(_Existente(playlists[i])),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Dialogos

/// Pide un nombre de playlist. Devuelve null si se cancelo.
Future<String?> pedirNombrePlaylist(
  BuildContext context, {
  required String titulo,
  required String aceptar,
  String inicial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _DialogoNombre(titulo: titulo, aceptar: aceptar, inicial: inicial),
  );
}

class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({
    required this.titulo,
    required this.aceptar,
    required this.inicial,
  });

  final String titulo;
  final String aceptar;
  final String inicial;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController _controlador = TextEditingController(
    text: widget.inicial,
  );

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nombre = _controlador.text.trim();
    if (nombre.isEmpty) return;
    Navigator.of(context).pop(nombre);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controlador,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        // Sin esto habria que bajar el teclado para llegar al boton.
        onSubmitted: (_) => _confirmar(),
        decoration: const InputDecoration(hintText: 'Nombre de la playlist'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        // Escucha al controlador para poder deshabilitarse con el campo vacio.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controlador,
          builder: (context, valor, _) => TextButton(
            onPressed: valor.text.trim().isEmpty ? null : _confirmar,
            child: Text(widget.aceptar),
          ),
        ),
      ],
    );
  }
}

/// Confirmacion para acciones que no se pueden deshacer, y que ademas borran
/// algo del servidor.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String aceptar,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(contexto).colorScheme.error,
          ),
          child: Text(aceptar),
        ),
      ],
    ),
  );

  return respuesta ?? false;
}
