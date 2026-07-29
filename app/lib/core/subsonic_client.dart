import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Error devuelto por el servidor Subsonic (Navidrome) o por la conexión.
class SubsonicException implements Exception {
  const SubsonicException(this.mensaje, {this.codigo});

  final String mensaje;

  /// Código de error de la API Subsonic, cuando lo hay.
  /// Los que interesan: 40 = credenciales inválidas, 70 = no encontrado.
  ///
  /// Que venga un código significa que el servidor **contestó**: el problema
  /// es la petición, no la red.
  final int? codigo;

  bool get esCredencialInvalida => codigo == 40;

  /// True cuando no se pudo llegar al servidor (a diferencia de haber llegado
  /// y que rechazara la petición).
  bool get esProblemaDeRed => codigo == null;

  @override
  String toString() => mensaje;
}

/// Cliente de la API Subsonic que expone Navidrome.
///
/// La autenticación de Subsonic no manda la contraseña: por cada request se
/// genera un `salt` al azar y se envía `t = md5(contraseña + salt)`. El
/// servidor rehace el mismo cálculo y compara. Así la contraseña nunca viaja,
/// ni siquiera cifrada.
///
/// El cliente acepta **varias direcciones** para el mismo servidor (la de la
/// red local y la del tailnet) y descubre sola cuál responde. Ver [_resolver].
class SubsonicClient {
  SubsonicClient({
    required List<String> urls,
    required this.usuario,
    required this.password,
    Dio? dio,
  }) : assert(urls.isNotEmpty, 'Hace falta al menos una dirección'),
       urls = List.unmodifiable(urls),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 20),
             ),
           ),
       _dioSonda =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(milliseconds: 1800),
               receiveTimeout: const Duration(milliseconds: 1800),
             ),
           );

  /// Direcciones candidatas, en orden de preferencia. Normalmente la local
  /// primero (más rápida, sin pasar por el túnel) y la del tailnet después.
  final List<String> urls;
  final String usuario;
  final String password;

  final Dio _dio;

  /// Dio con timeouts cortos, solo para probar direcciones. Sin esto, detectar
  /// que la IP local no responde tardaría 12 segundos en vez de 2.
  final Dio _dioSonda;

  final Random _random = Random.secure();

  /// Dirección que se comprobó que funciona. Se descarta al fallar la red,
  /// para que un cambio de WiFi a datos móviles se detecte solo.
  String? _activa;

  static const String _version = '1.16.1';
  static const String _cliente = 'miSpotify';

  /// Dirección en uso. Antes de la primera conexión asume la preferida.
  String get baseUrlActiva => _activa ?? urls.first;

  /// Acepta lo que el usuario haya tipeado y devuelve una URL usable.
  ///
  /// `192.168.1.194:4533` → `http://192.168.1.194:4533`
  /// `http://mi-spotify:4533/` → `http://mi-spotify:4533`
  static String normalizarUrl(String entrada) {
    var url = entrada.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Parámetros de autenticación, con un salt nuevo en cada llamada.
  Map<String, String> _paramsAuth() {
    final salt = _generarSalt();
    final token = md5.convert(utf8.encode(password + salt)).toString();
    return {
      'u': usuario,
      't': token,
      's': salt,
      'v': _version,
      'c': _cliente,
      'f': 'json',
    };
  }

  String _generarSalt() {
    const alfabeto = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      12,
      (_) => alfabeto[_random.nextInt(alfabeto.length)],
    ).join();
  }

  /// Arma una URL firmada sobre una dirección concreta.
  Uri _uriEn(
    String baseUrl,
    String endpoint, [
    Map<String, String> params = const {},
  ]) {
    return Uri.parse(
      '$baseUrl/rest/$endpoint',
    ).replace(queryParameters: {..._paramsAuth(), ...params});
  }

  /// Arma una URL completa firmada sobre la dirección activa. Se usa para
  /// portadas y streaming, donde el reproductor necesita la URL en vez de la
  /// respuesta parseada.
  Uri construirUri(String endpoint, [Map<String, String> params = const {}]) =>
      _uriEn(baseUrlActiva, endpoint, params);

  /// Prueba las direcciones en orden y se queda con la primera que responde.
  ///
  /// Si alguna contesta con un error de la API (por ejemplo contraseña mala),
  /// corta ahí: llegamos al servidor, probar la otra dirección no aportaría
  /// nada y solo demoraría el mensaje de error.
  Future<String> _resolver() async {
    SubsonicException? ultimoError;

    for (final url in urls) {
      try {
        await _pedir(_dioSonda, _uriEn(url, 'ping'));
        _activa = url;
        return url;
      } on SubsonicException catch (e) {
        if (!e.esProblemaDeRed) rethrow;
        ultimoError = e;
      }
    }

    throw ultimoError ??
        const SubsonicException('No se pudo conectar al servidor.');
  }

  /// Llama a un endpoint y devuelve el contenido de `subsonic-response`.
  ///
  /// Si la dirección activa deja de responder (típicamente al salir de casa),
  /// la descarta y vuelve a resolver antes de dar el error por definitivo.
  Future<Map<String, dynamic>> _get(
    String endpoint, [
    Map<String, String> params = const {},
  ]) async {
    final url = _activa ?? await _resolver();

    try {
      return await _pedir(_dio, _uriEn(url, endpoint, params));
    } on SubsonicException catch (e) {
      if (!e.esProblemaDeRed || urls.length == 1) rethrow;

      _activa = null;
      final nueva = await _resolver();
      return _pedir(_dio, _uriEn(nueva, endpoint, params));
    }
  }

  /// Ejecuta la petición y desenvuelve la respuesta Subsonic.
  Future<Map<String, dynamic>> _pedir(Dio dio, Uri uri) async {
    late final Response<dynamic> respuesta;
    try {
      respuesta = await dio.getUri<dynamic>(uri);
    } on DioException catch (e) {
      throw SubsonicException(_mensajeDeRed(e));
    }

    final cuerpo = respuesta.data;
    if (cuerpo is! Map) {
      throw const SubsonicException(
        'El servidor respondió algo inesperado. ¿Es realmente un servidor Navidrome?',
        codigo: -1,
      );
    }

    final datos = cuerpo['subsonic-response'];
    if (datos is! Map) {
      throw const SubsonicException(
        'La respuesta no tiene formato Subsonic. Revisá la dirección del servidor.',
        codigo: -1,
      );
    }

    if (datos['status'] != 'ok') {
      final error = datos['error'];
      final codigo = error is Map ? error['code'] as int? : null;
      final mensaje = error is Map ? error['message'] as String? : null;
      throw SubsonicException(
        codigo == 40
            ? 'Usuario o contraseña incorrectos.'
            : (mensaje ?? 'El servidor rechazó la petición.'),
        codigo: codigo ?? -1,
      );
    }

    return Map<String, dynamic>.from(datos);
  }

  String _mensajeDeRed(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'El servidor no respondió a tiempo. Si estás fuera de casa, '
            'revisá que Tailscale esté activo.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar al servidor. Revisá la dirección y que '
            'Tailscale esté activo.';
      case DioExceptionType.badResponse:
        return 'El servidor respondió con un error '
            '(${e.response?.statusCode ?? 'sin código'}).';
      default:
        return 'Fallo de conexión con el servidor.';
    }
  }

  /// Verifica servidor y credenciales de una sola vez.
  Future<void> ping() => _get('ping');

  /// URL de la portada de un álbum o canción, lista para `Image.network`.
  Uri urlPortada(String id, {int? tamano}) => construirUri('getCoverArt', {
    'id': id,
    if (tamano != null) 'size': '$tamano',
  });

  /// URL de streaming de una canción, lista para el reproductor.
  Uri urlStream(String id) => construirUri('stream', {'id': id});
}
