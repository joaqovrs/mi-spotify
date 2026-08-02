import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../models/biblioteca.dart';

/// Error devuelto por el servidor Subsonic (Navidrome) o por la conexion.
class SubsonicException implements Exception {
  const SubsonicException(this.mensaje, {this.codigo});

  final String mensaje;

  /// Codigo de error de la API Subsonic, cuando lo hay.
  /// Los que interesan: 40 = credenciales invalidas, 70 = no encontrado.
  ///
  /// Que venga un codigo significa que el servidor **contesto**: el problema
  /// es la peticion, no la red.
  final int? codigo;

  bool get esCredencialInvalida => codigo == 40;

  /// True cuando no se pudo llegar al servidor (a diferencia de haber llegado
  /// y que rechazara la peticion).
  bool get esProblemaDeRed => codigo == null;

  @override
  String toString() => mensaje;
}

/// Cliente de la API Subsonic que expone Navidrome.
///
/// La autenticacion de Subsonic no manda la contraseña: por cada request se
/// genera un `salt` al azar y se envia `t = md5(contraseña + salt)`. El
/// servidor rehace el mismo calculo y compara. Asi la contraseña nunca viaja,
/// ni siquiera cifrada.
///
/// El cliente acepta **varias direcciones** para el mismo servidor (la de la
/// red local y la del tailnet) y descubre sola cual responde. Ver [_resolver].
class SubsonicClient {
  SubsonicClient({
    required List<String> urls,
    required this.usuario,
    required this.password,
    Dio? dio,
  }) : assert(urls.isNotEmpty, 'Hace falta al menos una dirección'),
       urls = List.unmodifiable(urls),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 20),
             ),
           ),
       _dioSonda =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(milliseconds: 1800),
               receiveTimeout: const Duration(milliseconds: 1800),
             ),
           );

  /// Direcciones candidatas, en orden de preferencia. Normalmente la local
  /// primero (mas rapida, sin pasar por el tunel) y la del tailnet despues.
  final List<String> urls;
  final String usuario;
  final String password;

  final Dio _dio;

  /// Dio con timeouts cortos, solo para probar direcciones. Sin esto, detectar
  /// que la IP local no responde tardaria 12 segundos en vez de 2.
  final Dio _dioSonda;

  final Random _random = Random.secure();

  /// Direccion que se comprobo que funciona. Se descarta al fallar la red,
  /// para que un cambio de WiFi a datos moviles se detecte solo.
  String? _activa;

  static const String _version = '1.16.1';
  static const String _cliente = 'MiMusic';

  /// Direccion en uso. Antes de la primera conexion asume la preferida.
  String get baseUrlActiva => _activa ?? urls.first;

  /// Acepta lo que el usuario haya tipeado y devuelve una URL usable.
  ///
  /// `192.168.1.194:4533` → `http://192.168.1.194:4533`
  /// `http://mi-spotify:4533/` → `http://mi-spotify:4533`
  static String normalizarUrl(String entrada) {
    var url = entrada.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Parametros de autenticacion, con un salt nuevo en cada llamada.
  Map<String, String> _paramsAuth() {
    final salt = _generarSalt();
    final token = md5.convert(utf8.encode(password + salt)).toString();
    return {
      'u': usuario,
      't': token,
      's': salt,
      'v': _version,
      'c': _cliente,
      'f': 'json',
    };
  }

  String _generarSalt() {
    const alfabeto = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      12,
      (_) => alfabeto[_random.nextInt(alfabeto.length)],
    ).join();
  }

  /// Arma una URL firmada sobre una direccion concreta.
  ///
  /// Los valores de [params] pueden ser un `String` o una `List<String>`.
  /// Subsonic no usa listas separadas por comas: repite el parametro
  /// (`songId=1&songId=2`), y asi es como lo escribe `Uri` con una lista.
  Uri _uriEn(
    String baseUrl,
    String endpoint, [
    Map<String, Object> params = const {},
  ]) {
    return Uri.parse(
      '$baseUrl/rest/$endpoint',
    ).replace(queryParameters: {..._paramsAuth(), ...params});
  }

  /// Arma una URL completa firmada sobre la direccion activa. Se usa para
  /// portadas y streaming, donde el reproductor necesita la URL en vez de la
  /// respuesta parseada.
  Uri construirUri(String endpoint, [Map<String, String> params = const {}]) =>
      _uriEn(baseUrlActiva, endpoint, params);

  /// Prueba las direcciones en orden y se queda con la primera que responde.
  ///
  /// Si alguna contesta con un error de la API (por ejemplo contraseña mala),
  /// corta ahi: llegamos al servidor, probar la otra direccion no aportaria
  /// nada y solo demoraria el mensaje de error.
  Future<String> _resolver() async {
    SubsonicException? ultimoError;

    for (final url in urls) {
      try {
        await _pedir(_dioSonda, _uriEn(url, 'ping'));
        _activa = url;
        return url;
      } on SubsonicException catch (e) {
        if (!e.esProblemaDeRed) rethrow;
        ultimoError = e;
      }
    }

    throw ultimoError ??
        const SubsonicException('No se pudo conectar al servidor.');
  }

  /// Llama a un endpoint y devuelve el contenido de `subsonic-response`.
  ///
  /// Si la direccion activa deja de responder (tipicamente al salir de casa),
  /// la descarta y vuelve a resolver antes de dar el error por definitivo.
  Future<Map<String, dynamic>> _get(
    String endpoint, [
    Map<String, Object> params = const {},
  ]) async {
    final url = _activa ?? await _resolver();

    try {
      return await _pedir(_dio, _uriEn(url, endpoint, params));
    } on SubsonicException catch (e) {
      if (!e.esProblemaDeRed || urls.length == 1) rethrow;

      _activa = null;
      final nueva = await _resolver();
      return _pedir(_dio, _uriEn(nueva, endpoint, params));
    }
  }

  /// Ejecuta la peticion y desenvuelve la respuesta Subsonic.
  Future<Map<String, dynamic>> _pedir(Dio dio, Uri uri) async {
    late final Response<dynamic> respuesta;
    try {
      respuesta = await dio.getUri<dynamic>(uri);
    } on DioException catch (e) {
      throw SubsonicException(_mensajeDeRed(e));
    }

    final cuerpo = respuesta.data;
    if (cuerpo is! Map) {
      throw const SubsonicException(
        'El servidor respondió algo inesperado. ¿Es realmente un servidor Navidrome?',
        codigo: -1,
      );
    }

    final datos = cuerpo['subsonic-response'];
    if (datos is! Map) {
      throw const SubsonicException(
        'La respuesta no tiene formato Subsonic. Revisa la dirección del servidor.',
        codigo: -1,
      );
    }

    if (datos['status'] != 'ok') {
      final error = datos['error'];
      final codigo = error is Map ? error['code'] as int? : null;
      final mensaje = error is Map ? error['message'] as String? : null;
      throw SubsonicException(
        codigo == 40
            ? 'Usuario o contraseña incorrectos.'
            : (mensaje ?? 'El servidor rechazó la petición.'),
        codigo: codigo ?? -1,
      );
    }

    return Map<String, dynamic>.from(datos);
  }

  String _mensajeDeRed(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'El servidor no respondió a tiempo. Revisa que la laptop esté '
            'encendida y con internet.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar al servidor. Revisa la dirección y que la '
            'laptop esté encendida.';
      case DioExceptionType.badResponse:
        return 'El servidor respondió con un error '
            '(${e.response?.statusCode ?? 'sin código'}).';
      default:
        return 'Fallo de conexión con el servidor.';
    }
  }

  /// Verifica servidor y credenciales de una sola vez.
  Future<void> ping() => _get('ping');

  /// URL de la portada de un album o cancion.
  ///
  /// El resultado se memoriza a proposito. Como cada llamada genera un salt
  /// nuevo, sin esta cache la URL cambiaria en cada rebuild del widget y la
  /// cache de imagenes nunca acertaria: cada scroll volveria a descargar todas
  /// las portadas.
  Uri urlPortada(String id, {int? tamano}) {
    final clave = '$id@${tamano ?? 0}';
    return _portadas.putIfAbsent(
      clave,
      () => construirUri('getCoverArt', {
        'id': id,
        if (tamano != null) 'size': '$tamano',
      }),
    );
  }

  final Map<String, Uri> _portadas = {};

  /// URL de streaming de una cancion, lista para el reproductor.
  Uri urlStream(String id) => construirUri('stream', {'id': id});

  // --------------------------------------------------------------- Descargas

  /// Baja el archivo **original** de una cancion al telefono.
  ///
  /// Usa `download` y no `stream`: `stream` puede transcodificar segun la
  /// configuracion del servidor, y para guardar en disco queremos el archivo
  /// tal cual esta en `/srv/musica`.
  ///
  /// Devuelve el tamaño escrito.
  Future<int> descargarCancion(
    String id,
    String destino, {
    void Function(double)? onProgreso,
  }) {
    return _bajarA(
      (base) => _uriEn(base, 'download', {'id': id}),
      destino,
      onProgreso: onProgreso,
    );
  }

  /// Baja la caratula para poder mostrarla sin servidor.
  Future<int> descargarPortada(String coverArt, String destino, {int tamano = 640}) {
    return _bajarA(
      (base) => _uriEn(base, 'getCoverArt', {'id': coverArt, 'size': '$tamano'}),
      destino,
    );
  }

  /// Escribe un endpoint binario a disco.
  ///
  /// Se resuelve la direccion igual que en el resto del cliente, pero aqui no
  /// se reintenta con la otra: una descarga puede durar minutos y volver a
  /// empezarla sola, sin avisar, sorprenderia mas de lo que ayudaria.
  ///
  /// Reusa el Dio normal a proposito: su `receiveTimeout` cuenta el tiempo
  /// **entre trozos** recibidos, no el total, asi que no corta un archivo
  /// grande — solo uno que dejo de llegar.
  Future<int> _bajarA(
    Uri Function(String baseUrl) arma,
    String destino, {
    void Function(double)? onProgreso,
  }) async {
    final url = _activa ?? await _resolver();

    try {
      await _dio.downloadUri(
        arma(url),
        destino,
        onReceiveProgress: onProgreso == null
            ? null
            : (recibido, total) {
                if (total > 0) onProgreso(recibido / total);
              },
      );
    } on DioException catch (e) {
      throw SubsonicException(_mensajeDeRed(e));
    }

    return File(destino).length();
  }

  // ---------------------------------------------------------------- Biblioteca

  /// Albumes segun un criterio de `getAlbumList2`.
  ///
  /// Tipos que usa la pantalla de inicio: `newest` (agregados recientemente),
  /// `frequent` (los que mas escuchaste), `recent` (los ultimos que sonaron),
  /// `random` y `alphabeticalByName`.
  Future<List<Album>> albumes({
    required String tipo,
    int cantidad = 20,
    int desplazamiento = 0,
  }) async {
    final datos = await _get('getAlbumList2', {
      'type': tipo,
      'size': '$cantidad',
      'offset': '$desplazamiento',
    });

    return _comoLista(datos['albumList2'], 'album')
        .map(Album.desdeJson)
        .toList();
  }

  /// Canciones al azar de toda la biblioteca.
  Future<List<Cancion>> cancionesAlAzar({int cantidad = 50}) async {
    final datos = await _get('getRandomSongs', {'size': '$cantidad'});

    return _comoLista(datos['randomSongs'], 'song')
        .map(Cancion.desdeJson)
        .toList();
  }

  /// Todos los artistas. Subsonic los devuelve agrupados por letra inicial,
  /// asi que hay que aplanar los indices.
  Future<List<Artista>> artistas() async {
    final datos = await _get('getArtists');
    final indices = _comoLista(datos['artists'], 'index');

    return [
      for (final indice in indices)
        ..._comoLista(indice, 'artist').map(Artista.desdeJson),
    ];
  }

  /// Canciones de un album, en el orden del disco.
  Future<List<Cancion>> cancionesDeAlbum(String albumId) async {
    final datos = await _get('getAlbum', {'id': albumId});

    return _comoLista(datos['album'], 'song').map(Cancion.desdeJson).toList();
  }

  /// Albumes de un artista.
  Future<List<Album>> albumesDeArtista(String artistaId) async {
    final datos = await _get('getArtist', {'id': artistaId});

    return _comoLista(datos['artist'], 'album').map(Album.desdeJson).toList();
  }

  // ---------------------------------------------------------------- Favoritos

  /// Todo lo marcado con estrella en el servidor.
  Future<Favoritos> favoritos() async {
    final datos = await _get('getStarred2');
    final estrellados = datos['starred2'];

    return Favoritos(
      canciones: _comoLista(estrellados, 'song').map(Cancion.desdeJson).toList(),
      albumes: _comoLista(estrellados, 'album').map(Album.desdeJson).toList(),
      artistas: _comoLista(
        estrellados,
        'artist',
      ).map(Artista.desdeJson).toList(),
    );
  }

  /// Marca o desmarca un favorito.
  ///
  /// Subsonic usa un parametro distinto por tipo (`id` para canciones,
  /// `albumId`, `artistId`) y dos endpoints distintos en vez de un booleano.
  Future<void> marcarFavorito({
    required String id,
    required TipoFavorito tipo,
    required bool favorito,
  }) async {
    final parametro = switch (tipo) {
      TipoFavorito.cancion => 'id',
      TipoFavorito.album => 'albumId',
      TipoFavorito.artista => 'artistId',
    };

    await _get(favorito ? 'star' : 'unstar', {parametro: id});
  }

  // ---------------------------------------------------------------- Playlists

  /// Todas las playlists del usuario.
  Future<List<Playlist>> playlists() async {
    final datos = await _get('getPlaylists');

    return _comoLista(datos['playlists'], 'playlist')
        .map(Playlist.desdeJson)
        .toList();
  }

  /// Canciones de una playlist, en el orden guardado.
  ///
  /// Subsonic las llama `entry` aqui, no `song` como en el resto de la API.
  Future<List<Cancion>> cancionesDePlaylist(String id) async {
    final datos = await _get('getPlaylist', {'id': id});

    return _comoLista(datos['playlist'], 'entry').map(Cancion.desdeJson).toList();
  }

  /// Crea una playlist, opcionalmente con canciones desde el arranque.
  Future<Playlist> crearPlaylist({
    required String nombre,
    List<String> cancionIds = const [],
  }) async {
    final datos = await _get('createPlaylist', {
      'name': nombre,
      if (cancionIds.isNotEmpty) 'songId': cancionIds,
    });

    final creada = datos['playlist'];
    if (creada is Map) {
      return Playlist.desdeJson(Map<String, dynamic>.from(creada));
    }

    // La especificacion permite contestar sin cuerpo. Como necesitamos el id
    // para poder abrirla, en ese caso la rescatamos del listado por nombre.
    final todas = await playlists();
    final coincidencias = todas.where((p) => p.nombre == nombre);
    if (coincidencias.isEmpty) {
      throw const SubsonicException(
        'La playlist se creó pero el servidor no devolvió su identificador.',
        codigo: -1,
      );
    }

    return coincidencias.last;
  }

  Future<void> renombrarPlaylist({
    required String id,
    required String nombre,
  }) async {
    await _get('updatePlaylist', {'playlistId': id, 'name': nombre});
  }

  /// Suma canciones al final de la playlist.
  Future<void> agregarAPlaylist({
    required String id,
    required List<String> cancionIds,
  }) async {
    if (cancionIds.isEmpty) return;

    await _get('updatePlaylist', {
      'playlistId': id,
      'songIdToAdd': cancionIds,
    });
  }

  /// Quita canciones **por posicion**, no por id: una misma cancion puede estar
  /// repetida en la playlist y hay que poder sacar solo la que se toco.
  Future<void> quitarDePlaylist({
    required String id,
    required List<int> indices,
  }) async {
    if (indices.isEmpty) return;

    await _get('updatePlaylist', {
      'playlistId': id,
      'songIndexToRemove': [for (final indice in indices) '$indice'],
    });
  }

  /// Reescribe el contenido completo en el orden dado.
  ///
  /// `updatePlaylist` solo sabe agregar al final y quitar por indice, asi que
  /// reordenar exige mandar la lista entera. `createPlaylist` con un
  /// `playlistId` existente es la via que deja Subsonic para eso.
  Future<void> reemplazarCancionesDePlaylist({
    required String id,
    required List<String> cancionIds,
  }) async {
    await _get('createPlaylist', {'playlistId': id, 'songId': cancionIds});
  }

  Future<void> borrarPlaylist(String id) async {
    await _get('deletePlaylist', {'id': id});
  }

  /// Busca en toda la biblioteca: canciones, albumes y artistas de una vez.
  Future<ResultadoBusqueda> buscar(String consulta, {int porTipo = 30}) async {
    final texto = consulta.trim();
    if (texto.isEmpty) return const ResultadoBusqueda.vacio();

    final datos = await _get('search3', {
      'query': texto,
      'songCount': '$porTipo',
      'albumCount': '$porTipo',
      'artistCount': '$porTipo',
    });

    final resultado = datos['searchResult3'];

    return ResultadoBusqueda(
      canciones: _comoLista(resultado, 'song').map(Cancion.desdeJson).toList(),
      albumes: _comoLista(resultado, 'album').map(Album.desdeJson).toList(),
      artistas: _comoLista(resultado, 'artist').map(Artista.desdeJson).toList(),
    );
  }

  /// Saca una lista de un contenedor de Subsonic tolerando las dos formas en
  /// que puede venir: ausente cuando esta vacia, o un objeto suelto en vez de
  /// una lista cuando hay un unico elemento.
  List<Map<String, dynamic>> _comoLista(dynamic contenedor, String clave) {
    if (contenedor is! Map) return const [];

    final valor = contenedor[clave];
    if (valor is List) {
      return valor.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (valor is Map) return [Map<String, dynamic>.from(valor)];
    return const [];
  }
}
