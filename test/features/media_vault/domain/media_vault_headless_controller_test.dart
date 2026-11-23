import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/media_vault/domain/media_vault_headless_controller.dart';

void main() {
  group('MediaVaultHeadlessController', () {
    test('manages catalog, timeline clip sequencing, mute/solo, and JSON disk persistence', () {
      final controller = MediaVaultHeadlessController();

      final customAsset = MediaAssetEntity(
        id: 'asset_synth_lead',
        title: 'Analog Lead 124',
        fileName: 'analog_lead_124.wav',
        extensionName: 'wav',
        kind: MediaAssetKind.audioTrack,
        durationMs: 4000,
        bpm: 124.0,
        camelotKey: '8A',
        tags: const ['synth', 'lead'],
        createdAt: DateTime.utc(2026, 1, 1),
      );
      controller.registerAsset(customAsset);

      expect(controller.findAsset('asset_synth_lead'), isNotNull);
      expect(controller.searchAssets(query: 'analog').length, equals(1));

      final clip1 = controller.placeAssetOnTrack(
        assetId: 'asset_synth_lead',
        trackId: 'track_deck_a',
        rawStartMs: 0,
      );
      final clip2 = controller.placeAssetOnTrack(
        assetId: 'asset_synth_lead',
        trackId: 'track_deck_a',
        rawStartMs: 1000, // overlaps clip1 -> auto-shifts non-overlapping
      );

      expect(clip1, isNotNull);
      expect(clip2, isNotNull);
      final deckATrack = controller.project.tracks.firstWhere((t) => t.trackId == 'track_deck_a');
      expect(deckATrack.clips.length, equals(2));
      expect(deckATrack.clips[1].startMs, greaterThanOrEqualTo(deckATrack.clips[0].endMs));

      // Mute / solo checks
      controller.toggleTrackSolo('track_deck_a');
      expect(controller.isTrackAudible('track_deck_a'), isTrue);
      expect(controller.isTrackAudible('track_deck_b'), isFalse);

      controller.toggleTrackMute('track_deck_a');
      expect(controller.isTrackAudible('track_deck_a'), isFalse);

      // Persist to temp JSON file and restore into a fresh headless controller
      final tempDir = Directory.systemTemp.createTempSync('tunner_vault_headless_');
      try {
        final jsonFile = '${tempDir.path}/vault_state.json';
        controller.saveToFile(jsonFile);

        final restored = MediaVaultHeadlessController();
        final loaded = restored.loadFromFile(jsonFile);
        expect(loaded, isTrue);
        expect(restored.findAsset('asset_synth_lead')?.title, equals('Analog Lead 124'));
        final restoredTrack =
            restored.project.tracks.firstWhere((t) => t.trackId == 'track_deck_a');
        expect(restoredTrack.clips.length, equals(2));
        expect(restoredTrack.isSolo, isTrue);
        expect(restoredTrack.isMuted, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
