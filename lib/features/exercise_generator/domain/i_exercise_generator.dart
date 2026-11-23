import '../../song_library/domain/song_package_entity.dart';
import 'algorithmic_exercise_generator.dart';

/// Contrato de dominio puro para generadores algorítmicos de ejercicios
/// técnicos, escalas, arpegios y estudios de afinación.
abstract class IExerciseGenerator {
  SongPackage generate({
    required String rootNote,
    required ExerciseType type,
    ExerciseRhythm rhythm = ExerciseRhythm.quarter,
    int bpm = 80,
  });
}
