import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'services/reproductor_handler.dart';
import 'state/reproductor_providers.dart';
import 'state/sesion_providers.dart';
import 'state/tema_providers.dart';
import 'ui/login_screen.dart';
import 'ui/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    ProviderScope(
      overrides: [reproductorProvider.overrideWithValue(handler)],
      child: const MiSpotifyApp(),
    ),
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
      ref.read(reproductorProvider).cliente = switch (estado) {
        SesionAbierta(cliente: final cliente) => cliente,
        _ => null,
      };
    });

    return switch (ref.watch(sesionProvider)) {
      SesionCargando() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      SesionCerrada() => const LoginScreen(),
      SesionAbierta() => const ShellScreen(),
    };
  }
}
