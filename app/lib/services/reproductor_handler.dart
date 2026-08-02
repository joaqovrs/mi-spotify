import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Motor de reproduccion.
///
/// `audio_service` corre esto dentro de un servicio en primer plano de Android,
/// que es lo que permite que la musica siga sonando con la app cerrada y que
/// aparezcan los controles en la notificacion y en la pantalla de bloqueo.
///
/// La URL de streaming de cada cancion viaja en `extras['url']` del [MediaItem],
/// asi el handler no necesita conocer el cliente de Subsonic ni las credenciales.
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
}
