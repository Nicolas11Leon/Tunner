import 'dart:math' as math;
import '../../pedagogy/domain/vocal_evaluation_result.dart';
import '../../practice_evaluator/domain/note_evaluation_entity.dart';
import '../../practice_evaluator/domain/practice_report_entity.dart';
import 'pedagogical_report_models.dart';

/// Agregador headless en Pure Dart para consolidar `PedagogicalSessionData`
/// sin depender de `TunerViewModel` ni de widgets Flutter.
class PedagogicalSessionAggregator {
  final List<TimedCentsSample> _centsSamples = [];
  final List<NoteEvaluationEntity> _noteEvaluations = [];
  List<double> _harmonicRatios = const [1.0, 0.5, 0.25, 0.12, 0.08, 0.04, 0.02, 0.01];
  double _spectralCentroidHz = 0.0;
  double _thdPercentage = 0.0;
  double _rhythmMeanBpm = 120.0;
  VocalEvaluationResult? _vocalEvaluation;

  List<TimedCentsSample> get centsSamples => List.unmodifiable(_centsSamples);
  List<NoteEvaluationEntity> get noteEvaluations => List.unmodifiable(_noteEvaluations);

  void addCentsSample(double timeSec, double cents) {
    if (!timeSec.isFinite || !cents.isFinite) return;
    _centsSamples.add(TimedCentsSample(timeSec: timeSec, cents: cents));
  }

  void addNoteEvaluation(NoteEvaluationEntity evaluation) {
    _noteEvaluations.add(evaluation);
  }

  void setSpectralTelemetry({
    double? spectralCentroidHz,
    double? thdPercentage,
    List<double>? harmonicRatios,
  }) {
    if (spectralCentroidHz != null && spectralCentroidHz.isFinite) {
      _spectralCentroidHz = spectralCentroidHz;
    }
    if (thdPercentage != null && thdPercentage.isFinite) {
      _thdPercentage = thdPercentage;
    }
    if (harmonicRatios != null && harmonicRatios.isNotEmpty) {
      _harmonicRatios = List<double>.unmodifiable(harmonicRatios);
    }
  }

  void setRhythmMeanBpm(double bpm) {
    if (bpm.isFinite && bpm > 0) {
      _rhythmMeanBpm = bpm;
    }
  }

  void setVocalEvaluation(VocalEvaluationResult evaluation) {
    _vocalEvaluation = evaluation;
  }

  void reset() {
    _centsSamples.clear();
    _noteEvaluations.clear();
    _harmonicRatios = const [1.0, 0.5, 0.25, 0.12, 0.08, 0.04, 0.02, 0.01];
    _spectralCentroidHz = 0.0;
    _thdPercentage = 0.0;
    _rhythmMeanBpm = 120.0;
    _vocalEvaluation = null;
  }

