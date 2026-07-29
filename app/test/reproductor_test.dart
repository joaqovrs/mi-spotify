import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/core/subsonic_client.dart';
import 'package:mi_spotify/models/biblioteca.dart';
import 'package:mi_spotify/state/reproductor_providers.dart';

void main() {
  final cliente = SubsonicClient(
    urls: ['http://servidor:4533'],
    usuario: 'joaco',
    password: 'secreta',
  );

  group('aMediaItem', () {
    test('lleva la URL de streaming ya firmada en los extras', () {
      final item = aMediaItem(
        Cancion.desdeJson({
          'id': 'cancion-1',
          'title': 'Un tema',
          'artist': 'Un artista',
          'album': 'Un disco',
          'duration': 187,
          'coverArt': 'al-1',
        }),
        cliente,
      );

      final url = item.extras!['url'] as String;

      // El handler corre aislado del cliente: si la URL no viniera firmada acá,
      // no tendría manera de autenticarse contra Navidrome.
      expect(url, contains('/rest/stream'));
      expect(url, contains('id=cancion-1'));
      expect(url, contains('t='));
      expect(url, contains('s='));
      expect(url, isNot(contains('secreta')));
    });

    test('mapea los metadatos que muestra la notificación', () {
      final item = aMediaItem(
        Cancion.desdeJson({
          'id': 'c-2',
          'title': 'Otro tema',
          'artist': 'Otro artista',
          'album': 'Otro disco',
          'duration': 200,
        }),
        cliente,
      );

      expect(item.id, 'c-2');
      expect(item.title, 'Otro tema');
      expect(item.artist, 'Otro artista');
      expect(item.album, 'Otro disco');
      expect(item.duration, const Duration(seconds: 200));
    });

    test('sin portada no inventa una URL de carátula', () {
      final item = aMediaItem(Cancion.desdeJson({'id': 'c-3'}), cliente);

      expect(item.artUri, isNull);
      expect(portadaDe(item), isNull);
    });

    test('guarda el id de portada aparte del id de la canción', () {
      final item = aMediaItem(
        Cancion.desdeJson({'id': 'c-4', 'coverArt': 'portada-distinta'}),
        cliente,
      );

      expect(portadaDe(item), 'portada-distinta');
    });
  });

  group('formatearDuracion', () {
    test('usa minutos y segundos', () {
      expect(formatearDuracion(const Duration(seconds: 187)), '3:07');
      expect(formatearDuracion(Duration.zero), '0:00');
    });

    test('agrega las horas solo cuando hacen falta', () {
      expect(
        formatearDuracion(const Duration(hours: 1, minutes: 2, seconds: 33)),
        '1:02:33',
      );
    });
  });

  group('ProgresoReproduccion', () {
    test('calcula la fracción reproducida', () {
      const progreso = ProgresoReproduccion(
        posicion: Duration(seconds: 30),
        duracion: Duration(seconds: 120),
        buffer: Duration(seconds: 60),
      );

      expect(progreso.fraccion, 0.25);
    });

    test('devuelve 0 si el servidor no informó duración', () {
      const progreso = ProgresoReproduccion(
        posicion: Duration(seconds: 30),
        duracion: Duration.zero,
        buffer: Duration.zero,
      );

      expect(progreso.fraccion, 0);
    });

    test('acota la fracción para que la barra nunca se desborde', () {
      // Pasa de verdad: el archivo dura un poco más que lo que dice la etiqueta.
      const progreso = ProgresoReproduccion(
        posicion: Duration(seconds: 130),
        duracion: Duration(seconds: 120),
        buffer: Duration(seconds: 120),
      );

      expect(progreso.fraccion, 1.0);
    });
  });
}
