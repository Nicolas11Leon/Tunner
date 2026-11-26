import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/presentation/widgets/pitch_contour_blob_strip_widget.dart';
import 'package:tunner/features/tuner_screen.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-UX-06 Focused Tuner & Melodyne 5 Pitch Contour Blobs Tests', () {
    late _FakePitchService pitchService;
    late TunerViewModel viewModel;

    setUp(() {
      pitchService = _FakePitchService();
      viewModel = TunerViewModel(
        pitchService: pitchService,
        metronomeService: _FakeMetroService(),
      );
      addTearDown(viewModel.dispose);
    });

    Widget createTestApp() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: TunerScreen(),
        ),
      );
    }

    testWidgets(
      'PitchContourBlobStripWidget renders in Pro mode and displays live note, frequency and cents deviation',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('melodyne_pitch_contour_blob_strip')),
          findsOneWidget,
        );
        expect(
          find.text('CONTORNO TONAL & BLOBS (MELODYNE VIEW)'),
          findsOneWidget,
        );
        expect(find.byType(PitchContourBlobStripWidget), findsOneWidget);

        // Activar captura y simular detección de La4 (440.0 Hz)
        await tester.tap(find.byKey(const Key('pro_persistent_mic_toggle_btn')));
        await tester.pump();

        pitchService.onPitchDetected?.call(440.0);
        await tester.pump();

        final badgeText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('melodyne_blob_live_readout_badge')),
            matching: find.byType(Text),
          ),
        );
        expect(badgeText.data, contains('La4'));
        expect(badgeText.data, contains('440.0 Hz'));
        expect(badgeText.data, contains('+0.0 ct'));

        final blobCountText = tester.widget<Text>(
          find.byKey(const Key('melodyne_blob_count_text')),
        );
        expect(blobCountText.data, equals('Blobs: 1'));

        await tester.pump(const Duration(milliseconds: 360));
      },
    );

    testWidgets(
      'tuner_toggle_melodyne_blobs_btn toggles blob strip visibility and btn_clear_pitch_blobs clears blob queue',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Activar captura y registrar 2 muestras
        await tester.tap(find.byKey(const Key('pro_persistent_mic_toggle_btn')));
        await tester.pump();
        pitchService.onPitchDetected?.call(440.0);
        await tester.pump();
        pitchService.onPitchDetected?.call(442.0);
        await tester.pump();

        expect(
          tester
              .widget<Text>(find.byKey(const Key('melodyne_blob_count_text')))
              .data,
          equals('Blobs: 2'),
        );

        // Limpiar cola de blobs con btn_clear_pitch_blobs
        await tester.tap(find.byKey(const Key('btn_clear_pitch_blobs')));
        await tester.pump();

        expect(
          tester
              .widget<Text>(find.byKey(const Key('melodyne_blob_count_text')))
              .data,
          equals('Blobs: 0'),
        );

        // Ocultar tira de blobs con tuner_toggle_melodyne_blobs_btn
        await tester
            .tap(find.byKey(const Key('tuner_toggle_melodyne_blobs_btn')));
        await tester.pump();

        expect(
          find.byKey(const Key('melodyne_pitch_contour_blob_strip')),
          findsNothing,
        );

        // Volver a mostrar tira de blobs
        await tester
            .tap(find.byKey(const Key('tuner_toggle_melodyne_blobs_btn')));
        await tester.pump();

        expect(
          find.byKey(const Key('melodyne_pitch_contour_blob_strip')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 360));
      },
    );

    testWidgets(
      'Ergonomic quick tools menu button is present and opens low-entropy categorized DSP options in Pro mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 100));

        final menuBtn =
            find.byKey(const Key('tuner_ergonomic_quick_tools_menu_btn'));
        expect(menuBtn, findsOneWidget);
        expect(find.text('Herramientas Rápidas DSP'), findsOneWidget);

        await tester.tap(menuBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.text('DSP · Calibración y Rigor de Micrófono'),
          findsOneWidget,
        );
        expect(
          find.text('Afinación · Temperamentos Históricos (12-EDO)'),
          findsOneWidget,
        );
        expect(
          find.text('Referencia · Dron Armónico de Pedal'),
          findsOneWidget,
        );
      },
    );
  });
}
