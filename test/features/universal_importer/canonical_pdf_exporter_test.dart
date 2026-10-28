import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/universal_importer/domain/canonical_pdf_exporter.dart';
import 'package:tunner/features/universal_importer/data/pdf_score_parser.dart';

void main() {
  group('CanonicalPdfExporter Domain Tests', () {
    const exporter = CanonicalPdfExporter();

    test('generates valid PDF header and trailer signatures', () {
      final score = HierarchicalScore(
        title: 'Estudio en Do Mayor',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: const TimeSignature(4, 4),
            notes: const [
              HierarchicalNote(startTick: 0, durationTicks: 4, noteName: 'C4'),
              HierarchicalNote(startTick: 4, durationTicks: 4, noteName: 'D4'),
              HierarchicalNote(startTick: 8, durationTicks: 4, noteName: 'E4'),
              HierarchicalNote(startTick: 12, durationTicks: 4, noteName: 'F4'),
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(
        score: score,
        title: 'Estudio en Do Mayor',
        composer: 'J.S. Bach',
      );

      expect(pdfBytes, isNotEmpty);

      final pdfString = latin1.decode(pdfBytes, allowInvalid: true);

      // Cabecera ISO 32000-1 (%PDF-1.4)
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);

      // Objetos estructurales indispensables
      expect(pdfString.contains('/Type /Catalog'), isTrue);
      expect(pdfString.contains('/Type /Pages'), isTrue);
      expect(pdfString.contains('/Type /Page'), isTrue);
      expect(pdfString.contains('stream'), isTrue);
      expect(pdfString.contains('endstream'), isTrue);
      expect(pdfString.contains('xref'), isTrue);
      expect(pdfString.contains('trailer'), isTrue);
      expect(pdfString.contains('startxref'), isTrue);

      // Cierre estándar PDF
      expect(pdfString.trimRight().endsWith('%%EOF'), isTrue);
    });

    test('renders score metadata, 5-line staves, noteheads, and rests', () {
      final score = HierarchicalScore(
        title: 'Sonata Nocturna',
        baseBpm: 90,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: const TimeSignature(4, 4),
            notes: const [
              HierarchicalNote(startTick: 0, durationTicks: 8, noteName: 'G4'), // Blanca (hollow)
              HierarchicalNote(startTick: 8, durationTicks: 4, noteName: 'C4'), // Negra con ledger line
              HierarchicalNote(startTick: 12, durationTicks: 2, noteName: 'A5'), // Corchea con ledger line y flag
              HierarchicalNote(startTick: 14, durationTicks: 2, noteName: 'REST', isRest: true), // Silencio
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: const TimeSignature(4, 4),
            notes: const [
              HierarchicalNote(startTick: 0, durationTicks: 16, noteName: 'C5'), // Redonda (whole note)
            ],
          ),
        ],
      );

      final pkg = SongPackage(
        id: 'pkg_test_pdf',
        title: 'Sonata Nocturna',
        composer: 'W.A. Mozart',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: 90,
        score: score,
        tracks: const [],
      );

      final pdfBytes = exporter.exportToPdf(pkg);
      final pdfString = latin1.decode(pdfBytes, allowInvalid: true);

      // Metadatos sanitizados
      expect(pdfString.contains('Sonata Nocturna'), isTrue);
      expect(pdfString.contains('W.A. Mozart'), isTrue);
      expect(pdfString.contains('q = 90 BPM'), isTrue);

      // Trazos de pentagrama (operador lineto 'l S')
      expect(pdfString.contains('m 45.0'), isTrue);
      expect(pdfString.contains('l S'), isTrue);

      // Cabeza de notas curvas y rectángulos acotados para OMR
      expect(pdfString.contains('c f'), isTrue);
      expect(pdfString.contains('re f'), isTrue);
    });

    test('supports multi-page pagination when score contains many measures', () {
      final measures = List.generate(
        32,
        (i) => MeasureEntity(
          index: i,
          timeSignature: const TimeSignature(4, 4),
          notes: const [
            HierarchicalNote(startTick: 0, durationTicks: 4, noteName: 'C4'),
            HierarchicalNote(startTick: 4, durationTicks: 4, noteName: 'E4'),
            HierarchicalNote(startTick: 8, durationTicks: 4, noteName: 'G4'),
            HierarchicalNote(startTick: 12, durationTicks: 4, noteName: 'C5'),
          ],
        ),
      );

      final score = HierarchicalScore(
        title: 'Sinfonía Extensa',
        baseBpm: 120,
        measures: measures,
      );

      final pdfBytes = exporter.exportScore(score: score, title: 'Sinfonía Extensa');
      final pdfString = latin1.decode(pdfBytes, allowInvalid: true);

      // Con 32 compases a 4 compases por sistema = 8 sistemas.
      // Más de 6 sistemas generan al menos 2 páginas A4 en el árbol /Pages
      expect(pdfString.contains('/Count 2'), isTrue);
      expect(pdfString.contains('Pagina 1 de 2'), isTrue);
      expect(pdfString.contains('Pagina 2 de 2'), isTrue);
    });

    test('round-trip compatibility: exported PDF is recognized and parsed by PdfScoreParser', () async {
      final score = HierarchicalScore(
        title: 'Vals de Prueba',
        baseBpm: 100,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: const TimeSignature(4, 4),
            notes: const [
              HierarchicalNote(startTick: 0, durationTicks: 4, noteName: 'E4'),
              HierarchicalNote(startTick: 4, durationTicks: 4, noteName: 'G4'),
              HierarchicalNote(startTick: 8, durationTicks: 4, noteName: 'B4'),
              HierarchicalNote(startTick: 12, durationTicks: 4, noteName: 'D5'),
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: const TimeSignature(4, 4),
            notes: const [
              HierarchicalNote(startTick: 0, durationTicks: 8, noteName: 'F4'),
              HierarchicalNote(startTick: 8, durationTicks: 8, noteName: 'A4'),
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(
        score: score,
        title: 'Vals de Prueba',
        composer: 'Chopin',
      );

      final parser = PdfScoreParser();

      // Verificar que canParse reconozca el archivo generado por su firma y extensión
      expect(parser.canParse('partitura_exportada.pdf', pdfBytes), isTrue);

      final parsedResult = await parser.parseScoreData(
        bytes: pdfBytes,
        fileName: 'partitura_exportada.pdf',
      );

      expect(parsedResult.package.title, equals('Vals de Prueba'));
      expect(parsedResult.package.score.measures, isNotEmpty);
      expect(parsedResult.totalNotes, greaterThan(0));
    });
  });
}
