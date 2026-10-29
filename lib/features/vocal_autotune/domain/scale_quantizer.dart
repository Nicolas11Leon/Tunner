import 'dart:math' as math;
import 'autotune_config_entity.dart';

/// Resultado de la cuantización de afinación y cálculo de pitch-shifting.
class ScaleQuantizationResult {
  final double detectedFrequencyHz;
  final double targetFrequencyHz;
  final String targetNoteName;
  final double pitchShiftRatio; // alpha = target / detected
  final double centsDeviation; // Desviación en cents con respecto a la nota objetivo
  final bool isVoiced;
  final bool isNoteInScale;

  const ScaleQuantizationResult({
    required this.detectedFrequencyHz,
    required this.targetFrequencyHz,
    required this.targetNoteName,
    required this.pitchShiftRatio,
    required this.centsDeviation,
    required this.isVoiced,
    required this.isNoteInScale,
  });

  factory ScaleQuantizationResult.unvoiced(double detectedHz) {
    return ScaleQuantizationResult(
      detectedFrequencyHz: detectedHz,
      targetFrequencyHz: detectedHz,
      targetNoteName: '--',
      pitchShiftRatio: 1.0,
      centsDeviation: 0.0,
      isVoiced: false,
      isNoteInScale: false,
    );
  }
}

/// Motor de cuantización matemática de tono a escala musical y filtro de inercia temporal.
class ScaleQuantizer {
  double _lastSmoothedRatio = 1.0;

  ScaleQuantizer();

  /// Reinicia el filtro de suavizado temporal de inercia.
  void reset() {
    _lastSmoothedRatio = 1.0;
  }

  /// Cuantiza la frecuencia detectada hacia la escala musical configurada y calcula
  /// el ratio de corrección $\alpha$ con inercia configurable (`retuneSpeedMs`).
  ScaleQuantizationResult quantize({
    required double detectedPitchHz,
    required AutoTuneConfigEntity config,
    double deltaSeconds = 0.02,
  }) {
    if (!config.isEnabled || detectedPitchHz <= 20.0) {
      _lastSmoothedRatio = 1.0;
      return ScaleQuantizationResult.unvoiced(detectedPitchHz);
    }

    final a4 = config.a4Reference > 20.0 ? config.a4Reference : 440.0;

    // Conversión a escala continua fraccional de MIDI (69 = A4)
    final double continuousMidi = 69.0 + 12.0 * (math.log(detectedPitchHz / a4) / math.ln2);
    final int roundedMidi = continuousMidi.round();
    final int detectedPitchClass = (roundedMidi % 12 + 12) % 12;

    // Buscar la nota permitida más cercana según la escala activa
    final int targetMidi = _findClosestScaleMidi(
      continuousMidi: continuousMidi,
      detectedPitchClass: detectedPitchClass,
      roundedMidi: roundedMidi,
      config: config,
    );

    // Calcular frecuencia objetivo exacta
    final double targetHz = a4 * math.pow(2.0, (targetMidi - 69.0) / 12.0);

    // Desviación en cents hacia la nota cuantizada
    final double centsDiff = 1200.0 * (math.log(detectedPitchHz / targetHz) / math.ln2);

    // Ratio instantáneo de modificación tonal
    final double rawRatio = targetHz / detectedPitchHz;

    // Ponderar por el grado de corrección deseado (0.0 a 1.0)
    final double targetRatio = 1.0 + (rawRatio - 1.0) * config.correctionAmount.clamp(0.0, 1.0);

    // Aplicar filtro de inercia unipolar según retuneSpeedMs
    final double smoothedRatio;
    if (config.retuneSpeedMs <= 0.0) {
      // Hard Tune instantáneo sin inercia
      smoothedRatio = targetRatio;
    } else {
      final double tau = config.retuneSpeedMs / 1000.0;
      final double effectiveDelta = deltaSeconds.clamp(0.001, 0.2);
      final double alphaCoeff = (1.0 - math.exp(-effectiveDelta / tau)).clamp(0.01, 1.0);
      smoothedRatio = _lastSmoothedRatio + alphaCoeff * (targetRatio - _lastSmoothedRatio);
    }
    _lastSmoothedRatio = smoothedRatio;

    // Determinar nombre de nota formateado (ej. "Do4 / C4")
    final int targetPitchClass = (targetMidi % 12 + 12) % 12;
    final int octave = (targetMidi ~/ 12) - 1;
    final String noteName = '${kChromaticNoteNames[targetPitchClass]}$octave';

    return ScaleQuantizationResult(
      detectedFrequencyHz: detectedPitchHz,
      targetFrequencyHz: targetHz,
      targetNoteName: noteName,
      pitchShiftRatio: smoothedRatio,
      centsDeviation: centsDiff,
      isVoiced: true,
      isNoteInScale: config.isPitchClassAllowed(detectedPitchClass),
    );
  }

  /// Encuentra la nota MIDI permitida por la escala más próxima a la frecuencia continua.
  int _findClosestScaleMidi({
    required double continuousMidi,
    required int detectedPitchClass,
    required int roundedMidi,
    required AutoTuneConfigEntity config,
  }) {
    if (config.isPitchClassAllowed(detectedPitchClass)) {
      return roundedMidi;
    }

    // Si la nota detectada no está en la escala, buscar la más cercana dentro de +-6 semitonos
    int bestMidi = roundedMidi;
    double minDistance = double.infinity;

    for (int offset = -6; offset <= 6; offset++) {
      final candidateMidi = roundedMidi + offset;
      final candidatePitchClass = (candidateMidi % 12 + 12) % 12;

      if (config.isPitchClassAllowed(candidatePitchClass)) {
        final distance = (continuousMidi - candidateMidi).abs();
        if (distance < minDistance) {
          minDistance = distance;
          bestMidi = candidateMidi;
        }
      }
    }

    return bestMidi;
  }
}
