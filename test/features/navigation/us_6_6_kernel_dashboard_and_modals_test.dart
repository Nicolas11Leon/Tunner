import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_device_matrix_port.dart';
import 'package:tunner/core/design_system/organisms/studio_desktop_app_shell.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/dsl/domain/i_synth_voice_pool_port.dart';
import 'package:tunner/core/file_system/data/memory_studio_file_system_repository.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/terminal/domain/i_terminal_feature_ports.dart';
import 'package:tunner/features/drone/presentation/harmonic_drone_modal.dart';
import 'package:tunner/features/exercise_generator/domain/algorithmic_exercise_generator.dart';
import 'package:tunner/features/exercise_generator/presentation/exercise_generator_modal.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/navigation/presentation/home_dashboard_screen.dart';
import 'package:tunner/features/navigation/presentation/tool_search_modal.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

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

class _FakeProjectPort implements ITerminalProjectPort {
  @override
  String get activeTitle => 'Obra Test';

  @override
  String get activeComposer => 'Compositor';

  @override
  int get bpm => 100;

  @override
  void updateBpm(int newBpm) {}

  @override
  Uint8List exportCurrentProjectToTunner({String? projectTitle}) {
    return Uint8List.fromList([1, 2, 3, 4, 5]);
  }
}

class _FakeSynthPool implements ISynthVoicePoolPort {
  @override
  int get maxPolyphony => 8;
  @override
  int get activeVoiceCount => 0;
  @override
  String get dslWaveformName => 'sine';
  @override
  double attackSeconds = 0.01;
  @override
  double decaySeconds = 0.1;
  @override
  double sustainLevel = 0.8;
  @override
  double releaseSeconds = 0.2;
  @override
  double get masterGain => 1.0;

  @override
  void setDslWaveform(DslSynthWaveform value) {}

  @override
  void noteOn(int midiNote, double velocity, {double? frequency}) {}

  @override
  void noteOff(int midiNote) {}

  @override
  void panic() {}
}

class _FakeVocalPort implements ITerminalVocalPedagogyPort {
  List<double> lastEvaluatedFrequencies = const [];

  @override
  TerminalVocalEvalSnapshot evaluate({
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  }) {
    lastEvaluatedFrequencies = frequenciesHz;
    return TerminalVocalEvalSnapshot(
      evaluationId: 'eval-1',
      targetFrequencyHz: targetFrequencyHz,
      measuredMeanFrequencyHz: frequenciesHz.first,
      centsDeviation: 0.0,
      jitterPercent: 0.2,
      shimmerPercent: 0.5,
      vibratoRateHz: 5.0,
      vibratoDepthCents: 15.0,
      overallScore: 96.0,
      classificationLabel: 'Excelente',
      payloadHashSha256: 'abc123',
    );
  }

  @override
  Uint8List generateCertificatePdf({
    required String studentName,
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  }) {
    return Uint8List.fromList('%PDF-1.4 $studentName'.codeUnits);
  }
}

class _FakeMatrixPort implements IStudioAudioDeviceMatrixPort {
  @override
  AudioDeviceMatrixEntity matrix;

  _FakeMatrixPort(this.matrix);

