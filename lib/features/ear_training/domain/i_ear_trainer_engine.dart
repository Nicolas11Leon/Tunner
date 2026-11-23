import 'blind_ear_trainer_engine.dart';
import 'ear_training_exercise.dart';
import 'musical_interval.dart';

/// Contrato de dominio puro para motores de entrenamiento auditivo
/// y discriminación de intervalos a ciegas.
abstract class IEarTrainerEngine {
  EarTrainingConfig get config;
  set config(EarTrainingConfig value);

  EarTrainingQuestion? get currentQuestion;
  int get totalQuestionsAnswered;
  int get correctAnswersCount;
  int get currentStreak;
  int get bestStreak;
  int get totalScore;
  List<EarTrainingAnswerResult> get history;

  double get accuracyPercentage;
  double get averageCentsDeviation;
  double get averageResponseTimeMs;

  EarTrainingQuestion generateNextQuestion();

  EarTrainingAnswerResult submitIntervalChoice(
    MusicalInterval selected, {
    int responseTimeMs = 1200,
    double centsDeviation = 0.0,
    bool hasAcousticCents = true,
  });

  EarTrainingAnswerResult submitSungFrequency(
    double sungFrequencyHz, {
    int responseTimeMs = 1800,
  });

  void resetSession();
}
