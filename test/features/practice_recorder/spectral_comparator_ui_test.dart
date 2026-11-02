import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/practice_recorder/domain/spectral_comparator_service.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recorder_dock.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_modal.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_painter.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;

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

  late _FakePitchService pitchService;
  late TunerViewModel viewModel;

  setUp(() {
    pitchService = _FakePitchService();
    viewModel = TunerViewModel(
      pitchService: pitchService,
      metronomeService: _FakeMetroService(),
    );
  });

  group('SpectralComparatorPainter Tests', () {
    test('renders without throwing exceptions on canvas', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 300);

      const comparison = SpectralComparisonResult(
        takeAId: 'take_1',
        takeAName: 'Toma 1',
        takeBId: 'take_2',
        takeBName: 'Toma 2',
        meanPitchDeviationA: 12.0,
        meanPitchDeviationB: 3.0,
        pitchStabilityDelta: 9.0,
        inTunePercentageA: 20.0,
        inTunePercentageB: 85.0,
        meanCentroidA: 1100.0,
        meanCentroidB: 1350.0,
        centroidDeltaHz: 250.0,
        comparisonPoints: [
          SpectralComparisonPoint(timeMs: 0, centsA: 10.0, centsB: 2.0, centroidA: 1100.0, centroidB: 1350.0),
          SpectralComparisonPoint(timeMs: 100, centsA: -8.0, centsB: 1.0, centroidA: 1120.0, centroidB: 1360.0),
        ],
        pedagogicalSummary: 'Mejora notable de afinación.',
      );

      final painter = SpectralComparatorPainter(
        comparison: comparison,
        palette: TunnerThemePalette.obsidianStudio,
        currentPlaybackPositionNormalized: 0.5,
      );

      expect(() => painter.paint(canvas, size), returnsNormally);
    });
  });

  group('SpectralComparatorModal UI Tests', () {
    testWidgets('renders header, metric cards, pedagogical summary and audition buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpectralComparatorModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('COMPARADOR ESPECTRAL DE TOMAS'), findsOneWidget);
      expect(find.text('DELTA AFINACIÓN'), findsOneWidget);
      expect(find.text('AFINACIÓN PURA (±5c)'), findsOneWidget);
      expect(find.text('DELTA BRILLO (Hz)'), findsOneWidget);

      // Botones de audición A/B
      expect(find.byKey(const Key('audition_take_a_btn')), findsOneWidget);
      expect(find.byKey(const Key('audition_take_b_btn')), findsOneWidget);

      // Simular toque de audición Toma A
      await tester.tap(find.byKey(const Key('audition_take_a_btn')));
      await tester.pump();

      // Cerrar modal
      expect(find.byKey(const Key('close_spectral_comparator_btn')), findsOneWidget);
    });
  });

  group('PracticeRecorderDock & TunerScreen Comparator Integration Tests', () {
    testWidgets('PracticeRecorderDock open_spectral_comparator_btn opens comparator modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const Scaffold(
              body: Center(child: PracticeRecorderDock()),
            ),
          ),
        ),
      );
      await tester.pump();

      final openBtn = find.byKey(const Key('open_spectral_comparator_btn'));
      expect(openBtn, findsOneWidget);

      await tester.tap(openBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('COMPARADOR ESPECTRAL DE TOMAS'), findsOneWidget);
    });

    testWidgets('TunerScreen pedagogical chip opens spectral comparator modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      final compChip = find.byKey(const Key('open_spectral_comparator_chip'));
      expect(compChip, findsOneWidget);

      await tester.ensureVisible(compChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(compChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('COMPARADOR ESPECTRAL DE TOMAS'), findsOneWidget);
    });

    testWidgets('TunerViewModel manages multi-track takes, solo, mute and gain reactively', (tester) async {
      final initialTakesCount = viewModel.multiTrackSession.takes.length;

      final newTake = PracticeTakeEntity(
        id: 'new_take_3',
        name: 'Toma 3 (Ensayo Final)',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 5),
        filePath: '',
      );

      viewModel.addPracticeTake(newTake);
      expect(viewModel.multiTrackSession.takes.length, equals(initialTakesCount + 1));
      expect(viewModel.multiTrackSession.selectedTakeBId, equals('new_take_3'));

      // Probar selección de tomas A y B
      viewModel.selectComparisonTakes(takeAId: 'take_1', takeBId: 'new_take_3');
      expect(viewModel.multiTrackSession.selectedTakeAId, equals('take_1'));
      expect(viewModel.multiTrackSession.selectedTakeBId, equals('new_take_3'));

      // Probar Mute y Solo
      viewModel.setTakeMute('new_take_3', true);
      expect(viewModel.multiTrackSession.takes.firstWhere((t) => t.id == 'new_take_3').isMuted, isTrue);

      viewModel.setTakeSolo('new_take_3', true);
      expect(viewModel.multiTrackSession.takes.firstWhere((t) => t.id == 'new_take_3').isSolo, isTrue);

      viewModel.setTakeGain('new_take_3', 0.85);
      expect(viewModel.multiTrackSession.takes.firstWhere((t) => t.id == 'new_take_3').gain, closeTo(0.85, 0.001));
    });
  });
}
