import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/packaging/domain/tunner_project_manifest_entity.dart';
import 'package:tunner/core/packaging/domain/tunner_project_package_entity.dart';
import 'package:tunner/core/packaging/infrastructure/tunner_package_codec_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  group('TunerViewModel Packaging Integration Tests', () {
    late TunerViewModel viewModel;
    late StudioAudioDeviceMatrixService matrixService;
    late PolyphonicVoicePool voicePool;

    setUp(() {
      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: MemoryAudioHardwarePersistenceService(),
        captureService: MemoryStudioMasterCaptureService(),
      );
      voicePool = PolyphonicVoicePool();
      viewModel = TunerViewModel(
        audioDeviceMatrixService: matrixService,
        polyphonicVoicePool: voicePool,
      );
    });

    test('exportCurrentProjectToTunner produces valid .tunner package with full session state', () {
      voicePool.waveform = SynthWaveform.pulse;
      voicePool.pulseWidth = 0.35;
      voicePool.attackSeconds = 0.05;
      voicePool.decaySeconds = 0.12;
      voicePool.sustainLevel = 0.65;
      voicePool.releaseSeconds = 0.40;
      voicePool.masterGain = 0.92;
      viewModel.updateBpm(136);

      final packageBytes = viewModel.exportCurrentProjectToTunner(
        projectTitle: 'Nocturno en Fa Menor',
        author: 'Frederic Chopin',
      );

      expect(packageBytes, isNotEmpty);

      // Decodificar directamente usando el codec
      const codec = TunnerPackageCodecService();
      final decoded = codec.decodePackage(packageBytes, verifyHashes: true);

      expect(decoded.manifest.title, 'Nocturno en Fa Menor');
      expect(decoded.manifest.author, 'Frederic Chopin');
      expect(decoded.manifest.bpm, 136.0);
      expect(decoded.hasScore, isTrue);
      expect(decoded.hasSynthPreset, isTrue);
      expect(decoded.hasRoutingMatrix, isTrue);

      expect(decoded.synthPresetJson?['waveform'], 'pulse');
      expect(decoded.synthPresetJson?['pulseWidth'], 0.35);
      expect(decoded.synthPresetJson?['attack'], 0.05);
      expect(decoded.synthPresetJson?['masterGain'], 0.92);
    });

    test('importProjectFromTunnerBytes restores bpm, synth parameters and notifies listeners', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      const codec = TunnerPackageCodecService();
      final manifest = TunnerProjectManifestEntity(
        id: 'external_proj_099',
        title: 'Cyber Anthem 2026',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        bpm: 144.0,
      );

      final externalPackage = TunnerProjectPackageEntity(
        manifest: manifest,
        synthPresetJson: {
          'waveform': 'triangle',
          'attack': 0.08,
          'decay': 0.15,
          'sustain': 0.75,
          'release': 0.50,
          'pulseWidth': 0.5,
          'masterGain': 0.88,
        },
        routingMatrixJson: {
          'masterGain': 0.95,
          'isMuted': false,
          'eqLowDb': 3.0,
        },
      );

      final packageBytes = codec.encodePackage(externalPackage);

      // Importar en el ViewModel
      final restored = viewModel.importProjectFromTunnerBytes(packageBytes, verifyHashes: true);

      expect(restored.manifest.title, 'Cyber Anthem 2026');
      expect(viewModel.bpm, 144);
      expect(viewModel.polyphonicVoicePool.waveform, SynthWaveform.triangle);
      expect(viewModel.polyphonicVoicePool.attackSeconds, 0.08);
      expect(viewModel.polyphonicVoicePool.sustainLevel, 0.75);
      expect(viewModel.polyphonicVoicePool.releaseSeconds, 0.50);
      expect(viewModel.polyphonicVoicePool.masterGain, 0.88);
      expect(notified, isTrue);
    });
  });
}
