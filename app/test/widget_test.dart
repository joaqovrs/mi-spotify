import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/core/auth_storage.dart';
import 'package:mi_spotify/core/subsonic_client.dart';

void main() {
  group('normalizarUrl', () {
    test('agrega http:// cuando falta el esquema', () {
      expect(
        SubsonicClient.normalizarUrl('192.168.1.194:4533'),
        'http://192.168.1.194:4533',
      );
    });

    test('respeta https cuando ya viene puesto', () {
      expect(
        SubsonicClient.normalizarUrl('https://mi-spotify.ts.net'),
        'https://mi-spotify.ts.net',
      );
    });

    test('saca las barras finales', () {
      expect(
        SubsonicClient.normalizarUrl('http://mi-spotify:4533//'),
        'http://mi-spotify:4533',
      );
    });

    test('limpia espacios alrededor', () {
      expect(
        SubsonicClient.normalizarUrl('  100.91.22.33:4533  '),
        'http://100.91.22.33:4533',
      );
    });
  });

  group('construirUri', () {
    final cliente = SubsonicClient(
      urls: ['http://servidor:4533'],
      usuario: 'joaco',
      password: 'secreta',
    );

    test('apunta a /rest/ y manda los parámetros de Subsonic', () {
      final uri = cliente.construirUri('ping');

      expect(uri.path, '/rest/ping');
      expect(uri.queryParameters['u'], 'joaco');
      expect(uri.queryParameters['v'], '1.16.1');
      expect(uri.queryParameters['c'], 'miSpotify');
      expect(uri.queryParameters['f'], 'json');
    });

    test('nunca incluye la contraseña en texto plano', () {
      final uri = cliente.construirUri('ping');

      expect(uri.toString().contains('secreta'), isFalse);
      expect(uri.queryParameters['t'], isNotEmpty);
      expect(uri.queryParameters['s'], isNotEmpty);
    });

    test('usa un salt distinto en cada llamada', () {
      final primera = cliente.construirUri('ping').queryParameters['s'];
      final segunda = cliente.construirUri('ping').queryParameters['s'];

      expect(primera, isNot(segunda));
    });
  });

  group('doble dirección', () {
    test('antes de conectarse prefiere la primera de la lista', () {
      final cliente = SubsonicClient(
        urls: ['http://192.168.1.194:4533', 'http://100.91.22.33:4533'],
        usuario: 'joaco',
        password: 'secreta',
      );

      expect(cliente.baseUrlActiva, 'http://192.168.1.194:4533');
      expect(cliente.construirUri('ping').host, '192.168.1.194');
    });

    test('Credenciales pone la local antes que la remota', () {
      const credenciales = Credenciales(
        urlRemota: 'http://100.91.22.33:4533',
        urlLocal: 'http://192.168.1.194:4533',
        usuario: 'joaco',
        password: 'secreta',
      );

      expect(credenciales.urls, [
        'http://192.168.1.194:4533',
        'http://100.91.22.33:4533',
      ]);
    });

    test('sin dirección local queda solo la remota', () {
      const credenciales = Credenciales(
        urlRemota: 'http://100.91.22.33:4533',
        usuario: 'joaco',
        password: 'secreta',
      );

      expect(credenciales.urls, ['http://100.91.22.33:4533']);
    });
  });
}
