import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/media_vault/domain/timeline_project_entity.dart';

void main() {
  group('MediaAssetEntity & TimelineProjectEntity Domain Tests', () {
    final trackA = MediaAssetEntity(
      id: 'asset_1',
      title: 'Deep House Groove',
      fileName: 'deep_house.wav',
      extensionName: 'wav',
      kind: MediaAssetKind.audioTrack,
      durationMs: 4000,
      bpm: 120.0,
      camelotKey: '8A',
      tags: const <String>['house', 'warm'],
      createdAt: DateTime.utc(2026, 11, 14),
    );

    final scoreB = MediaAssetEntity(
      id: 'asset_2',
      title: 'Bach Flute Partita',
      fileName: 'partita.musicxml',
      extensionName: 'musicxml',
      kind: MediaAssetKind.sheetMusic,
      durationMs: 0,
      bpm: 100.0,
      camelotKey: '9B',
      tags: const <String>['baroque', 'flute'],
      createdAt: DateTime.utc(2026, 11, 14),
    );

    test('matchesFilter filters by query, tags, camelot key, and kind', () {
      expect(trackA.matchesFilter(query: '8A'), isTrue);
      expect(trackA.matchesFilter(query: 'house'), isTrue);
      expect(
        trackA.matchesFilter(query: 'house', kindFilter: MediaAssetKind.stem),
        isFalse,
      );
      expect(
        scoreB.matchesFilter(query: 'flute', kindFilter: MediaAssetKind.sheetMusic),
        isTrue,
      );
    });

    test('quantizeMs snaps raw drop offset to nearest beat at 120 BPM (500ms/beat)', () {
      final project = TimelineProjectEntity.defaultWorkspace().copyWith(
        masterBpm: 120.0,
        snapToBeatgrid: true,
      );

      expect(project.quantizeMs(480), 500);
      expect(project.quantizeMs(1120), 1000);
      expect(project.quantizeMs(-50), 0);

      final freeProject = project.copyWith(snapToBeatgrid: false);
      expect(freeProject.quantizeMs(480), 480);
    });

    test('placeAssetOnTrack resolves collisions non-destructively', () {
      var project = TimelineProjectEntity.defaultWorkspace().copyWith(
        masterBpm: 120.0,
        snapToBeatgrid: true,
      );

      project = project.placeAssetOnTrack(
        asset: trackA,
        trackId: 'track_deck_a',
        rawStartMs: 0,
        clipId: 'clip_1',
      );
      project = project.placeAssetOnTrack(
        asset: trackA,
        trackId: 'track_deck_a',
        rawStartMs: 1000, // Overlaps [0, 4000)
        clipId: 'clip_2',
      );

      final lane = project.tracks.firstWhere((t) => t.trackId == 'track_deck_a');
      expect(lane.clips.length, 2);
      expect(lane.clips[0].startMs, 0);
      expect(lane.clips[1].startMs, 4000);
      expect(project.totalDurationMs, 8000);
    });

    test('non-audio asset with 0 duration receives default timeline clip duration', () {
      var project = TimelineProjectEntity.defaultWorkspace();
      project = project.placeAssetOnTrack(
        asset: scoreB,
        trackId: 'track_score_midi',
        rawStartMs: 500,
        clipId: 'clip_score',
      );

      final lane = project.tracks.firstWhere((t) => t.trackId == 'track_score_midi');
      expect(lane.clips.single.durationMs, TimelineProjectEntity.defaultNonAudioClipDurationMs);
    });

    test('isTrackAudible respects Mute and Solo rules', () {
      var project = TimelineProjectEntity.defaultWorkspace();
      expect(project.isTrackAudible(project.tracks[0]), isTrue);

      project = project.toggleTrackMute('track_deck_a');
      expect(project.isTrackAudible(project.tracks[0]), isFalse);

      project = project.toggleTrackSolo('track_deck_b');
      expect(project.isTrackAudible(project.tracks[1]), isTrue);
      expect(project.isTrackAudible(project.tracks[2]), isFalse);
    });

    test('JSON roundtrip preserves MediaAssetEntity and TimelineProjectEntity', () {
      var project = TimelineProjectEntity.defaultWorkspace();
      project = project.placeAssetOnTrack(
        asset: trackA,
        trackId: 'track_deck_a',
        rawStartMs: 0,
        clipId: 'clip_1',
      );

      final decodedAsset = MediaAssetEntity.fromMetadataJson(trackA.toMetadataJson());
      expect(decodedAsset.id, trackA.id);
      expect(decodedAsset.camelotKey, '8A');
      expect(decodedAsset.tags, trackA.tags);

      final decodedProject = TimelineProjectEntity.fromJson(project.toJson());
      expect(decodedProject.totalDurationMs, 4000);
      expect(decodedProject.tracks.first.clips.single.clipId, 'clip_1');
    });
  });
}
