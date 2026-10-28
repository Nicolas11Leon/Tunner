import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/pedagogy_report/presentation/pedagogical_report_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';

class _FakePitchService implements IPitchDetectorService {
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

Widget createTestApp(TunerViewModel vm, {Widget? home}) {
  return ChangeNotifierProvider<TunerViewModel>.value(
    value: vm,
    child: MaterialApp(
      home: home ?? const Scaffold(body: PedagogicalReportModal()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;

  setUp(() {
    viewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      metronomeService: _FakeMetroService(),
    );
  });

  testWidgets('PedagogicalReportModal renders all metadata inputs, KPIs and section toggles', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Reporte Pedagógico y Certificado PDF'), findsOneWidget);
    expect(find.byKey(const Key('student_name_field')), findsOneWidget);
    expect(find.byKey(const Key('instrument_name_field')), findsOneWidget);
    expect(find.byKey(const Key('institution_field')), findsOneWidget);
    expect(find.byKey(const Key('teacher_name_field')), findsOneWidget);

    expect(find.byKey(const Key('toggle_intonation_graph')), findsOneWidget);
    expect(find.byKey(const Key('toggle_harmonics_histogram')), findsOneWidget);
    expect(find.byKey(const Key('toggle_rhythm_jitter')), findsOneWidget);
    expect(find.byKey(const Key('toggle_certificate')), findsOneWidget);

    expect(find.byKey(const Key('export_pedagogical_pdf_btn')), findsOneWidget);
  });

  testWidgets('User can edit student name and toggle certificate switch', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final studentField = find.byKey(const Key('student_name_field'));
    await tester.enterText(studentField, 'Laura Sofia Diaz');
    await tester.pump();

    expect(find.text('Laura Sofia Diaz'), findsOneWidget);

    final certSwitch = find.byKey(const Key('toggle_certificate'));
    await tester.ensureVisible(certSwitch);
    await tester.pump();

    await tester.tap(certSwitch);
    await tester.pump();

    final switchWidget = tester.widget<SwitchListTile>(certSwitch);
    expect(switchWidget.value, false);
  });

  testWidgets('Tapping export button compiles PDF and displays SnackBar with KB size', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final exportBtn = find.byKey(const Key('export_pedagogical_pdf_btn'));
    await tester.tap(exportBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Reporte PDF exportado exitosamente'), findsOneWidget);
  });

  testWidgets('TunerScreen displays open_pedagogical_report_chip and opens modal on tap', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel, home: const TunerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final reportChip = find.byKey(const Key('open_pedagogical_report_chip'));
    expect(reportChip, findsOneWidget);

    await tester.ensureVisible(reportChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(reportChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PedagogicalReportModal), findsOneWidget);
    expect(find.text('Reporte Pedagógico y Certificado PDF'), findsOneWidget);
  });
}
