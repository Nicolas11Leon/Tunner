import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_pitch_entity.dart';
import 'package:tunner/features/chord_analyzer/presentation/polyphonic_live_voicing_widget.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/pedagogy_report/presentation/pedagogical_report_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  test('US-6.2: currentPedagogicalSessionData no fabrica datos sinteticos sin sesiones previas', () {
    final vm = TunerViewModel(seedDefaults: false);
    final data = vm.currentPedagogicalSessionData;

    expect(data.totalEvaluatedNotes, 0);
    expect(data.tuningAccuracyPercentage, 0.0);
    expect(data.spectralCentroidHz, 0.0);
    expect(data.thdPercentage, 0.0);
    expect(data.harmonicRatios, isEmpty);
    vm.dispose();
  });

  testWidgets('US-6.2: PedagogicalReportModal inicializa el instrumento desde TunerViewModel.activeInstrument', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final vm = TunerViewModel(seedDefaults: false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    final targetInstrument = InstrumentProfileEntity.standardInstruments.last;
    vm.setInstrumentProfile(targetInstrument);

    await tester.pumpWidget(
      ChangeNotifierProvider<TunerViewModel>.value(
        value: vm,
        child: const MaterialApp(
          home: Scaffold(
            body: PedagogicalReportModal(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final field = tester.widget<TextFormField>(find.byKey(const Key('instrument_name_field')));
    expect(field.controller?.text, targetInstrument.name);
    vm.dispose();
  });

  testWidgets('US-6.2: PolyphonicLiveVoicingWidget renderiza barras H1-H8 con muestras DFT reales', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final vm = TunerViewModel(seedDefaults: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<TunerViewModel>.value(
        value: vm,
        child: MaterialApp(
          home: Scaffold(
            body: PolyphonicLiveVoicingWidget(
              analysisResult: PolyphonicMultiToneAnalysisResult.empty,
              palette: vm.currentPalette,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('H1'), findsOneWidget);
    expect(find.text('H8'), findsOneWidget);
    vm.dispose();
  });
}
