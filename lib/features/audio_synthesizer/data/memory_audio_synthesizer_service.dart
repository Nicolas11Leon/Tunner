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

  @override
  void dispose() {
    _isDiapasonPlaying = false;
  }
}
