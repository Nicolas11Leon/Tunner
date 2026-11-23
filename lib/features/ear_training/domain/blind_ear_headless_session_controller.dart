import '../../pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';
import 'blind_ear_trainer_engine.dart';
import 'ear_training_exercise.dart';
import 'musical_interval.dart';

/// Controlador headless en Pure Dart para sesiones de entrenamiento auditivo a ciegas.
///
/// Desacopla la logica de ventana de estabilidad vocal (3 muestras cantadas consecutivas
/// con deriva inferior a 50 cents) y la priorizacion de items vencidos (`isDue`) de
/// `EbbinghausSpacedRepetitionEngine` respecto de la capa de presentacion Flutter.
class BlindEarHeadlessSessionController {
  /// Numero de muestras cantadas estables consecutivas requeridas para confirmar tono.
  static const int defaultStabilityWindowSize = 3;

  /// Deriva maxima permitida entre muestras consecutivas para considerarse estables.
  static const double defaultMaxDriftCents = 50.0;

  /// Frecuencia minima valida para rechazar silencio o ruido subsonico.
  static const double defaultMinValidFrequencyHz = 20.0;

  final BlindEarTrainerEngine engine;
  final EbbinghausSpacedRepetitionEngine? ebbinghausEngine;
  final int stabilityWindowSize;
  final double maxDriftCents;
  final double minValidFrequencyHz;

  final List<double> _consecutiveSungSamples = [];
  double _lastDetectedFrequencyHz = 0.0;
  EarTrainingAnswerResult? _lastResult;
  EarTrainingEvaluationResult? _lastEbbinghausEvaluation;

  BlindEarHeadlessSessionController({
    BlindEarTrainerEngine? engine,
    this.ebbinghausEngine,
    this.stabilityWindowSize = defaultStabilityWindowSize,
    this.maxDriftCents = defaultMaxDriftCents,
    this.minValidFrequencyHz = defaultMinValidFrequencyHz,
  }) : engine = engine ?? BlindEarTrainerEngine();

  EarTrainingQuestion? get currentQuestion => engine.currentQuestion;
  EarTrainingAnswerResult? get lastResult => _lastResult;
  EarTrainingEvaluationResult? get lastEbbinghausEvaluation => _lastEbbinghausEvaluation;
  int get consecutiveStableSampleCount => _consecutiveSungSamples.length;
  double get lastDetectedFrequencyHz => _lastDetectedFrequencyHz;

  /// Mapea un `MusicalInterval` a su identificador canonico en `EbbinghausSpacedRepetitionEngine`.
  static String ebbinghausIdForInterval(MusicalInterval interval) {
    switch (interval) {
      case MusicalInterval.unison:
        return 'interval_P1';
      case MusicalInterval.minorSecond:
        return 'interval_m2';
      case MusicalInterval.majorSecond:
        return 'interval_M2';
      case MusicalInterval.minorThird:
        return 'interval_m3';
      case MusicalInterval.majorThird:
        return 'interval_M3';
      case MusicalInterval.perfectFourth:
        return 'interval_P4';
      case MusicalInterval.tritone:
        return 'interval_TT';
      case MusicalInterval.perfectFifth:
        return 'interval_P5';
      case MusicalInterval.minorSixth:
        return 'interval_m6';
      case MusicalInterval.majorSixth:
        return 'interval_M6';
      case MusicalInterval.minorSeventh:
        return 'interval_m7';
      case MusicalInterval.majorSeventh:
        return 'interval_M7';
      case MusicalInterval.perfectOctave:
        return 'interval_P8';
    }
  }

  /// Resuelve el `MusicalInterval` correspondiente a un item de categoria `interval`.
  static MusicalInterval? intervalFromEbbinghausItem(EarTrainingItemEntity item) {
    if (item.category != EarTrainingCategory.interval) return null;
    final roundedSemitones = item.semitones.round();
    if ((item.semitones - roundedSemitones).abs() > 0.01) return null;
    if (roundedSemitones < 0 || roundedSemitones > 12) return null;
    return MusicalInterval.fromSemitones(roundedSemitones);
  }

  /// Genera la siguiente pregunta priorizando los intervalos vencidos (`isDue`)
  /// con menor retencion cognitiva en `EbbinghausSpacedRepetitionEngine`.
  EarTrainingQuestion generateNextQuestion({
    bool prioritizeDue = true,
    DateTime? now,
    double targetRetention = 0.90,
  }) {
    _consecutiveSungSamples.clear();
    _lastDetectedFrequencyHz = 0.0;
    _lastResult = null;
    _lastEbbinghausEvaluation = null;

    final spacedEngine = ebbinghausEngine;
    if (!prioritizeDue || spacedEngine == null) {
      return engine.generateNextQuestion();
    }

    final referenceTime = now ?? DateTime.now();
    final dueItems = spacedEngine.getDueItems(
      now: referenceTime,
      targetRetention: targetRetention,
    );

    final activeSet = engine.config.activeIntervals.toSet();
    final dueIntervals = <MusicalInterval>[];
    for (final item in dueItems) {
      final interval = intervalFromEbbinghausItem(item);
      if (interval != null && activeSet.contains(interval) && !dueIntervals.contains(interval)) {
        dueIntervals.add(interval);
      }
    }

    if (dueIntervals.isEmpty) {
      return engine.generateNextQuestion();
    }

    // Prioriza el intervalo vencido mas urgente (menor retencion R(t)).
    final originalConfig = engine.config;
    engine.config = EarTrainingConfig(
      activeIntervals: [dueIntervals.first],
      onlyAscending: originalConfig.onlyAscending,
      useJustIntonation: originalConfig.useJustIntonation,
      minBaseFrequencyHz: originalConfig.minBaseFrequencyHz,
      maxBaseFrequencyHz: originalConfig.maxBaseFrequencyHz,
    );
    try {
      return engine.generateNextQuestion();
    } finally {
      engine.config = originalConfig;
    }
  }

