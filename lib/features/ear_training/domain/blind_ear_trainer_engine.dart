import 'dart:math' as math;
import 'ear_training_exercise.dart';
import 'i_ear_trainer_engine.dart';
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
class BlindEarTrainerEngine implements IEarTrainerEngine {
  @override
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

    // Generar frecuencia base dentro del rango configurado (ej: 220Hz a 440Hz, o personalizado en A0=27.5Hz..C8=4186.01Hz)
    // Calculando todas las notas cromáticas 12-EDO dentro de [minBaseFrequencyHz, maxBaseFrequencyHz]
    final minHz = math.min(config.minBaseFrequencyHz, config.maxBaseFrequencyHz);
    final maxHz = math.max(config.minBaseFrequencyHz, config.maxBaseFrequencyHz);
    final candidatePitches = <({double freqHz, String label})>[];
    const englishNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const solfegeNames = ['Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'];

    for (int midi = 21; midi <= 108; midi++) {
      final rawFreq = 440.0 * math.pow(2.0, (midi - 69) / 12.0);
      final roundedFreq = (rawFreq * 100.0).roundToDouble() / 100.0;
      if (rawFreq >= minHz - 1e-6 && rawFreq <= maxHz + 1e-6) {
        final semitone = midi % 12;
        final octave = (midi ~/ 12) - 1;
        final eng = '${englishNames[semitone]}$octave';
        final sol = '${solfegeNames[semitone]} $octave';
        String suffix = '';
        if (midi == 60) suffix = ' Central';
        if (midi == 69) suffix = ' Diapasón';
        candidatePitches.add((
          freqHz: roundedFreq,
          label: '$eng ($sol$suffix)',
        ));
      }
    }

    if (candidatePitches.isEmpty) {
      // Si el rango personalizado es más estrecho que un semitono, usar la nota cromática más cercana al punto medio
      final midHz = (minHz + maxHz) / 2.0;
      final clampedMid = midHz.clamp(27.5, 4186.01);
      final midi = (69 + 12.0 * (math.log(clampedMid / 440.0) / math.ln2)).round().clamp(21, 108);
      final rawFreq = 440.0 * math.pow(2.0, (midi - 69) / 12.0);
      final roundedFreq = (rawFreq * 100.0).roundToDouble() / 100.0;
      final semitone = midi % 12;
      final octave = (midi ~/ 12) - 1;
      candidatePitches.add((
        freqHz: roundedFreq.clamp(minHz, maxHz),
        label: '${englishNames[semitone]}$octave (${solfegeNames[semitone]} $octave)',
      ));
    }

    final selectedBase = candidatePitches[_random.nextInt(candidatePitches.length)];
    final basePitch = selectedBase.freqHz;
    final noteName = selectedBase.label;

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
    bool hasAcousticCents = true,
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
      hasAcousticCents: hasAcousticCents,
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
      final wrongInterval = MusicalInterval.values.firstWhere(
        (v) => v != current.targetInterval,
      );
      return submitIntervalChoice(
        wrongInterval,
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
      final target = interval.calculateTargetFrequency(
        baseHz,
        ascending: isAscending,
        useJustIntonation: config.useJustIntonation,
      );
      final diffCents = MusicalInterval.calculateCentsDeviation(freqHz, target).abs();
      if (diffCents < minDiff) {
        minDiff = diffCents;
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
