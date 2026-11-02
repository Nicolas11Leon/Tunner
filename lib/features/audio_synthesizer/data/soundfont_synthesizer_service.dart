import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/pcm_wav_synthesizer.dart';
import '../domain/sf2/sf2_models.dart';
import '../domain/sf2/sf2_parser.dart';
import '../domain/sf2/sf2_wavetable_oscillator.dart';
import '../domain/sf2/tunner_acoustic_soundfont_bank.dart';

/// Servicio de aplicación e infraestructura para la síntesis de audio SoundFont SF2.
/// Maneja la carga de bancos, selección de preset y renderizado de notas a buffers WAV canónicos.
class SoundFontSynthesizerService {
  SoundFontSynthesizerService({
    Sf2SoundFont? initialBank,
  }) : _activeSoundFont = initialBank ?? TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();

  Sf2SoundFont _activeSoundFont;
  int _activePatch = 0; // Default: Grand Piano (GM #0)
  final Sf2WavetableOscillator _oscillator = const Sf2WavetableOscillator();
  final Sf2Parser _parser = const Sf2Parser();

  Sf2SoundFont get activeSoundFont => _activeSoundFont;
  int get activePatch => _activePatch;
  List<Sf2Preset> get availablePresets => _activeSoundFont.presets;

  /// Cambia el banco activo parseando un archivo `.sf2` externo.
  void loadSoundFontFromBytes(Uint8List sf2Bytes) {
    try {
      final parsed = _parser.parse(sf2Bytes);
      _activeSoundFont = parsed;
      _activePatch = parsed.presets.isNotEmpty ? parsed.presets.first.patch : 0;
    } catch (e) {
      // Si falla la carga del binario, preservar el banco esencial seguro
      rethrow;
    }
  }

  /// Restablece el banco SoundFont al esencial de Tunner.
  void resetToEssentialsBank() {
    _activeSoundFont = TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();
    _activePatch = 0;
  }

  /// Selecciona el instrumento activo por su número de patch.
  void selectPatch(int patch) {
    _activePatch = patch;
  }

  /// Sintetiza una nota instrumental a un arreglo canónico de bytes WAV PCM de 16 bits.
  Uint8List synthesizeNoteWav({
    required int midiPitch,
    double durationSeconds = 1.0,
    int velocity = 100,
    int sampleRate = 44100,
  }) {
    final preset = _activeSoundFont.findPreset(_activePatch);
    if (preset == null || _activeSoundFont.sampleHeaders.isEmpty) {
      // Fallback a tono senoidal en PCM
      return _generateFallbackWav(
        midiPitch: midiPitch,
        durationSeconds: durationSeconds,
        sampleRate: sampleRate,
      );
    }

    // Buscar zona del preset correspondiente a la nota
    Sf2Zone? matchingPresetZone;
    for (final zone in preset.zones) {
      if (zone.keyRange.contains(midiPitch) && zone.velRange.contains(velocity)) {
        matchingPresetZone = zone;
        break;
      }
    }

    final instrumentId = matchingPresetZone?.instrumentId ??
        (preset.zones.isNotEmpty ? preset.zones.first.instrumentId : 0);

    Sf2Instrument? inst;
    if (instrumentId != null && instrumentId < _activeSoundFont.instruments.length) {
      inst = _activeSoundFont.instruments[instrumentId];
    } else if (_activeSoundFont.instruments.isNotEmpty) {
      inst = _activeSoundFont.instruments.first;
    }

    Sf2Zone? matchingInstZone;
    if (inst != null) {
      for (final zone in inst.zones) {
        if (zone.keyRange.contains(midiPitch) && zone.velRange.contains(velocity)) {
          matchingInstZone = zone;
          break;
        }
      }
      matchingInstZone ??= inst.zones.isNotEmpty ? inst.zones.first : null;
    }

    final sampleId = matchingInstZone?.sampleId ?? 0;
    if (sampleId >= _activeSoundFont.sampleHeaders.length) {
      return _generateFallbackWav(
        midiPitch: midiPitch,
        durationSeconds: durationSeconds,
        sampleRate: sampleRate,
      );
    }

    final sampleHeader = _activeSoundFont.sampleHeaders[sampleId];

    final samples = _oscillator.renderNoteSamples(
      sampleData: _activeSoundFont.sampleData,
      header: sampleHeader,
      targetMidiPitch: midiPitch,
      durationSeconds: durationSeconds,
      outputSampleRate: sampleRate,
      velocity: velocity,
    );

    return _floatSamplesToWavBytes(samples, sampleRate: sampleRate);
  }

  static Uint8List _floatSamplesToWavBytes(
    Float64List samples, {
    int sampleRate = 44100,
  }) {
    final pcmBytes = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i].clamp(-32767.0, 32767.0).round();
      pcmBytes[i] = s;
    }

    final pcmByteData = pcmBytes.buffer.asUint8List();
    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmByteData.length,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final outBuilder = BytesBuilder(copy: false);
    outBuilder.add(header);
    outBuilder.add(pcmByteData);
    return outBuilder.takeBytes();
  }

  static Uint8List _generateFallbackWav({
    required int midiPitch,
    required double durationSeconds,
    required int sampleRate,
  }) {
    final freq = 440.0 * math.pow(2.0, (midiPitch - 69) / 12.0);
    final totalSamples = (durationSeconds * sampleRate).round();
    final samples = Float64List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final env = (1.0 - (i / totalSamples)).clamp(0.0, 1.0);
      samples[i] = math.sin(2.0 * math.pi * freq * t) * env * 24000.0;
    }

    return _floatSamplesToWavBytes(samples, sampleRate: sampleRate);
  }
}
