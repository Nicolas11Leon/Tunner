import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/app/terminal_feature_adapters.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';

void main() {
  group('EarTrainingItemEntity Tests', () {
    test('Valores por defecto y aserciones de invariantes matematicos', () {
      final now = DateTime.now();
      final item = EarTrainingItemEntity(
        id: 'test_p5',
        name: 'Quinta Justa',
        category: EarTrainingCategory.interval,
        semitones: 7.0,
        centsDeviation: 700.0,
        nextReviewDate: now,
      );

      expect(item.stabilityDays, equals(1.0));
      expect(item.easeFactor, equals(2.50));
      expect(item.repetitions, equals(0));
      expect(item.lapses, equals(0));
      expect(item.totalAttempts, equals(0));
      expect(item.averageCentsError, equals(0.0));
      expect(item.lastReviewDate, isNull);

      // Aserciones de validacion
      expect(
        () => EarTrainingItemEntity(
          id: 'invalid',
          name: 'Inv',
          category: EarTrainingCategory.interval,
          semitones: 1.0,
          centsDeviation: 100.0,
          stabilityDays: 0.0,
          nextReviewDate: now,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => EarTrainingItemEntity(
          id: 'invalid',
          name: 'Inv',
          category: EarTrainingCategory.interval,
          semitones: 1.0,
          centsDeviation: 100.0,
          easeFactor: 1.29,
          nextReviewDate: now,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Curva de Ebbinghaus R(t) = exp(-t / S) calcula el decaimiento exacto', () {
      final reviewDate = DateTime(2026, 11, 1, 12, 0);
      final item = EarTrainingItemEntity(
        id: 'test_p4',
        name: 'Cuarta Justa',
        category: EarTrainingCategory.interval,
        semitones: 5.0,
        centsDeviation: 500.0,
        stabilityDays: 2.0, // S = 2 dias
        lastReviewDate: reviewDate,
        nextReviewDate: reviewDate.add(const Duration(days: 2)),
      );

      // En el momento exacto del repaso (t = 0), retencion = 1.0 (100%)
      expect(item.retentionAt(reviewDate), closeTo(1.0, 1e-6));

      // Pasados 2 dias (t = S), R(2) = e^(-2 / 2) = e^(-1) ~= 0.367879
      final twoDaysLater = reviewDate.add(const Duration(days: 2));
      expect(item.retentionAt(twoDaysLater), closeTo(0.367879, 1e-4));

      // Pasado 1 dia (t = S / 2), R(1) = e^(-0.5) ~= 0.60653
      final oneDayLater = reviewDate.add(const Duration(days: 1));
      expect(item.retentionAt(oneDayLater), closeTo(0.60653, 1e-4));

      // Si nunca fue revisado, retencion es forzada a 0.10
      final virginItem = EarTrainingItemEntity(
        id: 'test_p4_virgin',
        name: 'Cuarta Justa',
        category: EarTrainingCategory.interval,
        semitones: 5.0,
        centsDeviation: 500.0,
        nextReviewDate: reviewDate,
      );
      expect(virginItem.retentionAt(reviewDate), equals(0.10));
    });

    test('isDue determina correctamente cuando un item requiere repaso', () {
      final reviewDate = DateTime(2026, 11, 1, 12, 0);
      final item = EarTrainingItemEntity(
        id: 'test_m3',
        name: 'Tercera Menor',
        category: EarTrainingCategory.interval,
        semitones: 3.0,
        centsDeviation: 300.0,
        stabilityDays: 10.0,
        lastReviewDate: reviewDate,
        nextReviewDate: reviewDate.add(const Duration(days: 10)),
      );

      // Inmediatamente despues del repaso no esta pendiente (R = 1.0 > 0.90)
      expect(item.isDue(reviewDate.add(const Duration(minutes: 30))), isFalse);

      // Pasados 5 dias, la retencion decae: e^(-5 / 10) = e^(-0.5) ~= 0.606 < 0.90 -> isDue = true
      expect(item.isDue(reviewDate.add(const Duration(days: 5))), isTrue);

      // Item sin revision previa siempre esta pendiente
      final virgin = EarTrainingItemEntity(
        id: 'test_m3_virgin',
        name: 'Tercera Menor',
        category: EarTrainingCategory.interval,
        semitones: 3.0,
        centsDeviation: 300.0,
        nextReviewDate: reviewDate,
      );
      expect(virgin.isDue(reviewDate), isTrue);
    });
  });

  group('EbbinghausSpacedRepetitionEngine Logic Tests', () {
    late EbbinghausSpacedRepetitionEngine engine;

    setUp(() {
      engine = EbbinghausSpacedRepetitionEngine();
    });

    test('Catalogo canonico contiene intervalos, microtonos y acordes fundamentales', () {
      final items = engine.allItems;
      expect(items, isNotEmpty);
      expect(items.any((i) => i.id == 'interval_m2'), isTrue);
      expect(items.any((i) => i.id == 'interval_P5'), isTrue);
      expect(items.any((i) => i.id == 'microtone_quarter_tone'), isTrue);
      expect(items.any((i) => i.id == 'chord_triad_major'), isTrue);
    });

    test('calculateQualityGrade clasifica con rigor acustico en microcents y tiempo', () {
      // 1. Perfecto: correcto, <= 5 cents, <= 2.0s -> 5
      expect(
        engine.calculateQualityGrade(isCorrect: true, centsError: 2.0, responseTimeSeconds: 1.2),
        equals(5),
      );

      // 2. Notable: correcto, <= 15 cents, <= 4.0s -> 4
      expect(
        engine.calculateQualityGrade(isCorrect: true, centsError: 12.0, responseTimeSeconds: 3.5),
        equals(4),
      );

      // 3. Aceptable con vacilacion: correcto, > 15 cents o > 4.0s -> 3
      expect(
        engine.calculateQualityGrade(isCorrect: true, centsError: 25.0, responseTimeSeconds: 5.0),
        equals(3),
      );

      // 4. Incorrecto pero cercano (semitono / 100 cents) -> 2
      expect(
        engine.calculateQualityGrade(isCorrect: false, centsError: 90.0, responseTimeSeconds: 3.0),
        equals(2),
      );

      // 5. Incorrecto moderado (200 cents) -> 1
      expect(
        engine.calculateQualityGrade(isCorrect: false, centsError: 180.0, responseTimeSeconds: 4.0),
        equals(1),
      );

      // 6. Confunsion total (> 200 cents) -> 0
      expect(
        engine.calculateQualityGrade(isCorrect: false, centsError: 450.0, responseTimeSeconds: 6.0),
        equals(0),
      );
    });

    test('Secuencia de aciertos consecutivos incrementa estabilidad exponencialmente', () {
      final baseDate = DateTime(2026, 11, 10, 10, 0);

      // Repaso 1: Perfecto (q = 5)
      final r1 = engine.submitAnswer(
        'interval_P5',
        isCorrect: true,
        centsError: 1.5,
        responseTimeSeconds: 1.0,
        timestamp: baseDate,
      );
      expect(r1.qualityGrade, equals(5));
      expect(r1.updatedItem.repetitions, equals(1));
      expect(r1.updatedItem.stabilityDays, equals(1.0));
      expect(r1.updatedItem.easeFactor, greaterThan(2.50));

      // Repaso 2: Perfecto
      final r2 = engine.submitAnswer(
        'interval_P5',
        isCorrect: true,
        centsError: 2.0,
        responseTimeSeconds: 1.2,
        timestamp: baseDate.add(const Duration(days: 1)),
      );
      expect(r2.updatedItem.repetitions, equals(2));
      expect(r2.updatedItem.stabilityDays, equals(3.0));

      // Repaso 3: Perfecto -> estabilidad = 3.0 * EF
      final r3 = engine.submitAnswer(
        'interval_P5',
        isCorrect: true,
        centsError: 1.0,
        responseTimeSeconds: 0.9,
        timestamp: baseDate.add(const Duration(days: 4)),
      );
      expect(r3.updatedItem.repetitions, equals(3));
      expect(r3.updatedItem.stabilityDays, greaterThan(7.0));
    });

    test('Fallo penaliza estabilidad y resetea repeticiones consecutivas', () {
      final baseDate = DateTime(2026, 11, 10, 10, 0);

      // Primero consolidamos 2 aciertos
      engine.submitAnswer('interval_m2', isCorrect: true, centsError: 2.0, responseTimeSeconds: 1.0, timestamp: baseDate);
      engine.submitAnswer('interval_m2', isCorrect: true, centsError: 2.0, responseTimeSeconds: 1.0, timestamp: baseDate.add(const Duration(days: 1)));

      final beforeFail = engine.getItem('interval_m2')!;
      expect(beforeFail.repetitions, equals(2));
      expect(beforeFail.stabilityDays, equals(3.0));

      // Simulamos fallo rotundo
      final failResult = engine.submitAnswer(
        'interval_m2',
        isCorrect: false,
        centsError: 150.0,
        responseTimeSeconds: 4.5,
        timestamp: baseDate.add(const Duration(days: 2)),
      );

      expect(failResult.qualityGrade, lessThan(3));
      expect(failResult.updatedItem.repetitions, equals(0));
      expect(failResult.updatedItem.lapses, equals(1));
      expect(failResult.updatedItem.stabilityDays, lessThan(beforeFail.stabilityDays));
    });

    test('getDueItems prioriza los ejercicios con menor retencion cognitiva', () {
      final now = DateTime.now();
      final due = engine.getDueItems(now: now);
      expect(due, isNotEmpty);

      // Verificar orden ascendente de retencion
      for (int i = 0; i < due.length - 1; i++) {
        expect(due[i].retentionAt(now), lessThanOrEqualTo(due[i + 1].retentionAt(now)));
      }
    });

    test('overallRetentionAverage y reset', () {
      final now = DateTime.now();
      final initialAvg = engine.overallRetentionAverage(now);
      expect(initialAvg, greaterThan(0.0));

      engine.submitAnswer('interval_P8', isCorrect: true, centsError: 0.5, responseTimeSeconds: 1.0, timestamp: now);
      expect(engine.getItem('interval_P8')!.repetitions, equals(1));

      engine.reset();
      expect(engine.getItem('interval_P8')!.repetitions, equals(0));
    });
  });

  group('TunnerOsKernel CLI Train Commands Tests', () {
    late TunnerOsKernel kernel;

    setUp(() {
      kernel = TunnerOsKernel(
        earTrainingEngine: EbbinghausTerminalAdapter(),
      );
    });

    test('train status muestra el resumen pedagogico', () async {
      final res = await kernel.execute('train status');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[ESTADO DE ENTRENAMIENTO AUDITIVO'));
      expect(res.message, contains('Total de Ejercicios en Catalogo:'));
      expect(res.message, contains('Retencion Cognitiva Promedio:'));
    });

    test('train review lista los ejercicios pendientes de repaso', () async {
      final res = await kernel.execute('train review');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('EJERCICIOS PENDIENTES DE REPASO:'));
    });

    test('train list muestra todo el inventario de intervalos', () async {
      final res = await kernel.execute('train list');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('CATALOGO DE ENTRENAMIENTO AUDITIVO:'));
      expect(res.message, contains('interval_P5'));
    });

    test('train answer califica y actualiza la curva de memoria', () async {
      final res = await kernel.execute('train answer interval_P5 2.5 1.4 1');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[EVALUACION PEDAGOGICA EBBINGHAUS]'));
      expect(res.message, contains('Calificacion de Calidad: 5/5'));
      expect(res.message, contains('Nueva Estabilidad: 1.00 dias'));

      // Verificar que el item cambio en el motor
      final p5 = kernel.earTrainingEngine!.getItem('interval_P5', DateTime.now())!;
      expect(p5.repetitions, equals(1));
    });

    test('train reset reinicia el catalogo', () async {
      await kernel.execute('train answer interval_P5 2.5 1.4 1');
      final res = await kernel.execute('train reset');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[OK] Catalogo de entrenamiento auditivo reiniciado'));
      expect(kernel.earTrainingEngine!.getItem('interval_P5', DateTime.now())!.repetitions, equals(0));
    });
  });
}
