import 'biblioteca.dart';

/// Una canción guardada en el teléfono.
///
/// Se guarda una copia de los **metadatos**, no solo la ruta del archivo: la
/// pestaña de descargas tiene que poder listarse y reproducirse con el servidor
/// apagado, y sin esto habría que pedirle los títulos a Navidrome justo cuando
/// no se lo puede alcanzar.
class Descarga {
  const Descarga({
    required this.cancion,
    required this.archivo,
    required this.bytes,
    this.portada,
  });

  final Cancion cancion;

  /// Ruta absoluta del audio, dentro del almacenamiento privado de la app.
  final String archivo;

  /// Ruta absoluta de la carátula. Null cuando el álbum no tenía o cuando la
  /// imagen falló: es un extra, nunca motivo para dar la descarga por perdida.
  final String? portada;

  /// Tamaño del audio en disco. Se guarda al bajarlo para poder mostrar cuánto
  /// espacio ocupa todo sin tener que ir a preguntarle al sistema de archivos
  /// por cada canción cada vez que se abre la pantalla.
  final int bytes;

  Map<String, dynamic> aJson() => {
    'cancion': cancion.aJson(),
    'archivo': archivo,
    if (portada != null) 'portada': portada,
    'bytes': bytes,
  };

  factory Descarga.desdeJson(Map<String, dynamic> json) {
    return Descarga(
      cancion: Cancion.desdeJson(
        Map<String, dynamic>.from(json['cancion'] as Map),
      ),
      archivo: json['archivo'] as String,
      portada: json['portada'] as String?,
      bytes: json['bytes'] as int? ?? 0,
    );
  }
}

/// `4,2 MB`. En múltiplos de 1024, que es como informa el espacio Android.
String formatearTamano(int bytes) {
  const unidades = ['B', 'KB', 'MB', 'GB'];

  var valor = bytes.toDouble();
  var unidad = 0;
  while (valor >= 1024 && unidad < unidades.length - 1) {
    valor /= 1024;
    unidad++;
  }

  // Los bytes sueltos con decimales no dicen nada; de KB para arriba, uno.
  final texto = unidad == 0
      ? valor.round().toString()
      : valor.toStringAsFixed(1).replaceAll('.', ',');

  return '$texto ${unidades[unidad]}';
}
