import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../core/descargas_storage.dart';
import '../core/media_items.dart';
import '../core/subsonic_client.dart';
import '../models/biblioteca.dart';
import 'arbol_multimedia.dart';

/// Motor de reproduccion.
///
/// `audio_service` corre esto dentro de un servicio en primer plano de Android,
/// que es lo que permite que la musica siga sonando con la app cerrada y que
/// aparezcan los controles en la notificacion y en la pantalla de bloqueo.
///
/// La URL de streaming de cada cancion viaja en `extras['url']` del [MediaItem],
/// asi el handler no necesita conocer el cliente de Subsonic ni las credenciales
/// **para reproducir**. Para el arbol de Android Auto (`getChildren`) si hace
/// falta un [SubsonicClient]: lo inyecta `main.dart` con el setter [cliente]
/// cada vez que cambia la sesion, en vez de que el handler lea el Keystore por
/// su cuenta — asi usa siempre la misma doble direccion local/remota que el
/// resto de la app, sin duplicar esa logica.
class ReproductorHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  ReproductorHandler() {
    _player.playbackEventStream.listen(
      _difundirEstado,
      onError: (Object e, StackTrace s) => _difundirError(),
    );

    // Cuando el reproductor pasa de pista, hay que avisarle al sistema cual
    // suena ahora para que la notificacion se actualice.
    _player.currentIndexStream.listen((indice) {
      final lista = queue.value;
      if (indice == null || indice >= lista.length) return;
      mediaItem.add(lista[indice]);
    });

