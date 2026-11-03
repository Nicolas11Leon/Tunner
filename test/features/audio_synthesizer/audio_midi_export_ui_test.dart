import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';
import 'package:tunner/features/audio_synthesizer/presentation/audio_midi_export_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio & MIDI Stem Export UI Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
    });

    Widget createModalTestApp() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AudioMidiExportModal.show(context, viewModel),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
    }

    Widget createScreenTestApp() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: TunerScreen(),
        ),
      );
    }

    testWidgets('AudioMidiExportModal renders all switches, chips and generate button', (tester) async {
      await tester.pumpWidget(createModalTestApp());
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export_audio_midi_modal')), findsOneWidget);
      expect(find.text('Exportación de Stems & MIDI'), findsOneWidget);
      expect(find.byKey(const Key('export_switch_master')), findsOneWidget);
      expect(find.byKey(const Key('export_switch_stems')), findsOneWidget);
      expect(find.byKey(const Key('export_switch_midi')), findsOneWidget);
      expect(find.text('44.1 kHz'), findsOneWidget);
      expect(find.text('48.0 kHz'), findsOneWidget);
      expect(find.byKey(const Key('export_generate_btn')), findsOneWidget);
    });

    testWidgets('Tapping export_generate_btn synthesizes bundle and lists exported files', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createModalTestApp());
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('export_generate_btn')));
        while (viewModel.isExportingStems) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.lastExportBundle, isNotNull);
      expect(viewModel.lastExportBundle!.files.isNotEmpty, isTrue);

      expect(find.text('ARCHIVOS EXPORTADOS EN DISCO LOCAL', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('export_stem_item_0'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('Composition workspace displays export_stems_midi_btn and opens modal', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      viewModel.setWorkspace(WorkspaceType.composition);
      await tester.pumpWidget(createScreenTestApp());
      await tester.pumpAndSettle();

      final exportBtn = find.byKey(const Key('export_stems_midi_btn'));
      expect(exportBtn, findsOneWidget);

      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export_audio_midi_modal')), findsOneWidget);
      expect(find.text('Exportación de Stems & MIDI'), findsOneWidget);
    });
  });
}
