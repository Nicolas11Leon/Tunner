import 'adaptive_scaffolding_engine.dart';
import 'learner_profile_entity.dart';

/// Contrato de dominio puro para el motor de andamiaje adaptativo y
/// diagnóstico pedagógico instantáneo.
abstract class IAdaptiveScaffoldingEngine {
  double computeEffectiveTolerance({
    required LearnerProfileEntity profile,
    int consecutiveSuccesses = 0,
  });

  bool isNoteInTune({
    required double centsDeviation,
    required LearnerProfileEntity profile,
    int consecutiveSuccesses = 0,
  });

  PedagogicalDiagnosticResult evaluateNote({
    required double centsDeviation,
    required LearnerProfileEntity profile,
    int consecutiveSuccesses = 0,
    int consecutiveErrors = 0,
    bool isSharp = false,
  });
}
