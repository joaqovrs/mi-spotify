import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/models/biblioteca.dart';

void main() {
  group('ResultadoBusqueda', () {
    test('el vacío no tiene nada de ningún tipo', () {
      const resultado = ResultadoBusqueda.vacio();

      expect(resultado.estaVacio, isTrue);
      expect(resultado.canciones, isEmpty);
      expect(resultado.albumes, isEmpty);
      expect(resultado.artistas, isEmpty);
    });

    test('alcanza con un resultado de cualquier tipo para no estar vacío', () {
      final soloArtistas = ResultadoBusqueda(
        canciones: const [],
        albumes: const [],
        artistas: [Artista.desdeJson({'id': 'ar-1', 'name': 'Spinetta'})],
      );

      expect(soloArtistas.estaVacio, isFalse);
    });
  });
}