    // Al terminar la cola, volver al principio en pausa en vez de quedar en un
    // estado raro con la ultima pista terminada.
    _player.processingStateStream.listen((estado) async {
      if (estado == ProcessingState.completed) {
        await _player.pause();
        await _player.seek(Duration.zero, index: 0);
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final DescargasStorage _descargasStorage = const DescargasStorage();

  SubsonicClient? _cliente;

  /// Ultimas carpetas de canciones que le mostro a Android Auto, por
  /// `parentMediaId`. Es lo que le permite a [playFromMediaId] reconstruir la
  /// cola entera (no solo la cancion tocada) cuando el auto pide reproducir
  /// algo que ya se navego en esta corrida del proceso.
  final Map<String, List<MediaItem>> _hojasCache = {};

  /// De que playlist salio cada carpeta cacheada, para las mismas que
  /// [origenCola] usa en el resto de la app. Solo las carpetas de playlist
  /// tienen entrada aca — las de album o descargas quedan sin sincronizar
  /// porque no son editables desde la pantalla de una lista.
  final Map<String, String> _origenPorHoja = {};

  /// El [SubsonicClient] con el que Android Auto arma Playlists, Albumes y
  /// Artistas. Se limpia la cache de carpetas al asignarlo: la app es
  /// multiusuario, y sin esto cerrar sesion y entrar con otra cuenta dejaria
  /// en el auto carpetas de la cuenta anterior.
  set cliente(SubsonicClient? valor) {
    _cliente = valor;
    _hojasCache.clear();
    _origenPorHoja.clear();
  }

  String? _origenCola;

  /// De donde salio la cola que esta sonando.
  ///
  /// Sirve para saber si una edicion hecha en pantalla tiene que reflejarse en
  /// la reproduccion: reordenar la playlist que estas escuchando cambia lo que
  /// viene, pero reordenar otra cualquiera no. Queda en null cuando la cola no
  /// se corresponde con ninguna lista editable — un album, o una mezcla al azar
  /// que ya no respeta el orden original.
  String? get origenCola => _origenCola;

  /// Si el modo aleatorio esta encendido.
  ///
  /// Es un modo, no una accion: la cola conserva el orden del album o de la
  /// playlist y solo cambia el recorrido. Por eso apagarlo devuelve todo a su
  /// lugar sin tener que recargar nada.
  bool get aleatorioActivo => _player.shuffleModeEnabled;

  /// Volumen de reproduccion, entre 0 y 1.
  Future<void> setVolume(double volumen) => _player.setVolume(volumen);

  /// Volumen actual, para que un control nuevo arranque mostrando el valor
  /// real en vez de asumir 1.0.
  Stream<double> get volumenStream => _player.volumeStream;

  /// Carga una lista y arranca en la posicion indicada.
  Future<void> reproducirLista(
    List<MediaItem> canciones,
    int indice, {
    String? origen,
  }) async {
    if (canciones.isEmpty) return;

    queue.add(canciones);
    mediaItem.add(canciones[indice]);
    _origenCola = origen;

    await _player.setAudioSources(
      canciones.map(_fuenteDe).toList(),
      initialIndex: indice,
      initialPosition: Duration.zero,
    );

    // Cargar canciones nuevas reinicia el recorrido: hay que sortearlo otra vez
    // o el aleatorio quedaria siguiendo el orden del disco.
    if (_player.shuffleModeEnabled) await _player.shuffle();

    await _player.play();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final activo = shuffleMode != AudioServiceShuffleMode.none;

    // Se sortea antes de encender para que cada vez que se active salga un
    // recorrido nuevo, y no siempre el mismo de la primera vez. `shuffle` deja
    // primera a la cancion que esta sonando, asi que no se corta nada.
    if (activo) await _player.shuffle();
    await _player.setShuffleModeEnabled(activo);

    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  /// Mueve una cancion dentro de la cola sin cortar lo que suena.
  ///
  /// Los indices son los mismos que usa `onReorderItem`: [hasta] es la posicion
  /// final, ya descontado el hueco que deja la cancion movida. Es tambien lo
  /// que espera `moveAudioSource`, asi que pasan derecho.
  Future<void> moverEnCola(int desde, int hasta) async {
    final lista = queue.value;
    if (!_enRango(desde, lista) || !_enRango(hasta, lista)) return;
    if (desde == hasta) return;

    final nueva = [...lista];
    nueva.insert(hasta, nueva.removeAt(desde));
    queue.add(nueva);

    await _player.moveAudioSource(desde, hasta);
  }

  /// Saca una cancion de la cola. Si era la ultima, deja el reproductor parado
  /// en vez de en una cola vacia sonando a nada.
  Future<void> quitarDeCola(int indice) async {
    final lista = queue.value;
    if (!_enRango(indice, lista)) return;

    final nueva = [...lista]..removeAt(indice);
    queue.add(nueva);

    if (nueva.isEmpty) {
      _origenCola = null;
      mediaItem.add(null);
      await _player.stop();
      await _player.clearAudioSources();
      return;
    }

    await _player.removeAudioSourceAt(indice);
  }

  bool _enRango(int indice, List<MediaItem> lista) =>
      indice >= 0 && indice < lista.length;

  /// Suma canciones al final de la cola sin cortar lo que esta sonando.
  ///
  /// Es lo que necesita la sincronizacion con la playlist que suena: agregar
  /// un tema a la lista tiene que dejarlo tambien al final de la cola, para que
  /// las dos sigan siendo el mismo orden. Para el boton de la interfaz esta
  /// [agregarComoSiguiente], que es lo que espera quien lo toca.
  ///
  /// Con la cola vacia no tendria sentido "agregar" a la nada: en ese caso
  /// arranca la reproduccion.
  Future<void> agregarACola(List<MediaItem> canciones) async {
    if (canciones.isEmpty) return;

    if (queue.value.isEmpty) {
      await reproducirLista(canciones, 0);
      return;
    }

    queue.add([...queue.value, ...canciones]);
    await _player.addAudioSources(canciones.map(_fuenteDe).toList());
  }

  /// Mete canciones justo despues de la que esta sonando.
  ///
  /// Al final de la cola no sirve de nada: con un album de quince temas
  /// encolar algo significaba esperar una hora para escucharlo. Lo que se
  /// espera de este boton es "esto va despues de lo que suena, y despues sigue
  /// todo como estaba", asi que se inserta en el medio y el resto del album
  /// conserva su orden detras.
  Future<void> agregarComoSiguiente(List<MediaItem> canciones) async {
    if (canciones.isEmpty) return;

    final lista = queue.value;
    final actual = _player.currentIndex;

    // Sin nada sonando no hay un "despues de esto": se cae al final, que con la
    // cola vacia significa arrancar la reproduccion.
    if (lista.isEmpty || actual == null || actual >= lista.length) {
      await agregarACola(canciones);
      return;
    }

    final destino = actual + 1;

    final nueva = [...lista]..insertAll(destino, canciones);
    queue.add(nueva);

    // La cola dejo de ser un calco de la lista de la que salio: de aqui en
    // adelante sus indices no coinciden con los de la playlist, y aplicarle una
    // edicion de esa pantalla moveria la cancion equivocada.
    _origenCola = null;

    await _player.insertAudioSources(
      destino,
      canciones.map(_fuenteDe).toList(),
    );
  }

  AudioSource _fuenteDe(MediaItem item) {
    final url = item.extras?['url'] as String?;
    if (url == null) {
      throw StateError('La canción ${item.id} no trae URL de streaming.');
    }
    return AudioSource.uri(Uri.parse(url), tag: item);
  }

  void _difundirEstado(PlaybackEvent evento) {
    final sonando = _player.playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (sonando) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: sonando,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: evento.currentIndex,
      ),
    );
  }

  void _difundirError() {
    playbackState.add(
      playbackState.value.copyWith(processingState: AudioProcessingState.idle),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    // Igual que en Spotify: si ya pasaron unos segundos, el boton reinicia la
    // cancion en vez de saltar a la anterior.
    if (_player.position > const Duration(seconds: 4)) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seekToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Corta la reproduccion y vacia la cola por completo.
  ///
  /// Lo usa `main.dart` al cerrar sesion: sin esto la cancion seguia sonando
  /// con la sesion cerrada, y la app es multiusuario, asi que dejar la cola
  /// puesta mostraria lo que escuchaba quien se fue a quien entre despues.
  Future<void> detenerYVaciar() async {
    _origenCola = null;
    queue.add(const []);
    mediaItem.add(null);
    await _player.stop();
    await _player.clearAudioSources();
  }

  // ------------------------------------------------------------ Android Auto

  /// El arbol que navega Android Auto (y cualquier otro `MediaBrowser`, como
  /// Wear OS). Playlists, Albumes y Artistas necesitan [_cliente]; sin sesion
  /// quedan vacios pero Descargas sigue andando, porque lee directo del
  /// telefono igual que la pestaña de Descargas de la app.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final cliente = _cliente;
    final nodo = interpretarNodo(parentMediaId);

    return switch (nodo) {
      NodoRaiz() => nodosRaiz(),
      NodoListaPlaylists() => cliente == null
          ? const []
          : [
              for (final p in await cliente.playlists())
                nodoPlaylist(p, portada: _portada(cliente, p.coverArt)),
            ],
      NodoListaAlbumes() => cliente == null
          ? const []
          : [
              for (final a in await cliente.albumes(
                tipo: 'alphabeticalByName',
                cantidad: 500,
              ))
                nodoAlbum(a, portada: _portada(cliente, a.coverArt)),
            ],
      NodoListaArtistas() => cliente == null
          ? const []
          : [
              for (final a in await cliente.artistas())
                nodoArtista(a, portada: _portada(cliente, a.coverArt)),
            ],
      NodoDescargas() => _hojaDescargas(),
      NodoPlaylist(id: final id) => cliente == null
          ? const []
          : _hojaCanciones(
              parentMediaId,
              await cliente.cancionesDePlaylist(id),
              cliente,
              origen: origenDePlaylist(id),
            ),
      NodoAlbum(id: final id) => cliente == null
          ? const []
          : _hojaCanciones(
              parentMediaId,
              await cliente.cancionesDeAlbum(id),
              cliente,
            ),
      NodoArtista(id: final id) => cliente == null
          ? const []
          : [
              for (final a in await cliente.albumesDeArtista(id))
                nodoAlbum(a, portada: _portada(cliente, a.coverArt)),
            ],
      NodoDesconocido() => const [],
    };
  }

  Uri? _portada(SubsonicClient cliente, String? coverArt) =>
      coverArt == null ? null : cliente.urlPortada(coverArt, tamano: 256);

  /// Arma y cachea una carpeta de canciones reproducibles.
  List<MediaItem> _hojaCanciones(
    String parentMediaId,
    List<Cancion> canciones,
    SubsonicClient cliente, {
    String? origen,
  }) {
    final lista = [for (final c in canciones) aMediaItem(c, cliente)];
    _hojasCache[parentMediaId] = lista;
    if (origen != null) _origenPorHoja[parentMediaId] = origen;
    return lista;
  }

  Future<List<MediaItem>> _hojaDescargas() async {
    final descargas = await _descargasStorage.leer();
    final lista = [
      for (final d in descargas) aMediaItem(d.cancion, _cliente, descarga: d),
    ];
    _hojasCache[idRaizDescargas] = lista;
    return lista;
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    for (final lista in _hojasCache.values) {
      for (final item in lista) {
        if (item.id == mediaId) return item;
      }
    }
    return null;
  }

  /// Lo que llama Android Auto al tocar una cancion del arbol.
  ///
  /// Busca primero en las carpetas ya mostradas en esta corrida, para armar
  /// la cola con toda la lista (el resto del album o de la playlist), no solo
  /// la cancion tocada. Si la cache esta fria — el proceso se reinicio y el
  /// auto retoma sin haber navegado antes — hay dos redes de contencion:
  /// primero lo descargado (no necesita servidor), y recien despues un pedido
  /// suelto al servidor.
  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    for (final entrada in _hojasCache.entries) {
      final indice = entrada.value.indexWhere((m) => m.id == mediaId);
      if (indice == -1) continue;

      await reproducirLista(
        entrada.value,
        indice,
        origen: _origenPorHoja[entrada.key],
      );
      return;
    }

    final descargas = await _descargasStorage.leer();
    for (final d in descargas) {
      if (d.cancion.id != mediaId) continue;
      await reproducirLista([aMediaItem(d.cancion, _cliente, descarga: d)], 0);
      return;
    }

    final cliente = _cliente;
    if (cliente == null) return;

    final cancion = await cliente.buscarCancion(mediaId);
    if (cancion == null) return;
    await reproducirLista([aMediaItem(cancion, cliente)], 0);
  }
}
