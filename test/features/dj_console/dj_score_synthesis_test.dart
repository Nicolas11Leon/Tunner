import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_audio_processor.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_track_loader_modal.dart';
import 'package:tunner/features/song_library/data/song_decomposer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DJ Score Audio Synthesis & Preset Grooves Tests (UC-97)', () {
    late DjAudioProcessor processor;

    setUp(() {
      processor = DjAudioProcessor(sampleRate: 44100);
    });

    test('synthesizeSongPackageTrack produces authentic Für Elise audio buffer', () {
      final curated = SongDecomposerService.getCuratedLibrary();
      final furElise = curated.firstWhere((s) => s.id == 'beethoven_fur_elise');

      final samples = processor.synthesizeSongPackageTrack(
        furElise,
        deckId: 'A',
        durationMs: 4000,
      );

      expect(samples.length, equals(44100 * 4));
      expect(samples.any((s) => s != 0.0), isTrue);

      // Verify no digital clipping occurred
      for (final s in samples) {
        expect(s >= -1.0 && s <= 1.0, isTrue);
      }
    });

    test('synthesizeSongPackageTrack produces distinct audio for Canon in D vs Für Elise', () {
      final curated = SongDecomposerService.getCuratedLibrary();
      final furElise = curated.firstWhere((s) => s.id == 'beethoven_fur_elise');
      final canon = curated.firstWhere((s) => s.id == 'pachelbel_canon');

      final samplesElise = processor.synthesizeSongPackageTrack(furElise, deckId: 'A', durationMs: 2000);
      final samplesCanon = processor.synthesizeSongPackageTrack(canon, deckId: 'A', durationMs: 2000);

      expect(samplesElise.length, equals(samplesCanon.length));

      // Calculate difference between both waveforms
      double diffSum = 0.0;
      for (int i = 0; i < samplesElise.length; i++) {
        diffSum += (samplesElise[i] - samplesCanon[i]).abs();
      }

      // Must be substantially distinct acoustic tracks
      expect(diffSum / samplesElise.length, greaterThan(0.05));
    });

    test('synthesizePresetTrack produces unique sonic signatures for all 5 presets', () {
      final presets = DjTrackLoaderModal.studioLibrary;
      expect(presets.length, equals(5));

      final generatedTracks = <String, Float32List>{};
      for (final p in presets) {
        final buffer = processor.synthesizePresetTrack(
          p.title,
          bpm: p.bpm,
          deckId: 'A',
          durationMs: 2000,
        );
        expect(buffer.length, equals(44100 * 2));
        generatedTracks[p.title] = buffer;
      }

      // Compare every pair of presets to verify none are identical
      final keys = generatedTracks.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        for (int j = i + 1; j < keys.length; j++) {
          final b1 = generatedTracks[keys[i]]!;
          final b2 = generatedTracks[keys[j]]!;

          double diff = 0.0;
          for (int k = 0; k < b1.length; k++) {
            diff += (b1[k] - b2[k]).abs();
          }
          final avgDiff = diff / b1.length;
          expect(avgDiff, greaterThan(0.04), reason: '${keys[i]} vs ${keys[j]} must have distinct audio');
        }
      }
    });

    test('DjConsoleViewModel loads Für Elise with beat tracking and audio buffer', () async {
      final vm = DjConsoleViewModel();
      final curated = SongDecomposerService.getCuratedLibrary();
      final furElise = curated.firstWhere((s) => s.id == 'beethoven_fur_elise');

      final samples = processor.synthesizeSongPackageTrack(
        furElise,
        deckId: 'A',
        durationMs: 4000,
      );

      final detectedBpm = vm.loadTrackWithBeatTracking(
        'A',
        title: furElise.title,
        artist: furElise.composer,
        audioSamples: samples,
      );

      expect(vm.deckA.trackTitle, equals(furElise.title));
      expect(vm.deckA.artist, equals(furElise.composer));
      expect(detectedBpm, greaterThan(60.0));
      expect(vm.waveformA.isNotEmpty, isTrue);

      vm.dispose();
    });
  });
}
