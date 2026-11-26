import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-HC-04: Inyección real de activePackage desde TunerViewModel a DjStudioWorkstationView', () {
    late StudioPatchbayRoutingService routingService;

    setUp(() {
      routingService = StudioPatchbayRoutingService();
      routingService.resetToDefaults();
    });

    tearDown(() {
      routingService.resetToDefaults();
    });

    testWidgets(
      '1. Inyecta activePackage, BPM y notas reales desde TunerViewModel en canal_a y Deck A',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final tunerVm = TunerViewModel();
        await tunerVm.loadPersistedState();
        final djVm = DjConsoleViewModel();
        addTearDown(() {
          djVm.dispose();
          tunerVm.dispose();
        });

        final customPackage = SongPackage(
          id: 'pkg_estudio_coral_re',
          title: 'Estudio Coral en Re',
          composer: 'Compositor de Prueba',
          genre: MusicGenre.classical,
          difficulty: SongDifficulty.intermediate,
          defaultBpm: 136,
          score: HierarchicalScore(
            title: 'Estudio Coral en Re',
            baseBpm: 136,
            measures: [
              MeasureEntity(
                index: 0,
                timeSignature: TimeSignature.commonTime44,
                notes: [
                  HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Re4'),
                  HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Fa#4'),
                  HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'La4'),
                ],
              ),
            ],
          ),
          tracks: const [],
        );
        tunerVm.loadSongPackage(customPackage);

        Map<String, dynamic>? capturedSignalPayload;
        routingService.registerPlug(
          const StudioModularPlug(
            id: 'test_canal_a_observer',
            label: 'OBSERVER',
            toolId: 'test_observer',
            type: StudioPlugType.audioInput,
            connectedChannelId: 'canal_a',
          ),
        );
        routingService.registerSinkListener('test_canal_a_observer', (sourceId, channelId, payload) {
          if (sourceId == 'plug_score_melody_out') {
            capturedSignalPayload = payload;
          }
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<TunerViewModel>.value(
            value: tunerVm,
            child: MaterialApp(
              home: DjStudioWorkstationView(
                viewModel: djVm,
                initialViewMode: 'modular',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final injectBtn = find.byKey(const Key('inject_score_melody_btn'));
        expect(injectBtn, findsOneWidget);
        await tester.ensureVisible(injectBtn);
        await tester.tap(injectBtn);
        await tester.pumpAndSettle();

        final canalA = routingService.matrix.channels['canal_a']!;
        expect(canalA.activeTrackTitle, 'Partitura: Estudio Coral en Re');
        expect(canalA.activeBpm, 136.0);
        expect(canalA.activeCamelotKey, '8B');

        expect(capturedSignalPayload, isNotNull);
        expect(capturedSignalPayload!['title'], 'Partitura: Estudio Coral en Re');
        expect(capturedSignalPayload!['bpm'], 136.0);
        expect(capturedSignalPayload!['notes'], ['Re4', 'Fa#4', 'La4']);

        expect(djVm.deckA.trackTitle, 'Partitura: Estudio Coral en Re');
        expect(djVm.deckA.bpm, 136.0);
      },
    );

    testWidgets(
      '2. Mantiene fallback Sonata No. 1 a 120.0 BPM cuando no existe Provider<TunerViewModel>',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final djVm = DjConsoleViewModel();
        addTearDown(djVm.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: DjStudioWorkstationView(
              viewModel: djVm,
              initialViewMode: 'modular',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final injectBtn = find.byKey(const Key('inject_score_melody_btn'));
        expect(injectBtn, findsOneWidget);
        await tester.ensureVisible(injectBtn);
        await tester.tap(injectBtn);
        await tester.pumpAndSettle();

        final canalA = routingService.matrix.channels['canal_a']!;
        expect(canalA.activeTrackTitle, 'Partitura: Sonata No. 1 en C Mayor');
        expect(canalA.activeBpm, 120.0);

        expect(djVm.deckA.trackTitle, 'Partitura: Sonata No. 1 en C Mayor');
        expect(djVm.deckA.bpm, 120.0);
      },
    );
  });
}
