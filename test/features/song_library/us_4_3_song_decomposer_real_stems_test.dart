import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_decomposer_service.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';

void main() {
  group('US-4.3 SongDecomposerService Real Stems, Rests & Serialization Tests', () {
    test('parseMelodyText returns a single rest measure when input is empty (no hardcoded Do4-Mi4-Sol4-Do5)', () {
      final measures = SongDecomposerService.parseMelodyText(
        '',
        TimeSignature.commonTime44,
      );

      expect(measures.length, equals(1));
      expect(measures.first.notes.length, equals(1));
      expect(measures.first.notes.first.isRest, isTrue);
      expect(measures.first.notes.first.durationTicks, equals(16));
    });

    test('decomposeCustomScore generates real instrumental stemScores for lead, harmony, bass and rhythm', () {
      final measures = SongDecomposerService.parseMelodyText(
        'C4:4 E4:4 G4:4 C5:4',
        TimeSignature.commonTime44,
      );

      final package = SongDecomposerService.decomposeCustomScore(
        title: 'Obra Multi-Stem Real',
        composer: 'Tunner Test',
        bpm: 112,
        timeSignature: TimeSignature.commonTime44,
        measures: measures,
        includeLead: true,
        includePiano: true,
        includeBass: true,
        includeRhythm: true,
      );

      expect(package.defaultBpm, equals(112));
      expect(package.tracks.length, equals(4));
      expect(package.stemScores.keys, containsAll(['lead_stem', 'harmony_stem', 'bass_stem', 'rhythm_stem']));

      // Harmony stem debe contener triada (3 notas simultaneas en tick 0)
      final harmonyNotes = package.stemScores['harmony_stem']!.measures.first.notes;
      expect(harmonyNotes.length, equals(3));
      expect(harmonyNotes.every((n) => n.startTick == 0 && n.durationTicks == 16), isTrue);

      // Bass stem debe contener fundamental en registro grave (octava 2)
      final bassNotes = package.stemScores['bass_stem']!.measures.first.notes;
      expect(bassNotes.length, equals(1));
      expect(bassNotes.first.noteName.endsWith('2'), isTrue, reason: 'Bajo debe ubicarse en octava 2');

      // Rhythm stem debe contener 4 pulsos para 4/4
      final rhythmNotes = package.stemScores['rhythm_stem']!.measures.first.notes;
      expect(rhythmNotes.length, equals(4));
    });

    test('SongPackage toMap/fromMap round-trip preserves stemScores', () {
      final measures = [
        MeasureEntity(
          index: 0,
          timeSignature: TimeSignature.waltzTime34,
          notes: [HierarchicalNote.note(startTick: 0, durationTicks: 12, noteName: 'La4')],
        ),
      ];

      final pkg = SongDecomposerService.decomposeCustomScore(
        title: 'Vals en 3/4',
        composer: 'Autor',
        bpm: 95,
        timeSignature: TimeSignature.waltzTime34,
        measures: measures,
      );

      final map = pkg.toMap();
      final restored = SongPackage.fromMap(map);

      expect(restored.stemScores.length, equals(pkg.stemScores.length));
      expect(restored.stemScores['harmony_stem']!.measures.first.notes.length, equals(3));
      expect(restored.stemScores['rhythm_stem']!.measures.first.notes.length, equals(3));
    });
  });
}
