import 'dart:math' as math;
import 'adsr_envelope_generator.dart';

/// Formas de onda admitidas por el oscilador acústico.
enum SynthWaveform {
  sine,
  sawtooth,
  pulse,
  triangle,
}

/// Voz sintetizadora monofónica independiente.
///
/// Modela un oscilador matemático acoplado a un generador de envolvente ADSR
/// y cálculo dinámico de fase para generación de señal en tiempo lineal.
class PolyphonicSynthVoice {
  final int id;
  final AdsrEnvelopeGenerator envelope;

  int _noteNumber = -1;
  double _frequency = 440.0;
  double _velocity = 0.8;
  SynthWaveform waveform = SynthWaveform.sine;
  double _pulseWidth = 0.5;

  double _phase = 0.0;
  int _ageSamples = 0;

  PolyphonicSynthVoice({
    required this.id,
    double sampleRate = 44100.0,
  }) : envelope = AdsrEnvelopeGenerator(sampleRate: sampleRate);

  // Getters
  int get noteNumber => _noteNumber;
  double get frequency => _frequency;
  double get velocity => _velocity;
  double get pulseWidth => _pulseWidth;
  int get ageSamples => _ageSamples;
  bool get isActive => envelope.isActive;
  bool get isIdle => envelope.isIdle;
  AdsrStage get stage => envelope.stage;
  double get currentAmplitude => envelope.currentAmplitude;

  // Setters
  set pulseWidth(double value) => _pulseWidth = value.clamp(0.05, 0.95);

  /// Dispara la voz para ejecutar una nota musical con frecuencia y velocidad dadas.
  void startNote({
    required int noteNumber,
    required double frequency,
    required double velocity,
    SynthWaveform? waveform,
    double? pulseWidth,
  }) {
    _noteNumber = noteNumber;
    _frequency = math.max(10.0, frequency);
    _velocity = velocity.clamp(0.0, 1.0);
    if (waveform != null) this.waveform = waveform;
    if (pulseWidth != null) _pulseWidth = pulseWidth.clamp(0.05, 0.95);

    _ageSamples = 0;
    envelope.noteOn();
  }

  /// Pasa la voz a la fase de liberación (Release).
  void stopNote() {
    envelope.noteOff();
  }

  /// Cancela instantáneamente el sonido de la voz forzándola a reposo.
  void kill() {
    _noteNumber = -1;
    _ageSamples = 0;
    _phase = 0.0;
    envelope.reset();
  }

  /// Genera y retorna la siguiente muestra de audio calculada [-1.0, 1.0].
  double renderNextSample(double sampleRate) {
    if (!envelope.isActive) {
      return 0.0;
    }

    _ageSamples++;
    final envAmp = envelope.processSample();
    if (envAmp <= 0.00001) {
      if (envelope.isIdle) {
        _noteNumber = -1;
      }
      return 0.0;
    }

    // Cálculo de la forma de onda
    double rawSample = 0.0;
    switch (waveform) {
      case SynthWaveform.sine:
        rawSample = math.sin(2.0 * math.pi * _phase);
        break;

      case SynthWaveform.sawtooth:
        rawSample = 2.0 * _phase - 1.0;
        break;

      case SynthWaveform.pulse:
        rawSample = (_phase < _pulseWidth) ? 1.0 : -1.0;
        break;

      case SynthWaveform.triangle:
        if (_phase < 0.5) {
          rawSample = 4.0 * _phase - 1.0;
        } else {
          rawSample = 3.0 - 4.0 * _phase;
        }
        break;
    }

    // Incremento de fase
    final phaseIncrement = _frequency / sampleRate;
    _phase += phaseIncrement;
    if (_phase >= 1.0) {
      _phase -= _phase.floor();
    }

    return rawSample * envAmp * _velocity;
  }
}
