import 'dart:math' as math;
import 'guided_lesson_entity.dart';

/// Motor de evaluación acústica en Pure Dart para lecciones guiadas interactivas.
/// Valida en tiempo real si el instrumentista emite la nota objetivo, mide la desviación
/// en cents y acumula el tiempo de sostenimiento continuo hasta completar cada paso.
class GuidedLessonEvaluator {
  GuidedLessonProgressEntity? _progress;

  GuidedLessonEvaluator();

  GuidedLessonProgressEntity? get activeProgress => _progress;
  bool get hasActiveLesson => _progress != null && !_progress!.isLessonComplete;

  /// Inicia una nueva sesión de práctica guiada para la lección especificada.
  GuidedLessonProgressEntity startLesson(
    GuidedLessonEntity lesson, {
    double? customToleranceCents,
  }) {
    // Si se proporciona una tolerancia adaptativa (del perfil pedagógico), ajustarla a los pasos
    final List<GuidedLessonStepEntity> adaptedSteps;
    if (customToleranceCents != null && customToleranceCents > 0) {
      adaptedSteps = lesson.steps.map((s) {
        return s.copyWith(toleranceCents: customToleranceCents);
      }).toList();
    } else {
      adaptedSteps = lesson.steps;
    }

    final adaptedLesson = GuidedLessonEntity(
      id: lesson.id,
      title: lesson.title,
      description: lesson.description,
      category: lesson.category,
      difficulty: lesson.difficulty,
      steps: adaptedSteps,
    );

    _progress = GuidedLessonProgressEntity(
      lesson: adaptedLesson,
      currentStepIndex: 0,
      sustainedSeconds: 0.0,
      isStepComplete: false,
      isLessonComplete: false,
    );

    return _progress!;
  }

  /// Cancela o finaliza la sesión activa.
  void cancelLesson() {
    _progress = null;
  }

  /// Evalúa una muestra de afinación en tiempo real y actualiza el progreso.
  GuidedLessonProgressEntity? evaluateSample({
    required double frequencyHz,
    required double cents,
    required String detectedNoteName,
    required double deltaSeconds,
  }) {
    if (_progress == null || _progress!.isLessonComplete) {
      return _progress;
    }

    final step = _progress!.currentStep;
    final effectiveTolerance = step.toleranceCents;

    // Verificar si hay silencio o sonido no tonal
    if (frequencyHz <= 20.0 || detectedNoteName.isEmpty || detectedNoteName == '--') {
      return _progress;
    }

    // Verificar correspondencia de nota musical
    final bool noteMatches = _matchesTargetNote(
      detectedNote: detectedNoteName,
      targetNote: step.targetNoteName,
      detectedFreq: frequencyHz,
      targetFreq: step.targetFrequencyHz,
    );

    final bool inTune = cents.abs() <= effectiveTolerance;

    if (noteMatches && inTune) {
      // Acumular tiempo de sostenimiento exitoso
      final double newSustained = _progress!.sustainedSeconds + deltaSeconds;

      if (newSustained >= step.targetDurationSeconds) {
        // Paso completado con éxito
        final bool isLast = _progress!.currentStepIndex + 1 >= _progress!.lesson.totalSteps;

        if (isLast) {
          _progress = _progress!.copyWith(
            sustainedSeconds: step.targetDurationSeconds,
            isStepComplete: true,
            isLessonComplete: true,
            successfulNotesCount: _progress!.successfulNotesCount + 1,
          );
        } else {
          _progress = _progress!.copyWith(
            currentStepIndex: _progress!.currentStepIndex + 1,
            sustainedSeconds: 0.0,
            isStepComplete: true,
            successfulNotesCount: _progress!.successfulNotesCount + 1,
          );
        }
      } else {
        _progress = _progress!.copyWith(
          sustainedSeconds: newSustained,
          isStepComplete: false,
        );
      }
    } else {
      // Si la nota desafina o es incorrecta, penalización suave (retroceso pausado)
      if (_progress!.sustainedSeconds > 0) {
        final decayed = math.max(0.0, _progress!.sustainedSeconds - (deltaSeconds * 0.4));
        _progress = _progress!.copyWith(
          sustainedSeconds: decayed,
          isStepComplete: false,
        );
      }
    }

    return _progress;
  }

  /// Permite navegar manualmente a un paso específico de la lección.
  GuidedLessonProgressEntity? jumpToStep(int stepIndex) {
    if (_progress == null) return null;
    if (stepIndex < 0 || stepIndex >= _progress!.lesson.totalSteps) return _progress;

    _progress = _progress!.copyWith(
      currentStepIndex: stepIndex,
      sustainedSeconds: 0.0,
      isStepComplete: false,
      isLessonComplete: false,
    );
    return _progress;
  }

  /// Compara nombres de nota considerando equivalencias Solfege / Cifrado (ej. Sol4 == G4).
  static bool _matchesTargetNote({
    required String detectedNote,
    required String targetNote,
    required double detectedFreq,
    required double targetFreq,
  }) {
    final cleanDetected = detectedNote.replaceAll(' ', '').toUpperCase();
    final cleanTarget = targetNote.replaceAll(' ', '').toUpperCase();

    if (cleanDetected == cleanTarget) return true;

    // Equivalencia de notas en español e internacional
    final Map<String, String> equivalences = {
      'DO': 'C',
      'RE': 'D',
      'MI': 'E',
      'FA': 'F',
      'SOL': 'G',
      'LA': 'A',
      'SI': 'B',
    };

    String mappedTarget = cleanTarget;
    for (final entry in equivalences.entries) {
      if (mappedTarget.startsWith(entry.key)) {
        mappedTarget = mappedTarget.replaceFirst(entry.key, entry.value);
        break;
      }
    }

    String mappedDetected = cleanDetected;
    for (final entry in equivalences.entries) {
      if (mappedDetected.startsWith(entry.key)) {
        mappedDetected = mappedDetected.replaceFirst(entry.key, entry.value);
        break;
      }
    }

    if (mappedDetected == mappedTarget) return true;

    // Validación acústica por ratio de frecuencias si el nombre difiere por micro-afinación
    if (targetFreq > 20.0 && detectedFreq > 20.0) {
      final ratio = detectedFreq / targetFreq;
      final centsDiff = (1200.0 * (math.log(ratio) / math.ln2)).abs();
      return centsDiff <= 50.0; // Mismo semitono
    }

    return false;
  }
}
