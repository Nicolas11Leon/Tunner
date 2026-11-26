import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/sheet_music/domain/score_playback_coordinator.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';

void main() {
  group('US-UX-08: Live SMuFL Note Coloring, Live Pitch Trail & A-B Measure Loop', () {
    late PolyphonicVoicePool voicePool;
    late ScorePlaybackCoordinator coordinator;
    late HierarchicalScore fourMeasureScore;

    setUp(() {
      voicePool = PolyphonicVoicePool(maxPolyphony: 8);
      coordinator = ScorePlaybackCoordinator(voicePool: voicePool, initialBpm: 120.0);

      MeasureEntity buildMeasure(int idx, String noteName) {
        return MeasureEntity(
          index: idx,
          timeSignature: TimeSignature.commonTime44,
          notes: [
            HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: noteName),
            HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: noteName),
            HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: noteName),
            HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: noteName),
          ],
        );
      }

      fourMeasureScore = HierarchicalScore(
        title: 'US-UX-08 4-Measure Loop Test Score',
        baseBpm: 120,
        measures: [
          buildMeasure(0, 'Do4'),
          buildMeasure(1, 'Re4'),
          buildMeasure(2, 'Mi4'),
          buildMeasure(3, 'Fa4'),
        ],
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('Prueba 1: ScorePlaybackCoordinator.setMeasureLoopRange(1, 2) cicla entre compases 1 y 2 e incrementa loopIterationCount; clearMeasureLoop() restaura el avance lineal', () {
      expect(coordinator.isMeasureLoopActive, isFalse);
      expect(coordinator.loopIterationCount, 0);
      expect(coordinator.waitForNoteMode, isFalse);

      coordinator.setWaitForNoteMode(true);
      expect(coordinator.waitForNoteMode, isTrue);

      coordinator.setMeasureLoopRange(1, 2);
      expect(coordinator.isMeasureLoopActive, isTrue);
      expect(coordinator.loopStartMeasureIndex, 1);
      expect(coordinator.loopEndMeasureIndex, 2);
      expect(coordinator.loopIterationCount, 0);

      // Iniciar reproducción desde el compás 1
      coordinator.startPlayback(score: fourMeasureScore, startMeasure: 1, startSubTick: 0);
      expect(coordinator.currentMeasureIndex, 1);
      expect(coordinator.currentSubTick, 0);

      // Avanzar los 16 sub-ticks del compás 1 -> debe pasar al compás 2
      for (int i = 0; i < 16; i++) {
        coordinator.advanceTick();
      }
      expect(coordinator.currentMeasureIndex, 2);
      expect(coordinator.currentSubTick, 0);
      expect(coordinator.loopIterationCount, 0);

      // Avanzar los 16 sub-ticks del compás 2 -> al terminar el compás 2 debe saltar de vuelta al compás 1
      for (int i = 0; i < 16; i++) {
        coordinator.advanceTick();
      }
      expect(coordinator.currentMeasureIndex, 1);
      expect(coordinator.currentSubTick, 0);
      expect(coordinator.loopIterationCount, 1);

      // Un segundo ciclo completo (compás 1 + compás 2 = 32 sub-ticks)
      for (int i = 0; i < 32; i++) {
        coordinator.advanceTick();
      }
      expect(coordinator.currentMeasureIndex, 1);
      expect(coordinator.currentSubTick, 0);
      expect(coordinator.loopIterationCount, 2);

      // Limpiar el bucle A-B restaura el comportamiento lineal normal
      coordinator.clearMeasureLoop();
      expect(coordinator.isMeasureLoopActive, isFalse);
      expect(coordinator.loopStartMeasureIndex, isNull);
      expect(coordinator.loopEndMeasureIndex, isNull);
      expect(coordinator.loopIterationCount, 0);

      // Avanzar compás 1 (16 ticks) -> compás 2 (16 ticks) -> ahora debe avanzar linealmente al compás 3
      for (int i = 0; i < 32; i++) {
        coordinator.advanceTick();
      }
      expect(coordinator.currentMeasureIndex, 3);
      expect(coordinator.currentSubTick, 0);
    });

    test('Prueba 2: RealSheetMusicPainter.resolveNoteEvaluationColor devuelve colores semánticos para aciertos, fallos, notas no evaluadas, silencios y selección', () {
      const palette = TunnerThemePalette.obsidianStudio;
      final history = <int, bool>{
        0: true, // Nota 0 (sub-ticks 0..3): acertada
        4: false, // Nota 1 (sub-ticks 4..7): fallada
      };

      // Nota 0: Acertada -> correctPitchColor
      final hitColor = RealSheetMusicPainter.resolveNoteEvaluationColor(
        isSelected: false,
        isRest: false,
        noteIndex: 0,
        totalNotes: 4,
        history: history,
        palette: palette,
      );
      expect(hitColor, equals(palette.correctPitchColor));

      // Nota 1: Fallada -> errorPitchColor
      final missColor = RealSheetMusicPainter.resolveNoteEvaluationColor(
        isSelected: false,
        isRest: false,
        noteIndex: 1,
        totalNotes: 4,
        history: history,
        palette: palette,
      );
      expect(missColor, equals(palette.errorPitchColor));

      // Nota 2: Aún no evaluada -> musicalSymbolsColor
      final unevaluatedColor = RealSheetMusicPainter.resolveNoteEvaluationColor(
        isSelected: false,
        isRest: false,
        noteIndex: 2,
        totalNotes: 4,
        history: history,
        palette: palette,
      );
      expect(unevaluatedColor, equals(palette.musicalSymbolsColor));

      // Silencio en el rango evaluado -> musicalSymbolsColor
      final restColor = RealSheetMusicPainter.resolveNoteEvaluationColor(
        isSelected: false,
        isRest: true,
        noteIndex: 0,
        totalNotes: 4,
        history: history,
        palette: palette,
      );
      expect(restColor, equals(palette.musicalSymbolsColor));

      // Nota seleccionada -> secondaryAccent (tiene prioridad visual)
      final selectedColor = RealSheetMusicPainter.resolveNoteEvaluationColor(
        isSelected: true,
        isRest: false,
        noteIndex: 0,
        totalNotes: 4,
        history: history,
        palette: palette,
      );
      expect(selectedColor, equals(palette.secondaryAccent));
    });

    testWidgets('Prueba 3: Renderizar CustomPaint con RealSheetMusicPainter pasando history: {0: true, 4: false}, loopStartMeasure: 0, loopEndMeasure: 3 pinta sin excepciones', (WidgetTester tester) async {
      final notes = [
        HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
        HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Mi4'),
        HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Sol4'),
        HierarchicalNote.rest(startTick: 12, durationTicks: 4),
      ];

      final painter = RealSheetMusicPainter(
        currentSubTick: 6,
        notes: notes,
        history: const <int, bool>{0: true, 4: false},
        liveNote: 'Mi4',
        liveCents: -3.5,
        isCountingIn: false,
        countInBeat: 0,
        loopStartMeasure: 0,
        loopEndMeasure: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 240,
                child: CustomPaint(
                  painter: painter,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
