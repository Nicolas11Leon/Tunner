import 'dart:math' as math;
import 'learner_profile_entity.dart';

/// Resultado de una evaluación pedagógica adaptativa instantánea.
class PedagogicalDiagnosticResult {
  final bool isInTune;
  final double effectiveToleranceCents;
  final String primaryFeedback;
  final String? biomechanicalCue;
  final String motivationalCue;
  final int? suggestedBpmAdjustment;
  final int scaffoldingLevel;

  const PedagogicalDiagnosticResult({
    required this.isInTune,
    required this.effectiveToleranceCents,
    required this.primaryFeedback,
    this.biomechanicalCue,
    required this.motivationalCue,
    this.suggestedBpmAdjustment,
    required this.scaffoldingLevel,
  });
}

/// Motor de andamiaje dinámico y diagnóstico adaptativo basado en psicología del aprendizaje.
/// Opera 100% en memoria en Pure Dart con cero latencia y cero dependencias de UI.
class AdaptiveScaffoldingEngine {
  const AdaptiveScaffoldingEngine();

  /// Calcula la tolerancia efectiva en cents considerando el andamiaje progresivo (scaffolding fade-out).
  double computeEffectiveTolerance({
    required LearnerProfileEntity profile,
    int consecutiveSuccesses = 0,
  }) {
    if (!profile.enableScaffoldingFadeOut) {
      return profile.centsTolerance;
    }

    // Desvanecimiento suave: por cada 3 notas afinadas consecutivas, la ventana se reduce en 2.0 cents
    // hasta un piso mínimo de 10.0 cents (evitando rigidez prematura en infantes).
    final reduction = (consecutiveSuccesses ~/ 3) * 2.0;
    final minTolerance = 10.0;
    return math.max(minTolerance, profile.centsTolerance - reduction);
  }

  /// Evalúa si una desviación en cents cumple con la tolerancia del perfil activo.
  bool isNoteInTune({
    required double centsDeviation,
    required LearnerProfileEntity profile,
    int consecutiveSuccesses = 0,
  }) {
    final tolerance = computeEffectiveTolerance(
      profile: profile,
      consecutiveSuccesses: consecutiveSuccesses,
    );
    return centsDeviation.abs() <= tolerance;
  }

  /// Genera un diagnóstico pedagógico completo adaptado al perfil cognitivo del usuario.
  PedagogicalDiagnosticResult evaluateNote({
    required double centsDeviation,
    required LearnerProfileEntity profile,
    int consecutiveSuccesses = 0,
    int consecutiveErrors = 0,
    bool isSharp = false,
  }) {
    final effectiveTolerance = computeEffectiveTolerance(
      profile: profile,
      consecutiveSuccesses: consecutiveSuccesses,
    );

    final isInTune = centsDeviation.abs() <= effectiveTolerance;
    final absDeviation = centsDeviation.abs();

    String primaryFeedback;
    String? biomechanicalCue;
    String motivationalCue;
    int? suggestedBpmAdjustment;

    switch (profile.feedbackStyle) {
      case FeedbackStyle.playfulEncouraging:
        if (isInTune) {
          primaryFeedback = 'Afinacion en el centro dorado.';
          motivationalCue = consecutiveSuccesses >= 5
              ? 'Racha brillante de notas limpias. Gran concentracion.'
              : 'Excelente sonido. Sigue explorando este tono.';
        } else {
          primaryFeedback = centsDeviation > 0
              ? 'Un poquito alto. Desciende suavemente la voz.'
              : 'Un poquito bajo. Eleva ligeramente la altura sonora.';
          motivationalCue = 'Muy cerca de la meta. Escucha el tono de referencia e intenta otra vez.';
        }
        break;

      case FeedbackStyle.constructiveBiomechanical:
        if (isInTune) {
          primaryFeedback =
              'Entonacion precisa (${centsDeviation >= 0 ? "+" : ""}${centsDeviation.toStringAsFixed(1)} cents).';
          motivationalCue =
              'Control motor y apoyo estables. La memoria muscular se esta consolidando.';
          biomechanicalCue = 'Mantener la relajacion laringea y el soporte costodiafragmatico.';
        } else {
          primaryFeedback = centsDeviation > 0
              ? 'Desvio positivo (+${absDeviation.toStringAsFixed(1)} cents): Tendencia a sobrepresion.'
              : 'Desvio negativo (-${absDeviation.toStringAsFixed(1)} cents): Caida de soporte o velocidad del flujo.';

          if (centsDeviation > 0) {
            biomechanicalCue =
                'Aliviar la tension en la raiz de la lengua y verificar la apertura faringea.';
          } else {
            biomechanicalCue =
                'Fortalecer la presion del aire subglotico y mantener la postura erguida sin tensar hombros.';
          }

          motivationalCue = consecutiveErrors >= 3
              ? 'El error indica la frontera de aprendizaje. Desaceleremos temporalmente para asimilar el pasaje.'
              : 'Ajuste natural de ensayo. Aplica la pauta biomecanica en la siguiente emision.';

          if (consecutiveErrors >= 4) {
            suggestedBpmAdjustment = -5; // Sugiere desacelerar para reducir carga cognitiva
          }
        }
        break;

      case FeedbackStyle.strictMicrotonal:
        if (isInTune) {
          primaryFeedback =
              'Precision de conservatorio (${centsDeviation >= 0 ? "+" : ""}${centsDeviation.toStringAsFixed(1)} cents | Tol: +-5c).';
          motivationalCue = 'Afinacion pura conforme a estandar orquestal.';
        } else {
          primaryFeedback = centsDeviation > 0
              ? 'Desviacion sharp (+${absDeviation.toStringAsFixed(1)} cents).'
              : 'Desviacion flat (-${absDeviation.toStringAsFixed(1)} cents).';
          motivationalCue = 'Fuera del margen de tolerancia microtonal estricto.';
        }
        break;
    }

    final scaffoldingLevel = (effectiveTolerance / 5.0).round().clamp(1, 5);

    return PedagogicalDiagnosticResult(
      isInTune: isInTune,
      effectiveToleranceCents: effectiveTolerance,
      primaryFeedback: primaryFeedback,
      biomechanicalCue: biomechanicalCue,
      motivationalCue: motivationalCue,
      suggestedBpmAdjustment: suggestedBpmAdjustment,
      scaffoldingLevel: scaffoldingLevel,
    );
  }
}
