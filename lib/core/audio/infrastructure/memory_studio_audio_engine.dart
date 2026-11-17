import 'dart:async';
import 'dart:typed_data';
import '../domain/i_studio_audio_channel.dart';
import '../domain/i_studio_audio_engine.dart';
import '../domain/studio_audio_track_state.dart';
import '../domain/studio_transport_status.dart';

/// Implementación en memoria de un canal de audio para pruebas unitarias e integración en CI.
class MemoryStudioAudioChannel implements IStudioAudioChannel {
  @override
  final String channelId;

  StudioTransportStatus _status = StudioTransportStatus.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3);
  double _volume = 1.0;
  double _playbackRate = 1.0;
  bool _isLooping = false;
  String? _sourceTitle;

  Uint8List? loadedBytes;
  String? loadedFilePath;

  final StreamController<StudioAudioTrackState> _stateController =
      StreamController<StudioAudioTrackState>.broadcast();

  MemoryStudioAudioChannel({required this.channelId});

  void _emit() {
    if (_stateController.isClosed) return;
    _stateController.add(
      StudioAudioTrackState(
        channelId: channelId,
        status: _status,
        currentPositionMs: _currentPosition.inMilliseconds,
        durationMs: _totalDuration.inMilliseconds,
        volume: _volume,
        playbackRate: _playbackRate,
        isLooping: _isLooping,
        sourceTitle: _sourceTitle,
      ),
    );
  }

  @override
  StudioTransportStatus get status => _status;

  @override
  bool get isPlaying => _status == StudioTransportStatus.playing;

  @override
  bool get isPaused => _status == StudioTransportStatus.paused;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  double get volume => _volume;

  @override
  double get playbackRate => _playbackRate;

  @override
  Stream<StudioAudioTrackState> get stateStream => _stateController.stream;

  @override
  Future<void> loadSource({
    String? filePath,
    Uint8List? bytes,
    bool loop = false,
    String? title,
  }) async {
    loadedFilePath = filePath;
    loadedBytes = bytes;
    _isLooping = loop;
    _sourceTitle = title;
    _status = StudioTransportStatus.stopped;
    _currentPosition = Duration.zero;
    _emit();
  }

  @override
  Future<void> play() async {
    _status = StudioTransportStatus.playing;
    _emit();
  }

  @override
  Future<void> pause() async {
    _status = StudioTransportStatus.paused;
    _emit();
  }

  @override
  Future<void> stop() async {
    _status = StudioTransportStatus.stopped;
    _currentPosition = Duration.zero;
    _emit();
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    _emit();
  }

  @override
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    // Preserva estrictamente el estado si está en pausa o detenido
    _emit();
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate.clamp(0.5, 2.0);
    _emit();
  }

  @override
  Future<void> dispose() async {
    _status = StudioTransportStatus.stopped;
    await _stateController.close();
  }
}

/// Implementación en memoria del motor central para pruebas unitarias.
class MemoryStudioAudioEngine implements IStudioAudioEngine {
  final Map<String, MemoryStudioAudioChannel> channels = {};

  @override
  IStudioAudioChannel getChannel(String channelId) {
    final normalized = channelId.trim().toLowerCase();
    return channels.putIfAbsent(
      normalized,
      () => MemoryStudioAudioChannel(channelId: normalized),
    );
  }

  @override
  Future<void> pauseAll() async {
    for (final ch in channels.values) {
      if (ch.isPlaying) await ch.pause();
    }
  }

  @override
  Future<void> stopAll() async {
    for (final ch in channels.values) {
      await ch.stop();
    }
  }

  @override
  Future<void> dispose() async {
    for (final ch in channels.values) {
      await ch.dispose();
    }
    channels.clear();
  }
}
