import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/models/biblioteca.dart';
import 'package:mi_spotify/services/arbol_multimedia.dart';

void main() {
  group('interpretarNodo', () {
    test('la raiz de audio_service es NodoRaiz', () {
      expect(interpretarNodo(AudioService.browsableRootId), isA<NodoRaiz>());
    });

    test('las cuatro carpetas fijas', () {
      expect(interpretarNodo(idRaizPlaylists), isA<NodoListaPlaylists>());
      expect(interpretarNodo(idRaizAlbumes), isA<NodoListaAlbumes>());
      expect(interpretarNodo(idRaizArtistas), isA<NodoListaArtistas>());
      expect(interpretarNodo(idRaizDescargas), isA<NodoDescargas>());
    });

    test('los nodos con id llevan el id sin el prefijo', () {
      expect((interpretarNodo(idDePlaylist('p-1')) as NodoPlaylist).id, 'p-1');
      expect((interpretarNodo(idDeAlbum('al-1')) as NodoAlbum).id, 'al-1');
      expect(
        (interpretarNodo(idDeArtista('ar-1')) as NodoArtista).id,
        'ar-1',
      );
    });

    test('cualquier otra cosa cae en NodoDesconocido', () {
      expect(interpretarNodo('lo-que-sea'), isA<NodoDesconocido>());
    });
  });

  group('nodosRaiz', () {
    test('las cuatro carpetas, en orden, y ninguna reproducible', () {
      final nodos = nodosRaiz();

      expect(nodos.map((n) => n.id), [
        idRaizPlaylists,
        idRaizAlbumes,
        idRaizArtistas,
        idRaizDescargas,
      ]);
      expect(nodos.every((n) => n.playable == false), isTrue);
    });
  });

  group('nodoPlaylist / nodoAlbum / nodoArtista', () {
    test('arman el id con el prefijo correcto y no son reproducibles', () {
      final playlist = Playlist.desdeJson({'id': 'p-1', 'name': 'Ruta'});
      final album = Album.desdeJson({
        'id': 'al-1',
        'name': 'Disco',
        'artist': 'Banda',
      });
      final artista = Artista.desdeJson({'id': 'ar-1', 'name': 'Banda'});

      expect(nodoPlaylist(playlist).id, 'playlist:p-1');
      expect(nodoAlbum(album).id, 'album:al-1');
      expect(nodoArtista(artista).id, 'artista:ar-1');

      expect(nodoPlaylist(playlist).playable, isFalse);
      expect(nodoAlbum(album).playable, isFalse);
      expect(nodoArtista(artista).playable, isFalse);
    });

    test('pasan la portada que reciben, sin inventar una', () {
      final album = Album.desdeJson({'id': 'al-2', 'name': 'Otro'});
      final portada = Uri.parse('http://servidor/rest/getCoverArt?id=al-2');

      expect(nodoAlbum(album).artUri, isNull);
      expect(nodoAlbum(album, portada: portada).artUri, portada);
    });
  });
}
