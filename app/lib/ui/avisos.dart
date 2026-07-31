import 'package:flutter/material.dart';

/// Muestra un aviso reemplazando al anterior, para que dos acciones seguidas
/// no encolen dos mensajes que se pisan.
///
/// Vive suelto y no dentro de `acciones.dart` porque lo usan tanto las acciones
/// como los widgets, y si estuviera allá los imports se harían circulares.
void avisar(ScaffoldMessengerState mensajero, String texto) {
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(texto), duration: const Duration(seconds: 2)),
    );
}
