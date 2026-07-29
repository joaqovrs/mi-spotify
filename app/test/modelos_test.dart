import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/models/biblioteca.dart';

void main() {
  group('Album.desdeJson', () {
    test('lee los campos habituales de Navidrome', () {
      final album = Album.desdeJson({
        'id': 'al-1',
        'name': 'Ídolos',
        'artist': 'Los Redondos',
        'artistId': 'ar-9',
        'coverArt': 'al-1',
        'year': 1988,
        'songCount': 10,
      });

      expect(album.id, 'al-1');
      expect(album.nombre, 'Ídolos');
      expect(album.artista, 'Los Redondos');
      expect(album.anio, 1988);
      expect(album.cantidadCanciones, 10);
    });

    test('sobrevive a un álbum sin metadatos', () {
      final album = Album.desdeJson({'id': 'al-2'});

      expect(album.nombre, 'Sin título');
      expect(album.artista, 'Artista desconocido');
      expect(album.coverArt, isNull);
    });

    test('convierte el id numérico a texto', () {
      // Algunos servidores Subsonic mandan el id como número.
      final album = Album.desdeJson({'id': 42, 'name': 'Disco'});

      expect(album.id, '42');
    });
  });

  group('Cancion', () {
    test('formatea la duración en minutos y segundos', () {
      expect(
        Cancion.desdeJson({'id': '1', 'duration': 187}).duracionFormateada,
        '3:07',
      );
      expect(
        Cancion.desdeJson({'id': '2', 'duration': 60}).duracionFormateada,
        '1:00',
      );
      expect(
        Cancion.desdeJson({'id': '3', 'duration': 9}).duracionFormateada,
        '0:09',
      );
    });

    test('muestra un guion cuando el servidor no informó la duración', () {
      expect(Cancion.desdeJson({'id': '4'}).duracionFormateada, '—');
    });
  });

  group('Artista.desdeJson', () {
    test('lee nombre y cantidad de álbumes', () {
      final artista = Artista.desdeJson({
        'id': 'ar-1',
        'name': 'Spinetta',
        'albumCount': 3,
      });

      expect(artista.nombre, 'Spinetta');
      expect(artista.cantidadAlbumes, 3);
    });
  });
}
