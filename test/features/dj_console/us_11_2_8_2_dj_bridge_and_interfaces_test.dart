import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/domain/i_studio_master_clock_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_clock_service.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/features/dj_console/data/dj_deck_audio_service.dart';
import 'package:tunner/features/dj_console/domain/dj_sampler_bank_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_deck_patchbay_bridge.dart';
import 'package:tunner/features/ear_training/domain/blind_ear_trainer_engine.dart';
import 'package:tunner/features/ear_training/domain/i_ear_trainer_engine.dart';
import 'package:tunner/features/exercise_generator/domain/algorithmic_exercise_generator.dart';
import 'package:tunner/features/exercise_generator/domain/i_exercise_generator.dart';
import 'package:tunner/features/guided_lessons/domain/i_task_catalog_index.dart';
import 'package:tunner/features/guided_lessons/domain/task_catalog_index.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_reference_synth.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/harmonic_tutor/domain/i_harmonic_reference_synth.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_view_model.dart';
import 'package:tunner/features/pedagogy_profiles/domain/adaptive_scaffolding_engine.dart';
import 'package:tunner/features/pedagogy_profiles/domain/i_adaptive_scaffolding_engine.dart';
import 'package:tunner/features/project_format/data/tunner_binary_project_codec.dart';
import 'package:tunner/features/project_format/domain/i_tunner_binary_codec.dart';

class _FakeHarmonicReferenceSynth implements IHarmonicReferenceSynth {
  int callCount = 0;

  @override
  int get sampleRate => 48000;

  @override
  Float32List generateChordBuffer({
    required double rootFrequency,
    required List<HarmonicRole> roles,
    int durationMs = 1000,
    double volume = 0.5,
  }) {
    callCount++;
    return Float32List.fromList(<double>[0.25, -0.25, 0.5, -0.5]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-11.2: DjDeckPatchbayBridge, telemetryNotifier & DjDeckAudioService DI', () {
    test('Scoped bridge IDs prevent global collision and isolate dispose across instances', () {
      final routing = StudioPatchbayRoutingService.isolated();
      final vm1 = DjConsoleViewModel();
      final vm2 = DjConsoleViewModel();

      final bridge1 = DjDeckPatchbayBridge(
        viewModel: vm1,
        routingService: routing,
        scopePrefix: 'dj_modal_1',
      );
      final bridge2 = DjDeckPatchbayBridge(
        viewModel: vm2,
        routingService: routing,
        scopePrefix: 'dj_workstation_2',
        includeMasterOut: true,
      );

      expect(bridge1.deckAPlugId, equals('dj_modal_1_plug_dj_deck_a_in'));
      expect(bridge1.deckBPlugId, equals('dj_modal_1_plug_dj_deck_b_in'));
      expect(bridge2.deckAPlugId, equals('dj_workstation_2_plug_dj_deck_a_in'));
      expect(bridge2.masterOutPlug?.id, equals('dj_workstation_2_plug_dj_master_out'));

      expect(routing.plugs.containsKey(bridge1.deckAPlugId), isTrue);
      expect(routing.plugs.containsKey(bridge2.deckAPlugId), isTrue);

      // Dispose bridge1; bridge2 must continue receiving signals on canal_a.
      bridge1.dispose();

      const sourcePlug = StudioModularPlug(
        id: 'test_source_out',
        label: 'TEST OUT',
        toolId: 'test_tool',
        type: StudioPlugType.audioOutput,
        connectedChannelId: 'canal_a',
      );
      routing.registerPlug(sourcePlug);
      routing.dispatchSignalFromPlug(
        sourcePlugId: 'test_source_out',
        payload: const <String, dynamic>{
          'title': 'Isolated Track A',
          'bpm': 132.0,
          'key': '9A',
        },
      );

      expect(vm2.deckA.trackTitle, equals('Isolated Track A'));
      expect(vm2.deckA.bpm, closeTo(132.0, 0.01));
      expect(vm1.deckA.trackTitle, isNot(equals('Isolated Track A')));

      bridge2.dispose();
      vm1.dispose();
      vm2.dispose();
      routing.dispose();
    });

    test('publishMixerChannelAsset routes to canal_c without hijacking Deck A', () {
      final routing = StudioPatchbayRoutingService.isolated();
      final vm = DjConsoleViewModel();
      final bridge = DjDeckPatchbayBridge(
        viewModel: vm,
        routingService: routing,
        scopePrefix: 'dj_mixer_test',
      );

      final initialTitleA = vm.deckA.trackTitle;
      final pcm = Float32List.fromList(<double>[0.1, 0.2, 0.3, 0.4]);

      bridge.publishMixerChannelAsset(
        title: 'Aux Stem Bass',
        bpm: 126.0,
        camelotKey: '7A',
        pcmBuffer: pcm,
      );

      final canalC = routing.matrix.channels['canal_c'];
      expect(canalC, isNotNull);
      expect(canalC!.activeTrackTitle, equals('Aux Stem Bass'));
      expect(canalC.activeBpm, closeTo(126.0, 0.01));
      expect(canalC.activeCamelotKey, equals('7A'));
      expect(canalC.livePcmBuffer, equals(pcm));
      expect(vm.deckA.trackTitle, equals(initialTitleA));

      bridge.dispose();
      vm.dispose();
      routing.dispose();
    });

    test('DjConsoleViewModel exposes 30 Hz telemetryNotifier and disposes cleanly', () async {
      final vm = DjConsoleViewModel();
      final snapshots = <({double vuA, double vuB, double phaseA, double phaseB})>[];

      void listener() {
        snapshots.add(vm.telemetryNotifier.value);
      }

      vm.telemetryNotifier.addListener(listener);
      vm.togglePlay('A');

      await Future<void>.delayed(const Duration(milliseconds: 110));

      expect(snapshots, isNotEmpty);
      expect(snapshots.last.phaseA, inInclusiveRange(0.0, 1.0));
      expect(snapshots.last.vuA, greaterThanOrEqualTo(0.0));

      vm.telemetryNotifier.removeListener(listener);
      vm.dispose();
    });

    test('DjConsoleViewModel.triggerSamplerBuffer stores and plays dispatched asset buffer', () {
      final vm = DjConsoleViewModel();
      final samples = Float32List.fromList(<double>[0.2, -0.2, 0.4, -0.4]);

      vm.triggerSamplerBuffer(
        samples,
        sampleRate: 44100,
        pad: DjSamplerPadType.stadiumImpact,
      );

      expect(vm.lastSamplerBuffer, equals(samples));
      expect(vm.sampler.lastTriggeredPad, equals(DjSamplerPadType.stadiumImpact));
      expect(vm.sampler.triggerSequence, greaterThanOrEqualTo(1));
      vm.dispose();
    });

    test('DjDeckAudioService works via explicit IStudioAudioEngine injection without FLUTTER_TEST', () async {
      final engine = MemoryStudioAudioEngine();
      final service = DjDeckAudioService(audioEngine: engine);

      expect(service.audioEngine, same(engine));
      await service.playDeck('A');
      expect(service.isDeckPlaying('A'), isTrue);
      await service.pauseDeck('A');
      expect(service.isDeckPlaying('A'), isFalse);

      service.dispose();
    });
  });

