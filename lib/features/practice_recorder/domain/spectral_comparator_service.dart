import 'dart:math' as math;
import 'multitrack_session_entity.dart';

/// Punto alineado en el tiempo para la comparación directa entre dos tomas.
class SpectralComparisonPoint {
  final int timeMs;
  final double? centsA;
  final double? centsB;
  final double? centroidA;
  final double? centroidB;

  const SpectralComparisonPoint({
    required this.timeMs,
    this.centsA,
    this.centsB,
    this.centroidA,
    this.centroidB,
  });

  /// Diferencia absoluta de entonación entre ambas tomas en este instante temporal.
  double? get centsDelta {
    if (centsA == null || centsB == null) return null;
    return (centsB! - centsA!).abs();
  }
}

/// Resultado consolidado de la contrastación matemática y acústica entre dos tomas.
class SpectralComparisonResult {
  final String takeAId;
  final String takeAName;
  final String takeBId;
  final String takeBName;

  final double meanPitchDeviationA; // Desviación media absoluta en cents
  final double meanPitchDeviationB; // Desviación media absoluta en cents
  final double pitchStabilityDelta; // Positivo si Toma B es más afinada que Toma A
  final double inTunePercentageA;    // % muestras dentro de +-5 cents
  final double inTunePercentageB;    // % muestras dentro de +-5 cents

  final double meanCentroidA;       // Brillo medio en Hz
  final double meanCentroidB;       // Brillo medio en Hz
  final double centroidDeltaHz;     // Diferencia de brillo tímbrico

  final List<SpectralComparisonPoint> comparisonPoints;
  final String pedagogicalSummary;

  const SpectralComparisonResult({
    required this.takeAId,
    required this.takeAName,
    required this.takeBId,
    required this.takeBName,
    required this.meanPitchDeviationA,
    required this.meanPitchDeviationB,
    required this.pitchStabilityDelta,
    required this.inTunePercentageA,
    required this.inTunePercentageB,
    required this.meanCentroidA,
    required this.meanCentroidB,
    required this.centroidDeltaHz,
    required this.comparisonPoints,
    required this.pedagogicalSummary,
  });

  static const SpectralComparisonResult empty = SpectralComparisonResult(
    takeAId: '',
    takeAName: 'Toma A',
    takeBId: '',
    takeBName: 'Toma B',
    meanPitchDeviationA: 0.0,
    meanPitchDeviationB: 0.0,
    pitchStabilityDelta: 0.0,
    inTunePercentageA: 0.0,
    inTunePercentageB: 0.0,
    meanCentroidA: 0.0,
    meanCentroidB: 0.0,
    centroidDeltaHz: 0.0,
    comparisonPoints: [],
    pedagogicalSummary: 'Sin datos comparativos suficientes.',
  );
}

/// Servicio de dominio puro para el análisis y comparación de tomas de práctica instrumental.
class SpectralComparatorService {
  const SpectralComparatorService();

