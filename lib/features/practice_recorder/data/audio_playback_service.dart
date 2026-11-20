import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../../core/audio/domain/i_studio_audio_channel.dart';
import '../../../core/audio/domain/i_studio_audio_engine.dart';
import '../../../core/audio/infrastructure/memory_studio_audio_engine.dart';
import '../../../core/audio/infrastructure/studio_audio_channel.dart';
import '../../../core/audio/infrastructure/studio_audio_engine.dart';
import '../domain/i_audio_playback_service.dart';

/// Implementación de infraestructura para la reproducción de tomas de práctica
/// conectada al motor canónico de audio central [IStudioAudioEngine].
class AudioPlaybackService implements IAudioPlaybackService {
  final IStudioAudioEngine _audioEngine;
  final IStudioAudioChannel _channel;
  final bool _ownsChannel;
  StreamSubscription<dynamic>? _stateSub;

  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<void> _completeController = StreamController<void>.broadcast();

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  factory AudioPlaybackService({
    IStudioAudioEngine? audioEngine,
    AudioPlayer? player,
  }) {
    final resolvedEngine = audioEngine ??
        (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine());
    return AudioPlaybackService._(
      audioEngine: resolvedEngine,
      channel: player != null
          ? StudioAudioChannel(channelId: 'practice_take', injectedPlayer: player)
          : resolvedEngine.getChannel('practice_take'),
      ownsChannel: player != null || audioEngine == null,
    );
  }

  AudioPlaybackService._({
    required IStudioAudioEngine audioEngine,
    required IStudioAudioChannel channel,
    required bool ownsChannel,
  })  : _audioEngine = audioEngine,
        _channel = channel,
        _ownsChannel = ownsChannel {
    _stateSub = _channel.stateStream.listen((state) {
      _positionController.add(Duration(milliseconds: state.currentPositionMs));
      _durationController.add(Duration(milliseconds: state.durationMs));
      if (state.isStopped && state.currentPositionMs == 0) {
        _completeController.add(null);
      }
    });
  }

  /// Retorna la instancia del motor de audio central que reproduce las tomas de práctica.
  IStudioAudioEngine get audioEngine => _audioEngine;

  @override
  bool get isPlaying => _channel.isPlaying;

  @override
  Future<void> play(String filePath) async {
    await _channel.loadSource(filePath: filePath, loop: false, title: 'Practice Take');
    await _channel.play();
  }

  @override
  Future<void> pause() async {
    await _channel.pause();
  }

  @override
  Future<void> stop() async {
    await _channel.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _channel.seek(position);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await _channel.setPlaybackRate(rate);
  }

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionController.close();
    _durationController.close();
    _completeController.close();
    if (_ownsChannel) {
      _channel.dispose();
    } else {
      _channel.stop();
    }
  }
}
