import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../../core/audio/domain/i_studio_audio_channel.dart';
import '../../../core/audio/domain/i_studio_audio_engine.dart';
import '../../../core/audio/infrastructure/memory_studio_audio_engine.dart';
import '../../../core/audio/infrastructure/studio_audio_channel.dart';
import '../../../core/audio/infrastructure/studio_audio_engine.dart';
import '../../audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import '../domain/i_dj_deck_audio_player.dart';

/// Implementación de infraestructura para la emisión de audio real en la Consola DJ.
/// Conecta Deck A y Deck B al motor oficial de audio central [IStudioAudioEngine],
/// garantizando transiciones de transporte síncronas, protección anti-despausado por volumen,
/// reanudación fiel de pistas y compatibilidad de mezcla simultánea a 60/120 FPS.
class DjDeckAudioService implements IDjDeckAudioPlayer {
  final IStudioAudioEngine _audioEngine;
  final IStudioAudioChannel _channelA;
  final IStudioAudioChannel _channelB;

  Uint8List? _demoGrooveABytes;
  Uint8List? _demoGrooveBBytes;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  DjDeckAudioService({
    IStudioAudioEngine? audioEngine,
    AudioPlayer? playerA,
    AudioPlayer? playerB,
  })  : _audioEngine = audioEngine ??
            (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()),
        _channelA = playerA != null
            ? StudioAudioChannel(channelId: 'dj_deck_a', injectedPlayer: playerA)
            : (audioEngine ?? (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()))
                .getChannel('dj_deck_a'),
        _channelB = playerB != null
            ? StudioAudioChannel(channelId: 'dj_deck_b', injectedPlayer: playerB)
            : (audioEngine ?? (_isTestEnvironment ? MemoryStudioAudioEngine() : StudioAudioEngine()))
                .getChannel('dj_deck_b') {
    _initializeDemoGrooves();
  }

  /// Retorna la instancia del motor de audio central asignado a la consola DJ.
  IStudioAudioEngine get audioEngine => _audioEngine;

  void _initializeDemoGrooves() {
    // Generar bucle rítmico audible para Deck A (124 BPM, 4 compases)
    _demoGrooveABytes = _generateAudibleRhythmWav(
      bpm: 124.0,
      bassFreqHz: 55.0, // La1
      durationSeconds: 7.74,
      accentLead: true,
    );

    // Generar bucle rítmico audible para Deck B (128 BPM, 4 compases)
    _demoGrooveBBytes = _generateAudibleRhythmWav(
      bpm: 128.0,
      bassFreqHz: 65.4, // Do2
      durationSeconds: 7.50,
      accentLead: false,
    );
  }

  @override
  bool isDeckPlaying(String deckId) {
    return deckId.toUpperCase() == 'A' ? _channelA.isPlaying : _channelB.isPlaying;
  }

  @override
  Future<void> loadDeckTrack(
    String deckId, {
    String? filePath,
    Uint8List? wavBytes,
    String? title,
    double? bpm,
  }) async {
    final isDeckA = deckId.toUpperCase() == 'A';
    final channel = isDeckA ? _channelA : _channelB;

    if (filePath != null && filePath.isNotEmpty) {
      await channel.loadSource(filePath: filePath, loop: true, title: title);
    } else if (wavBytes != null && wavBytes.isNotEmpty) {
      await channel.loadSource(bytes: wavBytes, loop: true, title: title);
    } else {
      final defaultBytes = isDeckA ? _demoGrooveABytes : _demoGrooveBBytes;
      if (defaultBytes != null) {
        await channel.loadSource(bytes: defaultBytes, loop: true, title: 'Studio Groove');
      }
    }
  }

  @override
  Future<void> playDeck(String deckId) async {
    final isDeckA = deckId.toUpperCase() == 'A';
    final channel = isDeckA ? _channelA : _channelB;
    await channel.play();
  }

