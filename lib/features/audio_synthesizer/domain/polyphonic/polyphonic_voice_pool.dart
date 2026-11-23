import 'dart:math' as math;
import 'dart:typed_data';
import '../../../../core/dsl/domain/i_synth_voice_pool_port.dart';
import '../pcm_wav_synthesizer.dart';
import 'adsr_envelope_generator.dart';
import 'polyphonic_synth_voice.dart';

/// Grupo de voces polifónicas con asignación dinámica y algoritmo de robo de voces.
///
/// Gestiona un conjunto determinista de [PolyphonicSynthVoice] (por defecto 16 voces),
/// permitiendo la ejecución de acordes complejos, notas simultáneas y control centralizado
/// de envolvente ADSR y forma de onda.
class PolyphonicVoicePool implements ISynthVoicePoolPort {
  @override
  final int maxPolyphony;
  final List<PolyphonicSynthVoice> _voices;

  SynthWaveform _waveform = SynthWaveform.triangle;
  double _pulseWidth = 0.5;
  double _masterGain = 0.75;
  double _sampleRate;

  PolyphonicVoicePool({
    this.maxPolyphony = 16,
    double sampleRate = 44100.0,
    double attackSeconds = 0.015,
    double decaySeconds = 0.08,
    double sustainLevel = 0.65,
    double releaseSeconds = 0.18,
    SynthWaveform defaultWaveform = SynthWaveform.triangle,
  })  : _sampleRate = sampleRate,
        _waveform = defaultWaveform,
        _voices = [] {
    for (int i = 0; i < maxPolyphony; i++) {
      final voice = PolyphonicSynthVoice(id: i, sampleRate: sampleRate);
      voice.envelope.attackSeconds = attackSeconds;
      voice.envelope.decaySeconds = decaySeconds;
      voice.envelope.sustainLevel = sustainLevel;
      voice.envelope.releaseSeconds = releaseSeconds;
      voice.waveform = defaultWaveform;
      _voices.add(voice);
    }
  }

  @override
  void setDslWaveform(DslSynthWaveform value) {
    switch (value) {
      case DslSynthWaveform.sine:
        waveform = SynthWaveform.sine;
        break;
      case DslSynthWaveform.sawtooth:
        waveform = SynthWaveform.sawtooth;
        break;
      case DslSynthWaveform.pulse:
        waveform = SynthWaveform.pulse;
        break;
      case DslSynthWaveform.triangle:
        waveform = SynthWaveform.triangle;
        break;
    }
  }

  // Getters
  List<PolyphonicSynthVoice> get voices => List.unmodifiable(_voices);
  @override
  int get activeVoiceCount => _voices.where((v) => v.isActive).length;
  SynthWaveform get waveform => _waveform;
  @override
  String get dslWaveformName => _waveform.name;
  double get pulseWidth => _pulseWidth;
  @override
  double get masterGain => _masterGain;
  double get sampleRate => _sampleRate;

  @override
  double get attackSeconds => _voices.first.envelope.attackSeconds;
  @override
  double get decaySeconds => _voices.first.envelope.decaySeconds;
  @override
  double get sustainLevel => _voices.first.envelope.sustainLevel;
  @override
  double get releaseSeconds => _voices.first.envelope.releaseSeconds;

  // Setters globales aplicados a todas las voces
  set waveform(SynthWaveform value) {
    _waveform = value;
    for (final voice in _voices) {
      voice.waveform = value;
    }
  }

  set pulseWidth(double value) {
    _pulseWidth = value.clamp(0.05, 0.95);
    for (final voice in _voices) {
      voice.pulseWidth = _pulseWidth;
    }
  }

  set masterGain(double value) => _masterGain = value.clamp(0.0, 1.0);

  @override
  set attackSeconds(double value) {
    for (final voice in _voices) {
      voice.envelope.attackSeconds = value;
    }
  }

  @override
  set decaySeconds(double value) {
    for (final voice in _voices) {
      voice.envelope.decaySeconds = value;
    }
  }

  @override
  set sustainLevel(double value) {
    for (final voice in _voices) {
      voice.envelope.sustainLevel = value;
    }
  }

  @override
  set releaseSeconds(double value) {
    for (final voice in _voices) {
      voice.envelope.releaseSeconds = value;
    }
  }

  set sampleRate(double value) {
    _sampleRate = value;
    for (final voice in _voices) {
      voice.envelope.sampleRate = value;
    }
  }

  /// Calcula la frecuencia en Hz a partir del número de nota MIDI estándar.
  /// Fórmula canónica: f = referencePitchHz * 2^((midi - 69) / 12)
  static double midiToFrequency(
    int midiNote, {
    double referencePitchHz = 440.0,
  }) {
    final safeRef = referencePitchHz > 0.0 ? referencePitchHz : 440.0;
    return safeRef * math.pow(2.0, (midiNote - 69.0) / 12.0);
  }

  /// Alias compatible con [StemAudioSynthesizer.midiPitchToFrequency].
  static double midiPitchToFrequency(
    int midiPitch, {
    double referencePitchHz = 440.0,
  }) =>
      midiToFrequency(midiPitch, referencePitchHz: referencePitchHz);

