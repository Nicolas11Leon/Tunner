import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../../../core/audio/domain/i_studio_audio_channel.dart';
import '../../../core/audio/domain/i_studio_audio_engine.dart';
import '../../../core/audio/infrastructure/memory_studio_audio_engine.dart';
import '../../../core/audio/infrastructure/studio_audio_channel.dart';
import '../../../core/audio/infrastructure/studio_audio_engine.dart';
import '../domain/i_audio_synthesizer_service.dart';
import '../domain/pcm_wav_synthesizer.dart';

/// Implementación de infraestructura para la reproducción de clics de metrónomo, diapasón
/// y notas tonales mediante el motor canónico central [IStudioAudioEngine].
class AudioSynthesizerService implements IAudioSynthesizerService {
  final IStudioAudioEngine _audioEngine;
  final IStudioAudioChannel _clickChannel;
  final IStudioAudioChannel _diapasonChannel;
  final IStudioAudioChannel _noteChannel;
  final IStudioAudioChannel _droneChannel;

  // Buffers PCM pre-calculados en memoria RAM para rendimiento instantáneo
  late final Uint8List _downbeatBytes;
  late final Uint8List _offbeatBytes;

  bool _isDiapasonPlaying = false;
  double _activeDiapasonFrequency = 0.0;
  bool _isDroneLoopPlaying = false;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  AudioSynthesizerService({
    IStudioAudioEngine? audioEngine,
    AudioPlayer? clickPlayer,
    AudioPlayer? diapasonPlayer,
    AudioPlayer? notePlayer,
    AudioPlayer? dronePlayer,
  })  : _audioEngine = audioEngine ??
            (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()),
        _clickChannel = clickPlayer != null
            ? StudioAudioChannel(channelId: 'metronome_click', injectedPlayer: clickPlayer)
            : (audioEngine ?? (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()))
                .getChannel('metronome_click'),
        _diapasonChannel = diapasonPlayer != null
            ? StudioAudioChannel(channelId: 'tuning_diapason', injectedPlayer: diapasonPlayer)
            : (audioEngine ?? (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()))
                .getChannel('tuning_diapason'),
        _noteChannel = notePlayer != null
            ? StudioAudioChannel(channelId: 'instrument_note', injectedPlayer: notePlayer)
            : (audioEngine ?? (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()))
                .getChannel('instrument_note'),
        _droneChannel = dronePlayer != null
            ? StudioAudioChannel(channelId: 'harmonic_drone', injectedPlayer: dronePlayer)
            : (audioEngine ?? (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()))
                .getChannel('harmonic_drone') {
    _downbeatBytes = PcmWavSynthesizer.generateMetronomeClickWav(isDownbeat: true);
    _offbeatBytes = PcmWavSynthesizer.generateMetronomeClickWav(isDownbeat: false);
  }

  /// Retorna la instancia del motor de audio central que orquesta los canales del sintetizador.
  IStudioAudioEngine get audioEngine => _audioEngine;

  @override
  bool get isDiapasonPlaying => _isDiapasonPlaying;

  @override
  double get activeDiapasonFrequency => _activeDiapasonFrequency;

  @override
  Future<void> playMetronomeClick({required bool isDownbeat, double volume = 1.0}) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    if (clampedVolume <= 0.001) return;

    final bytes = isDownbeat ? _downbeatBytes : _offbeatBytes;
    try {
      await _clickChannel.setVolume(clampedVolume);
      await _clickChannel.loadSource(bytes: bytes, loop: false, title: 'Click');
      await _clickChannel.play();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error emitiendo clic de metronomo',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> startDiapasonTone(double frequency, {double volume = 0.8}) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    _activeDiapasonFrequency = frequency;
    _isDiapasonPlaying = true;

    try {
      final toneBytes = PcmWavSynthesizer.generateSineToneWav(
        frequency: frequency,
        durationSeconds: 2.0,
      );
      await _diapasonChannel.setVolume(clampedVolume);
      await _diapasonChannel.loadSource(bytes: toneBytes, loop: true, title: 'Diapason');
      await _diapasonChannel.play();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error iniciando tono de diapason',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> stopDiapasonTone() async {
    _isDiapasonPlaying = false;
    _activeDiapasonFrequency = 0.0;

    try {
      await _diapasonChannel.stop();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error deteniendo diapason',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> playNoteTone({
    required double frequency,
    required Duration duration,
    double volume = 0.8,
  }) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    if (clampedVolume <= 0.001 || frequency <= 20.0) return;

    try {
      final wavBytes = PcmWavSynthesizer.generateMusicalNoteWav(
        frequency: frequency,
        durationMs: duration.inMilliseconds,
      );
      await _noteChannel.setVolume(clampedVolume);
      await _noteChannel.loadSource(bytes: wavBytes, loop: false, title: 'Note');
      await _noteChannel.play();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error reproduciendo nota musical',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> playPcmWav(Uint8List wavBytes, {double volume = 0.8}) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    if (clampedVolume <= 0.001 || wavBytes.isEmpty) return;

    try {
      await _noteChannel.setVolume(clampedVolume);
      await _noteChannel.loadSource(bytes: wavBytes, loop: false, title: 'PCM WAV');
      await _noteChannel.play();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error emitiendo audio PCM WAV',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  bool get isDroneLoopPlaying => _isDroneLoopPlaying;

  @override
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7}) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    _isDroneLoopPlaying = true;

    try {
      await _droneChannel.setVolume(clampedVolume);
      await _droneChannel.loadSource(bytes: wavBytes, loop: true, title: 'Drone Loop');
      await _droneChannel.play();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error iniciando bucle de dron',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> stopDroneLoop() async {
    _isDroneLoopPlaying = false;
    try {
      await _droneChannel.stop();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'AudioSynthesizerService',
        'Error deteniendo dron',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  void dispose() {
    _clickChannel.dispose();
    _diapasonChannel.dispose();
    _noteChannel.dispose();
    _droneChannel.dispose();
  }
}
