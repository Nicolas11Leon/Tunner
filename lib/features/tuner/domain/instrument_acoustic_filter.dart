import 'dart:math' as math;

/// Configuración inmutable para el aislamiento acústico y rechazo de voz / ruidos.
class InstrumentAcousticFilterConfig {
  /// Activa o desactiva el aislamiento de tesitura y rechazo de habla.
  final bool enabled;

  /// Frecuencia mínima del instrumento acústico activo en Hz.
  final double minFrequencyHz;

  /// Frecuencia máxima del instrumento acústico activo en Hz.
  final double maxFrequencyHz;

  /// Umbral mínimo de claridad armónica MPM (rango 0.0 a 1.0).
  /// Instrumentos acústicos: ~0.80 - 0.85; Voz cantada: ~0.70; Desactivado: ~0.40.
  final double minClarity;

  /// Cantidad mínima de frames consecutivos estables antes de enganchar la nota (Tone Lock).
  final int minConsecutiveFrames;

  /// Tolerancia máxima de desviación en cents entre frames consecutivos para Tone Lock.
  final double maxCentsDeviation;

  const InstrumentAcousticFilterConfig({
    this.enabled = true,
    this.minFrequencyHz = 27.5,
    this.maxFrequencyHz = 4186.0,
    this.minClarity = 0.82,
    this.minConsecutiveFrames = 2,
    this.maxCentsDeviation = 35.0,
  });

  /// Configuración abierta para afinación universal cromática o voz entonada.
  factory InstrumentAcousticFilterConfig.universal({bool enabled = false}) {
    return InstrumentAcousticFilterConfig(
      enabled: enabled,
      minFrequencyHz: 27.5,
      maxFrequencyHz: 4186.0,
      minClarity: 0.70,
      minConsecutiveFrames: 1,
      maxCentsDeviation: 50.0,
    );
  }

  /// Crea una configuración estricta adaptada a la tesitura de un instrumento específico.
  factory InstrumentAcousticFilterConfig.forInstrument({
    required double minFrequencyHz,
    required double maxFrequencyHz,
    bool enabled = true,
    double minClarity = 0.82,
  }) {
    // Margen armónico de respiración del 10% inferior y superior
    final lowerBound = math.max(20.0, minFrequencyHz * 0.90);
    final upperBound = math.min(4200.0, maxFrequencyHz * 1.10);

    return InstrumentAcousticFilterConfig(
      enabled: enabled,
      minFrequencyHz: lowerBound,
      maxFrequencyHz: upperBound,
      minClarity: minClarity,
      minConsecutiveFrames: 2,
      maxCentsDeviation: 35.0,
    );
  }

  /// Evalúa si una frecuencia cae dentro de los márgenes acústicos del filtro.
  bool isFrequencyAllowed(double freqHz) {
    return freqHz >= minFrequencyHz && freqHz <= maxFrequencyHz;
  }

  InstrumentAcousticFilterConfig copyWith({
    bool? enabled,
    double? minFrequencyHz,
    double? maxFrequencyHz,
    double? minClarity,
    int? minConsecutiveFrames,
    double? maxCentsDeviation,
  }) {
    return InstrumentAcousticFilterConfig(
      enabled: enabled ?? this.enabled,
      minFrequencyHz: minFrequencyHz ?? this.minFrequencyHz,
      maxFrequencyHz: maxFrequencyHz ?? this.maxFrequencyHz,
      minClarity: minClarity ?? this.minClarity,
      minConsecutiveFrames: minConsecutiveFrames ?? this.minConsecutiveFrames,
      maxCentsDeviation: maxCentsDeviation ?? this.maxCentsDeviation,
    );
  }
}

/// Discriminador de estabilidad tonal (Tone Lock) y rechazo de prosodia vocal errática.
///
/// La voz hablada ordinaria cambia bruscamente de frecuencia cada 20-40 ms (> 80 cents),
/// mientras que una nota tocada en un instrumento musical se mantiene dentro de una ventana
/// de pocos cents por múltiples cuadros de tiempo.
class ToneLockTracker {
  double _lastCandidatePitch = 0.0;
  int _stableFrameCount = 0;
  double _lockedPitch = 0.0;

  double get lockedPitch => _lockedPitch;
  int get stableFrameCount => _stableFrameCount;
  bool get isLocked => _lockedPitch > 0.0 && _stableFrameCount >= 2;

  void reset() {
    _lastCandidatePitch = 0.0;
    _stableFrameCount = 0;
    _lockedPitch = 0.0;
  }

  /// Evalúa si el tono candidato califica como nota musical sostenida o debe descartarse.
  /// Retorna la frecuencia confirmada si supera el Tone Lock, o `null` si se descarta.
  double? processFrame({
    required double rawPitchHz,
    required double clarity,
    required InstrumentAcousticFilterConfig config,
  }) {
    if (!config.enabled) {
      // Modo abierto: solo exige rango físico de audio audible
      if (rawPitchHz >= 27.5 && rawPitchHz <= 4186.0) {
        return rawPitchHz;
      }
      return null;
    }

    // 1. Filtrado de Tesitura del Instrumento
    if (rawPitchHz < config.minFrequencyHz || rawPitchHz > config.maxFrequencyHz) {
      reset();
      return null;
    }

    // 2. Filtrado de Claridad Armónica (Descarta ruido y consonantes)
    if (clarity < config.minClarity) {
      reset();
      return null;
    }

    // 3. Verificación de Estabilidad Tonal (Tone Lock)
    if (_lastCandidatePitch <= 0.0) {
      _lastCandidatePitch = rawPitchHz;
      _stableFrameCount = 1;
      if (config.minConsecutiveFrames <= 1) {
        _lockedPitch = rawPitchHz;
        return _lockedPitch;
      }
      return null;
    }

    final centsDiff = 1200.0 * (math.log(rawPitchHz / _lastCandidatePitch) / math.ln2).abs();

    if (centsDiff <= config.maxCentsDeviation) {
      _stableFrameCount++;
      _lastCandidatePitch = rawPitchHz;

      if (_stableFrameCount >= config.minConsecutiveFrames) {
        _lockedPitch = rawPitchHz;
        return _lockedPitch;
      }
      return null;
    } else {
      // Salto brusco (prosodia de habla o transición rápida de transitorio)
      _lastCandidatePitch = rawPitchHz;
      _stableFrameCount = 1;
      return null;
    }
  }
}
