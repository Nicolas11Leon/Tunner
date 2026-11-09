import 'dart:math' as math;
import 'ear_training_exercise.dart';
import 'musical_interval.dart';

/// Configuración de la sesión de entrenamiento auditivo.
class EarTrainingConfig {
  /// Lista de intervalos habilitados en la práctica.
  final List<MusicalInterval> activeIntervals;

  /// Si es true, el ejercicio se genera únicamente en sentido ascendente.
  /// Si es false, se alterna aleatoriamente entre ascendente y descendente.
  final bool onlyAscending;

  /// Si es true, calcula las frecuencias según afinación justa en lugar de temperada.
  final bool useJustIntonation;

  /// Rango de frecuencias base permitidas en Hz (por defecto A3=220 Hz a A4=440 Hz).
  final double minBaseFrequencyHz;
  final double maxBaseFrequencyHz;

  const EarTrainingConfig({
    this.activeIntervals = const [
      MusicalInterval.unison,
      MusicalInterval.minorSecond,
      MusicalInterval.majorSecond,
      MusicalInterval.minorThird,
      MusicalInterval.majorThird,
      MusicalInterval.perfectFourth,
      MusicalInterval.tritone,
      MusicalInterval.perfectFifth,
      MusicalInterval.minorSixth,
      MusicalInterval.majorSixth,
      MusicalInterval.minorSeventh,
      MusicalInterval.majorSeventh,
      MusicalInterval.perfectOctave,
    ],
    this.onlyAscending = true,
    this.useJustIntonation = false,
    this.minBaseFrequencyHz = 220.0,
    this.maxBaseFrequencyHz = 440.0,
  });

  /// Configuración básica para principiantes (Unísono, 3ª Mayor, 4ª Justa, 5ª Justa, 8ª Justa).
  factory EarTrainingConfig.beginner() {
    return const EarTrainingConfig(
      activeIntervals: [
        MusicalInterval.unison,
        MusicalInterval.majorThird,
        MusicalInterval.perfectFourth,
        MusicalInterval.perfectFifth,
        MusicalInterval.perfectOctave,
      ],
      onlyAscending: true,
      useJustIntonation: false,
    );
  }
}

/// Motor determinista de entrenamiento auditivo y discriminación de intervalos a ciegas.
///
/// Implementado en Pure Dart bajo Clean Architecture (cero dependencias de UI).
class BlindEarTrainerEngine {
  EarTrainingConfig config;
  final math.Random _random;

  EarTrainingQuestion? _currentQuestion;
  int _questionCounter = 0;

  int _totalQuestionsAnswered = 0;
  int _correctAnswersCount = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalScore = 0;

  final List<EarTrainingAnswerResult> _history = [];

  BlindEarTrainerEngine({
    EarTrainingConfig? config,
    math.Random? random,
  })  : config = config ?? const EarTrainingConfig(),
        _random = random ?? math.Random();

  EarTrainingQuestion? get currentQuestion => _currentQuestion;
  int get totalQuestionsAnswered => _totalQuestionsAnswered;
  int get correctAnswersCount => _correctAnswersCount;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  int get totalScore => _totalScore;
  List<EarTrainingAnswerResult> get history => List.unmodifiable(_history);

  /// Porcentaje de precisión global de la sesión (0.0 a 100.0).
  double get accuracyPercentage {
    if (_totalQuestionsAnswered == 0) return 0.0;
    return (_correctAnswersCount / _totalQuestionsAnswered) * 100.0;
  }

  /// Promedio de desviación en cents de las respuestas correctas.
  double get averageCentsDeviation {
    final correctAnswers = _history.where((r) => r.isCorrect).toList();
    if (correctAnswers.isEmpty) return 0.0;
    final sum = correctAnswers.fold<double>(0.0, (acc, r) => acc + r.centsDeviation.abs());
    return sum / correctAnswers.length;
  }

  /// Promedio de tiempo de respuesta en milisegundos.
  double get averageResponseTimeMs {
    if (_history.isEmpty) return 0.0;
    final sum = _history.fold<int>(0, (acc, r) => acc + r.responseTimeMs);
    return sum / _history.length;
  }

