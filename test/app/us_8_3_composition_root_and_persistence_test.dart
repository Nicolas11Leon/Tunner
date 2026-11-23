import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/i_soundfont_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/sf2_models.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/tunner_acoustic_soundfont_bank.dart';
import 'package:tunner/features/audio_synthesizer/presentation/instrument_soundfont_selector_modal.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';

class _TestFileGateway implements IPlatformFileGateway {
  final String docsPath;
  final PlatformPickedFile? pickedFile;
  List<String>? lastAllowedExtensions;

  _TestFileGateway({
    required this.docsPath,
    this.pickedFile,
  });

  @override
  Future<String> getDocumentsDirectoryPath() async => docsPath;

  @override
  Future<String> getTemporaryDirectoryPath() async => docsPath;

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async =>
      '$docsPath/$fileName';

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async {
    lastAllowedExtensions = allowedExtensions;
    return pickedFile;
  }
}

class _FakeSoundFontSynthesizer implements ISoundFontSynthesizerService {
  int _activePatch = 0;
  Uint8List? loadedBytes;

  @override
  Sf2SoundFont get activeSoundFont =>
      TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();

  @override
  int get activePatch => _activePatch;

  @override
  List<Sf2Preset> get availablePresets => const [
        Sf2Preset(name: 'Concert Grand', patch: 0, bank: 0, zones: []),
        Sf2Preset(name: 'Custom SF2 Flute', patch: 73, bank: 0, zones: []),
      ];

  @override
  void selectPatch(int patch) {
    _activePatch = patch;
  }

  @override
  void loadSoundFontFromBytes(Uint8List sf2Bytes) {
    loadedBytes = sf2Bytes;
    _activePatch = 73;
  }

  @override
  void resetToEssentialsBank() {
    _activePatch = 0;
  }

