import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'core/plataforma.dart';
import 'core/theme.dart';
import 'services/puente_widget_flotante.dart';
import 'services/reproductor_handler.dart';
import 'state/descargas_providers.dart';
import 'state/favoritos_providers.dart';
import 'state/playlists_providers.dart';
import 'state/reproductor_providers.dart';
import 'state/sesion_providers.dart';
import 'state/tema_providers.dart';
import 'ui/login_screen.dart';
import 'ui/shell_screen.dart';
import 'ui/shell_screen_escritorio.dart';
import 'ui/widget_flotante/widget_flotante_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // En Windows, desktop_multi_window relanza este mismo ejecutable como un
  // proceso aparte para la ventana del widget flotante. Si esta corrida es
  // esa ventana, arranca una app chica y nada mas — ni just_audio ni
  // audio_service hacen falta ahi, esa ventana solo dibuja y manda comandos.
  WindowController? ventanaPropia;
  if (Platform.isWindows) {
    ventanaPropia = await WindowController.fromCurrentEngine();
    if (ventanaPropia.arguments.isNotEmpty) {
      runApp(WidgetFlotanteApp(argumentos: ventanaPropia.arguments));
      return;
    }
  }

  // just_audio no trae backend propio para Windows (WinRT via
  // just_audio_windows reproduce en silencio los streams HTTP de Navidrome:
  // la posicion avanza pero no sale audio, probablemente por como Navidrome
  // entrega el stream). media_kit (libmpv) tolera esos streams sin problema.
  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(windows: true);
  }

  // Tiene que crearse antes de la app: engancha el servicio de Android que
  // sostiene la reproduccion en segundo plano.
  final handler = await AudioService.init(
    builder: ReproductorHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.joaqovrs.mi_spotify.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // Se crea a mano (en vez de dejar que ProviderScope lo arme solo) porque
  // `configurarPuenteWidgetFlotante` necesita leer y escuchar providers desde
  // afuera del arbol de widgets, antes de `runApp`.
  final contenedor = ProviderContainer(
    overrides: [reproductorProvider.overrideWithValue(handler)],
  );

  if (Platform.isWindows) {
    configurarPuenteWidgetFlotante(contenedor, ventanaPropia!);
  }

  runApp(
    UncontrolledProviderScope(container: contenedor, child: const MiSpotifyApp()),
  );
}

class MiSpotifyApp extends ConsumerWidget {
  const MiSpotifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Mi Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: ref.watch(temaProvider),
      home: const _Puerta(),
    );
  }
}

/// Decide que mostrar segun el estado de la sesion. Es el unico lugar que
/// navega entre login y app, asi ninguna pantalla tiene que ocuparse de eso.
class _Puerta extends ConsumerWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Android Auto navega Playlists/Albumes/Artistas a traves del handler, no
    // de esta UI, asi que necesita su propio SubsonicClient. Se lo empuja aca
    // en vez de que el handler lea el Keystore por su cuenta, para que use
    // siempre la misma sesion (y la misma doble direccion local/remota) que
    // el resto de la app.
    ref.listen(sesionProvider, (_, estado) {
      final handler = ref.read(reproductorProvider);
      handler.cliente = switch (estado) {
        SesionAbierta(cliente: final cliente) => cliente,
        _ => null,
      };

      if (estado is SesionCerrada) {
        // Sin esto la cancion seguia sonando con la sesion cerrada: nada
        // paraba al reproductor porque el logout nunca lo tocaba, solo
        // borraba las credenciales guardadas.
        handler.detenerYVaciar();

        // favoritosProvider/descargasProvider/playlistsProvider piden
        // clienteProvider en el constructor de su StateNotifier, no dentro de
        // una funcion async: si algo los vuelve a evaluar despues de cerrar
        // sesion (no son autoDispose, asi que sobreviven al logout), ese
        // pedido explota de forma sincronica y sin capturar, y Riverpod
        // reintenta la reconstruccion en cada frame para siempre. Invalidarlos
        // ahora los tira abajo mientras la sesion todavia esta abierta un
        // instante mas, en vez de dejarlos colgados con un cliente viejo.
        ref.invalidate(favoritosProvider);
        ref.invalidate(descargasProvider);
        ref.invalidate(playlistsProvider);
        ref.invalidate(cancionesDePlaylistProvider);
      }
    });

    return switch (ref.watch(sesionProvider)) {
      SesionCargando() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      SesionCerrada() => const LoginScreen(),
      SesionAbierta() => esEscritorio
          ? const ShellScreenEscritorio()
          : const ShellScreen(),
    };
  }
}
