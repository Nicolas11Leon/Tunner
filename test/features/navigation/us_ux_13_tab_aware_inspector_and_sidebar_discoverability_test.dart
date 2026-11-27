import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/design_system/molecules/studio_tree_view.dart';
import 'package:tunner/core/design_system/molecules/studio_workspace_tab_bar.dart';
import 'package:tunner/features/audio_synthesizer/data/audio_synthesizer_service.dart';
import 'package:tunner/features/ear_training/presentation/blind_ear_trainer_modal.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_workspace_modal.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late MemoryStudioAudioEngine memoryEngine;

  setUp(() {
    memoryEngine = MemoryStudioAudioEngine();
    viewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      metronomeService: _FakeMetronomeService(),
      recorderService: _FakeRecorderService(),
      playbackService: _FakePlaybackService(),
      persistenceService: _FakePersistenceService(),
      audioSynthesizerService: AudioSynthesizerService(audioEngine: memoryEngine),
      seedDefaults: true,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group(
    'US-UX-13: Dynamic Tab-Aware Right Contextual Inspector & Sidebar Discoverability',
    () {
      testWidgets(
        'Prueba 1: Al abrir el Inspector Contextual Derecho y cambiar entre pestañas (0..5), la sección contextual cambia dinámicamente con los datos y acciones de cada espacio',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          viewModel.updateBpm(118);

          await tester.pumpWidget(
            ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: const MaterialApp(
                home: MainAppShell(),
              ),
            ),
          );
          await tester.pump();

          // Abrir Inspector Contextual Derecho
          await tester.tap(find.byKey(const Key('btn_toggle_right_inspector')));
          await tester.pump();

          final inspectorPanel = find.byKey(
            const Key('studio_right_contextual_inspector_panel'),
          );
          expect(inspectorPanel, findsOneWidget);
          expect(
            find.byKey(const Key('main_shell_live_inspector_context_card')),
            findsOneWidget,
          );

          // Botones universales preservados
          expect(
            find.byKey(const Key('inspector_quick_a4_442_btn')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inspector_quick_a4_440_btn')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inspector_quick_toggle_drone_btn')),
            findsOneWidget,
          );

          // Pestaña 0: Inicio
          expect(
            find.byKey(const Key('inspector_tab_context_section_0')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Contexto: Hub de Estudio'),
            ),
            findsOneWidget,
          );
          final tab0VaultBtn = find.byKey(
            const Key('inspector_tab0_open_vault_btn'),
          );
          expect(tab0VaultBtn, findsOneWidget);

          Future<void> selectWorkspaceTab(String label) async {
            final tabFinder = find.descendant(
              of: find.byType(StudioWorkspaceTabBar),
              matching: find.text(label),
            );
            await tester.ensureVisible(tabFinder);
            await tester.pump();
            await tester.tap(tabFinder);
            await tester.pump();
          }

          // Cambiar a Pestaña 1: Afinador
          await selectWorkspaceTab('Afinador');

          expect(
            find.byKey(const Key('inspector_tab_context_section_1')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inspector_tab_context_section_0')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Contexto: Afinador Estroboscópico'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text(
                'Temperamento: ${viewModel.selectedTemperament.name}',
              ),
            ),
            findsOneWidget,
          );

          // Cambiar a Pestaña 2: Aprender
          await selectWorkspaceTab('Aprender');

          expect(
            find.byKey(const Key('inspector_tab_context_section_2')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Contexto: Conservatorio & Pedagogía'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inspector_tab2_open_ear_trainer_btn')),
            findsOneWidget,
          );

          // Cambiar a Pestaña 3: Rack Modular
          await selectWorkspaceTab('Rack Modular');

          expect(
            find.byKey(const Key('inspector_tab_context_section_3')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Contexto: Rack Modular DSP'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Módulos en Rack: 4'),
            ),
            findsOneWidget,
          );

          // Cambiar a Pestaña 4: Partituras
          await selectWorkspaceTab('Partituras');

          expect(
            find.byKey(const Key('inspector_tab_context_section_4')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Contexto: Notación SMuFL'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text(
                'Compases: ${viewModel.totalMeasures} • ${viewModel.bpm} BPM',
              ),
            ),
            findsOneWidget,
          );

          // Cambiar a Pestaña 5: Consola DJ
          await selectWorkspaceTab('Consola DJ');

          expect(
            find.byKey(const Key('inspector_tab_context_section_5')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('inspector_tab_context_section_4')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Contexto: Estación DJ Dual'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: inspectorPanel,
              matching: find.text('Deck A: 124.0 BPM | Deck B: 128.0 BPM'),
            ),
            findsOneWidget,
          );

          // Verificar acción del botón contextual de Pestaña 2 (Aprender -> BlindEarTrainerModal)
          await selectWorkspaceTab('Aprender');
          await tester.tap(
            find.byKey(const Key('inspector_tab2_open_ear_trainer_btn')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byType(BlindEarTrainerModal), findsOneWidget);
        },
      );

      testWidgets(
        'Prueba 2: En el árbol lateral (StudioTreeView), Tutor Armónico (Entonación Justa) y Bóveda Multimedia & Timeline son descubribles y operables sin usar Ctrl+K',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: const MaterialApp(
                home: MainAppShell(),
              ),
            ),
          );
          await tester.pump();

          final treeView = find.byType(StudioTreeView);
          expect(treeView, findsOneWidget);

          final harmonicTutorItem = find.descendant(
            of: treeView,
            matching: find.text('Tutor Armónico (Entonación Justa)'),
          );
          final mediaVaultItem = find.descendant(
            of: treeView,
            matching: find.text('Bóveda Multimedia & Timeline'),
          );

          expect(harmonicTutorItem, findsOneWidget);
          expect(mediaVaultItem, findsOneWidget);

          // Abrir Tutor Armónico directamente desde el árbol lateral
          await tester.ensureVisible(harmonicTutorItem);
          await tester.pump();
          await tester.tap(harmonicTutorItem);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(HarmonicTutorModal), findsOneWidget);

          // Cerrar Tutor Armónico
          Navigator.of(tester.element(find.byType(HarmonicTutorModal))).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(HarmonicTutorModal), findsNothing);

          // Abrir Bóveda Multimedia directamente desde el árbol lateral
          await tester.ensureVisible(mediaVaultItem);
          await tester.pump();
          await tester.tap(mediaVaultItem);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(MediaVaultWorkspaceModal), findsOneWidget);
        },
      );
    },
  );
}
