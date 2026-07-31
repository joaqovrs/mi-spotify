import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credenciales del servidor de música.
///
/// El mismo Navidrome se alcanza por dos caminos: la IP de la red de casa
/// (rápida, sin salir a internet) y el dominio DDNS con el puerto abierto
/// (funciona desde cualquier lado). Se guardan las dos y la app elige sola.
class Credenciales {
  const Credenciales({
    required this.urlRemota,
    required this.usuario,
    required this.password,
    this.urlLocal,
  });

  /// Dirección del tailnet. Es la que siempre tiene que estar.
  final String urlRemota;

  /// Dirección en la red de casa. Opcional.
  final String? urlLocal;

  final String usuario;
  final String password;

  /// Direcciones a probar, en orden de preferencia: primero la local porque
  /// es más rápida y no pasa por el túnel; la remota como respaldo.
  List<String> get urls => [?urlLocal, urlRemota];
}

/// Guarda las credenciales en el almacén cifrado del sistema (Keystore en
/// Android), no en preferencias en texto plano.
class AuthStorage {
  const AuthStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _claveUrlRemota = 'servidor_url_remota';
  static const _claveUrlLocal = 'servidor_url_local';
  static const _claveUsuario = 'servidor_usuario';
  static const _clavePassword = 'servidor_password';

  Future<Credenciales?> leer() async {
    final urlRemota = await _storage.read(key: _claveUrlRemota);
    final usuario = await _storage.read(key: _claveUsuario);
    final password = await _storage.read(key: _clavePassword);

    if (urlRemota == null || usuario == null || password == null) return null;

    final urlLocal = await _storage.read(key: _claveUrlLocal);

    return Credenciales(
      urlRemota: urlRemota,
      urlLocal: (urlLocal != null && urlLocal.isNotEmpty) ? urlLocal : null,
      usuario: usuario,
      password: password,
    );
  }

  Future<void> guardar(Credenciales credenciales) async {
    await _storage.write(key: _claveUrlRemota, value: credenciales.urlRemota);
    await _storage.write(key: _claveUsuario, value: credenciales.usuario);
    await _storage.write(key: _clavePassword, value: credenciales.password);

    final local = credenciales.urlLocal;
    if (local == null) {
      await _storage.delete(key: _claveUrlLocal);
    } else {
      await _storage.write(key: _claveUrlLocal, value: local);
    }
  }

  Future<void> borrar() async {
    await _storage.delete(key: _claveUrlRemota);
    await _storage.delete(key: _claveUrlLocal);
    await _storage.delete(key: _claveUsuario);
    await _storage.delete(key: _clavePassword);
  }
}
