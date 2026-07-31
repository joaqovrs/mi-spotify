import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credenciales del servidor de musica.
///
/// Solo usuario y contrasena: las direcciones del servidor ya no se guardan
/// aca, viven en [Servidor] porque son las mismas para todo el mundo. Eso
/// ademas arregla solo a quien tenia guardada una direccion vieja.
class Credenciales {
  const Credenciales({required this.usuario, required this.password});

  final String usuario;
  final String password;
}

/// Guarda las credenciales en el almacen cifrado del sistema (Keystore en
/// Android), no en preferencias en texto plano.
class AuthStorage {
  const AuthStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _claveUsuario = 'servidor_usuario';
  static const _clavePassword = 'servidor_password';

  /// Sobras de cuando el login pedia las direcciones. Se borran al guardar
  /// para no dejar la IP del tailnet dando vueltas en el Keystore.
  static const _clavesViejas = ['servidor_url_remota', 'servidor_url_local'];

  Future<Credenciales?> leer() async {
    final usuario = await _storage.read(key: _claveUsuario);
    final password = await _storage.read(key: _clavePassword);

    if (usuario == null || password == null) return null;

    return Credenciales(usuario: usuario, password: password);
  }

  Future<void> guardar(Credenciales credenciales) async {
    await _storage.write(key: _claveUsuario, value: credenciales.usuario);
    await _storage.write(key: _clavePassword, value: credenciales.password);

    for (final clave in _clavesViejas) {
      await _storage.delete(key: clave);
    }
  }

  Future<void> borrar() async {
    await _storage.delete(key: _claveUsuario);
    await _storage.delete(key: _clavePassword);
    for (final clave in _clavesViejas) {
      await _storage.delete(key: clave);
    }
  }
}
