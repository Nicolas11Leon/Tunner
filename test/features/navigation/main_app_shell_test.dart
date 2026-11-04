import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/navigation/presentation/tool_search_modal.dart';

// Fakes para inyección segura en tests
class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _FakeMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

class _FakeRecorderService implements IPracticeRecorderService {
  @override
  Stream<double> get amplitudeStream => const Stream.empty();
  @override
  bool get isRecording => false;
  @override
  Future<void> startRecording({required String destinationPath}) async {}
  @override
  Future<void> pauseRecording() async {}
  @override
  Future<void> resumeRecording() async {}
  @override
  Future<String?> stopRecording() async => null;
  @override
  void dispose() {}
}

class _FakePlaybackService implements IAudioPlaybackService {
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  bool get isPlaying => false;
  @override
  Future<void> play(String filePath) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  void dispose() {}
}

class _FakePersistenceService implements ILocalPersistenceService {
  AppUserSettingsEntity? savedSettings;
  @override
  Future<AppUserSettingsEntity> loadSettings() async =>
      savedSettings ?? AppUserSettingsEntity.defaultSettings;
  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    savedSettings = settings;
  }
  @override
  Future<void> clearSettings() async {
    savedSettings = null;
  }
}

void main() {
  late TunerViewModel viewModel;
  late _FakePitchService pitchService;
  late _FakeMetronomeService metronomeService;

  setUp(() {
    pitchService = _FakePitchService();
    metronomeService = _FakeMetronomeService();

    viewModel = TunerViewModel(
      pitchService: pitchService,
      metronomeService: metronomeService,
      recorderService: _FakeRecorderService(),
      playbackService: _FakePlaybackService(),
      persistenceService: _FakePersistenceService(),
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  Widget createTestWidget() {
    return ChangeNotifierProvider<TunerViewModel>.value(
      value: viewModel,
      child: const MaterialApp(
        home: MainAppShell(),
      ),
    );
  }

  group('MainAppShell & Navigation Hub UI Tests', () {
    testWidgets('Renders Home Dashboard by default with cards and search trigger', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verificar elementos del Dashboard
      expect(find.text('TUNNER STUDIO'), findsOneWidget);
      expect(find.text('¿Qué deseas hacer hoy?'), findsOneWidget);
      expect(find.byKey(const Key('home_search_trigger_bar')), findsOneWidget);

      // Verificar tarjetas de acción principales
      expect(find.byKey(const Key('card_action_tuner')), findsOneWidget);
      expect(find.byKey(const Key('card_action_lessons')), findsOneWidget);
      expect(find.byKey(const Key('card_action_recorder')), findsOneWidget);
      expect(find.byKey(const Key('card_action_library')), findsOneWidget);

      // Verificar barra de navegación inferior
      expect(find.byKey(const Key('nav_tab_home')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_tuner')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_learning')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_studio')), findsOneWidget);
      expect(find.byKey(const Key('nav_tab_library')), findsOneWidget);
    });

    testWidgets('Tapping search trigger opens ToolSearchModal', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.byKey(const Key('home_search_trigger_bar')));
      await tester.pump(const Duration(milliseconds: 300));

      // Modal de búsqueda visible
      expect(find.byType(ToolSearchModal), findsOneWidget);
      expect(find.byKey(const Key('universal_search_input')), findsOneWidget);

      // Escribir "metronomo" en el buscador
      await tester.enterText(find.byKey(const Key('universal_search_input')), 'metronomo');
      await tester.pump(const Duration(milliseconds: 300));

      // Debe filtrar y encontrar la herramienta del metrónomo
      expect(find.byKey(const Key('tool_search_item_metronome_tool')), findsOneWidget);
    });

    testWidgets('Tapping card_action_tuner switches to Tuner tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.tap(find.byKey(const Key('card_action_tuner')));
      await tester.pump(const Duration(milliseconds: 300));

      // La barra de navegación debe reflejar la pestaña 1 seleccionada
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(1));
    });

    testWidgets('BottomNavigationBar switches tabs smoothly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Tocar Pestaña 2: Aprender
      await tester.tap(find.byKey(const Key('nav_tab_learning')));
      await tester.pump(const Duration(milliseconds: 300));

      var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(2));

      // Tocar Pestaña 4: Canciones
      await tester.tap(find.byKey(const Key('nav_tab_library')));
      await tester.pump(const Duration(milliseconds: 300));

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(4));

      // Volver a Inicio
      await tester.tap(find.byKey(const Key('nav_tab_home')));
      await tester.pump(const Duration(milliseconds: 300));

      navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(0));
    });
  });
}