  /// Compara dos tomas de práctica instrumental y retorna el informe acústico diferencial.
  SpectralComparisonResult compareTakes(
    PracticeTakeEntity takeA,
    PracticeTakeEntity takeB, {
    int timeStepMs = 50,
  }) {
    final devA = takeA.averagePitchDeviationCents;
    final devB = takeB.averagePitchDeviationCents;
    final stabilityDelta = devA - devB;

    // Calcular porcentajes de afinación pura (+-5 cents)
    final validPitchA = takeA.pitchTrack.where((p) => !p.isSilent && p.frequencyHz > 20).toList();
    final validPitchB = takeB.pitchTrack.where((p) => !p.isSilent && p.frequencyHz > 20).toList();

    final inTuneCountA = validPitchA.where((p) => p.centsDeviation.abs() <= 5.0).length;
    final inTuneCountB = validPitchB.where((p) => p.centsDeviation.abs() <= 5.0).length;

    final inTunePctA = validPitchA.isNotEmpty ? (inTuneCountA / validPitchA.length) * 100.0 : 0.0;
    final inTunePctB = validPitchB.isNotEmpty ? (inTuneCountB / validPitchB.length) * 100.0 : 0.0;

    final centroidA = takeA.averageSpectralCentroidHz;
    final centroidB = takeB.averageSpectralCentroidHz;
    final centroidDelta = centroidB - centroidA;

    // Alinear puntos temporales uniformes
    final maxDurationMs = math.max(
      takeA.duration.inMilliseconds,
      takeB.duration.inMilliseconds,
    );

    final comparisonPoints = <SpectralComparisonPoint>[];
    if (maxDurationMs > 0) {
      for (int t = 0; t <= maxDurationMs; t += timeStepMs) {
        final samplePitchA = _findClosestPitch(takeA.pitchTrack, t, timeStepMs);
        final samplePitchB = _findClosestPitch(takeB.pitchTrack, t, timeStepMs);
        final sampleSpecA = _findClosestSpectral(takeA.spectralTrack, t, timeStepMs);
        final sampleSpecB = _findClosestSpectral(takeB.spectralTrack, t, timeStepMs);

        comparisonPoints.add(
          SpectralComparisonPoint(
            timeMs: t,
            centsA: samplePitchA != null && !samplePitchA.isSilent ? samplePitchA.centsDeviation : null,
            centsB: samplePitchB != null && !samplePitchB.isSilent ? samplePitchB.centsDeviation : null,
            centroidA: sampleSpecA?.spectralCentroidHz,
            centroidB: sampleSpecB?.spectralCentroidHz,
          ),
        );
      }
    }

    // Redactar diagnóstico pedagógico objetivo
    String summary;
    if (stabilityDelta > 2.0) {
      summary = 'Mejora notable de afinación (+${stabilityDelta.toStringAsFixed(1)} cents de mayor estabilidad en ${takeB.name}).';
    } else if (stabilityDelta < -2.0) {
      summary = 'La ${takeA.name} mantuvo mayor precisión de afinación (+${(-stabilityDelta).toStringAsFixed(1)} cents mejor que ${takeB.name}).';
    } else {
      summary = 'Entonación consistente entre ambas tomas con diferencia menor a 2.0 cents.';
    }

    if (centroidDelta.abs() > 150.0) {
      final direction = centroidDelta > 0 ? 'más brillante y proyectado' : 'más cálido y redondo';
      summary += ' El timbre en ${takeB.name} fue $direction (Delta ${centroidDelta.toStringAsFixed(0)} Hz).';
    }

    return SpectralComparisonResult(
      takeAId: takeA.id,
      takeAName: takeA.name,
      takeBId: takeB.id,
      takeBName: takeB.name,
      meanPitchDeviationA: devA,
      meanPitchDeviationB: devB,
      pitchStabilityDelta: stabilityDelta,
      inTunePercentageA: inTunePctA,
      inTunePercentageB: inTunePctB,
      meanCentroidA: centroidA,
      meanCentroidB: centroidB,
      centroidDeltaHz: centroidDelta,
      comparisonPoints: comparisonPoints,
      pedagogicalSummary: summary,
    );
  }

  TimedPitchSample? _findClosestPitch(List<TimedPitchSample> track, int targetTimeMs, int maxToleranceMs) {
    if (track.isEmpty) return null;
    TimedPitchSample? closest;
    int minDiff = maxToleranceMs + 1;

    for (final s in track) {
      final diff = (s.timeMs - targetTimeMs).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = s;
      }
    }
    return minDiff <= maxToleranceMs ? closest : null;
  }

  TimedSpectralSample? _findClosestSpectral(List<TimedSpectralSample> track, int targetTimeMs, int maxToleranceMs) {
    if (track.isEmpty) return null;
    TimedSpectralSample? closest;
    int minDiff = maxToleranceMs + 1;

    for (final s in track) {
      final diff = (s.timeMs - targetTimeMs).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = s;
      }
    }
    return minDiff <= maxToleranceMs ? closest : null;
  }
}
