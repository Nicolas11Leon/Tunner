import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/atoms/studio_icon.dart';
import 'package:tunner/core/design_system/data/studio_theme_catalog_service.dart';
import 'package:tunner/core/design_system/domain/studio_icon_catalog.dart';
import 'package:tunner/core/design_system/domain/studio_theme_skin_entity.dart';
import 'package:tunner/core/design_system/organisms/studio_desktop_app_shell.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_radar_widget.dart';
import 'package:tunner/features/dj_console/domain/dj_deck_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_parallel_waveform_painter.dart';
import 'package:tunner/features/dj_console/presentation/vector_jog_wheel.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/presentation/drum_pads_tactile_widget.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart';
import 'package:tunner/features/practice_evaluator/presentation/practice_report_modal.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/tuner/presentation/strobe_tuner_widget.dart';

void _paintWithRecorder(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  picture.dispose();
}

void main() {
  tearDown(() {
    StudioIcon.resetManifestCache();
    StudioIcon.globalSvgBuilder = null;
  });

  group('US-7.1 — StudioIcon manifest cache & OLED Monochrome catalog sync', () {
    testWidgets(
      'StudioIcon renders fallback Icon directly without Image when PNG is not in manifest',
      (tester) async {
        expect(
          StudioIcon.hasBundledPngForId(StudioIconId.modulePianoRoll),
          isFalse,
        );
        expect(
          StudioIcon.hasBundledPngForId(StudioIconId.moduleTuner),
          isTrue,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StudioIcon(StudioIconId.modulePianoRoll, size: 20),
            ),
          ),
        );

        expect(find.byType(Icon), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    test('registerAvailablePngAssets and resetManifestCache update O(1) cache', () {
      final path = StudioIconCatalog.specFor(StudioIconId.modulePianoRoll).pngAssetPath;
      expect(StudioIcon.hasBundledPng(path), isFalse);

      StudioIcon.registerAvailablePngAssets(<String>[path]);
      expect(StudioIcon.hasBundledPng(path), isTrue);

      StudioIcon.resetManifestCache();
      expect(StudioIcon.hasBundledPng(path), isFalse);
    });

    test('StudioThemeCatalogService.isolated defaults to OLED Monochrome synchronized with StudioDesignTokens', () {
      final controller = StudioThemeController();
      final catalog = StudioThemeCatalogService.isolated(controller: controller);

      expect(catalog.activeSkin.id, StudioThemeSkinEntity.studioOledMonochrome.id);
      expect(
        catalog.activeSkin.toDesignTokens(),
        equals(StudioDesignTokens.studioOledMonochrome),
      );
      expect(
        controller.tokens,
        equals(StudioDesignTokens.studioOledMonochrome),
      );
    });

    testWidgets(
      'StudioDesktopAppShell sidebar mode switcher uses StudioDesignTokens instead of hardcoded cyan',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = StudioThemeController(
          initialTokens: StudioDesignTokens.studioOledMonochrome,
        );

        await tester.pumpWidget(
          StudioThemeScope(
            controller: controller,
            child: MaterialApp(
              home: StudioDesktopAppShell(
                currentBreadcrumb: 'Tuner',
                navigationSections: const [],
                activeItemId: 'tuner',
                onOpenSearch: () {},
                onOpenShortcuts: () {},
                customSidebarExplorer: const SizedBox(key: Key('custom_explorer')),
                activeView: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump();

        final explorerBtn = find.byKey(const Key('sidebar_mode_explorer_btn'));
        expect(explorerBtn, findsOneWidget);
        await tester.tap(explorerBtn);
        await tester.pump();

        final activeContainer = tester.widget<Container>(
          find.descendant(of: explorerBtn, matching: find.byType(Container)).first,
        );
        final decoration = activeContainer.decoration! as BoxDecoration;
        expect(decoration.color, StudioDesignTokens.studioOledMonochrome.elevatedSurface);
        expect(
          (decoration.border! as Border).top.color,
          StudioDesignTokens.studioOledMonochrome.accentPrimary,
        );
      },
    );
  });

  group('US-7.4 — CustomPainter hardening & shouldRepaint', () {
    test('RealSheetMusicPainter shouldRepaint reacts to timeSignature and totalMeasures', () {
      final base = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '--',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        timeSignature: TimeSignature.commonTime44,
        measureIndex: 0,
        totalMeasures: 4,
      );

      final differentTimeSig = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '--',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        timeSignature: TimeSignature.waltzTime34,
        measureIndex: 0,
        totalMeasures: 4,
      );

      final differentMeasures = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [],
        history: const {},
        liveNote: '--',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
        timeSignature: TimeSignature.commonTime44,
        measureIndex: 0,
        totalMeasures: 8,
      );

      expect(differentTimeSig.shouldRepaint(base), isTrue);
      expect(differentMeasures.shouldRepaint(base), isTrue);
    });

    test('RealSheetMusicPainter and DjParallelWaveformPainter survive degenerate sizes without throwing', () {
      final sheetPainter = RealSheetMusicPainter(
        currentSubTick: 0,
        notes: const [
          HierarchicalNote(
            noteName: 'Bb4',
            durationTicks: 4,
            startTick: 0,
          ),
        ],
        history: const {},
        liveNote: 'C4',
        liveCents: 0.0,
        isCountingIn: false,
        countInBeat: 0,
      );

      final djPainter = DjParallelWaveformPainter(
        deckA: const DjDeckEntity(deckId: 'A', isLoopActive: true),
        deckB: const DjDeckEntity(deckId: 'B'),
        waveformA: const [],
        waveformB: const [],
      );

      const degenerateSizes = <Size>[
        Size.zero,
        Size(4, 4),
        Size(12, 12),
        Size(double.nan, 40),
        Size(double.infinity, 40),
      ];

      for (final size in degenerateSizes) {
        expect(() => _paintWithRecorder(sheetPainter, size), returnsNormally);
        expect(() => _paintWithRecorder(djPainter, size), returnsNormally);
      }
    });

    testWidgets('ChordRadarWidget, StrobeTunerWidget, and VectorJogWheel render safely at tiny sizes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChordRadarWidget(
                  chromaVector: List<double>.filled(12, double.nan),
                  recognizedChord: ChordEntity.none,
                  palette: TunnerThemePalette.obsidianStudio,
                  size: 12.0,
                ),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: VectorJogWheel(
                    deckLabel: 'A',
                    accentColor: Colors.white,
                    isPlaying: true,
                    rotationAngle: double.nan,
                    diameter: 12.0,
                  ),
                ),
                const SizedBox(
                  width: 380,
                  child: StrobeTunerWidget(
                    cents: double.nan,
                    frequency: 440.0,
                    noteName: 'A4',
                    isRecording: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('US-7.4 — RenderFlex overflow hardening on narrow viewports', () {
    testWidgets('DrumPadsTactileWidget renders cleanly at 320px width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: DrumPadsTactileWidget(
                instrument: UniversalInstrumentDefinition.fluteConcert,
                onDrumHit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('PracticeReportModal renders cleanly at 320px width without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final report = PracticeReportEntity(
        songTitle: 'Estudio Polifónico de Precisión Avanzada en Do Mayor',
        instrumentName: 'Saxofón Tenor Sib (Transpositor)',
        timestamp: DateTime(2026, 1, 1),
        totalNotes: 32,
        hitNotes: 30,
        pitchAccuracyPercentage: 95.4,
        averageCentsDeviation: 2.3,
        rhythmAccuracyPercentage: 91.2,
        averageTimingDeltaMs: -4.5,
        sustainAccuracyPercentage: 93.0,
        overallScore: 94.1,
        grade: PerformanceGrade.a,
        evaluations: const [],
        noteAccuracyMap: const {'C4': 96.0, 'E4': 88.0},
        criticalNotes: const ['E4'],
        masteredNotes: const ['C4'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PracticeReportModal(
              report: report,
              palette: TunnerThemePalette.obsidianStudio,
              onRetry: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
