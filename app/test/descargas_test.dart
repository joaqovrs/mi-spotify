import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/core/descargas_storage.dart';
import 'package:mi_spotify/models/biblioteca.dart';
import 'package:mi_spotify/models/descarga.dart';

void main() {
  group('Cancion.aJson', () {
    test('vuelve a la forma de Subsonic y sobrevive al viaje de ida y vuelta', () {
      final original = Cancion.desdeJson({
        'id': 'c-1',
        'title': 'Un tema',
        'artist': 'Alguien',
        'album': 'Un disco',
        'albumId': 'al-1',
        'coverArt': 'al-1',
        'duration': 187,
        'suffix': 'flac',
      });

      final revivida = Cancion.desdeJson(original.aJson());

      expect(revivida.id, original.id);
      expect(revivida.titulo, original.titulo);
      expect(revivida.artista, original.artista);
      expect(revivida.album, original.album);
      expect(revivida.coverArt, original.coverArt);
      expect(revivida.duracion, original.duracion);
      expect(revivida.sufijo, 'flac');
    });

    test('no escribe los campos que el servidor no mando', () {
      final minima = Cancion.desdeJson({'id': 'c-2', 'title': 'Suelta'});

      // Guardar `null` explicitos engordaria el indice sin aportar nada.
      expect(minima.aJson().containsKey('album'), isFalse);
      expect(minima.aJson().containsKey('coverArt'), isFalse);
      expect(minima.aJson().containsKey('suffix'), isFalse);
    });
  });

  group('Descarga', () {
    final cancion = Cancion.desdeJson({
      'id': 'c-1',
      'title': 'Un tema',
      'coverArt': 'al-1',
      'suffix': 'mp3',
    });

    test('round-trip por el indice', () {
      final original = Descarga(
        cancion: cancion,
        archivo: '/datos/descargas/c-1.mp3',
        portada: '/datos/descargas/portada-al-1.jpg',
        bytes: 4200000,
      );

      final revivida = Descarga.desdeJson(original.aJson());

      expect(revivida.archivo, original.archivo);
      expect(revivida.portada, original.portada);
      expect(revivida.bytes, original.bytes);
      expect(revivida.cancion.titulo, 'Un tema');
    });

    test('sin caratula sigue siendo una descarga valida', () {
      final sinPortada = Descarga(
        cancion: cancion,
        archivo: '/datos/descargas/c-1.mp3',
        bytes: 100,
      );

      expect(Descarga.desdeJson(sinPortada.aJson()).portada, isNull);
    });
  });

  group('formatearTamano', () {
    test('los bytes sueltos van sin decimales', () {
      expect(formatearTamano(512), '512 B');
    });

    test('de KB para arriba, un decimal con coma', () {
      expect(formatearTamano(1536), '1,5 KB');
      expect(formatearTamano(4404019), '4,2 MB');
    });

    test('escala hasta GB y no mas', () {
      expect(formatearTamano(3 * 1024 * 1024 * 1024), '3,0 GB');
    });

    test('cero es cero bytes', () {
      expect(formatearTamano(0), '0 B');
    });
  });

  group('nombreSeguro', () {
    test('deja pasar los ids alfanumericos de Navidrome', () {
      expect(nombreSeguro('al-3f2b_9'), 'al-3f2b_9');
    });

    test('neutraliza lo que escribiria fuera de la carpeta', () {
      // Un id con barras podria apuntar a cualquier lado del sistema.
      expect(nombreSeguro('../../etc/passwd'), '______etc_passwd');
    });

    test('reemplaza espacios y acentos', () {
      expect(nombreSeguro('mi canción'), 'mi_canci_n');
    });
  });
}