  @override
  Uint8List synthesizeNoteWav({
    required int midiPitch,
    double durationSeconds = 1.0,
    int velocity = 100,
    int sampleRate = 44100,
  }) =>
      Uint8List(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-8.3: StudioCompositionRoot, OLED Persistence & Tmp Cleanup', () {
    test('StudioCompositionRoot reuses single fileSystemRepository and AudioSynthesizerService across ViewModels', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_us83_root_');
      try {
        final gateway = _TestFileGateway(docsPath: tempDir.path);
        final root = StudioCompositionRoot.create(platformFileGateway: gateway);

        final tunerVm = root.createTunerViewModel(seedDefaults: false);
        final djVm = root.createDjConsoleViewModel();
        final vaultVm = root.createMediaVaultViewModel();

        expect(
          djVm.fileSystemRepository,
          same(root.fileSystemService.fileSystemRepository),
        );
        expect(
          vaultVm.fileSystemRepository,
          same(root.fileSystemService.fileSystemRepository),
        );

        expect(tunerVm.audioSynthesizer, same(root.audioSynthesizerService));
        expect(djVm.audioSynthesizer, same(root.audioSynthesizerService));
        expect(vaultVm.audioSynthesizer, same(root.audioSynthesizerService));

        tunerVm.dispose();
        djVm.dispose();
        vaultVm.dispose();
        root.dispose();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('StudioCompositionRoot.dispose() disposes isolated themeCatalogService and masterDspChain cleanly', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_us83_dispose_');
      try {
        final gateway = _TestFileGateway(docsPath: tempDir.path);
        final isolatedRoot = StudioCompositionRoot.create(
          platformFileGateway: gateway,
          isolatedServices: true,
        );

        // Allocate internal scratch buffer on masterDspChain before disposal
        final left = Float32List.fromList([0.5, -0.5, 0.25, -0.25]);
        final right = Float32List.fromList([0.25, 0.5, -0.25, 0.5]);
        isolatedRoot.masterDspChain.processMasterBlock(left, right, isMono: true);

        isolatedRoot.dispose();
        // Idempotent second call must not throw
        isolatedRoot.dispose();

        // Isolated themeCatalogService must be disposed (adding listener throws FlutterError)
        expect(
          () => isolatedRoot.themeCatalogService.addListener(() {}),
          throwsFlutterError,
        );

        // Non-isolated root must NOT dispose the global singleton themeCatalogService
        final sharedRoot = StudioCompositionRoot.create(
          platformFileGateway: gateway,
          isolatedServices: false,
        );
        sharedRoot.dispose();

        void probeListener() {}
        expect(
          () => sharedRoot.themeCatalogService.addListener(probeListener),
          returnsNormally,
        );
        sharedRoot.themeCatalogService.removeListener(probeListener);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('JsonLocalPersistenceService.clearSettings() removes timestamped orphan *.tmp files without touching unrelated files', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_us83_tmp_');
      try {
        final service = JsonLocalPersistenceService(
          documentsPathProvider: () async => tempDir.path,
          fileName: 'tunner_settings.json',
        );

        await service.saveSettings(
          const AppUserSettingsEntity(activeStudioThemeId: 'studio_light'),
        );

        final basePath = '${tempDir.path}/tunner_settings.json';
        final legacyTmp = File('$basePath.tmp');
        final orphan1 = File('$basePath.1700000000001.tmp');
        final orphan2 = File('$basePath.1700000000002.tmp');
        final unrelatedTmp = File('${tempDir.path}/other_file.json.9999.tmp');
        final unrelatedJson = File('${tempDir.path}/keep_me.json');

        await legacyTmp.writeAsString('{}');
        await orphan1.writeAsString('{"partial":true}');
        await orphan2.writeAsString('{"partial":true}');
        await unrelatedTmp.writeAsString('keep');
        await unrelatedJson.writeAsString('keep');

        await service.clearSettings();

        expect(await File(basePath).exists(), isFalse);
        expect(await legacyTmp.exists(), isFalse);
        expect(await orphan1.exists(), isFalse);
        expect(await orphan2.exists(), isFalse);
        expect(await unrelatedTmp.exists(), isTrue);
        expect(await unrelatedJson.exists(), isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('TunerViewModel persists and restores activeStudioThemeId and synchronizes StudioThemeController', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_us83_oled_');
      try {
        final gateway = _TestFileGateway(docsPath: tempDir.path);

        // Session 1: change studio theme to studio_light and persist
        final root1 = StudioCompositionRoot.create(platformFileGateway: gateway);
        final vm1 = root1.createTunerViewModel(seedDefaults: false);
        await vm1.isInitialized;

        expect(vm1.activeStudioThemeId, equals('studio_oled_monochrome'));
        expect(
          root1.themeController.tokens.id,
          equals(StudioDesignTokens.studioOledMonochrome.id),
        );

        vm1.setActiveStudioThemeId('studio_light');
        await vm1.savePersistedState();

        expect(vm1.activeStudioThemeId, equals('studio_light'));
        expect(
          root1.themeController.tokens.id,
          equals(StudioDesignTokens.studioLight.id),
        );

        vm1.dispose();
        root1.dispose();

        // Session 2: cold boot restores activeStudioThemeId into both VM and StudioThemeController
        final root2 = StudioCompositionRoot.create(platformFileGateway: gateway);
        final vm2 = root2.createTunerViewModel(seedDefaults: false);
        await vm2.isInitialized;

        expect(vm2.activeStudioThemeId, equals('studio_light'));
        expect(
          root2.themeController.tokens.id,
          equals(StudioDesignTokens.studioLight.id),
        );

        vm2.dispose();
        root2.dispose();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    testWidgets('InstrumentSoundFontSelectorModal delegates .sf2 picking to injected IPlatformFileGateway', (tester) async {
      final sf2Bytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0x10, 0x00, 0x00, 0x00]);
      final gateway = _TestFileGateway(
        docsPath: '/tmp',
        pickedFile: PlatformPickedFile(
          name: 'custom_orchestra.sf2',
          bytes: sf2Bytes,
        ),
      );
      final fakeSynth = _FakeSoundFontSynthesizer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstrumentSoundFontSelectorModal(
                synthService: fakeSynth,
                fileGateway: gateway,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('load_external_sf2_btn')));
      await tester.pumpAndSettle();

      expect(gateway.lastAllowedExtensions, equals(const ['sf2']));
      expect(fakeSynth.loadedBytes, equals(sf2Bytes));
      expect(fakeSynth.activePatch, equals(73));
      expect(find.textContaining('custom_orchestra.sf2'), findsOneWidget);
    });
  });
}