  /// Genera deterministamente una nueva pregunta de entrenamiento auditivo.
  EarTrainingQuestion generateNextQuestion() {
    _questionCounter++;
    final intervals = config.activeIntervals;
    if (intervals.isEmpty) {
      throw StateError('No hay intervalos configurados en EarTrainingConfig');
    }

    // Seleccionar intervalo objetivo al azar
    final targetInterval = intervals[_random.nextInt(intervals.length)];

    // Generar frecuencia base dentro del rango configurado (ej: 220Hz a 440Hz)
    // Redondeando a una nota temperada estándar para facilitar la afinación
    final standardPitches = [220.0, 246.94, 261.63, 293.66, 329.63, 349.23, 392.0, 440.0];
    final basePitch = standardPitches[_random.nextInt(standardPitches.length)];

    final noteNames = {
      220.0: 'A3 (La 3)',
      246.94: 'B3 (Si 3)',
      261.63: 'C4 (Do 4 Central)',
      293.66: 'D4 (Re 4)',
      329.63: 'E4 (Mi 4)',
      349.23: 'F4 (Fa 4)',
      392.0: 'G4 (Sol 4)',
      440.0: 'A4 (La 4 Diapasón)',
    };
    final noteName = noteNames[basePitch] ?? 'A4';

    final isAscending = config.onlyAscending ? true : _random.nextBool();
    final targetPitch = targetInterval.calculateTargetFrequency(
      basePitch,
      ascending: isAscending,
      useJustIntonation: config.useJustIntonation,
    );

    // Generar opciones: 1 correcta y 3 distractores
    final distractors = MusicalInterval.values.where((i) => i != targetInterval).toList();
    distractors.shuffle(_random);

    final selectedDistractors = distractors.take(3).toList();
    final options = [...selectedDistractors, targetInterval]..shuffle(_random);
    final correctIndex = options.indexOf(targetInterval);

    final question = EarTrainingQuestion(
      id: 'q_$_questionCounter',
      baseNoteName: noteName,
      baseFrequencyHz: basePitch,
      targetFrequencyHz: targetPitch,
      targetInterval: targetInterval,
      isAscending: isAscending,
      options: options,
      correctOptionIndex: correctIndex,
    );

    _currentQuestion = question;
    return question;
  }

  /// Evalúa una respuesta seleccionada explícitamente (ej: mediante botones 1-4 o UI).
  EarTrainingAnswerResult submitIntervalChoice(
    MusicalInterval selected, {
    int responseTimeMs = 1200,
    double centsDeviation = 0.0,
  }) {
    final current = _currentQuestion;
    if (current == null) {
      throw StateError('No hay una pregunta activa. Llama a generateNextQuestion() primero.');
    }

    final result = EarTrainingAnswerResult.evaluate(
      selected: selected,
      target: current.targetInterval,
      centsDeviation: centsDeviation,
      responseTimeMs: responseTimeMs,
      currentStreak: _currentStreak,
    );

    _recordResult(result);
    return result;
  }

  /// Evalúa una frecuencia acústica cantada o tocada por el usuario en el micrófono.
  ///
  /// Calcula el intervalo más cercano según la frecuencia emitida
  /// y mide el error exacto en cents respecto a la nota teórica esperada.
  EarTrainingAnswerResult submitSungFrequency(
    double sungFrequencyHz, {
    int responseTimeMs = 1800,
  }) {
    final current = _currentQuestion;
    if (current == null) {
      throw StateError('No hay una pregunta activa.');
    }

    if (sungFrequencyHz <= 0) {
      return submitIntervalChoice(
        MusicalInterval.unison,
        responseTimeMs: responseTimeMs,
        centsDeviation: 999.0,
      );
    }

    // Calcular el desvío en cents entre la frecuencia cantada y la objetivo
    final centsError = MusicalInterval.calculateCentsDeviation(
      sungFrequencyHz,
      current.targetFrequencyHz,
    );

    // Si el error está dentro del semitono (±50 cents), se considera acierto
    // y se evalúa la maestría de afinación.
    final isWithinTargetTolerance = centsError.abs() <= 50.0;
    final detectedInterval = isWithinTargetTolerance
        ? current.targetInterval
        : _findClosestInterval(sungFrequencyHz, current.baseFrequencyHz, current.isAscending);

    return submitIntervalChoice(
      detectedInterval,
      responseTimeMs: responseTimeMs,
      centsDeviation: centsError,
    );
  }

  MusicalInterval _findClosestInterval(double freqHz, double baseHz, bool isAscending) {
    MusicalInterval best = MusicalInterval.unison;
    double minDiff = double.infinity;

    for (final interval in MusicalInterval.values) {
      final target = interval.calculateTargetFrequency(baseHz, ascending: isAscending);
      final diff = (target - freqHz).abs();
      if (diff < minDiff) {
        minDiff = diff;
        best = interval;
      }
    }
    return best;
  }

  void _recordResult(EarTrainingAnswerResult result) {
    _totalQuestionsAnswered++;
    _history.add(result);

    if (result.isCorrect) {
      _correctAnswersCount++;
      _currentStreak++;
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
      }
      _totalScore += result.scoreAwarded;
    } else {
      _currentStreak = 0;
    }
  }

  /// Reinicia las estadísticas de la sesión.
  void resetSession() {
    _currentQuestion = null;
    _questionCounter = 0;
    _totalQuestionsAnswered = 0;
    _correctAnswersCount = 0;
    _currentStreak = 0;
    _bestStreak = 0;
    _totalScore = 0;
    _history.clear();
  }
}