  @override
  void restoreMatrix(AudioDeviceMatrixEntity savedMatrix) {
    matrix = savedMatrix;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-6.6: TunnerOsKernel, Dashboard HUD/Templates, ToolSearchModal y ExerciseGenerator', () {
    test('TunnerOsKernel persiste project export y vocal cert en fileSystemRepository y dispara onTriggerSynthNote',
        () async {
      final fs = MemoryStudioFileSystemRepository();
      final synthPool = _FakeSynthPool();
      final vocalPort = _FakeVocalPort();
      int? triggeredMidi;

      final kernel = TunnerOsKernel(
        fileSystemRepository: fs,
        synthVoicePool: synthPool,
        projectPort: _FakeProjectPort(),
        vocalEvaluator: vocalPort,
        onTriggerSynthNote: (midi, vel) async {
          triggeredMidi = midi;
        },
        onReadCapturedFrequencies: () => List<double>.filled(12, 440.0),
        onReadCapturedAmplitudes: () => List<double>.filled(12, 0.9),
      );

      final synthRes = await kernel.execute('synth note A4 0.8');
      expect(synthRes.isSuccess, isTrue);
      expect(triggeredMidi, 69);

      final exportRes = await kernel.execute('project export "Mi Obra"');
      expect(exportRes.isSuccess, isTrue);
      final exportedBytes = await fs.readFile('exports/Mi_Obra.tunner');
      expect(exportedBytes, equals(Uint8List.fromList([1, 2, 3, 4, 5])));

      final evalRes = await kernel.execute('vocal eval 440');
      expect(evalRes.isSuccess, isTrue);
      expect(vocalPort.lastEvaluatedFrequencies.length, 12);

      final certRes = await kernel.execute('vocal cert "Ana" 440');
      expect(certRes.isSuccess, isTrue);
      final pdfBytes = await fs.readFile('certificates/Ana_vocal_cert.pdf');
      expect(pdfBytes.isNotEmpty, isTrue);
    });

    testWidgets('HomeDashboardScreen muestra telemetria dinamica de matriz y template_dj_elisa dispara callback',
        (tester) async {
      final matrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        bufferSize: 512,
        sampleRate: 48000,
      );
      final vm = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
        audioDeviceMatrixService: _FakeMatrixPort(matrix),
      );
      addTearDown(vm.dispose);

      String? loadedDeck;
      String? loadedSong;
      int? navigatedTab;

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: HomeDashboardScreen(
              onNavigateToTab: (tab) => navigatedTab = tab,
              onLoadDjTemplate: (deck, key) {
                loadedDeck = deck;
                loadedSong = key;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Buffer: 512 (10.7 ms)'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('template_dj_elisa')));
      await tester.tap(find.byKey(const Key('template_dj_elisa')));
      await tester.pump();

      expect(loadedDeck, 'A');
      expect(loadedSong, 'elisa');
      expect(vm.bpm, 126);
      expect(navigatedTab, 5);
    });

    testWidgets('StudioDesktopAppShell renderiza bufferLatencyLabel dinamico', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(initialTokens: StudioDesignTokens.studioDark),
          child: MaterialApp(
            home: StudioDesktopAppShell(
              currentBreadcrumb: 'Inicio',
              navigationSections: const [],
              activeItemId: 'home',
              activeView: const SizedBox(),
              onOpenSearch: () {},
              onOpenShortcuts: () {},
              bufferLatencyLabel: 'BUFFER: 512 • LATENCIA: 10.7 ms (48.0 kHz)',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('BUFFER: 512 • LATENCIA: 10.7 ms (48.0 kHz)'), findsOneWidget);
    });

    testWidgets('ToolSearchModal abre HarmonicDroneModal y SpectralComparatorModal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ToolSearchModal.show(context, vm),
                  child: const Text('Buscar'),
                ),
              ),
            ),
          ),
        ),
      );

      // Abrir buscador y lanzar Dron Armonico
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Dron');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tool_search_item_harmonic_drone')));
      await tester.pumpAndSettle();
      expect(find.byType(HarmonicDroneModal), findsOneWidget);

      // Cerrar modal de Dron y probar Comparador Espectral
      Navigator.of(tester.element(find.byType(HarmonicDroneModal))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Comparador');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tool_search_item_spectral_comparator')));
      await tester.pumpAndSettle();
      expect(find.byType(SpectralComparatorModal), findsOneWidget);
    });

    testWidgets('ExerciseGeneratorModal incluye half/whole, registra en workspaceScores y navega a Tab 4',
        (tester) async {
      final vm = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetroService(),
      );
      addTearDown(vm.dispose);
      int? navigatedTab;

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ExerciseGeneratorModal.show(
                    context,
                    onNavigateToTab: (tab) => navigatedTab = tab,
                  ),
                  child: const Text('Generador'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Generador'));
      await tester.pumpAndSettle();

      expect(find.text(ExerciseRhythm.half.displayName), findsOneWidget);
      expect(find.text(ExerciseRhythm.whole.displayName), findsOneWidget);

      await tester.ensureVisible(find.text(ExerciseRhythm.half.displayName));
      await tester.tap(find.text(ExerciseRhythm.half.displayName));
      await tester.pump();
      await tester.ensureVisible(find.text('Generar y Cargar en Atril'));
      await tester.tap(find.text('Generar y Cargar en Atril'));
      await tester.pumpAndSettle();

      expect(vm.workspaceScores.isNotEmpty, isTrue);
      expect(vm.workspaceScores.first.id, vm.activePackage.id);
      expect(navigatedTab, 4);
    });
  });
}