  /// Ingiere una muestra de frecuencia cantada en tiempo real aplicando el filtro
  /// de estabilidad de [stabilityWindowSize] muestras consecutivas (por defecto 3).
  ///
  /// Retorna `null` mientras la ventana no alcance estabilidad o ante silencio;
  /// retorna el `EarTrainingAnswerResult` evaluado al confirmarse las muestras estables.
  EarTrainingAnswerResult? ingestSungFrequencySample(
    double frequencyHz, {
    int responseTimeMs = 1800,
    DateTime? now,
  }) {
    if (engine.currentQuestion == null || _lastResult != null) {
      return null;
    }

    if (!frequencyHz.isFinite || frequencyHz <= minValidFrequencyHz) {
      _consecutiveSungSamples.clear();
      return null;
    }

    _lastDetectedFrequencyHz = frequencyHz;

    if (_consecutiveSungSamples.isNotEmpty) {
      final prevFreq = _consecutiveSungSamples.last;
      final deltaCents = MusicalInterval.calculateCentsDeviation(frequencyHz, prevFreq).abs();
      if (deltaCents >= maxDriftCents) {
        _consecutiveSungSamples.clear();
      }
    }

    _consecutiveSungSamples.add(frequencyHz);

    if (_consecutiveSungSamples.length < stabilityWindowSize) {
      return null;
    }

    final avgFreq = _consecutiveSungSamples.reduce((a, b) => a + b) /
        _consecutiveSungSamples.length;
    _consecutiveSungSamples.clear();

    return submitSungFrequency(
      avgFreq,
      responseTimeMs: responseTimeMs,
      now: now,
    );
  }

  /// Evalua una seleccion explicita de intervalo y sincroniza con Ebbinghaus si existe.
  EarTrainingAnswerResult submitChoice(
    MusicalInterval selected, {
    int responseTimeMs = 1200,
    double centsDeviation = 0.0,
    bool hasAcousticCents = true,
    DateTime? now,
  }) {
    _consecutiveSungSamples.clear();
    final result = engine.submitIntervalChoice(
      selected,
      responseTimeMs: responseTimeMs,
      centsDeviation: centsDeviation,
      hasAcousticCents: hasAcousticCents,
    );
    _lastResult = result;
    _syncEbbinghaus(result, now: now);
    return result;
  }

  /// Evalua una frecuencia cantada confirmada y sincroniza con Ebbinghaus si existe.
  EarTrainingAnswerResult submitSungFrequency(
    double sungFrequencyHz, {
    int responseTimeMs = 1800,
    DateTime? now,
  }) {
    _consecutiveSungSamples.clear();
    final result = engine.submitSungFrequency(
      sungFrequencyHz,
      responseTimeMs: responseTimeMs,
    );
    _lastResult = result;
    _syncEbbinghaus(result, now: now);
    return result;
  }

  void _syncEbbinghaus(EarTrainingAnswerResult result, {DateTime? now}) {
    final spacedEngine = ebbinghausEngine;
    if (spacedEngine == null) return;

    final itemId = ebbinghausIdForInterval(result.targetInterval);
    if (spacedEngine.getItem(itemId) == null) return;

    _lastEbbinghausEvaluation = spacedEngine.submitAnswer(
      itemId,
      isCorrect: result.isCorrect,
      centsError: result.centsDeviation,
      responseTimeSeconds: result.responseTimeMs / 1000.0,
      timestamp: now,
    );
  }

  /// Limpia unicamente el buffer de estabilidad vocal sin reiniciar la sesion.
  void clearSungBuffer() {
    _consecutiveSungSamples.clear();
    _lastDetectedFrequencyHz = 0.0;
  }

  /// Reinicia por completo la sesion de entrenamiento y su buffer vocal.
  void resetSession() {
    engine.resetSession();
    _consecutiveSungSamples.clear();
    _lastDetectedFrequencyHz = 0.0;
    _lastResult = null;
    _lastEbbinghausEvaluation = null;
  }

  /// Serializa el estado actual de la sesion headless para consumo MCP/JSON.
  Map<String, dynamic> toJson({bool hideCorrectOption = false}) {
    return {
      'totalQuestionsAnswered': engine.totalQuestionsAnswered,
      'correctAnswersCount': engine.correctAnswersCount,
      'accuracyPercentage': engine.accuracyPercentage,
      'currentStreak': engine.currentStreak,
      'bestStreak': engine.bestStreak,
      'totalScore': engine.totalScore,
      'averageCentsDeviation': engine.averageCentsDeviation,
      'averageResponseTimeMs': engine.averageResponseTimeMs,
      'consecutiveStableSampleCount': _consecutiveSungSamples.length,
      'stabilityWindowSize': stabilityWindowSize,
      'lastDetectedFrequencyHz': _lastDetectedFrequencyHz,
      'currentQuestion': currentQuestion?.toJson(hideCorrectOption: hideCorrectOption),
      'lastResult': _lastResult?.toJson(),
      'lastEbbinghausEvaluation': _lastEbbinghausEvaluation?.toJson(),
    };
  }
}
