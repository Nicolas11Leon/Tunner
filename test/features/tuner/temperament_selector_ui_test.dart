import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/tuner/presentation/temperament_selector_modal.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';

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

  group('Historical Temperaments UI and Integration Tests', () {
    test('AppUserSettingsEntity serializes and restores temperament configuration', () {
      final settings = AppUserSettingsEntity(
        selectedTemperamentId: 'werckmeister_iii',
        temperamentRootKey: 2,
      );
      final map = settings.toMap();
      expect(map['selectedTemperamentId'], equals('werckmeister_iii'));
      expect(map['temperamentRootKey'], equals(2));

      final restored = AppUserSettingsEntity.fromMap(map);
      expect(restored.selectedTemperamentId, equals('werckmeister_iii'));
      expect(restored.temperamentRootKey, equals(2));
    });

    testWidgets('TemperamentSelectorModal displays list and allows selecting temperament and root note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: const TemperamentSelectorModal(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("TEMPERAMENTOS HISTÓRICOS"), findsOneWidget);
      expect(find.text("TÓNICA / NOTA FUNDAMENTAL"), findsOneWidget);
      expect(find.text("Temperamento Igual (12-EDO)"), findsOneWidget);
      expect(find.text("Pitagórico (Pythagorean)"), findsOneWidget);

      // Seleccionar Pitagórico
      await tester.tap(find.byKey(const Key('temperament_card_pythagorean')));
      await tester.pump();
      expect(viewModel.selectedTemperament.id, equals('pythagorean'));

      // Cambiar tónica a Re
      await tester.tap(find.text("Re"));
      await tester.pump();
      expect(viewModel.temperamentRootKey, equals(2));
    });

    testWidgets('TunerScreen displays temperament chip and opens modal upon tap', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: viewModel,
          child: const MaterialApp(
            home: TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Chip visible en Modo Conservatorio Pro
      expect(find.byKey(const Key('pro_temperament_selector_chip')), findsOneWidget);
      expect(find.text("12-EDO"), findsWidgets);

      // Tocar chip de temperamento para abrir el modal
      await tester.tap(find.byKey(const Key('pro_temperament_selector_chip')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TemperamentSelectorModal), findsOneWidget);
      expect(find.text("TEMPERAMENTOS HISTÓRICOS"), findsOneWidget);

      // Cerrar modal
      Navigator.of(tester.element(find.byType(TemperamentSelectorModal))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TemperamentSelectorModal), findsNothing);
    });

    testWidgets('Tuning evaluation reflects historical microtonal cents target', (tester) async {
      // Activar Entonación Justa con tónica Do (0)
      viewModel.setTemperament('just_intonation');
      viewModel.setTemperamentRoot(0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Simular detección de Mi4 exacta a 329.63 Hz (frecuencia de Temperamento Igual)
      // En Equal, 329.63 Hz tiene 0 cents.
      // En Just Intonation, Mi4 pura (5:4 sobre Do) tiene objetivo a 327.03 Hz (-13.69 cents).
      // Por ende, una nota tocada a 329.63 Hz en Just Intonation está alta (+13.69 cents respecto al objetivo puro).
      pitchService.onPitchDetected?.call(329.63);
      await tester.pump();

      expect(viewModel.noteName, equals("Mi4"));
      expect(viewModel.cents, closeTo(13.69, 0.5));

      // Esperar que el temporizador de silencio termine limpiamente
      await tester.pump(const Duration(milliseconds: 70));
    });
  });
}
