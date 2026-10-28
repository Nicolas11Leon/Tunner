import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/pedagogy_profiles/domain/learner_profile_entity.dart';
import 'package:tunner/features/pedagogy_profiles/domain/adaptive_scaffolding_engine.dart';

void main() {
  group('LearnerProfileEntity Domain Tests', () {
    test('Factory presets define accurate pedagogical attributes', () {
      final child = LearnerProfileEntity.child();
      expect(child.type, LearnerProfileType.childPlayful);
      expect(child.centsTolerance, 25.0);
      expect(child.feedbackStyle, FeedbackStyle.playfulEncouraging);
      expect(child.visualDensity, VisualDensityLevel.minimalPlayful);
      expect(child.enableSmartWait, true);
      expect(child.enableScaffoldingFadeOut, true);

      final adult = LearnerProfileEntity.adult();
      expect(adult.type, LearnerProfileType.adultDeliberate);
      expect(adult.centsTolerance, 10.0);
      expect(adult.feedbackStyle, FeedbackStyle.constructiveBiomechanical);
      expect(adult.visualDensity, VisualDensityLevel.focusedAndragogic);

      final pro = LearnerProfileEntity.conservatory();
      expect(pro.type, LearnerProfileType.conservatoryMastery);
      expect(pro.centsTolerance, 5.0);
      expect(pro.feedbackStyle, FeedbackStyle.strictMicrotonal);
      expect(pro.visualDensity, VisualDensityLevel.fullObservatory);
    });

    test('LearnerProfileEntity JSON serialization roundtrip', () {
      final original = LearnerProfileEntity.adult().copyWith(
        title: 'Mi Perfil Andragogico',
        centsTolerance: 8.5,
      );

      final jsonMap = original.toJson();
      final restored = LearnerProfileEntity.fromJson(jsonMap);

      expect(restored.type, original.type);
      expect(restored.title, 'Mi Perfil Andragogico');
      expect(restored.centsTolerance, 8.5);
      expect(restored.feedbackStyle, original.feedbackStyle);
      expect(restored.visualDensity, original.visualDensity);
    });
  });

  group('AdaptiveScaffoldingEngine Domain Tests', () {
    const engine = AdaptiveScaffoldingEngine();

    test('Scaffolding fade-out reduces child tolerance as successes accumulate', () {
      final childProfile = LearnerProfileEntity.child();

      // Al inicio (0 aciertos): tolerancia completa de 25c
      expect(engine.computeEffectiveTolerance(profile: childProfile, consecutiveSuccesses: 0), 25.0);

      // Tras 3 aciertos: 23c
      expect(engine.computeEffectiveTolerance(profile: childProfile, consecutiveSuccesses: 3), 23.0);

      // Tras 9 aciertos: 19c
      expect(engine.computeEffectiveTolerance(profile: childProfile, consecutiveSuccesses: 9), 19.0);

      // Tras muchos aciertos, nunca cae por debajo del piso de 10c
      expect(engine.computeEffectiveTolerance(profile: childProfile, consecutiveSuccesses: 60), 10.0);
    });

    test('Adult and conservatory profiles maintain stable configured tolerance', () {
      final adultProfile = LearnerProfileEntity.adult();
      expect(engine.computeEffectiveTolerance(profile: adultProfile, consecutiveSuccesses: 20), 10.0);

      final proProfile = LearnerProfileEntity.conservatory();
      expect(engine.computeEffectiveTolerance(profile: proProfile, consecutiveSuccesses: 20), 5.0);
    });

    test('isNoteInTune reflects cognitive profile tolerance', () {
      final child = LearnerProfileEntity.child();
      final adult = LearnerProfileEntity.adult();
      final pro = LearnerProfileEntity.conservatory();

      const deviation = 18.0; // Desvío moderado de 18 cents

      // 18 cents es válido para un infante (tol = 25c), pero desafinado para adulto (10c) y pro (5c)
      expect(engine.isNoteInTune(centsDeviation: deviation, profile: child), isTrue);
      expect(engine.isNoteInTune(centsDeviation: deviation, profile: adult), isFalse);
      expect(engine.isNoteInTune(centsDeviation: deviation, profile: pro), isFalse);
    });

    test('evaluateNote generates biomechanical cues for adult errors and suggests BPM adjustment', () {
      final adult = LearnerProfileEntity.adult();

      final result = engine.evaluateNote(
        centsDeviation: -14.0, // Caída de entonación
        profile: adult,
        consecutiveErrors: 4,
      );

      expect(result.isInTune, isFalse);
      expect(result.biomechanicalCue, isNotNull);
      expect(result.biomechanicalCue!.contains('aire'), isTrue);
      expect(result.suggestedBpmAdjustment, equals(-5)); // Sugiere reducir tempo
    });

    test('evaluateNote delivers encouraging non-punitive feedback for children', () {
      final child = LearnerProfileEntity.child();

      final resultInTune = engine.evaluateNote(
        centsDeviation: 4.0,
        profile: child,
        consecutiveSuccesses: 6,
      );

      expect(resultInTune.isInTune, isTrue);
      expect(resultInTune.motivationalCue.contains('Racha brillante'), isTrue);

      final resultError = engine.evaluateNote(
        centsDeviation: 28.0,
        profile: child,
      );

      expect(resultError.isInTune, isFalse);
      expect(resultError.primaryFeedback.contains('Un poquito alto'), isTrue);
      expect(resultError.motivationalCue.contains('Muy cerca'), isTrue);
    });
  });
}
