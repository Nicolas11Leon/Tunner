import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/universal_importer/domain/vector_omr_engine.dart';

void main() {
  group('VectorOmrEngine Tests', () {
    const engine = VectorOmrEngine();

    test('Identifies 5 equidistant horizontal lines as a StaffSystem', () {
      // 5 staff lines with spacing 10 pt: y = 100, 110, 120, 130, 140
      final lines = [
        const OmrLine(x1: 50, y1: 100, x2: 450, y2: 100),
        const OmrLine(x1: 50, y1: 110, x2: 450, y2: 110),
        const OmrLine(x1: 50, y1: 120, x2: 450, y2: 120),
        const OmrLine(x1: 50, y1: 130, x2: 450, y2: 130),
        const OmrLine(x1: 50, y1: 140, x2: 450, y2: 140),
      ];

      final rects = [
        const OmrRect(x: 100, y: 96, width: 8, height: 8), // mi4 (line 1, y ~ 100)
        const OmrRect(x: 200, y: 116, width: 8, height: 8), // sol4 (line 2, y ~ 120)
      ];

      final score = engine.processGeometricElements(
        lines: lines,
        rects: rects,
        title: 'Pentagrama Simple',
      );

      expect(score.title, equals('Pentagrama Simple'));
      expect(score.measures, isNotEmpty);
      expect(score.measures.first.notes, isNotEmpty);
    });

    test('Subdivides measures using vertical barlines', () {
      final lines = [
        // 5 staff lines
        const OmrLine(x1: 50, y1: 100, x2: 450, y2: 100),
        const OmrLine(x1: 50, y1: 110, x2: 450, y2: 110),
        const OmrLine(x1: 50, y1: 120, x2: 450, y2: 120),
        const OmrLine(x1: 50, y1: 130, x2: 450, y2: 130),
        const OmrLine(x1: 50, y1: 140, x2: 450, y2: 140),
        // Barline in the middle (x = 250) and at the end (x = 450)
        const OmrLine(x1: 250, y1: 100, x2: 250, y2: 140),
        const OmrLine(x1: 450, y1: 100, x2: 450, y2: 140),
      ];

      final rects = [
        // Measure 1 notes (x < 250)
        const OmrRect(x: 100, y: 96, width: 8, height: 8),
        const OmrRect(x: 180, y: 116, width: 8, height: 8),
        // Measure 2 notes (x between 250 and 450)
        const OmrRect(x: 300, y: 106, width: 8, height: 8),
        const OmrRect(x: 380, y: 136, width: 8, height: 8),
      ];

      final score = engine.processGeometricElements(
        lines: lines,
        rects: rects,
      );

      expect(score.measures.length, greaterThanOrEqualTo(2));
      final m1 = score.measures[0];
      final m2 = score.measures[1];

      expect(m1.notes.any((n) => !n.isRest), isTrue);
      expect(m2.notes.any((n) => !n.isRest), isTrue);
    });

    test('Maps pitch accurately according to diatonic staff heights in treble clef', () {
      final lines = [
        const OmrLine(x1: 50, y1: 100, x2: 450, y2: 100), // Mi4 (line 1, y = 100)
        const OmrLine(x1: 50, y1: 110, x2: 450, y2: 110), // Sol4 (line 2, y = 110)
        const OmrLine(x1: 50, y1: 120, x2: 450, y2: 120), // Si4 (line 3, y = 120)
        const OmrLine(x1: 50, y1: 130, x2: 450, y2: 130), // Re5 (line 4, y = 130)
        const OmrLine(x1: 50, y1: 140, x2: 450, y2: 140), // Fa5 (line 5, y = 140)
      ];

      final rects = [
        // Note on Line 1: Mi4 (center y = 100)
        const OmrRect(x: 100, y: 96, width: 8, height: 8),
        // Note on Space 1: Fa4 (center y = 105)
        const OmrRect(x: 150, y: 101, width: 8, height: 8),
        // Note on Line 2: Sol4 (center y = 110)
        const OmrRect(x: 200, y: 106, width: 8, height: 8),
        // Note on Line 3: Si4 (center y = 120)
        const OmrRect(x: 250, y: 116, width: 8, height: 8),
      ];

      final score = engine.processGeometricElements(
        lines: lines,
        rects: rects,
      );

      final notes = score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(notes.length, equals(4));
      expect(notes[0].noteName, equals('Mi4'));
      expect(notes[1].noteName, equals('Fa4'));
      expect(notes[2].noteName, equals('Sol4'));
      expect(notes[3].noteName, equals('Si4'));
    });

    test('Discards non-equidistant or irregular horizontal lines', () {
      final lines = [
        const OmrLine(x1: 50, y1: 10, x2: 450, y2: 10),
        const OmrLine(x1: 50, y1: 30, x2: 450, y2: 30), // spacing 20
        const OmrLine(x1: 50, y1: 40, x2: 450, y2: 40), // spacing 10
        const OmrLine(x1: 50, y1: 45, x2: 450, y2: 45), // spacing 5
        const OmrLine(x1: 50, y1: 90, x2: 450, y2: 90), // spacing 45
      ];

      final rects = [
        const OmrRect(x: 100, y: 20, width: 10, height: 10),
      ];

      // Since spacing is completely non-uniform, fallback score is generated
      final score = engine.processGeometricElements(
        lines: lines,
        rects: rects,
        title: 'Fallback Score',
      );

      expect(score.title, equals('Fallback Score'));
      expect(score.measures, isNotEmpty);
      expect(score.measures.first.notes, isNotEmpty);
    });

    test('Generates empty rest measure when both lines and rects are empty', () {
      final score = engine.processGeometricElements(
        lines: const [],
        rects: const [],
        title: 'Empty Score',
      );

      expect(score.title, equals('Empty Score'));
      expect(score.measures.length, equals(1));
      expect(score.measures.first.notes.first.isRest, isTrue);
      expect(score.measures.first.notes.first.durationTicks, equals(16));
    });
  });
}
