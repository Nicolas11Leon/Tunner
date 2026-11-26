import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/features/audio_synthesizer/data/audio_synthesizer_service.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/media_vault/domain/media_synergy_target.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_workspace_modal.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/navigation/presentation/pro_command_palette_modal.dart';
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
    StudioPatchbayRoutingService().resetToDefaults();
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
    StudioPatchbayRoutingService().resetToDefaults();
  });

  group('US-HC-01: Live Right Contextual Inspector, Session Command Palette & MediaVault -> Canal C Routing', () {
    testWidgets(
      'Prueba 1: MainAppShell en viewport 1440x900 pasa telemetría viva al Inspector Contextual Derecho y actualiza referencePitch a 442.0 Hz en vivo',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        viewModel.setReferencePitch(438.0);
        viewModel.updateBpm(128);

        await tester.pumpWidget(
          ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const MaterialApp(
              home: MainAppShell(),
            ),
          ),
        );
        await tester.pump();

        // Abrir el Inspector Contextual Derecho
        final toggleInspectorBtn = find.byKey(const Key('btn_toggle_right_inspector'));
        expect(toggleInspectorBtn, findsOneWidget);
        await tester.tap(toggleInspectorBtn);
        await tester.pump();

        final inspectorPanel = find.byKey(const Key('studio_right_contextual_inspector_panel'));
        expect(inspectorPanel, findsOneWidget);
        expect(find.byKey(const Key('main_shell_live_inspector_context_card')), findsOneWidget);

        // Verificar valores vivos iniciales de TunerViewModel dentro del inspector
        expect(
          find.descendant(
            of: inspectorPanel,
            matching: find.text('438.0 Hz'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: inspectorPanel,
            matching: find.text('128 BPM'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: inspectorPanel,
            matching: find.text(viewModel.activeInstrument.name),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: inspectorPanel,
            matching: find.text('Obra: ${viewModel.activePackage.title}'),
          ),
          findsOneWidget,
        );

        // Pulsar botón rápido A4 = 442 Hz en el inspector
        final btn442 = find.byKey(const Key('inspector_quick_a4_442_btn'));
        expect(btn442, findsOneWidget);
        await tester.tap(btn442);
        await tester.pump();

        expect(viewModel.referencePitch, equals(442.0));
        expect(
          find.descendant(
            of: inspectorPanel,
            matching: find.text('442.0 Hz'),
          ),
          findsOneWidget,
        );

        // Pulsar botón rápido A4 = 440 Hz y toggle de Dron
        final btn440 = find.byKey(const Key('inspector_quick_a4_440_btn'));
        expect(btn440, findsOneWidget);
        await tester.tap(btn440);
        await tester.pump();
        expect(viewModel.referencePitch, equals(440.0));
        expect(
          find.descendant(
            of: inspectorPanel,
            matching: find.text('440.0 Hz'),
          ),
          findsOneWidget,
        );

        expect(find.byKey(const Key('inspector_quick_toggle_drone_btn')), findsOneWidget);
      },
    );

    testWidgets(
      'Prueba 2: Despachar un activo desde MediaVault (abierto vía CTRL+K en HomeDashboardScreen) hacia MediaSynergyTarget.mixerChannel publica en canal_c sin sobrescribir Deck A',
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

        // Guardar estado inicial del Canal A / Deck A antes del despacho
        final patchbay = StudioPatchbayRoutingService();
        final initialCanalATitle = patchbay.matrix.channels['canal_a']?.activeTrackTitle;

        // Abrir Command Palette desde HomeDashboardScreen usando el trigger CTRL+K unificado con la sesión de MainAppShell
        final homeCmdTrigger = find.byKey(const Key('home_universal_command_palette_trigger'));
        expect(homeCmdTrigger, findsOneWidget);
        await tester.tap(homeCmdTrigger);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ProCommandPaletteModal), findsOneWidget);

        // Filtrar y abrir Media Vault desde la Command Palette de sesión real
        await tester.enterText(
          find.byKey(const Key('command_palette_search_input')),
          'Bóveda Multimedia',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final openVaultCmd = find.byKey(const Key('command_item_open_media_vault'));
        expect(openVaultCmd, findsOneWidget);
        await tester.tap(openVaultCmd);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final vaultModalFinder = find.byType(MediaVaultWorkspaceModal);
        expect(vaultModalFinder, findsOneWidget);

        final vaultModal = tester.widget<MediaVaultWorkspaceModal>(vaultModalFinder);
        final sessionVaultVm = vaultModal.viewModel;

        final testAsset = MediaAssetEntity(
          id: 'us_hc_01_mixer_asset',
          title: 'Stem Acústico Canal C',
          fileName: 'stem_canal_c.wav',
          extensionName: 'wav',
          kind: MediaAssetKind.stem,
          durationMs: 8000,
          bpm: 132.0,
          camelotKey: '10A',
          createdAt: DateTime.utc(2026, 11, 26),
        );

        // Despachar hacia MediaSynergyTarget.mixerChannel
        sessionVaultVm.dispatchAssetToTool(
          testAsset,
          MediaSynergyTarget.mixerChannel,
        );
        await tester.pump();

        final canalC = patchbay.matrix.channels['canal_c'];
        expect(canalC, isNotNull);
        expect(canalC!.activeTrackTitle, equals('Stem Acústico Canal C'));
        expect(canalC.activeBpm, equals(132.0));
        expect(canalC.activeCamelotKey, equals('10A'));
        expect(canalC.isPlaying, isTrue);

        // Confirmar que Canal A (Deck A) no fue sobrescrito con el activo del mixer
        final canalAAfter = patchbay.matrix.channels['canal_a'];
        expect(canalAAfter?.activeTrackTitle, equals(initialCanalATitle));
        expect(canalAAfter?.activeTrackTitle, isNot(equals('Stem Acústico Canal C')));
      },
    );
  });
}
