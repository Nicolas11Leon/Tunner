import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/atoms/studio_icon.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/ear_training/domain/musical_interval.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/presentation/controllers/tuner_calibration_and_drone_helper.dart';
import 'package:tunner/features/tuner/presentation/modals/tuner_instrument_modal.dart';
import 'package:tunner/features/tuner/presentation/modals/tuner_library_modal.dart';
import 'package:tunner/features/tuner/presentation/modals/tuner_mixer_modal.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';

class _TestPitchService extends IPitchDetectorService {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> startRecording() async {
    startCount++;
  }

  @override
  Future<void> stopRecording() async {
    stopCount++;
  }
}

Widget _wrapWithStudioTheme(Widget child) {
  final controller = StudioThemeController(
    initialTokens: StudioDesignTokens.studioOledMonochrome,
  );
  return StudioThemeScope(
    controller: controller,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-9.3 Extracted Tuner Modals (StudioThemeScope + StudioIcon)', () {
    testWidgets('TunerLibraryModal renders curated repertoire and loads package', (tester) async {
      final vm = TunerViewModel(pitchService: _TestPitchService());
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _wrapWithStudioTheme(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TunerLibraryModal.show(context, vm),
              child: const Text('Open Library'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Library'));
      await tester.pumpAndSettle();

      expect(find.text('BIBLIOTECA & DESCOMPOSITOR'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);

      if (vm.curatedLibrary.length > 1) {
        final secondPkg = vm.curatedLibrary[1];
        await tester.tap(find.byKey(Key('load_song_pkg_btn_${secondPkg.id}')));
        await tester.pumpAndSettle();
        expect(vm.activePackage.id, equals(secondPkg.id));
      }
    });

    testWidgets('TunerMixerModal toggles mute and solo on metronome track', (tester) async {
      final vm = TunerViewModel(pitchService: _TestPitchService());
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _wrapWithStudioTheme(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TunerMixerModal.show(context, vm),
              child: const Text('Open Mixer'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Mixer'));
      await tester.pumpAndSettle();

      expect(find.text('CONSOLA MEZCLADORA (STEMS)'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);

      expect(vm.mixerConsole.metronomeTrack.isMuted, isFalse);
      await tester.tap(find.byKey(const Key('mixer_mute_btn_metronome')));
      await tester.pump();
      expect(vm.mixerConsole.metronomeTrack.isMuted, isTrue);

      await tester.tap(find.byKey(const Key('mixer_solo_btn_metronome')));
      await tester.pump();
      expect(vm.mixerConsole.metronomeTrack.isSolo, isTrue);
    });

    testWidgets('TunerInstrumentModal preserves keys and toggles smart instrument controls', (tester) async {
      final vm = TunerViewModel(pitchService: _TestPitchService());
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _wrapWithStudioTheme(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TunerInstrumentModal.show(context, vm),
              child: const Text('Open Instrument'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Instrument'));
      await tester.pumpAndSettle();

      expect(find.text('SELECTOR DE INSTRUMENTO'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
      expect(find.byKey(const Key('toggle_smart_instrument_switch')), findsOneWidget);
      expect(find.byKey(const Key('transpose_score_btn_piccolo')), findsOneWidget);

      await tester.tap(find.byKey(const Key('toggle_smart_instrument_switch')));
      await tester.pump();

      expect(vm.isSmartInstrumentTuningActive, isTrue);
      expect(find.byKey(const Key('auto_switch_instrument_checkbox')), findsOneWidget);
    });
  });

  group('US-9.3 Calibration Helper, Real DC Offset & Dispose Guard', () {
    test('computeDcOffset calculates exact arithmetic mean of PCM samples', () {
      expect(TunerCalibrationAndDroneHelper.computeDcOffset(null), equals(0.0));
      expect(TunerCalibrationAndDroneHelper.computeDcOffset(const []), equals(0.0));
      expect(
        TunerCalibrationAndDroneHelper.computeDcOffset(const [0.10, 0.20, 0.30, 0.20]),
        closeTo(0.20, 1e-9),
      );
      expect(
        TunerCalibrationAndDroneHelper.computeDcOffset(const [-0.05, 0.05, -0.05, 0.05]),
        closeTo(0.0, 1e-9),
      );
    });

    test('calibrateAmbientNoiseFloor measures real DC offset from captured audio windows', () async {
      final pitchService = _TestPitchService();
      final vm = TunerViewModel(pitchService: pitchService);
      addTearDown(vm.dispose);

      final future = vm.calibrateAmbientNoiseFloor(
        calibrationDuration: const Duration(milliseconds: 30),
      );

      // Simular señal entrante con sesgo DC positivo (+0.125) y RMS ambiental 0.01
      pitchService.onRmsLevelChanged?.call(0.010);
      pitchService.onRmsLevelChanged?.call(0.014);
      pitchService.onAudioWindowCaptured?.call(const [0.10, 0.15, 0.10, 0.15]);

      await future;

      final report = vm.lastNoiseReport;
      expect(report, isNotNull);
      expect(report!.meanRms, closeTo(0.012, 1e-6));
      expect(report.peakRms, closeTo(0.014, 1e-6));
      expect(report.detectedDcOffset, closeTo(0.125, 1e-6));
      expect(report.totalFramesAnalyzed, equals(2));
      expect(vm.isCalibratingNoiseFloor, isFalse);
      expect(pitchService.startCount, equals(1));
      expect(pitchService.stopCount, equals(1));
    });

    test('calibrateAmbientNoiseFloor falls back to latestAudioSamples when no new window arrives', () async {
      final pitchService = _TestPitchService();
      final vm = TunerViewModel(pitchService: pitchService);
      addTearDown(vm.dispose);

      // Precargar ventana PCM previa en latestAudioSamples con DC offset -0.04
      pitchService.onAudioWindowCaptured?.call(const [-0.02, -0.06, -0.04, -0.04]);

      final future = vm.calibrateAmbientNoiseFloor(
        calibrationDuration: const Duration(milliseconds: 20),
      );
      pitchService.onRmsLevelChanged?.call(0.006);
      await future;

      expect(vm.lastNoiseReport, isNotNull);
      expect(vm.lastNoiseReport!.detectedDcOffset, closeTo(-0.04, 1e-6));
    });

    test('calibrateAmbientNoiseFloor aborts safely when ViewModel is disposed mid-calibration', () async {
      final pitchService = _TestPitchService();
      final vm = TunerViewModel(pitchService: pitchService);

      final future = vm.calibrateAmbientNoiseFloor(
        calibrationDuration: const Duration(milliseconds: 30),
      );

      vm.dispose();
      await expectLater(future, completes);
      expect(vm.lastNoiseReport, isNull);
      expect(pitchService.stopCount, greaterThanOrEqualTo(1));
    });

    test('mapIntervalToEbbinghausId maps all musical intervals deterministically', () {
      for (final interval in MusicalInterval.values) {
        final id = TunerCalibrationAndDroneHelper.mapIntervalToEbbinghausId(interval);
        expect(id, startsWith('interval_'));
      }
      expect(
        TunerCalibrationAndDroneHelper.mapIntervalToEbbinghausId(MusicalInterval.perfectFifth),
        equals('interval_P5'),
      );
    });
  });

  group('US-9.3 UniversalInstrumentDefinition A4-Scaled Tunings', () {
    test('standardTuningFrequenciesFor(referencePitchHz: 442.0) scales frequencies proportionally', () {
      final base = UniversalInstrumentDefinition.violin.standardTuningFrequenciesFor();
      final symphonic = UniversalInstrumentDefinition.violin.standardTuningFrequenciesFor(
        referencePitchHz: 442.0,
      );

      expect(base, equals([196.00, 293.66, 440.00, 659.25]));
      expect(symphonic.length, equals(4));

      const scale = 442.0 / 440.0;
      expect(symphonic[0], closeTo(196.00 * scale, 1e-6));
      expect(symphonic[1], closeTo(293.66 * scale, 1e-6));
      expect(symphonic[2], closeTo(442.00, 1e-6));
      expect(symphonic[3], closeTo(659.25 * scale, 1e-6));
    });

    test('standardTuningFrequenciesFor returns empty list when instrument has no open strings', () {
      expect(
        UniversalInstrumentDefinition.fluteConcert.standardTuningFrequenciesFor(
          referencePitchHz: 442.0,
        ),
        isEmpty,
      );
    });

    test('standardTuningFrequenciesFor rejects non-positive reference pitch', () {
      expect(
        () => UniversalInstrumentDefinition.violin.standardTuningFrequenciesFor(
          referencePitchHz: 0.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => UniversalInstrumentDefinition.violin.standardTuningFrequenciesFor(
          referencePitchHz: -440.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
