import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/data/song_decomposer_service.dart';

void main() {
  group('SongDecomposerService Domain Tests', () {
    test('Curated library contains verified classical repertoire with decomposed stems', () {
      final library = SongDecomposerService.getCuratedLibrary();
      expect(library.length, greaterThanOrEqualTo(3));

      final canon = library.firstWhere((s) => s.id == 'pachelbel_canon');
      expect(canon.title, equals('Canon en Re Mayor'));
      expect(canon.tracks.length, equals(3));
      expect(canon.totalMeasures, equals(2));
      expect(canon.score.isValidScore, isTrue);

      final furElise = library.firstWhere((s) => s.id == 'beethoven_fur_elise');
      expect(furElise.initialTimeSignature, equals(TimeSignature.waltzTime34));
      expect(furElise.tracks.length, equals(3));
    });

    test('Decomposing custom user score generates complete SongPackage with multi-tracks', () {
      final customMeasures = [
        MeasureEntity(
          index: 0,
          timeSignature: TimeSignature.marchTime24,
          notes: [
            HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Sol4"),
            HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Do5"),
          ],
        ),
      ];

      final customSong = SongDecomposerService.decomposeCustomScore(
        title: "Mi Canción Original",
        composer: "Usuario",
        bpm: 100,
        timeSignature: TimeSignature.marchTime24,
        measures: customMeasures,
      );

      expect(customSong.title, equals("Mi Canción Original"));
      expect(customSong.defaultBpm, equals(100));
      expect(customSong.tracks.length, equals(3));
      expect(customSong.tracks.any((t) => t.id == "user_piano"), isTrue);
      expect(customSong.totalMeasures, equals(1));
    });
  });
}
