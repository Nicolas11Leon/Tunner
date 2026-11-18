import 'dart:typed_data';
import 'all_pass_filter.dart';
import 'comb_filter.dart';

/// Motor de reverberación algorítmica estéreo basado en la topología Schroeder-Moorer.
///
/// Emplea 4 filtros en peine en paralelo por canal con tiempos de retardo primos relativos,
/// seguidos de 2 filtros paso-todo en serie. Aplica decorrelación estéreo mediante un desfase
/// de retardo fijo en el canal derecho para enriquecer el campo acústico binaural.
class SchroederReverbEngine {
  // Retardos en muestras canónicos a 44.1 kHz (números primos o sin factores comunes)
  static const List<int> _combTunings = [1116, 1188, 1277, 1356];
  static const List<int> _allPassTunings = [225, 556];
  static const int _stereoSpread = 23;

  final List<CombFilter> _combLeft = [];
  final List<CombFilter> _combRight = [];
  final List<AllPassFilter> _allPassLeft = [];
  final List<AllPassFilter> _allPassRight = [];

  double _roomSize = 0.5;
  double _damping = 0.5;
  double _wetMix = 0.33;
  double _dryMix = 0.8;
  double _width = 1.0;

  SchroederReverbEngine({
    double roomSize = 0.5,
    double damping = 0.5,
    double wetMix = 0.33,
    double dryMix = 0.8,
    double width = 1.0,
  })  : _roomSize = roomSize,
        _damping = damping,
        _wetMix = wetMix,
        _dryMix = dryMix,
        _width = width {
    _initFilters();
    _updateParameters();
  }

  double get roomSize => _roomSize;
  double get damping => _damping;
  double get wetMix => _wetMix;
  double get dryMix => _dryMix;
  double get width => _width;

  set roomSize(double val) {
    _roomSize = val.clamp(0.0, 1.0);
    _updateParameters();
  }

  set damping(double val) {
    _damping = val.clamp(0.0, 1.0);
    _updateParameters();
  }

  set wetMix(double val) => _wetMix = val.clamp(0.0, 1.0);
  set dryMix(double val) => _dryMix = val.clamp(0.0, 1.0);
  set width(double val) => _width = val.clamp(0.0, 1.0);

  void _initFilters() {
    _combLeft.clear();
    _combRight.clear();
    _allPassLeft.clear();
    _allPassRight.clear();

    for (final tuning in _combTunings) {
      _combLeft.add(CombFilter(tuning));
      _combRight.add(CombFilter(tuning + _stereoSpread));
    }

    for (final tuning in _allPassTunings) {
      _allPassLeft.add(AllPassFilter(tuning, feedback: 0.5));
      _allPassRight.add(AllPassFilter(tuning + _stereoSpread, feedback: 0.5));
    }
  }

  void _updateParameters() {
    // Escalamiento canónico de feedback para estabilidad de filtros en peine
    final feedbackVal = _roomSize * 0.28 + 0.7;
    final dampVal = _damping * 0.4;

    for (var i = 0; i < _combLeft.length; i++) {
      _combLeft[i].feedback = feedbackVal;
      _combLeft[i].damp = dampVal;
      _combRight[i].feedback = feedbackVal;
      _combRight[i].damp = dampVal;
    }
  }

  /// Procesa bloques de audio estéreo de forma no bloqueante y sin asignaciones en bucle.
  void processStereo(
    Float32List leftIn,
    Float32List rightIn,
    Float32List leftOut,
    Float32List rightOut,
    int numSamples,
  ) {
    final wet1 = _wetMix * ((_width / 2.0) + 0.5);
    final wet2 = _wetMix * ((1.0 - _width) / 2.0);

    for (var i = 0; i < numSamples; i++) {
      final inputSample = (leftIn[i] + rightIn[i]) * 0.5;

      var outLeft = 0.0;
      var outRight = 0.0;

      // 1. Banco de filtros en peine en paralelo
      for (var c = 0; c < _combLeft.length; c++) {
        outLeft += _combLeft[c].process(inputSample);
        outRight += _combRight[c].process(inputSample);
      }

      // 2. Filtros paso-todo en serie
      for (var a = 0; a < _allPassLeft.length; a++) {
        outLeft = _allPassLeft[a].process(outLeft);
        outRight = _allPassRight[a].process(outRight);
      }

      // 3. Mezcla espacial y salida estéreo
      leftOut[i] = (leftIn[i] * _dryMix) + (outLeft * wet1) + (outRight * wet2);
      rightOut[i] = (rightIn[i] * _dryMix) + (outRight * wet1) + (outLeft * wet2);
    }
  }

  /// Limpia las líneas de retardo para suprimir cualquier cola de reverberación residual.
  void mute() {
    for (final c in _combLeft) {
      c.mute();
    }
    for (final c in _combRight) {
      c.mute();
    }
    for (final a in _allPassLeft) {
      a.mute();
    }
    for (final a in _allPassRight) {
      a.mute();
    }
  }
}
