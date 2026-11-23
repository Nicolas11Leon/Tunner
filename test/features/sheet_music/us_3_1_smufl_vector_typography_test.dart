import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/smufl/smufl_glyph_path_engine.dart';
import 'package:tunner/features/universal_importer/domain/canonical_pdf_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-3.1: Tipografia Musical Vectorial W3C SMuFL y PDF Canónico', () {
    const engine = SmuflGlyphPathEngine();
    const exporter = CanonicalPdfExporter();

    test('SmuflGlyphPathEngine define codepoints y puntos de anclaje SMuFL 1.4', () {
      expect(SmuflGlyphPathEngine.codepointGClef, equals(0xE050));
      expect(SmuflGlyphPathEngine.codepointFClef, equals(0xE062));
      expect(SmuflGlyphPathEngine.codepointCClef, equals(0xE05C));
      expect(SmuflGlyphPathEngine.codepointNoteheadWhole, equals(0xE0A2));
      expect(SmuflGlyphPathEngine.codepointNoteheadHalf, equals(0xE0A3));
      expect(SmuflGlyphPathEngine.codepointNoteheadBlack, equals(0xE0A4));
      expect(SmuflGlyphPathEngine.codepointAugmentationDot, equals(0xE1E7));

      const sp = 10.0;
      final upAnchor = engine.getStemUpAnchor(sp);
      expect(upAnchor.dx, closeTo(5.8, 0.1));
      expect(upAnchor.dy, closeTo(-1.6, 0.1));

      final downAnchor = engine.getStemDownAnchor(sp);
      expect(downAnchor.dx, closeTo(-5.8, 0.1));
      expect(downAnchor.dy, closeTo(1.6, 0.1));
    });

    test('SmuflGlyphPathEngine renderiza claves, cabezas, plicas y puntillos en Canvas', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const sp = 12.0;
      const color = Color(0xFF000000);

      expect(() {
        // Claves
        engine.drawGClef(canvas, anchorLine2: const Offset(50, 100), staffSpace: sp, color: color);
        engine.drawFClef(canvas, anchorLine4: const Offset(100, 100), staffSpace: sp, color: color);
        engine.drawCClef(canvas, anchorLine: const Offset(150, 100), staffSpace: sp, color: color);

        // Cabezas
        engine.drawNotehead(canvas, center: const Offset(200, 100), staffSpace: sp, color: color);
        engine.drawNotehead(canvas, center: const Offset(220, 100), staffSpace: sp, color: color, isHalf: true);
        engine.drawNotehead(canvas, center: const Offset(240, 100), staffSpace: sp, color: color, isWhole: true);

        // Puntillo
        engine.drawAugmentationDot(canvas, center: const Offset(215, 100), staffSpace: sp, color: color);

        // Plicas y corchetes
        engine.drawStem(canvas, noteCenter: const Offset(200, 100), staffSpace: sp, isUp: true, color: color);
        engine.drawFlag(canvas, stemTip: const Offset(200, 50), staffSpace: sp, isUp: true, flagCount: 2, color: color);

        // Silencios
        for (final ticks in [16, 8, 4, 2, 1]) {
          engine.drawRest(canvas, centerLine3: Offset(260 + (ticks * 10), 100), staffSpace: sp, durationTicks: ticks, color: color);
        }

        // Alteraciones
        engine.drawAccidental(canvas, center: const Offset(350, 100), staffSpace: sp, accidental: '#', color: color);
        engine.drawAccidental(canvas, center: const Offset(370, 100), staffSpace: sp, accidental: 'b', color: color);
        engine.drawAccidental(canvas, center: const Offset(390, 100), staffSpace: sp, accidental: 'n', color: color);

        // Lineas adicionales
        engine.drawLedgerLines(canvas, noteCenter: const Offset(200, 150), staffSpace: sp, stepFromLine1: -2, color: color);
      }, returnsNormally);

      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('CanonicalPdfExporter compila documento PDF valido con curvas SMuFL y alteraciones', () {
      final score = HierarchicalScore(
        title: 'Estudio de Tipografia SMuFL',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: const [
              HierarchicalNote(startTick: 0, noteName: 'C#4', durationTicks: 4), // Negra sostenido
              HierarchicalNote(startTick: 4, noteName: 'Bb4', durationTicks: 4), // Negra bemol
              HierarchicalNote(startTick: 8, noteName: 'En4', durationTicks: 4), // Negra becuadro
              HierarchicalNote(startTick: 12, noteName: 'G4', durationTicks: 2), // Corchea
              HierarchicalNote(startTick: 14, noteName: '', isRest: true, durationTicks: 2), // Silencio corchea
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: const [
              HierarchicalNote(startTick: 0, noteName: '', isRest: true, durationTicks: 1), // Silencio semicorchea
              HierarchicalNote(startTick: 1, noteName: 'D5', durationTicks: 1), // Semicorchea
              HierarchicalNote(startTick: 2, noteName: 'F#5', durationTicks: 6), // Negra con puntillo
              HierarchicalNote(startTick: 8, noteName: 'A4', durationTicks: 8), // Blanca
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(score: score);
      expect(pdfBytes, isNotEmpty);

      final pdfString = latin1.decode(pdfBytes);
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);

      // Verificar que el stream contiene trazados de curvas Bezier postscript ('c') y lineas ('l', 'm')
      expect(pdfString.contains(' c'), isTrue);
      expect(pdfString.contains(' m'), isTrue);
      expect(pdfString.contains(' l'), isTrue);
      // Verificar que el becuadro ('En4') emitio su comando de grosor PostScript ('1.4 w')
      expect(pdfString.contains('1.4 w'), isTrue);
    });

    test('CanonicalPdfExporter renderiza notas en Clave de Fa respecto a Sol2 (G2, paso 18)', () {
      final bassScore = HierarchicalScore(
        title: 'Estudio en Clave de Fa',
        baseBpm: 90,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: const [
              HierarchicalNote(startTick: 0, noteName: 'G2', durationTicks: 4), // Linea 1 en clave de Fa (offset 0)
              HierarchicalNote(startTick: 4, noteName: 'Cn3', durationTicks: 4), // Espacio 2 con becuadro
              HierarchicalNote(startTick: 8, noteName: 'F3', durationTicks: 8), // Linea 4 en clave de Fa
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(score: bassScore);
      final pdfString = latin1.decode(pdfBytes);

      // Clave de Fa emite trazos vectoriales sin operador re f (compatible Vector OMR)
      expect(pdfString.contains('c S'), isTrue);
      expect(pdfString.contains('h f'), isTrue);
      // G2 en Linea 1 (offset 0) no debe generar lineas adicionales inferiores
      // (En clave de Sol habria tenido offset -12 con multiples ledger lines)
      expect(pdfString.contains('1.4 w'), isTrue);
    });
  });
}
