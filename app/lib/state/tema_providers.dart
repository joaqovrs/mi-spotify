import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tema: Claro / Oscuro / Seguir al sistema.
///
/// Se guarda en preferencias comunes (no es información sensible) y se
/// restaura al abrir la app.
final temaProvider = StateNotifierProvider<TemaNotifier, ThemeMode>(
  (ref) => TemaNotifier()..restaurar(),
);

class TemaNotifier extends StateNotifier<ThemeMode> {
  TemaNotifier() : super(ThemeMode.system);

  static const _clave = 'modo_tema';

  Future<void> restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    if (!mounted || guardado == null) return;

    state = ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, modo.name);
  }
}
