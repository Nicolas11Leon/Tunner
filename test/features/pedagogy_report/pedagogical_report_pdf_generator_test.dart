import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_report_models.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_report_pdf_generator.dart';

void main() {
  group('PedagogicalReportModels Unit Tests', () {
    test('PedagogicalSessionData.sample creates consistent domain data', () {
      final session = PedagogicalSessionData.sample(
        accuracy: 94.0,
        avgCents: 0.8,
        stabilityDelta: 3.2,
        centroid: 910.0,
        bpm: 104.0,
        jitter: 9.8,
      );

      expect(session.tuningAccuracyPercentage, 94.0);
      expect(session.averageCentsDeviation, 0.8);
      expect(session.centsStabilityDelta, 3.2);
      expect(session.spectralCentroidHz, 910.0);
      expect(session.rhythmMeanBpm, 104.0);
      expect(session.rhythmJitterMs, 9.8);
      expect(session.masteryLevel, 'Virtuoso / Conservatorio');
      expect(session.timedPitchSamples.length, 61);
      expect(session.recommendations.isNotEmpty, true);
    });

    test('PedagogicalSessionData JSON serialization and roundtrip', () {
      final sample = PedagogicalSessionData.sample();
      final jsonMap = sample.toJson();
      final restored = PedagogicalSessionData.fromJson(jsonMap);

      expect(restored.sessionTitle, sample.sessionTitle);
      expect(restored.tuningAccuracyPercentage, sample.tuningAccuracyPercentage);
      expect(restored.averageCentsDeviation, sample.averageCentsDeviation);
      expect(restored.masteryLevel, sample.masteryLevel);
      expect(restored.timedPitchSamples.length, sample.timedPitchSamples.length);
      expect(restored.recommendations.length, sample.recommendations.length);
    });

    test('PedagogicalReportConfig copyWith and serialization', () {
      const config = PedagogicalReportConfig(
        studentName: 'Ana Maria Lopez',
        instrument: 'Violin',
        institution: 'Conservatorio Nacional',
      );

      final updated = config.copyWith(
        instrument: 'Viola',
        includeCertificate: false,
      );

      expect(updated.studentName, 'Ana Maria Lopez');
      expect(updated.instrument, 'Viola');
      expect(updated.institution, 'Conservatorio Nacional');
      expect(updated.includeCertificate, false);

      final jsonMap = updated.toJson();
      final fromJson = PedagogicalReportConfig.fromJson(jsonMap);
      expect(fromJson.studentName, updated.studentName);
      expect(fromJson.instrument, updated.instrument);
      expect(fromJson.includeCertificate, false);
    });
  });

  group('PedagogicalReportPdfGenerator ISO 32000-1 Compliance Tests', () {
    const generator = PedagogicalReportPdfGenerator();

    test('Generates valid 2-page PDF document when certificate is enabled', () {
      final session = PedagogicalSessionData.sample();
      const config = PedagogicalReportConfig(
        studentName: 'Carlos Ramirez',
        instrument: 'Flauta Traversa',
        institution: 'Academia Filarmonica',
        includeCertificate: true,
      );

      final pdfBytes = generator.generateReportPdf(
        session: session,
        config: config,
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length, greaterThan(3000));

      final rawPdf = utf8.decode(pdfBytes, allowMalformed: true);

      // Verificación de cabecera PDF 1.4
      expect(rawPdf.startsWith('%PDF-1.4'), true);

      // Verificación de estructura de catálogo y páginas
      expect(rawPdf.contains('/Type /Catalog'), true);
      expect(rawPdf.contains('/Type /Pages'), true);
      expect(rawPdf.contains('/Count 2'), true);

      // Verificación de metadatos Info
      expect(rawPdf.contains('/Title (Informe Pedagogico - Carlos Ramirez)'), true);
      expect(rawPdf.contains('/Producer (Tunner Pedagogical Report Generator ISO 32000-1)'), true);

      // Verificación de tabla xref y trailer
      expect(rawPdf.contains('xref'), true);
      expect(rawPdf.contains('trailer'), true);
      expect(rawPdf.contains('/Root 1 0 R'), true);
      expect(rawPdf.trim().endsWith('%%EOF'), true);
    });

    test('Generates single-page PDF document when certificate is disabled', () {
      final session = PedagogicalSessionData.sample();
      const config = PedagogicalReportConfig(
        studentName: 'Lucia Gomez',
        includeCertificate: false,
      );

      final pdfBytes = generator.generateReportPdf(
        session: session,
        config: config,
      );

      final rawPdf = utf8.decode(pdfBytes, allowMalformed: true);

      // Con certificado deshabilitado, el árbol debe tener exactamente 1 página
      expect(rawPdf.contains('/Count 1'), true);
      expect(rawPdf.trim().endsWith('%%EOF'), true);
    });

    test('Sanitizes accents and special characters without corrupting PDF stream', () {
      final session = PedagogicalSessionData.sample();
      const config = PedagogicalReportConfig(
        studentName: 'Andrés Peña (Violín & Flauta)',
        institution: 'Conservatorio de Música',
      );

      final pdfBytes = generator.generateReportPdf(
        session: session,
        config: config,
      );

      final rawPdf = utf8.decode(pdfBytes, allowMalformed: true);
      // Las tildes deben haber sido transliteradas de forma segura y los paréntesis escapados
      expect(rawPdf.contains('Andres Pena \\(Violin & Flauta\\)'), true);
      expect(rawPdf.contains('Conservatorio de Musica'), true);
    });
  });
}
