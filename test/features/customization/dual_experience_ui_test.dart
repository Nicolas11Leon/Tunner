import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
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

  group('Dual Experience Mode Tests', () {
    test('AppUserSettingsEntity serializes and deserializes AppDisplayMode properly', () {
      final settings = AppUserSettingsEntity(
        displayMode: AppDisplayMode.essential,
      );
      final map = settings.toMap();
      expect(map['displayMode'], equals('essential'));

      final restored = AppUserSettingsEntity.fromMap(map);
      expect(restored.displayMode, equals(AppDisplayMode.essential));

      final proSettings = AppUserSettingsEntity(
        displayMode: AppDisplayMode.conservatoryPro,
      );
      final proMap = proSettings.toMap();
      expect(proMap['displayMode'], equals('conservatoryPro'));

      final proRestored = AppUserSettingsEntity.fromMap(proMap);
      expect(proRestored.displayMode, equals(AppDisplayMode.conservatoryPro));
    });

    testWidgets('TunerScreen toggles between Conservatory Pro and Essential modes smoothly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Estado inicial: Modo Conservatorio Pro
      expect(find.text("Tunner Pro: Studio Pitch & Sheet Lab"), findsOneWidget);
      expect(find.byKey(const Key('toggle_essential_mode_btn')), findsOneWidget);

      // Cambiar a Modo Esencial
      await tester.tap(find.byKey(const Key('toggle_essential_mode_btn')));
      await tester.pump();

      expect(viewModel.isEssentialMode, isTrue);
      expect(find.text("Tunner (Modo Esencial)"), findsOneWidget);
      expect(find.byKey(const Key('essential_note_display')), findsOneWidget);
      expect(find.byKey(const Key('essential_mic_toggle_btn')), findsOneWidget);
      expect(find.byKey(const Key('essential_switch_to_pro_card')), findsOneWidget);

      // Simular cambio a Modo Pro desde la tarjeta inferior
      await tester.tap(find.byKey(const Key('essential_switch_to_pro_card')));
      await tester.pump();

      expect(viewModel.isEssentialMode, isFalse);
      expect(find.text("Tunner Pro: Studio Pitch & Sheet Lab"), findsOneWidget);
    });

    testWidgets('Essential mode correctly reflects detected pitch and tuning feedback', (tester) async {
      viewModel.setDisplayMode(AppDisplayMode.essential);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      final noteWidget = tester.widget<Text>(find.byKey(const Key('essential_note_display')));
      expect(noteWidget.data, equals("--"));
      expect(find.text("ESPERANDO AUDIO"), findsOneWidget);

      // Simular detección de afinación La4 (440.0 Hz)
      pitchService.onPitchDetected?.call(440.0);
      await tester.pump();

      final updatedNoteWidget = tester.widget<Text>(find.byKey(const Key('essential_note_display')));
      expect(updatedNoteWidget.data, equals("La4"));
      expect(find.text("440.0 Hz"), findsOneWidget);
      expect(find.textContaining("AFINADO"), findsOneWidget);

      // Esperar a que el temporizador de silencio (60ms) culmine limpiamente
      await tester.pump(const Duration(milliseconds: 70));
    });
  });
}
