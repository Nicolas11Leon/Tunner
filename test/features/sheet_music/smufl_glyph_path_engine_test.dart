import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/sheet_music/presentation/smufl/smufl_glyph_path_engine.dart';

void main() {
  group('SmuflGlyphPathEngine Tests', () {
    const engine = SmuflGlyphPathEngine();
    late PictureRecorder recorder;
    late Canvas canvas;

    setUp(() {
      recorder = PictureRecorder();
      canvas = Canvas(recorder);
    });

    test('renders noteheads (black, half, whole) without errors', () {
      expect(
        () => engine.drawNotehead(
          canvas,
          center: const Offset(100, 100),
          staffSpace: 12.0,
          color: Colors.black,
          isWhole: false,
          isHalf: false,
        ),
        returnsNormally,
      );

      expect(
        () => engine.drawNotehead(
          canvas,
          center: const Offset(150, 100),
          staffSpace: 12.0,
          color: Colors.black,
          isWhole: false,
          isHalf: true,
        ),
        returnsNormally,
      );

      expect(
        () => engine.drawNotehead(
          canvas,
          center: const Offset(200, 100),
          staffSpace: 12.0,
          color: Colors.black,
          isWhole: true,
        ),
        returnsNormally,
      );
    });

    test('renders stems and flags (up and down) without errors', () {
      expect(
        () => engine.drawStem(
          canvas,
          noteCenter: const Offset(100, 100),
          staffSpace: 12.0,
          isUp: true,
          color: Colors.black,
        ),
        returnsNormally,
      );

      expect(
        () => engine.drawStem(
          canvas,
          noteCenter: const Offset(100, 100),
          staffSpace: 12.0,
          isUp: false,
          color: Colors.black,
        ),
        returnsNormally,
      );

      expect(
        () => engine.drawFlag(
          canvas,
          stemTip: const Offset(105, 60),
          staffSpace: 12.0,
          isUp: true,
          flagCount: 2,
          color: Colors.black,
        ),
        returnsNormally,
      );
    });

    test('renders clefs (Treble and Bass) without errors', () {
      expect(
        () => engine.drawGClef(
          canvas,
          anchorLine2: const Offset(30, 80),
          staffSpace: 12.0,
          color: Colors.black,
        ),
        returnsNormally,
      );

      expect(
        () => engine.drawFClef(
          canvas,
          anchorLine4: const Offset(30, 60),
          staffSpace: 12.0,
          color: Colors.black,
        ),
        returnsNormally,
      );
    });

    test('renders rests and accidentals without errors', () {
      for (final duration in [1, 2, 4, 8, 16]) {
        expect(
          () => engine.drawRest(
            canvas,
            centerLine3: const Offset(100, 70),
            staffSpace: 12.0,
            durationTicks: duration,
            color: Colors.black,
          ),
          returnsNormally,
        );
      }

      for (final acc in ['#', 'b', 'n', '♯', '♭', '♮']) {
        expect(
          () => engine.drawAccidental(
            canvas,
            center: const Offset(80, 70),
            staffSpace: 12.0,
            accidental: acc,
            color: Colors.black,
          ),
          returnsNormally,
        );
      }
    });

    test('renders ledger lines above and below staff without errors', () {
      expect(
        () => engine.drawLedgerLines(
          canvas,
          noteCenter: const Offset(100, 120),
          staffSpace: 12.0,
          stepFromLine1: -2,
          color: Colors.black,
        ),
        returnsNormally,
      );

      expect(
        () => engine.drawLedgerLines(
          canvas,
          noteCenter: const Offset(100, 30),
          staffSpace: 12.0,
          stepFromLine1: 10,
          color: Colors.black,
        ),
        returnsNormally,
      );
    });
  });

  group('RealSheetMusicPainter SMuFL Integration Tests', () {
    test('getNoteStep calculates diatonic steps accurately', () {
      final painterTreble = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        clef: InstrumentClef.treble,
      );

      // En Clave de Sol (Mi4 es Línea 1 -> step = 0)
      expect(painterTreble.getNoteStep('Mi4'), 0);
      expect(painterTreble.getNoteStep('Sol4'), 2); // Línea 2
      expect(painterTreble.getNoteStep('Si4'), 4);  // Línea 3 (centro)
      expect(painterTreble.getNoteStep('Re5'), 6);  // Línea 4
      expect(painterTreble.getNoteStep('Fa5'), 8);  // Línea 5
      expect(painterTreble.getNoteStep('Do4'), -2); // Línea adicional inferior (Do central)

      final painterBass = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        clef: InstrumentClef.bass,
      );

      // En Clave de Fa (Sol2 es Línea 1 -> step = 0)
      expect(painterBass.getNoteStep('Sol2'), 0);
      expect(painterBass.getNoteStep('Fa3'), 6); // Línea 4 (Fa de clave)
    });

    test('findNoteIndexAtOffset performs hit testing accurately', () {
      final notes = [
        HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
        HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Mi4'),
        HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'Sol4'),
      ];

      final painter = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: notes,
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
      );

      const size = Size(800, 200);
      // Play area width = 800 - 75 - 20 = 705. Step width = 705 / 16 = 44.0625
      // Note 0: X [75.0, 75.0 + 4*44.06] = [75.0, 251.25]
      // Note 1: X [251.25, 427.5]
      // Note 2: X [427.5, 780.0]

      expect(painter.findNoteIndexAtOffset(const Offset(100, 100), size), 0);
      expect(painter.findNoteIndexAtOffset(const Offset(300, 100), size), 1);
      expect(painter.findNoteIndexAtOffset(const Offset(500, 100), size), 2);
      expect(painter.findNoteIndexAtOffset(const Offset(20, 100), size), isNull);
    });

    test('paint executes smoothly with SMuFL vector elements', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final notes = [
        HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do#4'),
        HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Mib4'),
        HierarchicalNote.rest(startTick: 8, durationTicks: 4),
        HierarchicalNote.note(startTick: 12, durationTicks: 2, noteName: 'Sol4'),
        HierarchicalNote.note(startTick: 14, durationTicks: 2, noteName: 'Si4'),
      ];

      final painter = RealSheetMusicPainter(
        currentSubTick: 2,
        notes: notes,
        history: {0: const PlayedRecord('Do#4', 2.0, true)},
        liveNote: 'Do#4',
        liveCents: 1.5,
        isCountingIn: false,
        countInBeat: 0,
        palette: TunnerThemePalette.obsidianStudio,
        selectedNoteIndex: 1,
      );

      expect(() => painter.paint(canvas, const Size(800, 240)), returnsNormally);
    });

    test('shouldRepaint responds to property updates', () {
      final p1 = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        selectedNoteIndex: null,
      );

      final p2 = RealSheetMusicPainter(
        currentSubTick: 1,
        notes: const [],
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        selectedNoteIndex: 0,
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });
  });
}