  group('US-8.2: Pure Domain DIP Interfaces Conformance', () {
    test('All 8 concrete services implement their corresponding domain interfaces', () {
      final IStudioMasterClockService clock = StudioMasterClockService();
      final IStudioAudioDeviceMatrixService matrix = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
      );
      final IHarmonicReferenceSynth synth = HarmonicReferenceSynth();
      final IEarTrainerEngine earTrainer = BlindEarTrainerEngine();
      final ITaskCatalogIndex catalog = TaskCatalogIndex();
      const IExerciseGenerator generator = AlgorithmicExerciseGenerator();
      const IAdaptiveScaffoldingEngine scaffolding = AdaptiveScaffoldingEngine();
      final ITunnerBinaryCodec codec = TunnerBinaryProjectCodec();

      expect(clock.bpm, closeTo(120.0, 0.01));
      expect(matrix.matrix.sampleRate, greaterThan(0));
      expect(synth.sampleRate, equals(44100));
      expect(earTrainer.totalQuestionsAnswered, equals(0));
      expect(catalog.count, greaterThan(0));
      expect(
        generator.generate(rootNote: 'Do4', type: ExerciseType.majorScale).score.measures,
        isNotEmpty,
      );
      expect(scaffolding, isA<IAdaptiveScaffoldingEngine>());
      expect(codec.maxAllowedDecompressedBytes, greaterThan(0));

      clock.dispose();
      matrix.dispose();
    });

    test('HarmonicTutorViewModel accepts injected IHarmonicReferenceSynth interface', () {
      final fakeSynth = _FakeHarmonicReferenceSynth();
      int? receivedSampleRate;

      final vm = HarmonicTutorViewModel(
        synth: fakeSynth,
        onPlayDroneSamples: (_, sampleRate) {
          receivedSampleRate = sampleRate;
        },
      );

      vm.toggleDrone();
      expect(fakeSynth.callCount, equals(1));
      expect(receivedSampleRate, equals(48000));
      expect(vm.currentDroneBuffer?.length, equals(4));

      vm.dispose();
    });
  });
}
