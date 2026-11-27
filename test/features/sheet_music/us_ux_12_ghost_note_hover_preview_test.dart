import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/composition_notation_workspace_view.dart';

void main() {
  group(
    'US-UX-12: Previsualización de Nota Fantasma al Pasar el Cursor (Ghost Note Hover Preview)',
    () {
      testWidgets(
        'Prueba 1: RealSheetMusicPainter con ghostHoverTick y ghostHoverNoteName expone hasGhostHoverPreview == true, renderiza sin excepciones y shouldRepaint detecta cambios',
        (tester) async {
          const notes = <HierarchicalNote>[
            HierarchicalNote(startTick: 0, durationTicks: 4, noteName: 'Do4'),
          ];

          final painterWithGhost = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
            ghostHoverTick: 4,
            ghostHoverNoteName: 'Fa#4',
            ghostHoverDurationTicks: 4,
          );

          expect(painterWithGhost.hasGhostHoverPreview, isTrue);

          final painterWithoutGhost = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
          );

          expect(painterWithoutGhost.hasGhostHoverPreview, isFalse);

          // Renderizar en CustomPaint incluyendo notas con líneas adicionales y silencios
          final painterHighLedger = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
            ghostHoverTick: 8,
            ghostHoverNoteName: 'Do6',
            ghostHoverDurationTicks: 8,
          );

          final painterRestGhost = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
            ghostHoverTick: 12,
            ghostHoverDurationTicks: 4,
            ghostHoverIsRest: true,
          );

          expect(painterRestGhost.hasGhostHoverPreview, isTrue);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 600,
                      height: 180,
                      child: CustomPaint(painter: painterWithGhost),
                    ),
                    SizedBox(
                      width: 600,
                      height: 180,
                      child: CustomPaint(painter: painterHighLedger),
                    ),
                    SizedBox(
                      width: 600,
                      height: 180,
                      child: CustomPaint(painter: painterRestGhost),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // Verificar shouldRepaint ante cambios en ghostHoverTick, ghostHoverNoteName, etc.
          final sameGhostPainter = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
            ghostHoverTick: 4,
            ghostHoverNoteName: 'Fa#4',
            ghostHoverDurationTicks: 4,
          );
          expect(painterWithGhost.shouldRepaint(sameGhostPainter), isFalse);

          final changedTickPainter = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
            ghostHoverTick: 8,
            ghostHoverNoteName: 'Fa#4',
            ghostHoverDurationTicks: 4,
          );
          expect(painterWithGhost.shouldRepaint(changedTickPainter), isTrue);

          final changedNotePainter = RealSheetMusicPainter(
            currentSubTick: -1,
            notes: notes,
            history: const {},
            liveNote: '--',
            liveCents: 0.0,
            isCountingIn: false,
            countInBeat: 0,
            ghostHoverTick: 4,
            ghostHoverNoteName: 'Sol4',
            ghostHoverDurationTicks: 4,
          );
          expect(painterWithGhost.shouldRepaint(changedNotePainter), isTrue);
        },
      );

      testWidgets(
        'Prueba 2: En CompositionNotationWorkspaceView, al mover el puntero sobre el lienzo en modo Escribir se actualiza la nota fantasma y aparece score_ghost_note_hover_badge, desapareciendo al salir',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final viewModel = TunerViewModel();
          addTearDown(viewModel.dispose);

          await tester.pumpWidget(
            StudioThemeScope(
              controller: StudioThemeController(),
              child: MaterialApp(
                home: Scaffold(
                  body: CompositionNotationWorkspaceView(
                    viewModel: viewModel,
                    palette: TunnerThemePalette.obsidianStudio,
                    onOpenLibraryModal: () {},
                    onOpenMixerModal: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('score_ghost_note_hover_badge')),
            findsNothing,
          );

          final canvasFinder = find.byKey(
            const Key('score_interactive_canvas_gesture'),
          );
          expect(canvasFinder, findsOneWidget);

          final canvasCenter = tester.getCenter(canvasFinder);

          final mouseGesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouseGesture.addPointer(location: Offset.zero);
          addTearDown(mouseGesture.removePointer);

          await mouseGesture.moveTo(canvasCenter);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('score_ghost_note_hover_badge')),
            findsOneWidget,
          );
          expect(find.textContaining('Previsualización:'), findsOneWidget);

          final customPaintFinder = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RealSheetMusicPainter,
          );
          final customPaint = tester.widget<CustomPaint>(customPaintFinder);
          final activePainter = customPaint.painter! as RealSheetMusicPainter;
          expect(activePainter.hasGhostHoverPreview, isTrue);
          expect(activePainter.ghostHoverTick, isNotNull);
          expect(activePainter.ghostHoverNoteName, isNotNull);

          // Mover el puntero fuera del lienzo del pentagrama
          await mouseGesture.moveTo(const Offset(5, 5));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('score_ghost_note_hover_badge')),
            findsNothing,
          );
          final exitedPaint = tester.widget<CustomPaint>(customPaintFinder);
          final exitedPainter = exitedPaint.painter! as RealSheetMusicPainter;
          expect(exitedPainter.hasGhostHoverPreview, isFalse);
        },
      );
    },
  );
}
