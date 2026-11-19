import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/features/pedagogy/domain/pedagogical_certificate_pdf_generator.dart';
import 'package:tunner/features/pedagogy/domain/vocal_stability_evaluator.dart';

void main() {
  group('VocalEvaluationResult Entity Tests', () {
    test('Entidad inmutable calcula hash SHA-256 consistente', () {
      final now = DateTime(2026, 11, 18, 12, 0);
      final result1 = VocalEvaluationResult(
        evaluationId: 'VOCAL-001',
        timestamp: now,
        targetFrequencyHz: 440.0,
        measuredMeanFrequencyHz: 440.5,
        centsDeviation: 1.96,
        jitterPercent: 0.45,
        shimmerPercent: 1.20,
        vibratoRateHz: 5.5,
        vibratoDepthCents: 45.0,
        overallScore: 94.5,
        classificationLabel: 'Excelente / Nivel Profesional',
      );

      final result2 = VocalEvaluationResult(
        evaluationId: 'VOCAL-001',
        timestamp: now,
        targetFrequencyHz: 440.0,
        measuredMeanFrequencyHz: 440.5,
        centsDeviation: 1.96,
        jitterPercent: 0.45,
        shimmerPercent: 1.20,
        vibratoRateHz: 5.5,
        vibratoDepthCents: 45.0,
        overallScore: 94.5,
        classificationLabel: 'Excelente / Nivel Profesional',
      );

      expect(result1.payloadHashSha256, isNotEmpty);
      expect(result1.payloadHashSha256.length, equals(64)); // SHA-256 hex string
      expect(result1.payloadHashSha256, equals(result2.payloadHashSha256));
      expect(result1 == result2, isTrue);
    });
  });

  group('VocalStabilityEvaluator Acoustic Analysis Tests', () {
    const evaluator = VocalStabilityEvaluator(analysisFrameRateHz: 50.0);

    test('Tono puro sintetico sin perturbacion produce jitter 0% y shimmer 0%', () {
      final freqs = List<double>.filled(50, 440.0);
      final amps = List<double>.filled(50, 0.85);

      final eval = evaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: 440.0,
      );

      expect(eval.centsDeviation, closeTo(0.0, 1e-4));
      expect(eval.jitterPercent, equals(0.0));
      expect(eval.shimmerPercent, equals(0.0));
      expect(eval.overallScore, greaterThan(85.0));
    });

    test('Perturbacion periodica cuantificada produce calculo preciso de jitter', () {
      // Alternancia de 440 Hz y 444 Hz (~0.9% de variacion de frecuencia)
      final freqs = <double>[];
      final amps = List<double>.filled(50, 0.80);
      for (int i = 0; i < 50; i++) {
        freqs.add(i % 2 == 0 ? 440.0 : 444.0);
      }

      final eval = evaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: 440.0,
      );

      expect(eval.jitterPercent, greaterThan(0.5));
      expect(eval.jitterPercent, lessThan(1.5));
    });

    test('Perturbacion de amplitud cuantificada produce calculo preciso de shimmer', () {
      final freqs = List<double>.filled(50, 440.0);
      final amps = <double>[];
      // Alternancia de 0.80 y 0.84 (~5% de variacion)
      for (int i = 0; i < 50; i++) {
        amps.add(i % 2 == 0 ? 0.80 : 0.84);
      }

      final eval = evaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: 440.0,
      );

      expect(eval.shimmerPercent, greaterThan(3.0));
      expect(eval.shimmerPercent, lessThan(7.0));
    });

    test('Extraccion de vibrato sinusoidal a 5 Hz con profundidad de 50 cents', () {
      const double frameRate = 50.0;
      const int numFrames = 100; // 2 segundos
      final freqs = <double>[];
      final amps = List<double>.filled(numFrames, 0.85);

      for (int i = 0; i < numFrames; i++) {
        final t = i / frameRate;
        // Modulación a 5 Hz con excursión de +-50 cents: f = 440 * 2^( (50/1200) * sin(2*pi*5*t) )
        final centsMod = 50.0 * math.sin(2.0 * math.pi * 5.0 * t);
        final f = 440.0 * math.pow(2.0, centsMod / 1200.0);
        freqs.add(f.toDouble());
      }

      final eval = evaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: 440.0,
      );

      // Tasa de vibrato esperada cercana a 5 Hz
      expect(eval.vibratoRateHz, inInclusiveRange(4.0, 6.0));
      // Profundidad de vibrato esperada cercana a 50 cents
      expect(eval.vibratoDepthCents, inInclusiveRange(40.0, 60.0));
    });

    test('Filtrado automatico de fotogramas silenciosos o fuera de Nyquist', () {
      final freqs = [0.0, 10.0, 440.0, 440.0, 440.0, 440.0, 440.0, 440.0, 9999.0];
      final amps = [0.0, 0.0, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.0001];

      final eval = evaluator.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: 440.0,
      );

      expect(eval.measuredMeanFrequencyHz, closeTo(440.0, 0.1));
    });
  });

  group('PedagogicalCertificatePdfGenerator Vector Binary Tests', () {
    test('Genera un archivo binario PDF-1.4 valido conforme a ISO 32000-1', () {
      final now = DateTime(2026, 11, 18, 14, 30);
      final eval = VocalEvaluationResult(
        evaluationId: 'VOCAL-TEST-007',
        timestamp: now,
        targetFrequencyHz: 440.0,
        measuredMeanFrequencyHz: 441.2,
        centsDeviation: 4.7,
        jitterPercent: 0.52,
        shimmerPercent: 1.85,
        vibratoRateHz: 5.6,
        vibratoDepthCents: 48.0,
        overallScore: 92.8,
        classificationLabel: 'Excelente / Nivel Profesional',
      );

      final pdfBytes = PedagogicalCertificatePdfGenerator.generateCertificatePdf(
        studentName: 'Cecilia Bartoli',
        evaluation: eval,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));

      final pdfString = latin1.decode(pdfBytes);

      // 1. Cabecera estándar PDF-1.4
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);

      // 2. Estructura de objetos indirectos
      expect(pdfString, contains('/Type /Catalog'));
      expect(pdfString, contains('/Type /Pages'));
      expect(pdfString, contains('/Type /Page'));
      expect(pdfString, contains('/MediaBox [0 0 595.28 841.89]')); // A4
      expect(pdfString, contains('/Type /Font'));

      // 3. Contenido vectorial del certificado
      expect(pdfString, contains('CONSERVATORIO DE AUDIO Y MUSICA TUNNER'));
      expect(pdfString, contains('Cecilia Bartoli'));
      expect(pdfString, contains('VOCAL-TEST-007'));
      expect(pdfString, contains('CALIFICACION GLOBAL: 92.8 / 100'));
      expect(pdfString, contains(eval.payloadHashSha256));

      // 4. Estructura final xref y trailer
      expect(pdfString, contains('xref\n0 7'));
      expect(pdfString, contains('trailer\n<< /Size 7 /Root 1 0 R >>'));
      expect(pdfString, contains('startxref'));
      expect(pdfString.trimRight().endsWith('%%EOF'), isTrue);
    });
  });

  group('TunnerOsKernel CLI Vocal Commands Tests', () {
    late TunnerOsKernel kernel;

    setUp(() {
      kernel = TunnerOsKernel();
    });

    test('Comando vocal eval genera reporte completo de estabilidad', () async {
      final res = await kernel.execute('vocal eval 440');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[INFORME DE EVALUACION VOCAL Y ESTABILIDAD ACUSTICA]'));
      expect(res.message, contains('Frecuencia Target: 440.0 Hz'));
      expect(res.message, contains('Jitter Relativo:'));
      expect(res.message, contains('Shimmer de Amplitud:'));
      expect(res.message, contains('Sello SHA-256:'));
    });

    test('Comando vocal cert genera y certifica documento PDF', () async {
      final res = await kernel.execute('vocal cert "Luciano Pavarotti" 440');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[CERTIFICADO OFICIAL DE CONSERVATORIO GENERADO EXITOSAMENTE]'));
      expect(res.message, contains('Formato: Binario Vectorial PDF-1.4 (ISO 32000-1)'));
      expect(res.message, contains('Candidato: Luciano Pavarotti'));
      expect(res.message, contains('Sello Digital SHA-256 (Inmutable):'));
    });
  });
}
