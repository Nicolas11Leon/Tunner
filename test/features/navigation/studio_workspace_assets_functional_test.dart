import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/tuning_preset_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/data/song_decomposer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Studio Workspace Assets End-to-End Functional Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state has empty workspaceScores and customTuningPresets by default', () {
      expect(viewModel.workspaceScores, isEmpty);
      expect(viewModel.customTuningPresets, isEmpty);
    });

    test('createWorkspaceScore creates new score, updates workspaceScores and activePackage', () {
      final newScore = viewModel.createWorkspaceScore(
        title: 'Sonata en Re Menor',
        bpm: 112,
        timeSignature: TimeSignature.waltzTime34,
        initialMeasures: 6,
      );

      expect(viewModel.workspaceScores.length, equals(1));
      expect(viewModel.workspaceScores.first.id, equals(newScore.id));
      expect(viewModel.workspaceScores.first.title, equals('Sonata en Re Menor'));
      expect(viewModel.workspaceScores.first.defaultBpm, equals(112));
      expect(viewModel.activePackage.id, equals(newScore.id));
      expect(viewModel.bpm, equals(112));
    });

    test('deleteWorkspaceScore removes target score from workspace', () {
      final scoreA = viewModel.createWorkspaceScore(
        title: 'Pieza A',
        bpm: 90,
        timeSignature: TimeSignature.commonTime44,
      );
      final scoreB = viewModel.createWorkspaceScore(
        title: 'Pieza B',
        bpm: 130,
        timeSignature: TimeSignature.commonTime44,
      );

      expect(viewModel.workspaceScores.length, equals(2));

      viewModel.deleteWorkspaceScore(scoreA.id);

      expect(viewModel.workspaceScores.length, equals(1));
      expect(viewModel.workspaceScores.first.id, equals(scoreB.id));
    });

    test('saveCustomTuningPreset stores entity and applyTuningPreset updates engine state', () {
      final preset = TuningPresetEntity(
        id: 'preset_berlin_443',
        name: 'Filarmónica de Berlín',
        referencePitchHz: 443.0,
        temperamentId: 'pythagorean',
        rootKey: 2, // Re
        createdAt: DateTime.now(),
      );

      viewModel.saveCustomTuningPreset(preset);

      expect(viewModel.customTuningPresets.length, equals(1));
      expect(viewModel.customTuningPresets.first.id, equals('preset_berlin_443'));

      // Aplica el preset
      viewModel.applyTuningPreset(preset);

      expect(viewModel.referencePitch, equals(443.0));
      expect(viewModel.selectedTemperament.id, equals('pythagorean'));
      expect(viewModel.temperamentRootKey, equals(2));
    });

    test('deleteCustomTuningPreset removes preset cleanly', () {
      final preset = TuningPresetEntity(
        id: 'preset_to_delete',
        name: 'Temporal',
        referencePitchHz: 438.0,
        createdAt: DateTime.now(),
      );

      viewModel.saveCustomTuningPreset(preset);
      expect(viewModel.customTuningPresets.length, equals(1));

      viewModel.deleteCustomTuningPreset('preset_to_delete');
      expect(viewModel.customTuningPresets, isEmpty);
    });

    test('importPresetToWorkspace clones canonical piece into user workspace', () {
      final curated = SongDecomposerService.getCuratedLibrary().first;

      final imported = viewModel.importPresetToWorkspace(curated);

      expect(viewModel.workspaceScores.length, equals(1));
      expect(viewModel.workspaceScores.first.title, equals(curated.title));
      expect(viewModel.workspaceScores.first.id, equals(imported.id));
      expect(viewModel.activePackage.title, equals(curated.title));
    });
  });
}
