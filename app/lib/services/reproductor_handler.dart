import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Motor de reproducción.
///
/// `audio_service` corre esto dentro de un servicio en primer plano de Android,
/// que es lo que permite que la música siga sonando con la app cerrada y que
/// aparezcan los controles en la notificación y en la pantalla de bloqueo.
///
/// La URL de streaming de cada canción viaja en `extras['url']` del [MediaItem],
/// así el handler no necesita conocer el cliente de Subsonic ni las credenciales.
class ReproductorHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  ReproductorHandler() {
    _player.playbackEventStream.listen(
      _difundirEstado,
      onError: (Object e, StackTrace s) => _difundirError(),
    );

    // Cuando el reproductor pasa de pista, hay que avisarle al sistema cuál
    // suena ahora para que la notificación se actualice.
    _player.currentIndexStream.listen((indice) {
      final lista = queue.value;
      if (indice == null || indice >= lista.length) return;
      mediaItem.add(lista[indice]);
    });

    // Al terminar la cola, volver al principio en pausa en vez de quedar en un
    // estado raro con la última pista terminada.
    _player.processingStateStream.listen((estado) async {
      if (estado == ProcessingState.completed) {
        await _player.pause();
        await _player.seek(Duration.zero, index: 0);
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();

  /// Carga una lista y arranca en la posición indicada.
  Future<void> reproducirLista(List<MediaItem> canciones, int indice) async {
    if (canciones.isEmpty) return;

    queue.add(canciones);
    mediaItem.add(canciones[indice]);

    await _player.setAudioSources(
      canciones.map(_fuenteDe).toList(),
      initialIndex: indice,
      initialPosition: Duration.zero,
    );
    await _player.play();
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
    // Igual que en Spotify: si ya pasaron unos segundos, el botón reinicia la
    // canción en vez de saltar a la anterior.
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
