import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_spotify/ui/widgets/marca.dart';

/// Que el icono del login este declarado en `pubspec.yaml`.
///
/// Es el unico error de esta pieza que no aparece en `flutter analyze`: la ruta
/// se resuelve recien al dibujar, y si esta mal el login sale con un cuadro
/// gris en vez del logo. Barato de comprobar, caro de descubrir en el telefono.
void main() {
  testWidgets('el icono de la app esta empaquetado', (tester) async {
    final datos = await rootBundle.load('assets/icono/icono.png');
    expect(datos.lengthInBytes, greaterThan(1000));
  });

  testWidgets('el logo dibuja el icono y no un icono de Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LogoMarca())),
    );
    await tester.pumpAndSettle();

    final imagen = tester.widget<Image>(find.byType(Image));

    // Va envuelto en ResizeImage porque el archivo es de 1024 px y aca se ve
    // del tamaño de un pulgar.
    expect(imagen.image, isA<ResizeImage>());
    expect((imagen.image as ResizeImage).imageProvider, isA<AssetImage>());
    expect(tester.takeException(), isNull);
  });
}
