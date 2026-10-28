import 'dart:typed_data';

import '../domain/i_audio_synthesizer_service.dart';

/// Implementación en memoria y aislada de [IAudioSynthesizerService] para pruebas unitarias.
/// Cero llamadas a canales de plataforma o plugins de audio nativo.
class MemoryAudioSynthesizerService implements IAudioSynthesizerService {
  final List<({bool isDownbeat, double volume})> clickHistory = [];
  bool _isDiapasonPlaying = false;
  double _activeDiapasonFrequency = 0.0;
  double lastDiapasonVolume = 0.0;

  @override
  bool get isDiapasonPlaying => _isDiapasonPlaying;

  @override
  double get activeDiapasonFrequency => _activeDiapasonFrequency;

  @override
  Future<void> playMetronomeClick({required bool isDownbeat, double volume = 1.0}) async {
    clickHistory.add((isDownbeat: isDownbeat, volume: volume));
  }

  @override
  Future<void> startDiapasonTone(double frequency, {double volume = 0.8}) async {
    _isDiapasonPlaying = true;
    _activeDiapasonFrequency = frequency;
    lastDiapasonVolume = volume;
  }

  @override
  Future<void> stopDiapasonTone() async {
    _isDiapasonPlaying = false;
    _activeDiapasonFrequency = 0.0;
  }

  final List<({double frequency, Duration duration, double volume})> playedNotes = [];

  @override
  Future<void> playNoteTone({
    required double frequency,
    required Duration duration,
    double volume = 0.8,
  }) async {
    playedNotes.add((frequency: frequency, duration: duration, volume: volume));
  }

  bool _isDroneLoopPlaying = false;
  Uint8List? lastDroneBuffer;
  double lastDroneVolume = 0.0;

  @override
  bool get isDroneLoopPlaying => _isDroneLoopPlaying;

  @override
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7}) async {
    _isDroneLoopPlaying = true;
    lastDroneBuffer = wavBytes;
    lastDroneVolume = volume;
  }

  @override
  Future<void> stopDroneLoop() async {
    _isDroneLoopPlaying = false;
  }

  @override
  void dispose() {
    _isDiapasonPlaying = false;
    _isDroneLoopPlaying = false;
    clickHistory.clear();
    playedNotes.clear();
  }
}
