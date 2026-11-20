import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/core/file_system/domain/i_studio_workspace_file_system.dart';
import 'package:tunner/core/file_system/domain/studio_file_type.dart';
import 'package:tunner/core/logging/infrastructure/studio_debug_logger.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/i_soundfont_synthesizer_service.dart';
import 'package:tunner/features/dj_console/domain/dj_hardware_catalog.dart';
import 'package:tunner/features/dj_console/domain/i_dj_console_blueprint_storage_service.dart';
import 'package:tunner/features/dj_console/domain/i_dj_keymap_persistence_service.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_reference_synth.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/instrument/domain/procedural_instrument_synthesizer.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/media_vault/domain/i_media_io_port.dart';
import 'package:tunner/features/media_vault/domain/in_memory_media_vault_repository.dart';
import 'package:tunner/features/media_vault/domain/media_synergy_target.dart';
import 'package:tunner/features/media_vault/domain/timeline_project_entity.dart';
import 'package:tunner/features/media_vault/domain/wav_pcm_codec.dart';
import 'package:tunner/features/project_format/domain/project_storage_repository.dart';
import 'package:tunner/features/song_library/domain/song_decomposer_service.dart';

void main() {
  group('Wave 5 Clean Architecture & DIP Hardening Tests', () {
    test('SongDecomposerService and DefaultSongDecomposerService satisfy ISongDecomposerService contract', () {
      final ISongDecomposerService service = const DefaultSongDecomposerService();
      final library = service.getCuratedLibrary();
      expect(library, isNotEmpty);
      expect(library.first.title, contains('Canon'));

      final templates = service.getDecompositionTemplates();
      expect(templates, isNotEmpty);

      // Verify static compatibility for pre-existing callers
      final staticLib = SongDecomposerService.getCuratedLibrary();
      expect(staticLib.length, equals(library.length));
    });

    test('StudioPatchbayRoutingService operates in isolated mode without singleton collision', () {
      final serviceA = StudioPatchbayRoutingService.isolated();
      final serviceB = StudioPatchbayRoutingService.isolated();

      const plugA = StudioModularPlug(
        id: 'plug_test_a',
        label: 'TEST A',
        toolId: 'test_tool',
        type: StudioPlugType.audioInput,
      );

      serviceA.registerPlug(plugA);
      expect(serviceA.plugs.containsKey('plug_test_a'), isTrue);
      expect(serviceB.plugs.containsKey('plug_test_a'), isFalse);

      serviceA.connectPlugToChannel('plug_test_a', 'canal_a');
      expect(serviceA.plugs['plug_test_a']!.isConnected, isTrue);

      // Verify pulse and signal dispatching
      Map<String, dynamic>? receivedPayload;
      serviceA.registerSinkListener('plug_test_a', (sourceId, channelId, payload) {
        receivedPayload = payload;
      });

      serviceA.dispatchSignalFromPlug(
        sourcePlugId: 'plug_test_a',
        payload: {'testKey': 42},
      );

      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['testKey'], equals(42));
    });

    test('NoOp implementations provide safe decoupled fallbacks for all domain ports', () async {
      // 1. Audio Synthesizer NoOp
      const noOpAudioSynth = NoOpAudioSynthesizerService();
      await noOpAudioSynth.playMetronomeClick(isDownbeat: true);
      expect(noOpAudioSynth.isDiapasonPlaying, isFalse);

      // 2. SoundFont Synthesizer NoOp
      const noOpSf2 = NoOpSoundFontSynthesizerService();
      expect(noOpSf2.activePatch, equals(0));
      expect(noOpSf2.synthesizeNoteWav(midiPitch: 60).length, greaterThan(0));

      // 3. DJ Keymap Persistence NoOp
      const noOpKeymap = NoOpDjKeymapPersistenceService();
      final keymap = await noOpKeymap.loadActiveProfile();
      expect(keymap.name, isNotEmpty);
      await noOpKeymap.saveProfile(keymap);
      await noOpKeymap.resetToDefault();

      // 4. DJ Console Blueprint Storage NoOp
      const noOpBlueprint = NoOpDjConsoleBlueprintStorageService();
      final blueprints = await noOpBlueprint.loadAllBlueprints();
      expect(blueprints, isEmpty);
      expect(await noOpBlueprint.loadBlueprintById('nonexistent'), isNull);

      // 5. Project Storage Repository NoOp
      const noOpProjectStorage = NoOpProjectStorageRepository();
      final proj = await noOpProjectStorage.loadProject('/path/test.tunner');
      expect(proj.projectName, equals('Proyecto en Blanco'));

      // 6. Workspace File System NoOp
      final noOpFs = NoOpStudioWorkspaceFileSystem();
      expect(noOpFs.rootFolder.name, equals('Root'));
      final createdFile = noOpFs.createFile(name: 'test.wav', fileType: StudioFileType.audioWav);
      expect(createdFile.name, equals('test.wav'));

      // 7. Media IO Service NoOp
      const noOpMediaIo = NoOpMediaIoService();
      final importRes = await noOpMediaIo.importBytes(fileName: 'a.wav', bytes: Uint8List(0));
      expect(importRes.success, isFalse);
      final exportRes = await noOpMediaIo.exportTimeline(
        project: TimelineProjectEntity.defaultWorkspace(),
        assetsById: const {},
        format: MediaExportFormat.wavMixdown,
      );
      expect(exportRes.success, isFalse);
    });

    test('Domain rehomed audio entities instantiate and process correctly without IO dependencies', () {
      // 1. DjHardwareCatalog
      final skins = DjHardwareCatalog.allSkins();
      expect(skins, isNotEmpty);

      // 2. ProceduralInstrumentSynthesizer
      final synthBuffer = ProceduralInstrumentSynthesizer.synthesizeNote(
        instrument: UniversalInstrumentDefinition.masterCatalog.first,
        frequencyHz: 440.0,
        durationSeconds: 0.1,
      );
      expect(synthBuffer.length, greaterThan(0));

      // 3. HarmonicReferenceSynth
      final referenceSynth = HarmonicReferenceSynth();
      final chordBuffer = referenceSynth.generateChordBuffer(
        rootFrequency: 440.0,
        roles: const [HarmonicRole.root, HarmonicRole.perfectFifth],
        durationMs: 100,
      );
      expect(chordBuffer.length, greaterThan(0));

      // 4. WavPcmCodec
      const codec = WavPcmCodec();
      final dummySamples = Float64List.fromList([0.0, 0.5, -0.5, 0.0]);
      final encodedWav = codec.encodeMono16Bit(dummySamples, sampleRate: 44100);
      expect(encodedWav.length, greaterThan(44));

      // 5. InMemoryMediaVaultRepository
      final repo = InMemoryMediaVaultRepository();
      expect(repo.getAll(), isNotEmpty);
    });

    test('StudioDebugLogger formats error and warning messages correctly', () {
      final logger = StudioDebugLogger.instance;
      // Should execute without throwing any exception
      logger.warning('TestTag', 'Warning test message', error: 'Sample warning error');
      logger.error('TestTag', 'Error test message', error: Exception('Sample error'));
    });
  });
}
