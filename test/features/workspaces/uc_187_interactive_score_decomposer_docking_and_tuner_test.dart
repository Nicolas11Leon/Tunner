import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/channels/data/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/presentation/studio_channel_patchbay_bar_widget.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/docking/domain/studio_dock_layout_entity.dart';
import 'package:tunner/core/docking/domain/studio_dock_zone.dart';
import 'package:tunner/core/docking/presentation/studio_dockable_panel_entity.dart';
import 'package:tunner/core/docking/presentation/studio_workspace_docking_container.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/song_library/presentation/song_decomposer_modal.dart';
import 'package:tunner/features/tuner/presentation/strobe_tuner_widget.dart';
import 'package:tunner/features/tuner/presentation/widgets/essential_tuner_panel.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/composition_notation_workspace_view.dart';
import 'package:tunner/features/workspaces/presentation/production_acoustic_lab_workspace_view.dart';

void main() {
  group('UC-187 Remediation: Direct Score Editor, Decomposer, Docking, Channels & Tuner', () {
    test('RealSheetMusicPainter resolves tick and pitch from canvas coordinates and caps staffSpacing', () {
      final painter = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
      );

      const desktopSize = Size(1000, 480);
      final tick0 = painter.resolveTickAtOffset(const Offset(80, 240), desktopSize, quantizeTicks: 4);
      final tickMid = painter.resolveTickAtOffset(const Offset(550, 240), desktopSize, quantizeTicks: 4);
      expect(tick0, equals(0));
      expect(tickMid, greaterThanOrEqualTo(4));

      final highNote = painter.resolveNoteNameAtOffset(const Offset(200, 180), desktopSize, accidental: '#');
      final lowNote = painter.resolveNoteNameAtOffset(const Offset(200, 300), desktopSize);
      expect(highNote, contains('#'));
      expect(highNote, isNot(equals(lowNote)));
    });

    testWidgets('CompositionNotationWorkspaceView supports direct click note insertion, measure addition and eraser', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = TunerViewModel();
      final initialMeasures = vm.totalMeasures;

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: CompositionNotationWorkspaceView(
                viewModel: vm,
                palette: TunnerThemePalette.obsidianStudio,
                onOpenLibraryModal: () {},
                onOpenMixerModal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Add a new measure directly from the canvas toolbar
      await tester.tap(find.byKey(const Key('score_add_measure_btn')));
      await tester.pumpAndSettle();
      expect(vm.totalMeasures, equals(initialMeasures + 1));

      // Select sharp accidental and eighth note duration (2 ticks)
      await tester.tap(find.byKey(const Key('score_accidental_chip_#')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('score_duration_chip_2')));
      await tester.pump();

      // Click directly on the score canvas to insert a note
      final canvasFinder = find.byKey(const Key('score_interactive_canvas_gesture'));
      final canvasRect = tester.getRect(canvasFinder);
      await tester.tapAt(Offset(canvasRect.left + 220, canvasRect.top + canvasRect.height * 0.45));
      await tester.pumpAndSettle();

      expect(vm.currentMeasureNotes.any((n) => n.noteName.contains('#')), isTrue);
    });

    testWidgets('SongDecomposerModal extracts from active score and auditions 4 Stems', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = TunerViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongDecomposerModal(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('decomposer_pick_audio_file_btn')), findsOneWidget);
      expect(find.byKey(const Key('decomposer_from_active_score_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('decomposer_from_active_score_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('decomposer_audition_lead_btn')), findsOneWidget);
      expect(find.byKey(const Key('decomposer_audition_harmony_btn')), findsOneWidget);
      expect(find.byKey(const Key('decomposer_audition_bass_btn')), findsOneWidget);
      expect(find.byKey(const Key('decomposer_audition_rhythm_btn')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('decomposer_audition_lead_btn')));
      await tester.tap(find.byKey(const Key('decomposer_audition_lead_btn')));
      await tester.pump();
    });

    testWidgets('StudioWorkspaceDockingContainer allows 1-click float and corner resize of floating window', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final panels = [
        StudioDockablePanelEntity(
          id: 'p_center',
          title: 'Panel Central',
          icon: Icons.music_note,
          currentZone: StudioDockZone.center,
          builder: (_) => const Center(child: Text('Centro')),
        ),
        StudioDockablePanelEntity(
          id: 'p_float',
          title: 'Panel Flotante Redimensionable',
          icon: Icons.tune,
          currentZone: StudioDockZone.floating,
          builder: (_) => const Center(child: Text('Flotante')),
        ),
      ];

      const layout = StudioDockLayoutEntity(
        zonePanelIds: {
          StudioDockZone.center: ['p_center'],
          StudioDockZone.left: [],
          StudioDockZone.right: [],
          StudioDockZone.bottom: [],
          StudioDockZone.floating: ['p_float'],
        },
      );

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 700,
                child: StudioWorkspaceDockingContainer(
                  panels: panels,
                  initialLayout: layout,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final floatFinder = find.byKey(const ValueKey('floating_panel_p_float'));
      final resizeHandle = find.byKey(const ValueKey('floating_resize_handle_p_float'));
      expect(floatFinder, findsOneWidget);
      expect(resizeHandle, findsOneWidget);

      final sizeBefore = tester.getSize(floatFinder);
      await tester.drag(resizeHandle, const Offset(80, 60));
      await tester.pumpAndSettle();
      final sizeAfter = tester.getSize(floatFinder);

      expect(sizeAfter.width, greaterThan(sizeBefore.width));
      expect(sizeAfter.height, greaterThan(sizeBefore.height));
    });

    testWidgets('StudioChannelPatchbayBarWidget opens channel inspector with fader, mute and play bus controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = StudioPatchbayRoutingService.isolated();
      service.resetToDefaults();

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: StudioChannelPatchbayBarWidget(routingService: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('channel_plugs_inspector_btn_canal_a')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('channel_inspector_mute_btn')), findsOneWidget);
      expect(find.byKey(const Key('channel_inspector_toggle_play_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('channel_inspector_mute_btn')));
      await tester.pumpAndSettle();
      expect(service.channels.firstWhere((c) => c.id == 'canal_a').isMuted, isTrue);
    });

    testWidgets('ProductionAcousticLabWorkspaceView and EssentialTunerPanel keep StrobeTunerWidget visible and reactive', (tester) async {
      final vm = TunerViewModel();

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: ProductionAcousticLabWorkspaceView(
                viewModel: vm,
                palette: TunnerThemePalette.obsidianStudio,
                onOpenMixerModal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StrobeTunerWidget), findsOneWidget);
      expect(find.byKey(const Key('pro_lab_mic_toggle_btn')), findsOneWidget);

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: EssentialTunerPanel(
                viewModel: vm,
                palette: TunnerThemePalette.obsidianStudio,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      vm.emitTelemetryForTesting(frequency: 440.0);
      await tester.pump();
      expect(find.text('440.0 Hz'), findsWidgets);
    });
  });
}
