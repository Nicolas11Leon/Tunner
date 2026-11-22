import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/navigation/presentation/home_dashboard_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/features/audio_synthesizer/data/audio_synthesizer_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late MemoryStudioAudioEngine memoryEngine;

  setUp(() {
    memoryEngine = MemoryStudioAudioEngine();
    viewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      audioSynthesizerService: AudioSynthesizerService(audioEngine: memoryEngine),
      seedDefaults: true,
    );
  });

  Widget buildWidget({
    required void Function(int) onNavigate,
    VoidCallback? onOpenTerminal,
    double width = 1200,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: SizedBox(
          width: width,
          height: 900,
          child: HomeDashboardScreen(
            onNavigateToTab: onNavigate,
            onOpenTerminal: onOpenTerminal,
          ),
        ),
      ),
    );
  }

  group('HomeDashboardScreen Pro Studio Hub UI Tests', () {
    testWidgets('Renders Core Audio Telemetry HUD with terminal button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool terminalOpened = false;

      await tester.pumpWidget(
        buildWidget(
          onNavigate: (_) {},
          onOpenTerminal: () => terminalOpened = true,
          width: 1200,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_core_audio_hud')), findsOneWidget);
      expect(find.textContaining('CORE AUDIO DSP:'), findsOneWidget);
      expect(find.textContaining('48.0 kHz • 24-bit'), findsOneWidget);

      final terminalBtn = find.byKey(const Key('home_open_terminal_hud_btn'));
      expect(terminalBtn, findsOneWidget);

      await tester.ensureVisible(terminalBtn);
      await tester.tap(terminalBtn);
      await tester.pump();
      expect(terminalOpened, isTrue);
    });

    testWidgets('Renders 5 main module cards including DJ Console', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWidget(
          onNavigate: (_) {},
          width: 1200,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_action_tuner')), findsOneWidget);
      expect(find.byKey(const Key('card_action_lessons')), findsOneWidget);
      expect(find.byKey(const Key('card_action_recorder')), findsOneWidget);
      expect(find.byKey(const Key('card_action_library')), findsOneWidget);
      expect(find.byKey(const Key('card_action_dj')), findsOneWidget);
    });

    testWidgets('Renders 4 quick starter project templates', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? navigatedTab;

      await tester.pumpWidget(
        buildWidget(
          onNavigate: (tab) => navigatedTab = tab,
          width: 1200,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('template_score_bach')), findsOneWidget);
      expect(find.byKey(const Key('template_dj_elisa')), findsOneWidget);
      expect(find.byKey(const Key('template_take_acoustic')), findsOneWidget);
      expect(find.byKey(const Key('template_preset_philharmonic')), findsOneWidget);

      // Tapping DJ template navigates to DJ Console tab 5
      await tester.ensureVisible(find.byKey(const Key('template_dj_elisa')));
      await tester.tap(find.byKey(const Key('template_dj_elisa')));
      await tester.pumpAndSettle();
      expect(navigatedTab, 5);
    });

    testWidgets('Workspace defaults seed scores and presets without fake recordings', (tester) async {
      expect(viewModel.workspaceScores.isNotEmpty, isTrue);
      expect(viewModel.recordingHistory, isEmpty);
      expect(viewModel.customTuningPresets.isNotEmpty, isTrue);
    });
  });
}