  /// Construye un `PedagogicalSessionData` a partir del estado acumulado en el agregador.
  PedagogicalSessionData buildSessionData({
    required String sessionTitle,
    DateTime? sessionDate,
    Duration? duration,
    double inTuneThresholdCents = 15.0,
  }) {
    final totalNotes = _noteEvaluations.isNotEmpty
        ? _noteEvaluations.length
        : _centsSamples.length;
    final inTuneCount = _noteEvaluations.isNotEmpty
        ? _noteEvaluations.where((e) => e.isPitchAccurate).length
        : _centsSamples.where((s) => s.cents.abs() <= inTuneThresholdCents).length;

    final accuracyPct = totalNotes > 0 ? (inTuneCount / totalNotes) * 100.0 : 0.0;

    final centsValues = _noteEvaluations.isNotEmpty
        ? _noteEvaluations.map((e) => e.centsDeviation).toList()
        : _centsSamples.map((s) => s.cents).toList();

    final avgCents = _meanAbs(centsValues);
    final stabilityDelta = _stdDev(centsValues);

    final timingDeltas = _noteEvaluations.map((e) => e.timingDeltaMs.toDouble()).toList();
    final rhythmJitterMs = timingDeltas.isNotEmpty ? _stdDev(timingDeltas) : 0.0;

    final resolvedDuration = duration ??
        (_centsSamples.length >= 2
            ? Duration(
                milliseconds: ((_centsSamples.last.timeSec - _centsSamples.first.timeSec)
                        .clamp(0.0, 86400.0) *
                    1000)
                    .round(),
              )
            : Duration.zero);

    final mastery = _classifyMastery(accuracyPct, rhythmJitterMs);
    final diagnostic = _buildDiagnostic(
      accuracyPct: accuracyPct,
      avgCents: avgCents,
      rhythmJitterMs: rhythmJitterMs,
      vocalEvaluation: _vocalEvaluation,
    );
    final recommendations = _buildRecommendations(
      accuracyPct: accuracyPct,
      avgCents: avgCents,
      rhythmJitterMs: rhythmJitterMs,
      vocalEvaluation: _vocalEvaluation,
    );

    return PedagogicalSessionData(
      sessionTitle: sessionTitle,
      sessionDate: sessionDate ?? DateTime.now(),
      duration: resolvedDuration,
      totalEvaluatedNotes: totalNotes,
      inTuneNotesCount: inTuneCount,
      tuningAccuracyPercentage: accuracyPct,
      averageCentsDeviation: avgCents,
      centsStabilityDelta: stabilityDelta,
      spectralCentroidHz: _spectralCentroidHz,
      thdPercentage: _thdPercentage,
      harmonicRatios: _harmonicRatios,
      rhythmMeanBpm: _rhythmMeanBpm,
      rhythmJitterMs: rhythmJitterMs,
      timedPitchSamples: List<TimedCentsSample>.unmodifiable(_centsSamples),
      masteryLevel: mastery,
      pedagogicalDiagnostic: diagnostic,
      recommendations: recommendations,
    );
  }

  /// Ensambla directamente un `PedagogicalSessionData` desde un `PracticeReportEntity`
  /// y telemetria acustica/vocal opcional sin requerir `TunerViewModel`.
  static PedagogicalSessionData fromPracticeReport(
    PracticeReportEntity report, {
    Duration duration = Duration.zero,
    double spectralCentroidHz = 0.0,
    double thdPercentage = 0.0,
    List<double> harmonicRatios = const [1.0, 0.5, 0.25, 0.12, 0.08, 0.04, 0.02, 0.01],
    double rhythmMeanBpm = 120.0,
    List<TimedCentsSample>? timedPitchSamples,
    VocalEvaluationResult? vocalEvaluation,
    String? sessionTitle,
  }) {
    final samples = timedPitchSamples ??
        List<TimedCentsSample>.generate(
          report.evaluations.length,
          (index) => TimedCentsSample(
            timeSec: index * 0.5,
            cents: report.evaluations[index].centsDeviation,
          ),
        );

    final centsValues = report.evaluations.isNotEmpty
        ? report.evaluations.map((e) => e.centsDeviation).toList()
        : samples.map((s) => s.cents).toList();
    final stabilityDelta = centsValues.isNotEmpty ? _stdDev(centsValues) : report.averageCentsDeviation;

    final timingDeltas = report.evaluations.map((e) => e.timingDeltaMs.toDouble()).toList();
    final rhythmJitterMs = timingDeltas.isNotEmpty
        ? _stdDev(timingDeltas)
        : report.averageTimingDeltaMs.abs();

    final mastery = _classifyMastery(report.pitchAccuracyPercentage, rhythmJitterMs);
    final diagnostic = _buildDiagnostic(
      accuracyPct: report.pitchAccuracyPercentage,
      avgCents: report.averageCentsDeviation,
      rhythmJitterMs: rhythmJitterMs,
      rhythmTendency: report.rhythmTendency,
      criticalNotes: report.criticalNotes,
      vocalEvaluation: vocalEvaluation,
    );
    final recommendations = _buildRecommendations(
      accuracyPct: report.pitchAccuracyPercentage,
      avgCents: report.averageCentsDeviation,
      rhythmJitterMs: rhythmJitterMs,
      rhythmTendency: report.rhythmTendency,
      criticalNotes: report.criticalNotes,
      vocalEvaluation: vocalEvaluation,
    );

    return PedagogicalSessionData(
      sessionTitle: sessionTitle ?? report.songTitle,
      sessionDate: report.timestamp,
      duration: duration,
      totalEvaluatedNotes: report.totalNotes,
      inTuneNotesCount: report.hitNotes,
      tuningAccuracyPercentage: report.pitchAccuracyPercentage,
      averageCentsDeviation: report.averageCentsDeviation,
      centsStabilityDelta: stabilityDelta,
      spectralCentroidHz: spectralCentroidHz,
      thdPercentage: thdPercentage,
      harmonicRatios: harmonicRatios,
      rhythmMeanBpm: rhythmMeanBpm,
      rhythmJitterMs: rhythmJitterMs,
      timedPitchSamples: samples,
      masteryLevel: mastery,
      pedagogicalDiagnostic: diagnostic,
      recommendations: recommendations,
    );
  }

