import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/descargas_providers.dart';
import '../state/reproductor_providers.dart';
import '../state/sesion_providers.dart';

/// Estado de la ventana del widget flotante, del lado de la ventana
/// principal (la unica que sabe si existe y si esta a la vista).
class EstadoWidgetFlotante {
  const EstadoWidgetFlotante({this.controlador, this.visible = false});

  final WindowController? controlador;
  final bool visible;

  EstadoWidgetFlotante copiarCon({WindowController? controlador, bool? visible}) =>
      EstadoWidgetFlotante(
        controlador: controlador ?? this.controlador,
        visible: visible ?? this.visible,
      );
}

/// Crea, muestra, esconde y alimenta la ventana del widget flotante.
///
/// La ventana del widget es un motor de Flutter aparte (`desktop_multi_window`
/// crea un proceso nuevo del mismo ejecutable): no tiene acceso a este
/// `ProviderScope`, asi que no puede leer `reproductorProvider` ni ningun otro
/// provider por su cuenta. Este notifier es el unico lado que sabe reproducir
/// y le manda a esa ventana ya resuelto lo que tiene que mostrar — la ventana
/// del widget solo dibuja y manda de vuelta que boton se toco.
class PuenteWidgetFlotanteNotifier extends StateNotifier<EstadoWidgetFlotante> {
  PuenteWidgetFlotanteNotifier(this._ref) : super(const EstadoWidgetFlotante());

  final Ref _ref;

  /// Crea la ventana si hace falta, o alterna mostrar/esconder si ya existe.
  Future<void> alternar() async {
    final controlador = state.controlador;

    if (controlador == null) {
      final propia = await WindowController.fromCurrentEngine();
      final nuevo = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: jsonEncode({'idPrincipal': propia.windowId}),
        ),
      );
      state = state.copiarCon(controlador: nuevo, visible: true);
      await _enviar(nuevo);
      await nuevo.show();
      return;
    }

    if (state.visible) {
      await controlador.hide();
      state = state.copiarCon(visible: false);
    } else {
      await _enviar(controlador);
      await controlador.show();
      state = state.copiarCon(visible: true);
    }
  }

  /// Le manda a la ventana del widget la cancion y el estado actuales, si esta
  /// creada y a la vista. Se llama al abrirla y cada vez que cambia la
  /// cancion o el estado de reproduccion (ver `configurarPuenteWidgetFlotante`
  /// en `main.dart`).
  Future<void> enviarEstadoActual() async {
    final controlador = state.controlador;
    if (controlador == null || !state.visible) return;
    await _enviar(controlador);
  }

  Future<void> _enviar(WindowController controlador) async {
    final cancion = _ref.read(cancionActualProvider).value;
    final reproduciendo = _ref.read(estadoReproduccionProvider).value?.playing ?? false;

    if (cancion == null) {
      await controlador.invokeMethod(
        'actualizar',
        jsonEncode({'cancion': null, 'reproduciendo': false}),
      );
      return;
    }

    final idPortada = portadaDe(cancion);
    String? caratula;
    var esArchivo = false;

    if (idPortada != null) {
      final local = _ref.read(portadasDescargadasProvider)[idPortada];
      if (local != null) {
        caratula = local;
        esArchivo = true;
      } else {
        caratula = _ref
            .read(clienteProvider)
            .urlPortada(idPortada, tamano: 200)
            .toString();
      }
    }

    await controlador.invokeMethod(
      'actualizar',
      jsonEncode({
        'cancion': {
          'titulo': cancion.title,
          'artista': cancion.artist,
          'caratula': caratula,
          'esArchivo': esArchivo,
        },
        'reproduciendo': reproduciendo,
      }),
    );
  }
}

final puenteWidgetFlotanteProvider =
    StateNotifierProvider<PuenteWidgetFlotanteNotifier, EstadoWidgetFlotante>(
      (ref) => PuenteWidgetFlotanteNotifier(ref),
    );

/// Engancha la ventana principal para que reciba los comandos de transporte
/// del widget flotante y le empuje la cancion/estado cada vez que cambian.
/// Se llama una sola vez, desde `main()`, antes de `runApp`.
void configurarPuenteWidgetFlotante(
  ProviderContainer contenedor,
  WindowController ventanaPropia,
) {
  ventanaPropia.setWindowMethodHandler((call) async {
    final handler = contenedor.read(reproductorProvider);
    switch (call.method) {
      case 'anterior':
        await handler.skipToPrevious();
      case 'reproducir_pausa':
        final sonando =
            contenedor.read(estadoReproduccionProvider).value?.playing ??
            false;
        if (sonando) {
          await handler.pause();
        } else {
          await handler.play();
        }
      case 'siguiente':
        await handler.skipToNext();
    }
  });

  void enviar() =>
      contenedor.read(puenteWidgetFlotanteProvider.notifier).enviarEstadoActual();

  contenedor.listen(cancionActualProvider, (_, _) => enviar());
  contenedor.listen(estadoReproduccionProvider, (_, _) => enviar());
}
