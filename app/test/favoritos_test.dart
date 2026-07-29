import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/models/biblioteca.dart';

void main() {
  final cancion = Cancion.desdeJson({'id': 'c-1', 'title': 'Un tema'});
  final album = Album.desdeJson({'id': 'al-1', 'name': 'Un disco'});
  final artista = Artista.desdeJson({'id': 'ar-1', 'name': 'Alguien'});

  group('Favoritos', () {
    test('el vacío no tiene ids', () {
      const favoritos = Favoritos.vacio();

      expect(favoritos.estaVacio, isTrue);
      expect(favoritos.ids, isEmpty);
    });

    test('junta los ids de los tres tipos en un solo conjunto', () {
      final favoritos = Favoritos(
        canciones: [cancion],
        albumes: [album],
        artistas: [artista],
      );

      // Un único conjunto permite que el corazón pregunte por id sin saber de
      // qué tipo es lo que está mostrando.
      expect(favoritos.ids, {'c-1', 'al-1', 'ar-1'});
      expect(favoritos.estaVacio, isFalse);
    });

    test('copiarCon deja intactas las listas que no se tocan', () {
      final original = Favoritos(
        canciones: [cancion],
        albumes: [album],
        artistas: [artista],
      );

      final sinCanciones = original.copiarCon(canciones: []);

      expect(sinCanciones.canciones, isEmpty);
      expect(sinCanciones.albumes, original.albumes);
      expect(sinCanciones.artistas, original.artistas);
      expect(sinCanciones.ids, {'al-1', 'ar-1'});
    });

    test('con un solo tipo marcado sigue sin estar vacío', () {
      final soloAlbumes = Favoritos(
        canciones: const [],
        albumes: [album],
        artistas: const [],
      );

      expect(soloAlbumes.estaVacio, isFalse);
      expect(soloAlbumes.ids, {'al-1'});
    });
  });
}
