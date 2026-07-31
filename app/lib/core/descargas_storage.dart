import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/biblioteca.dart';
import '../models/descarga.dart';

/// Los archivos descargados y el índice que los describe.
///
/// Todo va al almacenamiento **privado** de la app: no hace falta ningún
/// permiso de Android, no aparece en la galería ni en el reproductor del
/// sistema, y se limpia solo al desinstalar. El índice, en cambio, vive en
/// `shared_preferences`: son unos pocos kilobytes de metadatos y no justifica
/// traer una base de datos.
class DescargasStorage {
  const DescargasStorage();

  static const String _clave = 'descargas';

  /// Carpeta donde se guardan audios y carátulas, creada si hace falta.
  Future<Directory> carpeta() async {
    final base = await getApplicationSupportDirectory();
    final destino = Directory('${base.path}/descargas');

    if (!await destino.exists()) await destino.create(recursive: true);
    return destino;
  }

  /// Índice guardado, salteando lo que ya no esté en disco.
  ///
  /// Un archivo puede desaparecer sin que la app se entere (Android liberando
  /// espacio, un "borrar datos" a medias), así que el índice se verifica contra
  /// el disco en vez de creerle: es preferible que una canción figure como no
  /// descargada a que al tocarla no suene nada.
  Future<List<Descarga>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getStringList(_clave) ?? const <String>[];

    final descargas = <Descarga>[];
    for (final linea in guardado) {
      try {
        final descarga = Descarga.desdeJson(
          jsonDecode(linea) as Map<String, dynamic>,
        );
        if (await File(descarga.archivo).exists()) descargas.add(descarga);
      } catch (_) {
        // Entrada corrupta o de un formato viejo: se descarta sin ruido.
      }
    }

    return descargas;
  }

  Future<void> guardar(List<Descarga> descargas) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_clave, [
      for (final descarga in descargas) jsonEncode(descarga.aJson()),
    ]);
  }

  /// Dónde va el audio de una canción, conservando su formato original.
  Future<String> rutaDeAudio(Cancion cancion) async {
    final base = await carpeta();
    final extension = cancion.sufijo?.toLowerCase() ?? 'mp3';

    return '${base.path}/${nombreSeguro(cancion.id)}.$extension';
  }

  /// Dónde va una carátula. Se nombra por su id de portada y no por canción:
  /// todo un álbum comparte imagen y no tiene sentido bajarla una vez por tema.
  Future<String> rutaDePortada(String coverArt) async {
    final base = await carpeta();

    return '${base.path}/portada-${nombreSeguro(coverArt)}.jpg';
  }

  Future<void> borrarArchivo(String? ruta) async {
    if (ruta == null) return;

    final archivo = File(ruta);
    if (await archivo.exists()) await archivo.delete();
  }
}

/// Deja un identificador de Subsonic usable como nombre de archivo.
///
/// Los ids de Navidrome suelen ser alfanuméricos, pero nada lo garantiza y una
/// barra en el medio escribiría fuera de la carpeta.
String nombreSeguro(String identificador) =>
    identificador.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
