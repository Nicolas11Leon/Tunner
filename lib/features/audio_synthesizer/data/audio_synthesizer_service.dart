import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../domain/i_audio_synthesizer_service.dart';
import '../domain/pcm_wav_synthesizer.dart';

/// Implementación de infraestructura para la reproducción de clics de metrónomo y diapasón
/// utilizando síntesis procedural PCM en memoria RAM y [AudioPlayer.play] con [BytesSource].
class AudioSynthesizerService implements IAudioSynthesizerService {
  AudioPlayer? _clickPlayerInstance;
  AudioPlayer? _diapasonPlayerInstance;

  AudioPlayer get _clickPlayer => _clickPlayerInstance ??= AudioPlayer();
  AudioPlayer get _diapasonPlayer => _diapasonPlayerInstance ??= AudioPlayer();

  // Buffers PCM pre-calculados en memoria RAM para rendimiento instantáneo
  late final Uint8List _downbeatBytes;
  late final Uint8List _offbeatBytes;

  bool _isDiapasonPlaying = false;
  double _activeDiapasonFrequency = 0.0;

  AudioSynthesizerService({
    AudioPlayer? clickPlayer,
    AudioPlayer? diapasonPlayer,
  })  : _clickPlayerInstance = clickPlayer,
        _diapasonPlayerInstance = diapasonPlayer {
    _downbeatBytes = PcmWavSynthesizer.generateMetronomeClickWav(isDownbeat: true);
    _offbeatBytes = PcmWavSynthesizer.generateMetronomeClickWav(isDownbeat: false);
  }

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
      await _clickPlayer.stop();
      await _clickPlayer.setVolume(clampedVolume);
      await _clickPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      debugPrint('Error emitiendo clic de metrónomo: $e');
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
      await _diapasonPlayer.setReleaseMode(ReleaseMode.loop);
      await _diapasonPlayer.setVolume(clampedVolume);
      await _diapasonPlayer.play(BytesSource(toneBytes, mimeType: 'audio/wav'));
    } catch (e) {
      debugPrint('Error iniciando tono de diapasón: $e');
    }
  }

  @override
  Future<void> stopDiapasonTone() async {
    _isDiapasonPlaying = false;
    _activeDiapasonFrequency = 0.0;

    try {
      await _diapasonPlayer.stop();
    } catch (e) {
      debugPrint('Error deteniendo diapasón: $e');
    }
  }

  @override
  void dispose() {
    _clickPlayerInstance?.dispose();
    _diapasonPlayerInstance?.dispose();
  }
}
