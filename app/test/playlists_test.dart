import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/models/biblioteca.dart';
import 'package:mi_spotify/state/playlists_providers.dart';

void main() {
  group('Playlist', () {
    test('parsea lo que devuelve getPlaylists', () {
      final playlist = Playlist.desdeJson({
        'id': 'pl-1',
        'name': 'Para manejar',
        'songCount': 12,
        'duration': 2880,
        'coverArt': 'pl-1',
      });

      expect(playlist.id, 'pl-1');
      expect(playlist.nombre, 'Para manejar');
      expect(playlist.resumen, '12 canciones · 48 min');
    });

    test('tolera los campos que Navidrome omite', () {
      final playlist = Playlist.desdeJson({'id': 'pl-2'});

      expect(playlist.nombre, 'Sin nombre');
      expect(playlist.cantidadCanciones, isNull);
      expect(playlist.resumen, '0 canciones');
    });

    test('una playlist vacia no muestra "0 min"', () {
      final playlist = Playlist.desdeJson({
        'id': 'pl-3',
        'name': 'Nueva',
        'songCount': 0,
        'duration': 0,
      });

      expect(playlist.resumen, '0 canciones');
    });

    test('singular con una sola cancion', () {
      final playlist = Playlist.desdeJson({
        'id': 'pl-4',
        'name': 'Una sola',
        'songCount': 1,
        'duration': 200,
      });

      expect(playlist.resumen, '1 canción · 3 min');
    });

    test('copiarCon solo cambia el nombre', () {
      final original = Playlist.desdeJson({
        'id': 'pl-5',
        'name': 'Viejo',
        'songCount': 4,
        'duration': 600,
        'coverArt': 'pl-5',
      });

      final renombrada = original.copiarCon(nombre: 'Nuevo');

      expect(renombrada.nombre, 'Nuevo');
      expect(renombrada.id, original.id);
      expect(renombrada.coverArt, original.coverArt);
      expect(renombrada.resumen, original.resumen);
    });
  });

  group('reordenada', () {
    test('mover hacia abajo', () {
      expect(reordenada(['a', 'b', 'c'], 0, 1), ['b', 'a', 'c']);
    });

    test('mover hacia arriba', () {
      expect(reordenada(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('mover al final deja el elemento ultimo', () {
      expect(reordenada(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });

    test('no toca la lista original', () {
      final original = ['a', 'b', 'c'];
      reordenada(original, 0, 2);

      expect(original, ['a', 'b', 'c']);
    });
  });
}