  /// Activa una nota musical polifónica.
  /// Si no se especifica [frequency], se calcula automáticamente a partir de [noteNumber].
  @override
  void noteOn(int noteNumber, double velocity, {double? frequency}) {
    final freq = frequency ?? midiToFrequency(noteNumber);
    final voice = _findVoiceForNote(noteNumber);

    voice.startNote(
      noteNumber: noteNumber,
      frequency: freq,
      velocity: velocity,
      waveform: _waveform,
      pulseWidth: _pulseWidth,
    );
  }

  /// Pasa a fase de liberación todas las voces que se encuentren ejecutando [noteNumber].
  @override
  void noteOff(int noteNumber) {
    for (final voice in _voices) {
      if (voice.noteNumber == noteNumber && voice.isActive) {
        voice.stopNote();
      }
    }
  }

  /// Libera suavemente todas las notas actualmente activas.
  void allNotesOff() {
    for (final voice in _voices) {
      if (voice.isActive) {
        voice.stopNote();
      }
    }
  }

  /// Detiene inmediatamente todas las notas sin esperar la fase de Release.
  @override
  void panic() {
    for (final voice in _voices) {
      voice.kill();
    }
  }

  /// Localiza una voz disponible o aplica el algoritmo de robo de voz (Voice Stealing).
  PolyphonicSynthVoice _findVoiceForNote(int noteNumber) {
    // 1. Si la nota ya está sonando en una voz, reusarla
    for (final voice in _voices) {
      if (voice.noteNumber == noteNumber && voice.isActive) {
        return voice;
      }
    }

    // 2. Buscar una voz en reposo (idle)
    for (final voice in _voices) {
      if (voice.isIdle) {
        return voice;
      }
    }

    // 3. Algoritmo de Robo de Voz: buscar en fase de Release con menor amplitud
    PolyphonicSynthVoice? releaseCandidate;
    double lowestAmplitude = double.infinity;
    for (final voice in _voices) {
      if (voice.stage == AdsrStage.release && voice.currentAmplitude < lowestAmplitude) {
        lowestAmplitude = voice.currentAmplitude;
        releaseCandidate = voice;
      }
    }
    if (releaseCandidate != null) {
      return releaseCandidate;
    }

    // 4. Fallback de robo: tomar la voz más antigua en reproducción
    int oldestAge = -1;
    PolyphonicSynthVoice oldestCandidate = _voices.first;
    for (final voice in _voices) {
      if (voice.ageSamples > oldestAge) {
        oldestAge = voice.ageSamples;
        oldestCandidate = voice;
      }
    }
    return oldestCandidate;
  }

  /// Renderiza un bloque de muestras monofónicas sumando todas las voces activas.
  void renderMonoBlock({
    required Float64List out,
    required int numSamples,
  }) {
    for (int i = 0; i < numSamples; i++) {
      double sum = 0.0;
      for (int v = 0; v < _voices.length; v++) {
        final voice = _voices[v];
        if (voice.isActive) {
          sum += voice.renderNextSample(_sampleRate);
        }
      }
      final scaled = sum * _masterGain;
      out[i] = scaled / (1.0 + scaled.abs());
    }
  }

  /// Renderiza un bloque de muestras de audio estéreo sumando todas las voces activas.
  /// Aplica saturación suave analógica (Soft Limiter) para prevenir distorsión digital.
  void renderBlock({
    required Float64List leftOut,
    required Float64List rightOut,
    required int numSamples,
  }) {
    for (int i = 0; i < numSamples; i++) {
      double sum = 0.0;
      for (int v = 0; v < _voices.length; v++) {
        final voice = _voices[v];
        if (voice.isActive) {
          sum += voice.renderNextSample(_sampleRate);
        }
      }

      // Ganancia maestra
      final scaled = sum * _masterGain;

      // Saturación suave analógica: tanh aproximada y eficiente (x / (1 + |x|))
      final limited = scaled / (1.0 + scaled.abs());

      leftOut[i] = limited;
      rightOut[i] = limited;
    }
  }

  /// Renderiza la polifonía activa directamente a un arreglo de bytes en formato RIFF/WAVE PCM estándar de 16 bits estéreo.
  Uint8List renderWavBlock({
    required double durationSeconds,
    int sampleRate = 44100,
  }) {
    final numSamples = (sampleRate * durationSeconds).round();
    final leftOut = Float64List(numSamples);
    final rightOut = Float64List(numSamples);
    renderBlock(leftOut: leftOut, rightOut: rightOut, numSamples: numSamples);

    final pcmBytes = ByteData(numSamples * 4);
    for (int i = 0; i < numSamples; i++) {
      final sampleL = (leftOut[i] * 32767.0).clamp(-32768.0, 32767.0).round();
      final sampleR = (rightOut[i] * 32767.0).clamp(-32768.0, 32767.0).round();
      pcmBytes.setInt16(i * 4, sampleL, Endian.little);
      pcmBytes.setInt16(i * 4 + 2, sampleR, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 2,
      bitsPerSample: 16,
    );

    final wavBuffer = BytesBuilder(copy: false);
    wavBuffer.add(header);
    wavBuffer.add(pcmBytes.buffer.asUint8List());
    return wavBuffer.toBytes();
  }
}
