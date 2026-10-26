import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../domain/i_audio_playback_service.dart';

/// Implementación de infraestructura para la reproducción de tomas de práctica con [AudioPlayer].
/// Inicializa AudioPlayer de forma diferida (lazy) para evitar invocar canales de plataforma prematuramente.
class AudioPlaybackService implements IAudioPlaybackService {
  AudioPlayer? _player;
  bool _isPlaying = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<void> _completeController = StreamController<void>.broadcast();

  AudioPlaybackService({AudioPlayer? player}) : _player = player {
    if (player != null) {
      _bindPlayer(player);
    }
  }

  void _bindPlayer(AudioPlayer p) {
    _subscriptions.add(p.onPlayerStateChanged.listen((state) {
      _isPlaying = (state == PlayerState.playing);
    }));
    _subscriptions.add(p.onPositionChanged.listen(_positionController.add));
    _subscriptions.add(p.onDurationChanged.listen(_durationController.add));
    _subscriptions.add(p.onPlayerComplete.listen((_) => _completeController.add(null)));
  }

  AudioPlayer _getOrCreatePlayer() {
    if (_player == null) {
      final p = AudioPlayer();
      _player = p;
      _bindPlayer(p);
    }
    return _player!;
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> play(String filePath) async {
    final player = _getOrCreatePlayer();
    await player.stop();
    await player.play(DeviceFileSource(filePath));
  }

  @override
  Future<void> pause() async {
    if (_player != null) {
      await _player!.pause();
    }
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    if (_player != null) {
      await _player!.stop();
    }
    _isPlaying = false;
  }

  @override
  Future<void> seek(Duration position) async {
    if (_player != null) {
      await _player!.seek(position);
    }
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    if (_player != null) {
      await _player!.setPlaybackRate(rate);
    }
  }

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _positionController.close();
    _durationController.close();
    _completeController.close();
    _player?.dispose();
  }
}
