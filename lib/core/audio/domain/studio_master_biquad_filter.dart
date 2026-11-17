import 'dart:math' as math;

/// Tipo de filtro digital de segundo orden (Biquad).
enum StudioBiquadType {
  /// Filtro pasa-altos o pasa-bajos tipo estante inferior (Low Shelf).
  lowShelf,

  /// Filtro paramétrico acampanado (Peaking Bell).
  peaking,

  /// Filtro tipo estante superior (High Shelf).
  highShelf,
}

/// Implementación en punto flotante de 64 bits de un Filtro Biquad Digital (Direct Form I)
/// basado en el estándar del "Audio EQ Cookbook" de Robert Bristow-Johnson.
///
/// Ecuación en diferencias finitas en el dominio del tiempo discreto:
/// $$y[n] = \frac{b_0 x[n] + b_1 x[n-1] + b_2 x[n-2] - a_1 y[n-1] - a_2 y[n-2]}{a_0}$$
class StudioMasterBiquadFilter {
  final StudioBiquadType type;
  final double frequency;
  final double gainDb;
  final double q;
  final int sampleRate;

  // Coeficientes normalizados del filtro (divididos por a0)
  late double _b0;
  late double _b1;
  late double _b2;
  late double _a1;
  late double _a2;

  // Estados de retraso anteriores para Canal Izquierdo (L)
  double _x1L = 0.0;
  double _x2L = 0.0;
  double _y1L = 0.0;
  double _y2L = 0.0;

  // Estados de retraso anteriores para Canal Derecho (R)
  double _x1R = 0.0;
  double _x2R = 0.0;
  double _y1R = 0.0;
  double _y2R = 0.0;

  StudioMasterBiquadFilter({
    required this.type,
    required this.frequency,
    required this.gainDb,
    this.q = 0.70710678, // Butterworth Q
    this.sampleRate = 44100,
  }) {
    _calculateCoefficients();
  }

  /// Crea un filtro Low Shelf centrado típicamente en 100 Hz.
  factory StudioMasterBiquadFilter.lowShelf({
    double frequency = 100.0,
    double gainDb = 0.0,
    int sampleRate = 44100,
  }) {
    return StudioMasterBiquadFilter(
      type: StudioBiquadType.lowShelf,
      frequency: frequency,
      gainDb: gainDb,
      q: 0.70710678,
      sampleRate: sampleRate,
    );
  }

  /// Crea un filtro paramétrico Peaking Bell centrado típicamente en 1000 Hz.
  factory StudioMasterBiquadFilter.peaking({
    double frequency = 1000.0,
    double gainDb = 0.0,
    double q = 1.0,
    int sampleRate = 44100,
  }) {
    return StudioMasterBiquadFilter(
      type: StudioBiquadType.peaking,
      frequency: frequency,
      gainDb: gainDb,
      q: q,
      sampleRate: sampleRate,
    );
  }

  /// Crea un filtro High Shelf centrado típicamente en 8000 Hz.
  factory StudioMasterBiquadFilter.highShelf({
    double frequency = 8000.0,
    double gainDb = 0.0,
    int sampleRate = 44100,
  }) {
    return StudioMasterBiquadFilter(
      type: StudioBiquadType.highShelf,
      frequency: frequency,
      gainDb: gainDb,
      q: 0.70710678,
      sampleRate: sampleRate,
    );
  }

  /// Derivación matemática de los coeficientes de Robert Bristow-Johnson (RBJ)
  void _calculateCoefficients() {
    final clampedFreq = frequency.clamp(10.0, (sampleRate / 2.0) - 100.0);
    final a = math.pow(10.0, gainDb / 40.0).toDouble(); // sqrt(linearGain)
    final w0 = 2.0 * math.pi * clampedFreq / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / (2.0 * q.clamp(0.1, 10.0));

    double b0Raw = 1.0;
    double b1Raw = 0.0;
    double b2Raw = 0.0;
    double a0Raw = 1.0;
    double a1Raw = 0.0;
    double a2Raw = 0.0;

    switch (type) {
      case StudioBiquadType.lowShelf:
        final twoSqrtAAlpha = 2.0 * math.sqrt(a) * alpha;
        b0Raw = a * ((a + 1.0) - (a - 1.0) * cosW0 + twoSqrtAAlpha);
        b1Raw = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosW0);
        b2Raw = a * ((a + 1.0) - (a - 1.0) * cosW0 - twoSqrtAAlpha);
        a0Raw = (a + 1.0) + (a - 1.0) * cosW0 + twoSqrtAAlpha;
        a1Raw = -2.0 * ((a - 1.0) + (a + 1.0) * cosW0);
        a2Raw = (a + 1.0) + (a - 1.0) * cosW0 - twoSqrtAAlpha;
        break;

      case StudioBiquadType.peaking:
        b0Raw = 1.0 + alpha * a;
        b1Raw = -2.0 * cosW0;
        b2Raw = 1.0 - alpha * a;
        a0Raw = 1.0 + alpha / a;
        a1Raw = -2.0 * cosW0;
        a2Raw = 1.0 - alpha / a;
        break;

      case StudioBiquadType.highShelf:
        final twoSqrtAAlpha = 2.0 * math.sqrt(a) * alpha;
        b0Raw = a * ((a + 1.0) + (a - 1.0) * cosW0 + twoSqrtAAlpha);
        b1Raw = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosW0);
        b2Raw = a * ((a + 1.0) + (a - 1.0) * cosW0 - twoSqrtAAlpha);
        a0Raw = (a + 1.0) - (a - 1.0) * cosW0 + twoSqrtAAlpha;
        a1Raw = 2.0 * ((a - 1.0) - (a + 1.0) * cosW0);
        a2Raw = (a + 1.0) - (a - 1.0) * cosW0 - twoSqrtAAlpha;
        break;
    }

    if (a0Raw.abs() > 0.0000001) {
      _b0 = b0Raw / a0Raw;
      _b1 = b1Raw / a0Raw;
      _b2 = b2Raw / a0Raw;
      _a1 = a1Raw / a0Raw;
      _a2 = a2Raw / a0Raw;
    } else {
      _b0 = 1.0;
      _b1 = 0.0;
      _b2 = 0.0;
      _a1 = 0.0;
      _a2 = 0.0;
    }
  }

  /// Procesa una muestra estéreo [xL, xR] y retorna la muestra filtrada [yL, yR].
  (double, double) processStereoSample(double xL, double xR) {
    if (gainDb.abs() < 0.001) {
      return (xL, xR); // Ganancia plana (Bypass matemático instantáneo)
    }

    // Canal Izquierdo
    final yL = _b0 * xL + _b1 * _x1L + _b2 * _x2L - _a1 * _y1L - _a2 * _y2L;
    _x2L = _x1L;
    _x1L = xL;
    _y2L = _y1L;
    _y1L = yL;

    // Canal Derecho
    final yR = _b0 * xR + _b1 * _x1R + _b2 * _x2R - _a1 * _y1R - _a2 * _y2R;
    _x2R = _x1R;
    _x1R = xR;
    _y2R = _y1R;
    _y1R = yR;

    return (yL, yR);
  }

  /// Limpia los estados de retraso de memoria previa del filtro.
  void reset() {
    _x1L = 0.0;
    _x2L = 0.0;
    _y1L = 0.0;
    _y2L = 0.0;
    _x1R = 0.0;
    _x2R = 0.0;
    _y1R = 0.0;
    _y2R = 0.0;
  }
}
