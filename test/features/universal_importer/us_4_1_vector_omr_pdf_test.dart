import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/data/pdf_score_parser.dart';
import 'package:tunner/features/universal_importer/domain/canonical_pdf_exporter.dart';
import 'package:tunner/features/universal_importer/domain/vector_omr_engine.dart';

void main() {
  group('US-4.1 Vector OMR PDF Hardening Tests', () {
    const exporter = CanonicalPdfExporter();
    const parser = PdfScoreParser();
    const engine = VectorOmrEngine();

    Uint8List buildSyntheticPdf(String streamContent, {String title = 'Test PDF'}) {
      final streamBytes = utf8.encode(streamContent);
      final pdfText = '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 500] /Contents 4 0 R >>
endobj
4 0 obj
<< /Length ${streamBytes.length} >>
stream
$streamContent
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000202 00000 n 
trailer
<< /Size 5 /Root 1 0 R /Info << /Title ($title) >> >>
startxref
400
%%EOF''';
      return Uint8List.fromList(utf8.encode(pdfText));
    }

    test('CanonicalPdfExporter omits artificial 7.0 6.0 re f markers on noteheads', () {
      final score = HierarchicalScore(
        title: 'Pure Bezier Noteheads',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Sol4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'La4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 2, noteName: 'Si4'),
              HierarchicalNote.note(startTick: 14, durationTicks: 1, noteName: 'Do5'),
              HierarchicalNote.note(startTick: 15, durationTicks: 1, noteName: 'Re5'),
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(score: score, title: score.title);
      final pdfStr = latin1.decode(pdfBytes, allowInvalid: true);

      expect(pdfStr, contains('c s'));
      expect(pdfStr, contains('c f'));
      expect(pdfStr.contains('7.0 6.0 re f'), isFalse);
      expect(pdfStr.contains('re f'), isFalse);
    });

    test('Round-trip export and import preserves whole, half, quarter, eighth and sixteenth notes', () async {
      final originalScore = HierarchicalScore(
        title: 'Round Trip Ritmico',
        baseBpm: 110,
        measures: [
          // Compas 0: Redonda hueca sin plica (16 ticks)
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 16, noteName: 'Do5'),
            ],
          ),
          // Compas 1: 2 Blancas huecas con plica (8 + 8 ticks)
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'Sol4'),
            ],
          ),
          // Compas 2: 4 Negras rellenas con plica (4 * 4 ticks)
          MeasureEntity(
            index: 2,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Fa4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'La4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Si4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'Re5'),
            ],
          ),
          // Compas 3: Corcheas (2 ticks) y Semicorcheas (1 tick)
          MeasureEntity(
            index: 3,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 2, noteName: 'Do5'),
              HierarchicalNote.note(startTick: 2, durationTicks: 2, noteName: 'Si4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 1, noteName: 'La4'),
              HierarchicalNote.note(startTick: 5, durationTicks: 1, noteName: 'Sol4'),
              HierarchicalNote.note(startTick: 6, durationTicks: 1, noteName: 'Fa4'),
              HierarchicalNote.note(startTick: 7, durationTicks: 1, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'Re4'),
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(score: originalScore, title: originalScore.title);
      final parsed = await parser.parseScoreData(
        bytes: pdfBytes,
        fileName: 'roundtrip_ritmo.pdf',
      );

      expect(parsed.package.score.measures.length, equals(4));

      final m0 = parsed.package.score.measures[0].notes.where((n) => !n.isRest).toList();
      expect(m0.length, equals(1));
      expect(m0[0].noteName, equals('Do5'));
      expect(m0[0].durationTicks, equals(16));

      final m1 = parsed.package.score.measures[1].notes.where((n) => !n.isRest).toList();
      expect(m1.length, equals(2));
      expect(m1.map((n) => n.noteName).toList(), equals(['Mi4', 'Sol4']));
      expect(m1.map((n) => n.durationTicks).toList(), equals([8, 8]));

      final m2 = parsed.package.score.measures[2].notes.where((n) => !n.isRest).toList();
      expect(m2.length, equals(4));
      expect(m2.map((n) => n.noteName).toList(), equals(['Fa4', 'La4', 'Si4', 'Re5']));
      expect(m2.map((n) => n.durationTicks).toList(), equals([4, 4, 4, 4]));

      final m3 = parsed.package.score.measures[3].notes.where((n) => !n.isRest).toList();
      expect(m3.length, equals(7));
      expect(
        m3.map((n) => n.noteName).toList(),
        equals(['Do5', 'Si4', 'La4', 'Sol4', 'Fa4', 'Mi4', 'Re4']),
      );
      expect(
        m3.map((n) => n.durationTicks).toList(),
        equals([2, 2, 1, 1, 1, 1, 8]),
      );
    });

    test('Round-trip supports diatonic pitches beyond the legacy 13-note range (La3..Mi6)', () async {
      final originalScore = HierarchicalScore(
        title: 'Rango Diatonico Extendido',
        baseBpm: 100,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'La3'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Si3'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Si5'),
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'Do6'),
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Mi6'),
              HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'Sol3'),
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(score: originalScore, title: originalScore.title);
      final parsed = await parser.parseScoreData(
        bytes: pdfBytes,
        fileName: 'rango_extendido.pdf',
      );

      final m0Notes = parsed.package.score.measures[0].notes.where((n) => !n.isRest).toList();
      expect(m0Notes.map((n) => n.noteName).toList(), equals(['La3', 'Si3', 'Si5', 'Do6']));

      final m1Notes = parsed.package.score.measures[1].notes.where((n) => !n.isRest).toList();
      expect(m1Notes.map((n) => n.noteName).toList(), equals(['Mi6', 'Sol3']));
      expect(m1Notes.map((n) => n.durationTicks).toList(), equals([8, 8]));
    });

    test('PdfScoreParser tracks CTM stack (q/Q/cm), Bezier subpaths (h, S/s vs f/F/B) and ignores open arcs', () async {
      // Transformacion: flip Y y traslacion -> y_page = -y_local + 400
      // Lineas locales en y = 260, 250, 240, 230, 220 -> y_page = 140, 150, 160, 170, 180 (espaciado 10 pt)
      // Nota 1 (y_local = 260 -> y_page = 140 = Mi4): ovalo hueco cerrado con h S + plica -> 8 ticks
      // Nota 2 (y_local = 240 -> y_page = 160 = Si4): ovalo relleno con h B + plica -> 4 ticks
      // Nota 3 (y_local = 250 -> y_page = 150 = Sol4): ovalo relleno con F + plica + corchete -> 2 ticks
      // Ligadura abierta (S sin h) y rectangulo de clipping (W n) deben ser ignorados.
      const stream = '''
0 0 600 500 re W n
q
1 0 0 -1 0 400 cm
50 260 m 450 260 l S
50 250 m 450 250 l S
50 240 m 450 240 l S
50 230 m 450 230 l S
50 220 m 450 220 l S
450 220 m 450 260 l S

q
1 0 0 1 120 260 cm
-5 0 m -5 4 5 4 5 0 c 5 -4 -5 -4 -5 0 c h S
4.5 0 m 4.5 -30 l S
Q

q
1 0 0 1 220 240 cm
-5 0 m -5 4 5 4 5 0 c 5 -4 -5 -4 -5 0 c h B
-4.5 0 m -4.5 30 l S
Q

q
1 0 0 1 320 250 cm
-5 0 m -5 4 5 4 5 0 c 5 -4 -5 -4 -5 0 c F
4.5 0 m 4.5 -30 l S
4.5 -30 m 12 -22 l S
Q

120 270 m 160 285 190 285 220 270 c S
Q
''';

      final pdfBytes = buildSyntheticPdf(stream, title: 'CTM Bezier Test');
      final result = await parser.parseScoreData(bytes: pdfBytes, fileName: 'ctm_bezier.pdf');

      final notes = result.package.score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(notes.length, equals(3));
      expect(notes[0].noteName, equals('Mi4'));
      expect(notes[0].durationTicks, equals(8));
      expect(notes[1].noteName, equals('Si4'));
      expect(notes[1].durationTicks, equals(4));
      expect(notes[2].noteName, equals('Sol4'));
      expect(notes[2].durationTicks, equals(2));
    });

    test('VectorOmrEngine infers 2-tick and 1-tick beamed notes without fake Sol4', () {
      final lines = <OmrLine>[
        // Pentagrama de 5 lineas (espaciado 8 pt)
        const OmrLine(x1: 40, y1: 100, x2: 440, y2: 100),
        const OmrLine(x1: 40, y1: 108, x2: 440, y2: 108),
        const OmrLine(x1: 40, y1: 116, x2: 440, y2: 116),
        const OmrLine(x1: 40, y1: 124, x2: 440, y2: 124),
        const OmrLine(x1: 40, y1: 132, x2: 440, y2: 132),
        const OmrLine(x1: 240, y1: 100, x2: 240, y2: 132),
        const OmrLine(x1: 440, y1: 100, x2: 440, y2: 132),

        // Compas 1: 2 corcheas unidas por 1 barra horizontal (beam)
        const OmrLine(x1: 104.5, y1: 100, x2: 104.5, y2: 128),
        const OmrLine(x1: 154.5, y1: 104, x2: 154.5, y2: 132),
        const OmrLine(x1: 104.5, y1: 128, x2: 154.5, y2: 132),

        // Compas 2: 2 semicorcheas unidas por 2 barras horizontales
        const OmrLine(x1: 284.5, y1: 108, x2: 284.5, y2: 136),
        const OmrLine(x1: 334.5, y1: 112, x2: 334.5, y2: 140),
        const OmrLine(x1: 284.5, y1: 136, x2: 334.5, y2: 140),
        const OmrLine(x1: 284.5, y1: 131, x2: 334.5, y2: 135),
      ];

      final rects = <OmrRect>[
        // Compas 1: Mi4, Fa4
        const OmrRect(x: 95.5, y: 97, width: 9, height: 6, isFilled: true),
        const OmrRect(x: 145.5, y: 101, width: 9, height: 6, isFilled: true),
        // Compas 2: Sol4, La4
        const OmrRect(x: 275.5, y: 105, width: 9, height: 6, isFilled: true),
        const OmrRect(x: 325.5, y: 109, width: 9, height: 6, isFilled: true),
      ];

      final score = engine.processGeometricElements(lines: lines, rects: rects);
      expect(score.measures.length, equals(2));

      final m0Notes = score.measures[0].notes.where((n) => !n.isRest).toList();
      expect(m0Notes.length, equals(2));
      expect(m0Notes[0].noteName, equals('Mi4'));
      expect(m0Notes[0].durationTicks, equals(2));
      expect(m0Notes[1].noteName, equals('Fa4'));
      expect(m0Notes[1].durationTicks, equals(2));

      final m1Notes = score.measures[1].notes.where((n) => !n.isRest).toList();
      expect(m1Notes.length, equals(2));
      expect(m1Notes[0].noteName, equals('Sol4'));
      expect(m1Notes[0].durationTicks, equals(1));
      expect(m1Notes[1].noteName, equals('La4'));
      expect(m1Notes[1].durationTicks, equals(1));
    });

    test('Throws FormatException when PDF contains no valid staves (never fabricates Sol4)', () async {
      // Caso 1: PDF solo texto sin primitivas vectoriales de pentagrama
      final textOnlyPdf = buildSyntheticPdf(
        'BT /F1 12 Tf 1 0 0 1 72 400 Tm (Texto sin pentagrama) Tj ET',
        title: 'Solo Texto',
      );
      await expectLater(
        parser.parseScoreData(bytes: textOnlyPdf, fileName: 'solo_texto.pdf'),
        throwsA(isA<FormatException>()),
      );

      // Caso 2: PDF con figuras cerradas y menos de 5 lineas (escenario que antes fabricaba Sol4)
      final noStaffPdf = buildSyntheticPdf('''
50 100 m 450 100 l S
50 110 m 450 110 l S
50 120 m 450 120 l S
100 100 9 6 re f
200 115 9 6 re f
''', title: 'Sin Pentagrama');
      await expectLater(
        parser.parseScoreData(bytes: noStaffPdf, fileName: 'sin_pentagrama.pdf'),
        throwsA(isA<FormatException>()),
      );

      // Caso 3: VectorOmrEngine directo con rectangulos sin lineas de pentagrama
      expect(
        () => engine.processGeometricElements(
          lines: const [],
          rects: const [OmrRect(x: 100, y: 120, width: 9, height: 6)],
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
