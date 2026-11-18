import 'dart:math' as math;

/// Estados del ciclo de vida de la envolvente acústica ADSR.
enum AdsrStage {
  idle,
  attack,
  decay,
  sustain,
  release,
}

/// Generador de envolvente de cuatro etapas: Attack, Decay, Sustain y Release (ADSR).
///
/// Modula la amplitud de una voz acústica para evitar transitorios agresivos (clicks)
/// y reproducir dinámicas tímbricas realistas.
///
/// Ecuaciones de transición:
/// - Attack: Rampa lineal ascendente desde la amplitud actual hasta 1.0 en [attackSeconds].
/// - Decay: Caída lineal desde 1.0 hasta [sustainLevel] en [decaySeconds].
/// - Sustain: Nivel constante normalizado [0.0, 1.0].
/// - Release: Caída lineal desde el nivel actual de sostenimiento hasta 0.0 en [releaseSeconds].
class AdsrEnvelopeGenerator {
  double _attackSeconds;
  double _decaySeconds;
  double _sustainLevel;
  double _releaseSeconds;

  AdsrStage _stage = AdsrStage.idle;
  double _currentAmplitude = 0.0;
  double _startAmplitudeOnNoteOn = 0.0;
  double _releaseStartAmplitude = 0.0;

  int _stageSampleCounter = 0;
  int _attackSamples = 0;
  int _decaySamples = 0;
  int _releaseSamples = 0;

  double _sampleRate;

  AdsrEnvelopeGenerator({
    double attackSeconds = 0.02,
    double decaySeconds = 0.08,
    double sustainLevel = 0.7,
    double releaseSeconds = 0.15,
    double sampleRate = 44100.0,
  })  : _attackSeconds = math.max(0.001, attackSeconds),
        _decaySeconds = math.max(0.001, decaySeconds),
        _sustainLevel = sustainLevel.clamp(0.0, 1.0),
        _releaseSeconds = math.max(0.001, releaseSeconds),
        _sampleRate = math.max(1000.0, sampleRate) {
    _recalculateStageSamples();
  }

  // Getters
  AdsrStage get stage => _stage;
  double get currentAmplitude => _currentAmplitude;
  double get attackSeconds => _attackSeconds;
  double get decaySeconds => _decaySeconds;
  double get sustainLevel => _sustainLevel;
  double get releaseSeconds => _releaseSeconds;
  double get sampleRate => _sampleRate;
  bool get isIdle => _stage == AdsrStage.idle;
  bool get isActive => _stage != AdsrStage.idle;

  // Setters dinámicos
  set attackSeconds(double value) {
    _attackSeconds = math.max(0.001, value);
    _recalculateStageSamples();
  }

  set decaySeconds(double value) {
    _decaySeconds = math.max(0.001, value);
    _recalculateStageSamples();
  }

  set sustainLevel(double value) {
    _sustainLevel = value.clamp(0.0, 1.0);
  }

  set releaseSeconds(double value) {
    _releaseSeconds = math.max(0.001, value);
    _recalculateStageSamples();
  }

  set sampleRate(double value) {
    _sampleRate = math.max(1000.0, value);
    _recalculateStageSamples();
  }

  void _recalculateStageSamples() {
    _attackSamples = (_attackSeconds * _sampleRate).round();
    _decaySamples = (_decaySeconds * _sampleRate).round();
    _releaseSamples = (_releaseSeconds * _sampleRate).round();
  }

  /// Dispara el inicio de la nota musical.
  /// Si la voz ya estaba activa, parte de [_currentAmplitude] para evitar transitorios audibles.
  void noteOn() {
    _startAmplitudeOnNoteOn = _currentAmplitude;
    _stage = AdsrStage.attack;
    _stageSampleCounter = 0;
  }

  /// Dispara la liberación de la nota musical.
  void noteOff() {
    if (_stage == AdsrStage.idle) return;
    _releaseStartAmplitude = _currentAmplitude;
    _stage = AdsrStage.release;
    _stageSampleCounter = 0;
  }

  /// Interrumpe inmediatamente la voz forzándola a reposo.
  void reset() {
    _stage = AdsrStage.idle;
    _currentAmplitude = 0.0;
    _stageSampleCounter = 0;
  }

  /// Procesa una única muestra temporal y retorna el multiplicador de amplitud [0.0, 1.0].
  double processSample() {
    switch (_stage) {
      case AdsrStage.idle:
        _currentAmplitude = 0.0;
        return 0.0;

      case AdsrStage.attack:
        if (_attackSamples <= 0) {
          _currentAmplitude = 1.0;
          _stage = AdsrStage.decay;
          _stageSampleCounter = 0;
        } else {
          final progress = _stageSampleCounter / _attackSamples;
          _currentAmplitude = _startAmplitudeOnNoteOn + (1.0 - _startAmplitudeOnNoteOn) * progress;
          _stageSampleCounter++;
          if (_stageSampleCounter >= _attackSamples) {
            _currentAmplitude = 1.0;
            _stage = AdsrStage.decay;
            _stageSampleCounter = 0;
          }
        }
        return _currentAmplitude;

      case AdsrStage.decay:
        if (_decaySamples <= 0) {
          _currentAmplitude = _sustainLevel;
          _stage = AdsrStage.sustain;
          _stageSampleCounter = 0;
        } else {
          final progress = _stageSampleCounter / _decaySamples;
          _currentAmplitude = 1.0 - (1.0 - _sustainLevel) * progress;
          _stageSampleCounter++;
          if (_stageSampleCounter >= _decaySamples) {
            _currentAmplitude = _sustainLevel;
            _stage = AdsrStage.sustain;
            _stageSampleCounter = 0;
          }
        }
        return _currentAmplitude;

      case AdsrStage.sustain:
        _currentAmplitude = _sustainLevel;
        return _currentAmplitude;

      case AdsrStage.release:
        if (_releaseSamples <= 0) {
          _currentAmplitude = 0.0;
          _stage = AdsrStage.idle;
          _stageSampleCounter = 0;
        } else {
          final progress = _stageSampleCounter / _releaseSamples;
          _currentAmplitude = _releaseStartAmplitude * (1.0 - progress);
          _stageSampleCounter++;
          if (_stageSampleCounter >= _releaseSamples || _currentAmplitude <= 0.0001) {
            _currentAmplitude = 0.0;
            _stage = AdsrStage.idle;
            _stageSampleCounter = 0;
          }
        }
        return _currentAmplitude;
    }
  }
}
