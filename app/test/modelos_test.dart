import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/models/biblioteca.dart';

void main() {
  group('Album.desdeJson', () {
    test('lee los campos habituales de Navidrome', () {
      final album = Album.desdeJson({
        'id': 'al-1',
        'name': 'Idolos',
        'artist': 'Los Redondos',
        'artistId': 'ar-9',
        'coverArt': 'al-1',
        'year': 1988,
        'songCount': 10,
      });

      expect(album.id, 'al-1');
      expect(album.nombre, 'Idolos');
      expect(album.artista, 'Los Redondos');
      expect(album.anio, 1988);
      expect(album.cantidadCanciones, 10);
    });

    test('sobrevive a un album sin metadatos', () {
      final album = Album.desdeJson({'id': 'al-2'});

      expect(album.nombre, 'Sin titulo');
      expect(album.artista, 'Artista desconocido');
      expect(album.coverArt, isNull);
    });

    test('convierte el id numerico a texto', () {
      // Algunos servidores Subsonic mandan el id como numero.
      final album = Album.desdeJson({'id': 42, 'name': 'Disco'});

      expect(album.id, '42');
    });
  });

  group('Cancion', () {
    test('formatea la duracion en minutos y segundos', () {
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

    test('muestra un guion cuando el servidor no informo la duracion', () {
      expect(Cancion.desdeJson({'id': '4'}).duracionFormateada, '—');
    });
  });

  group('Artista.desdeJson', () {
    test('lee nombre y cantidad de albumes', () {
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
