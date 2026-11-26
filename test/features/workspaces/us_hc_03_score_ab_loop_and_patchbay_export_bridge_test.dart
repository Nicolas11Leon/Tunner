import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/composition_notation_workspace_view.dart';

void main() {
  group(
    'US-HC-03: Real Score A-B Loop Coordinator Bridge & 1-Click Patchbay CH A Export',
    () {
      Widget buildHost(TunerViewModel viewModel) {
        return StudioThemeScope(
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
        );
      }

      setUp(() {
        StudioPatchbayRoutingService().resetToDefaults();
      });

      tearDown(() {
        StudioPatchbayRoutingService().resetToDefaults();
      });

      testWidgets(
        'btn_set_loop_point_a, btn_set_loop_point_b and btn_clear_ab_loop configure ScorePlaybackCoordinator and RealSheetMusicPainter',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final viewModel = TunerViewModel();
          addTearDown(viewModel.dispose);

          await tester.pumpWidget(buildHost(viewModel));
          await tester.pumpAndSettle();

          expect(viewModel.scorePlaybackCoordinator.isMeasureLoopActive, isFalse);
          expect(viewModel.scorePlaybackCoordinator.loopStartMeasureIndex, isNull);
          expect(viewModel.scorePlaybackCoordinator.loopEndMeasureIndex, isNull);

          final btnA = find.byKey(const Key('btn_set_loop_point_a'));
          await tester.ensureVisible(btnA);
          await tester.tap(btnA);
          await tester.pumpAndSettle();

          final btnB = find.byKey(const Key('btn_set_loop_point_b'));
          await tester.ensureVisible(btnB);
          await tester.tap(btnB);
          await tester.pumpAndSettle();

          expect(viewModel.scorePlaybackCoordinator.isMeasureLoopActive, isTrue);
          expect(viewModel.scorePlaybackCoordinator.loopStartMeasureIndex, 0);
          expect(viewModel.scorePlaybackCoordinator.loopEndMeasureIndex, 0);

          final activeCanvasFinder = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RealSheetMusicPainter,
          );
          final activePaint = tester.widget<CustomPaint>(activeCanvasFinder);
          final activePainter = activePaint.painter! as RealSheetMusicPainter;
          expect(activePainter.loopStartMeasure, 0);
          expect(activePainter.loopEndMeasure, 0);

          final btnClear = find.byKey(const Key('btn_clear_ab_loop'));
          await tester.ensureVisible(btnClear);
          await tester.tap(btnClear);
          await tester.pumpAndSettle();

          expect(viewModel.scorePlaybackCoordinator.isMeasureLoopActive, isFalse);
          expect(viewModel.scorePlaybackCoordinator.loopStartMeasureIndex, isNull);
          expect(viewModel.scorePlaybackCoordinator.loopEndMeasureIndex, isNull);

          final clearedPaint = tester.widget<CustomPaint>(activeCanvasFinder);
          final clearedPainter = clearedPaint.painter! as RealSheetMusicPainter;
          expect(clearedPainter.loopStartMeasure, isNull);
          expect(clearedPainter.loopEndMeasure, isNull);

          // Also verify _buildAbMeasureLoopBar in Practice mode
          await tester.tap(find.byKey(const Key('dorico_mode_practice_chip')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('btn_set_loop_point_a')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('btn_set_loop_point_b')));
          await tester.pumpAndSettle();

          expect(viewModel.scorePlaybackCoordinator.isMeasureLoopActive, isTrue);
          expect(viewModel.scorePlaybackCoordinator.loopStartMeasureIndex, 0);
          expect(viewModel.scorePlaybackCoordinator.loopEndMeasureIndex, 0);

          await tester.tap(find.byKey(const Key('btn_clear_ab_loop')));
          await tester.pumpAndSettle();

          expect(viewModel.scorePlaybackCoordinator.isMeasureLoopActive, isFalse);
          expect(viewModel.scorePlaybackCoordinator.loopStartMeasureIndex, isNull);
          expect(viewModel.scorePlaybackCoordinator.loopEndMeasureIndex, isNull);
        },
      );

      testWidgets(
        'btn_send_score_to_patchbay_channel_a publishes activePackage title and bpm to canal_a in StudioPatchbayRoutingService',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final viewModel = TunerViewModel();
          addTearDown(viewModel.dispose);
          viewModel.updateBpm(136);

          await tester.pumpWidget(buildHost(viewModel));
          await tester.pumpAndSettle();

          final sendButton = find.byKey(
            const Key('btn_send_score_to_patchbay_channel_a'),
          );
          expect(sendButton, findsOneWidget);
          expect(find.text('Enviar a Patchbay (CH A)'), findsOneWidget);

          await tester.ensureVisible(sendButton);
          await tester.tap(sendButton);
          await tester.pumpAndSettle();

          final channelA = StudioPatchbayRoutingService().matrix.channels['canal_a'];
          expect(channelA, isNotNull);
          expect(
            channelA!.activeTrackTitle,
            'Partitura: ${viewModel.activePackage.title}',
          );
          expect(channelA.activeBpm, viewModel.bpm.toDouble());
          expect(channelA.isPlaying, viewModel.isMetronomePlaying);

          expect(
            find.text(
              'Partitura "${viewModel.activePackage.title}" publicada en Canal A del Patchbay (${viewModel.bpm} BPM).',
            ),
            findsOneWidget,
          );
        },
      );
    },
  );
}
