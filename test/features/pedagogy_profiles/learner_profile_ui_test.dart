import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/pedagogy_profiles/domain/learner_profile_entity.dart';
import 'package:tunner/features/pedagogy_profiles/presentation/learner_profile_selector_modal.dart';
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
      home: home ?? const Scaffold(body: LearnerProfileSelectorModal()),
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

  testWidgets('LearnerProfileSelectorModal renders 3 philosophy cards and tolerance slider', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Perfil Pedagógico y Andamiaje'), findsOneWidget);
    expect(find.byKey(const Key('profile_child_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_adult_card')), findsOneWidget);
    expect(find.byKey(const Key('profile_conservatory_card')), findsOneWidget);
    expect(find.byKey(const Key('cents_tolerance_slider')), findsOneWidget);
  });

  testWidgets('Tapping child card activates childPlayful profile and sets tolerance to 25c', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final childCard = find.byKey(const Key('profile_child_card'));
    await tester.tap(childCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(viewModel.learnerProfile.type, LearnerProfileType.childPlayful);
    expect(viewModel.centsTolerance, 25.0);
    expect(viewModel.isSmartWaitEnabled, true);
  });

  testWidgets('Tapping conservatory card activates conservatoryMastery and sets tolerance to 5c', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final proCard = find.byKey(const Key('profile_conservatory_card'));
    await tester.tap(proCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(viewModel.learnerProfile.type, LearnerProfileType.conservatoryMastery);
    expect(viewModel.centsTolerance, 5.0);
  });

  testWidgets('TunerScreen displays open_learner_profile_chip and opens modal on tap', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(viewModel, home: const TunerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final profileChip = find.byKey(const Key('open_learner_profile_chip'));
    expect(profileChip, findsOneWidget);

    await tester.ensureVisible(profileChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(profileChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LearnerProfileSelectorModal), findsOneWidget);
    expect(find.text('Perfil Pedagógico y Andamiaje'), findsOneWidget);
  });
}