  static double _meanAbs(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sum = values.fold<double>(0.0, (acc, v) => acc + v.abs());
    return sum / values.length;
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    double varianceSum = 0.0;
    for (final v in values) {
      final diff = v - mean;
      varianceSum += diff * diff;
    }
    return math.sqrt(varianceSum / values.length);
  }

  static String _classifyMastery(double accuracyPct, double rhythmJitterMs) {
    if (accuracyPct >= 90.0 && rhythmJitterMs <= 12.0) {
      return 'Virtuoso / Conservatorio';
    } else if (accuracyPct >= 80.0) {
      return 'Avanzado';
    } else if (accuracyPct >= 65.0) {
      return 'Intermedio';
    }
    return 'Iniciacion';
  }

  static String _buildDiagnostic({
    required double accuracyPct,
    required double avgCents,
    required double rhythmJitterMs,
    RhythmTendency? rhythmTendency,
    List<String> criticalNotes = const [],
    VocalEvaluationResult? vocalEvaluation,
  }) {
    final buffer = StringBuffer();
    buffer.write(
      'Precision tonal consolidada de ${accuracyPct.toStringAsFixed(1)}% '
      'con desvio promedio de ${avgCents.toStringAsFixed(1)} cents '
      'y dispersion ritmica de ${rhythmJitterMs.toStringAsFixed(1)} ms.',
    );

    if (rhythmTendency != null && rhythmTendency != RhythmTendency.stable) {
      buffer.write(' Tendencia temporal detectada: ${rhythmTendency.title}.');
    }
    if (criticalNotes.isNotEmpty) {
      buffer.write(' Notas criticas a reforzar: ${criticalNotes.join(', ')}.');
    }
    if (vocalEvaluation != null) {
      buffer.write(
        ' Estabilidad vocal: ${vocalEvaluation.classificationLabel} '
        '(jitter ${vocalEvaluation.jitterPercent.toStringAsFixed(2)}%, '
        'shimmer ${vocalEvaluation.shimmerPercent.toStringAsFixed(2)}%).',
      );
    }
    return buffer.toString();
  }

  static List<String> _buildRecommendations({
    required double accuracyPct,
    required double avgCents,
    required double rhythmJitterMs,
    RhythmTendency? rhythmTendency,
    List<String> criticalNotes = const [],
    VocalEvaluationResult? vocalEvaluation,
  }) {
    final recs = <String>[];
    if (avgCents > 10.0 || accuracyPct < 85.0) {
      recs.add('Practicar notas tenidas con dron armonico para estabilizar el centro tonal.');
    }
    if (rhythmJitterMs > 20.0 || rhythmTendency == RhythmTendency.rushing) {
      recs.add('Reducir el tempo en 10 BPM y trabajar subdivisiones con metronomo.');
    } else if (rhythmTendency == RhythmTendency.dragging) {
      recs.add('Anticipar la preparacion del ataque y practicar con clics en contratiempo.');
    }
    if (criticalNotes.isNotEmpty) {
      recs.add('Aislar en bucle lento las notas criticas: ${criticalNotes.join(', ')}.');
    }
    if (vocalEvaluation != null && vocalEvaluation.jitterPercent > 1.0) {
      recs.add('Estabilizar el flujo de aire diafragmatico para reducir el jitter de frecuencia.');
    }
    if (recs.isEmpty) {
      recs.add('Mantener la rutina actual e incrementar progresivamente la complejidad del repertorio.');
    }
    return List<String>.unmodifiable(recs);
  }
}
