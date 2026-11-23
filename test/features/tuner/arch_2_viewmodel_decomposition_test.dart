import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_stem_export_persistence_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/score_editor/presentation/score_editor_controller.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/domain/tuner_session_ports.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/domain/i_score_parser_service.dart';

class _FakePitch extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

void main() {
  group('ARCH-2 TunerViewModel Decomposition & Reactive Atomicity Verification', () {
    test('Codebase under lib/ has zero part / part of directives', () {
      final libDir = Directory('lib');
      final partFiles = <String>[];
      final partRegex = RegExp(r'^(part |part of )', multiLine: true);

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (partRegex.hasMatch(content)) {
          partFiles.add(entity.path);
        }
      }

      expect(partFiles, isEmpty, reason: 'Archivos part/part of encontrados: $partFiles');
    });

    test('TunerViewModel implements segregated ISP session ports and updates telemetryListenable atomically', () async {
      final vm = TunerViewModel(pitchService: _FakePitch());

      expect(vm, isA<IGuidedLessonSessionPort>());
      expect(vm, isA<IChordAnalyzerSessionPort>());
      expect(vm, isA<IScoreEditorSessionPort>());

      int telemetryUpdates = 0;
      vm.telemetryListenable.addListener(() {
        telemetryUpdates++;
      });

      expect(vm.telemetryListenable.value.isRecording, isFalse);
      await vm.toggleRecording();
      await Future<void>.delayed(Duration.zero);

      expect(vm.telemetryListenable.value.isRecording, isTrue);
      expect(telemetryUpdates, greaterThanOrEqualTo(1));

      vm.dispose();
    });

    test('ScoreEditorController executes undo/redo and MusicXML export standalone', () {
      final baseVm = TunerViewModel(pitchService: _FakePitch());
      final initialPkg = baseVm.activePackage;
      baseVm.dispose();

      final controller = ScoreEditorController(
        audioSynthesizer: const NoOpAudioSynthesizerService(),
        scoreImporterService: const NoOpScoreParserService(),
        stemSynthesizer: const StemAudioSynthesizer(),
        exportPersistenceService: const NoOpStemExportPersistenceService(),
        logger: const NoOpStudioLogger(),
        onNotify: () {},
      );

      expect(controller.canUndoScoreEdit, isFalse);
      final updated = controller.insertOrUpdateScoreNote(
        activePackage: initialPkg,
        measureIndex: 0,
        startTick: 0,
        durationTicks: 4,
        noteName: 'Sol4',
        referencePitch: 440.0,
        bpm: 120,
        playAudibleFeedback: false,
      );
      expect(controller.canUndoScoreEdit, isTrue);
      final reverted = controller.undoScoreEdit(updated);
      expect(reverted, isNotNull);
      expect(controller.exportActiveScoreToMusicXml(initialPkg), contains('<score-partwise'));
    });
  });
}