  @override
  Future<void> pauseDeck(String deckId) async {
    final isDeckA = deckId.toUpperCase() == 'A';
    final channel = isDeckA ? _channelA : _channelB;
    await channel.pause();
  }

  @override
  Future<void> seekDeck(String deckId, Duration position) async {
    final isDeckA = deckId.toUpperCase() == 'A';
    final channel = isDeckA ? _channelA : _channelB;
    await channel.seek(position);
  }

  @override
  Future<void> setDeckVolume(String deckId, double volume) async {
    final isDeckA = deckId.toUpperCase() == 'A';
    final channel = isDeckA ? _channelA : _channelB;
    await channel.setVolume(volume);
  }

  @override
  Future<void> setDeckPlaybackRate(String deckId, double rate) async {
    final isDeckA = deckId.toUpperCase() == 'A';
    final channel = isDeckA ? _channelA : _channelB;
    await channel.setPlaybackRate(rate);
  }

  @override
  void dispose() {
    _channelA.dispose();
    _channelB.dispose();
  }

  /// Sintetiza proceduralmente un bucle musical rítmico audible completo (Kick, Sub-Bass y Hi-Hats).
  static Uint8List _generateAudibleRhythmWav({
    required double bpm,
    required double bassFreqHz,
    required double durationSeconds,
    required bool accentLead,
  }) {
    const sampleRate = 44100;
    final totalSamples = (sampleRate * durationSeconds).round();
    final pcmBytes = ByteData(totalSamples * 2);

    final beatIntervalSamples = (sampleRate * 60.0 / bpm).round();

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final beatPos = i % beatIntervalSamples;
      final beatTime = beatPos / sampleRate;

      // 1. Kick Drum (Golpe de bombo en cada pulso de negra: 150 Hz -> 40 Hz con decaimiento rápido)
      final kickEnv = math.exp(-beatTime / 0.07);
      final kickFreq = 40.0 + 110.0 * math.exp(-beatTime / 0.03);
      final kickSignal = math.sin(2.0 * math.pi * kickFreq * beatTime) * kickEnv * 0.7;

      // 2. Línea de bajo tonal sub-bass (pulsante en semicorcheas)
      final subBassEnv = math.exp(-(beatPos % (beatIntervalSamples ~/ 2)) / (sampleRate * 0.12));
      final subBassSignal = math.sin(2.0 * math.pi * bassFreqHz * t) * subBassEnv * 0.45;

      // 3. Hi-Hat percusivo brillante (a contratiempo)
      double hatSignal = 0.0;
      if (beatPos > beatIntervalSamples ~/ 2) {
        final hatTime = (beatPos - beatIntervalSamples ~/ 2) / sampleRate;
        final hatEnv = math.exp(-hatTime / 0.02);
        final noise = (math.sin(i * 12.9898) * 43758.5453).remainder(1.0);
        hatSignal = noise * hatEnv * (accentLead ? 0.35 : 0.25);
      }

      // 4. Toque de sintetizador analógico en arpegio si es accentLead
      double synthLead = 0.0;
      if (accentLead) {
        final chordNote = (t * (bpm / 60.0) * 2.0).floor() % 4;
        final noteFreq = bassFreqHz * (chordNote == 0 ? 2.0 : chordNote == 1 ? 2.4 : chordNote == 2 ? 3.0 : 4.0);
        final leadEnv = math.exp(-(beatPos % (beatIntervalSamples ~/ 4)) / (sampleRate * 0.08));
        synthLead = math.sin(2.0 * math.pi * noteFreq * t) * leadEnv * 0.25;
      }

      final mixed = (kickSignal + subBassSignal + hatSignal + synthLead).clamp(-1.0, 1.0);
      final sampleInt16 = (mixed * 32767.0).round().clamp(-32768, 32767);
      pcmBytes.setInt16(i * 2, sampleInt16, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final result = Uint8List(header.length + pcmBytes.lengthInBytes);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, pcmBytes.buffer.asUint8List());
    return result;
  }
}
