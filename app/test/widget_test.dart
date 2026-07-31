import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/core/config.dart';
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
        SubsonicClient.normalizarUrl('https://mimusic.duckdns.org'),
        'https://mimusic.duckdns.org',
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
        SubsonicClient.normalizarUrl('  mimusic.duckdns.org:34533  '),
        'http://mimusic.duckdns.org:34533',
      );
    });
  });

  group('construirUri', () {
    final cliente = SubsonicClient(
      urls: ['http://servidor:4533'],
      usuario: 'joaco',
      password: 'secreta',
    );

    test('apunta a /rest/ y manda los parametros de Subsonic', () {
      final uri = cliente.construirUri('ping');

      expect(uri.path, '/rest/ping');
      expect(uri.queryParameters['u'], 'joaco');
      expect(uri.queryParameters['v'], '1.16.1');
      expect(uri.queryParameters['c'], 'MiMusic');
      expect(uri.queryParameters['f'], 'json');
    });

    test('nunca incluye la contrasena en texto plano', () {
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

  group('doble direccion', () {
    test('antes de conectarse prefiere la primera de la lista', () {
      final cliente = SubsonicClient(
        urls: ['http://192.168.1.194:4533', 'http://mimusic.duckdns.org:34533'],
        usuario: 'joaco',
        password: 'secreta',
      );

      expect(cliente.baseUrlActiva, 'http://192.168.1.194:4533');
      expect(cliente.construirUri('ping').host, '192.168.1.194');
    });

    test('Servidor prueba la local antes que la remota', () {
      // El orden importa: al reves, en casa saldria a internet para volver a
      // entrar por el router pudiendo ir directo.
      expect(Servidor.urls, [Servidor.urlLocal, Servidor.urlRemota]);
    });

    test('las direcciones estan normalizadas', () {
      for (final url in [
        Servidor.urlLocal,
        Servidor.urlRemota,
        Servidor.urlRegistro,
      ]) {
        expect(SubsonicClient.normalizarUrl(url), url);
      }
    });

    test('el registro no comparte puerto con Navidrome', () {
      // Son dos servicios distintos detras de dos port forwards distintos;
      // si coincidieran, uno de los dos quedaria inalcanzable.
      expect(Servidor.urlRegistro, isNot(Servidor.urlRemota));
    });
  });
}
