import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_storage.dart';
import '../core/subsonic_client.dart';

/// Estado de la sesión con el servidor.
sealed class SesionEstado {
  const SesionEstado();
}

/// Todavía se está leyendo el almacén seguro al arrancar la app.
class SesionCargando extends SesionEstado {
  const SesionCargando();
}

/// No hay credenciales guardadas: se muestra el login.
class SesionCerrada extends SesionEstado {
  const SesionCerrada();
}

/// Hay credenciales válidas y un cliente listo para usar.
class SesionAbierta extends SesionEstado {
  const SesionAbierta(this.cliente);

  final SubsonicClient cliente;
}

final authStorageProvider = Provider<AuthStorage>((ref) => const AuthStorage());

final sesionProvider = StateNotifierProvider<SesionNotifier, SesionEstado>(
  (ref) => SesionNotifier(ref.watch(authStorageProvider))..restaurar(),
);

class SesionNotifier extends StateNotifier<SesionEstado> {
  SesionNotifier(this._storage) : super(const SesionCargando());

  final AuthStorage _storage;

  /// Al arrancar: si hay credenciales guardadas se entra directo, sin pedir
  /// login de nuevo. No se valida contra el servidor acá a propósito — si el
  /// servidor está caído, igual queremos entrar y mostrar el error adentro,
  /// no dejar al usuario trabado en la pantalla de login.
  Future<void> restaurar() async {
    final credenciales = await _storage.leer();
    if (!mounted) return;

    state = credenciales == null
        ? const SesionCerrada()
        : SesionAbierta(_clienteDesde(credenciales));
  }

  /// Valida contra el servidor y, si anda, guarda las credenciales.
  /// Lanza [SubsonicException] si falla, para que el login muestre el motivo.
  ///
  /// Alcanza con que **una** de las dos direcciones responda: si estás en casa
  /// va a entrar por la local, y si estás afuera por el tailnet.
  Future<void> iniciarSesion({
    required String urlRemota,
    required String usuario,
    required String password,
    String? urlLocal,
  }) async {
    final local = urlLocal?.trim();
    final credenciales = Credenciales(
      urlRemota: SubsonicClient.normalizarUrl(urlRemota),
      urlLocal: (local == null || local.isEmpty)
          ? null
          : SubsonicClient.normalizarUrl(local),
      usuario: usuario.trim(),
      password: password,
    );

    final cliente = _clienteDesde(credenciales);
    await cliente.ping();

    await _storage.guardar(credenciales);
    if (!mounted) return;
    state = SesionAbierta(cliente);
  }

  Future<void> cerrarSesion() async {
    await _storage.borrar();
    if (!mounted) return;
    state = const SesionCerrada();
  }

  SubsonicClient _clienteDesde(Credenciales c) =>
      SubsonicClient(urls: c.urls, usuario: c.usuario, password: c.password);
}

/// Atajo para las pantallas que ya saben que hay sesión abierta.
final clienteProvider = Provider<SubsonicClient>((ref) {
  final estado = ref.watch(sesionProvider);
  if (estado is SesionAbierta) return estado.cliente;
  throw StateError('Se pidió el cliente sin una sesión abierta.');
});
