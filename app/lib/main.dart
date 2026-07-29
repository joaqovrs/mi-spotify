import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'state/sesion_providers.dart';
import 'state/tema_providers.dart';
import 'ui/login_screen.dart';
import 'ui/shell_screen.dart';

void main() {
  runApp(const ProviderScope(child: MiSpotifyApp()));
}

class MiSpotifyApp extends ConsumerWidget {
  const MiSpotifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'mi spotify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.oscuro,
      themeMode: ref.watch(temaProvider),
      home: const _Puerta(),
    );
  }
}

/// Decide qué mostrar según el estado de la sesión. Es el único lugar que
/// navega entre login y app, así ninguna pantalla tiene que ocuparse de eso.
class _Puerta extends ConsumerWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(sesionProvider)) {
      SesionCargando() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      SesionCerrada() => const LoginScreen(),
      SesionAbierta() => const ShellScreen(),
    };
  }
}
