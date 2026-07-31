import 'package:dio/dio.dart';

import 'config.dart';

/// Falla al crear una cuenta. El mensaje ya viene listo para mostrar.
class RegistroException implements Exception {
  const RegistroException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Crea usuarios en Navidrome a traves del servicio de registro.
///
/// No le pega a Navidrome directamente **a proposito**: crear un usuario exige
/// credenciales de administrador, y meterlas en el APK equivale a publicarlas
/// (cualquiera puede abrir un APK). Esas credenciales viven en el servidor,
/// dentro del servicio, y desde afuera solo se puede pedir "creame un usuario
/// comun". Ver infra/registro/.
class RegistroClient {
  RegistroClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Servidor.urlRegistro,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              // Los errores se leen del cuerpo, no de una excepcion: el
              // servicio manda el motivo en JSON y queremos mostrarlo tal cual.
              validateStatus: (_) => true,
            ),
          );

  final Dio _dio;

  Future<void> crearCuenta({
    required String usuario,
    required String password,
    required String invitacion,
  }) async {
    final Response respuesta;
    try {
      respuesta = await _dio.post(
        '/registro',
        data: {
          'usuario': usuario.trim(),
          'password': password,
          'invitacion': invitacion.trim(),
        },
      );
    } on DioException {
      throw const RegistroException(
        'No se pudo conectar con el servidor. Revisa tu conexion e '
        'intenta de nuevo.',
      );
    }

    if (respuesta.statusCode == 201) return;

    final cuerpo = respuesta.data;
    final motivo = (cuerpo is Map && cuerpo['error'] is String)
        ? cuerpo['error'] as String
        : 'No se pudo crear la cuenta (codigo ${respuesta.statusCode}).';

    throw RegistroException(motivo);
  }
}
