import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/data/song_decomposer_service.dart';

void main() {
  group('SongDecomposerService Logic Tests', () {
    test('normalizeNoteName normalizes English letter notation to Solfège', () {
      expect(SongDecomposerService.normalizeNoteName('c4'), 'Do4');
      expect(SongDecomposerService.normalizeNoteName('d#5'), 'Re#5');
      expect(SongDecomposerService.normalizeNoteName('eb4'), 'Mib4');
      expect(SongDecomposerService.normalizeNoteName('f4'), 'Fa4');
      expect(SongDecomposerService.normalizeNoteName('g3'), 'Sol3');
      expect(SongDecomposerService.normalizeNoteName('a4'), 'La4');
      expect(SongDecomposerService.normalizeNoteName('b5'), 'Si5');
    });

    test('normalizeNoteName handles rests and standard solfège correctly', () {
      expect(SongDecomposerService.normalizeNoteName('_'), '');
      expect(SongDecomposerService.normalizeNoteName('r'), '');
      expect(SongDecomposerService.normalizeNoteName('sil'), '');
      expect(SongDecomposerService.normalizeNoteName('do4'), 'Do4');
      expect(SongDecomposerService.normalizeNoteName('sol#4'), 'Sol#4');
    });

    test('parseMelodyText converts space-separated notes into valid measures with 4/4 meter', () {
      const melody = 'Do4:4 Re4:4 Mi4:4 Fa4:4 | Sol4:8 Fa4:8';
      final measures = SongDecomposerService.parseMelodyText(melody, TimeSignature.commonTime44);

      expect(measures.length, 2);

      // Primer compás: 4 negras (4 * 4 = 16 ticks)
      expect(measures[0].notes.length, 4);
      expect(measures[0].notes[0].noteName, 'Do4');
      expect(measures[0].notes[0].durationTicks, 4);
      expect(measures[0].notes[3].noteName, 'Fa4');

      // Segundo compás: 2 blancas (2 * 8 = 16 ticks)
      expect(measures[1].notes.length, 2);
      expect(measures[1].notes[0].noteName, 'Sol4');
      expect(measures[1].notes[0].durationTicks, 8);
      expect(measures[1].notes[1].noteName, 'Fa4');
      expect(measures[1].notes[1].durationTicks, 8);
    });

    test('parseMelodyText automatically pads incomplete measures with rests', () {
      const melody = 'Do4:4 Re4:4'; // Solo 8 ticks de 16
      final measures = SongDecomposerService.parseMelodyText(melody, TimeSignature.commonTime44);

      expect(measures.length, 1);
      expect(measures[0].notes.length, 3);
      expect(measures[0].notes[0].noteName, 'Do4');
      expect(measures[0].notes[1].noteName, 'Re4');
      expect(measures[0].notes[2].isRest, isTrue);
      expect(measures[0].notes[2].durationTicks, 8); // Silencio de relleno
    });

    test('parseMelodyText works accurately with 3/4 waltz meter', () {
      const melody = 'Mi4:4 Fa4:4 Sol4:4 | Do5:12'; // 3/4 -> 12 ticks por compás
      final measures = SongDecomposerService.parseMelodyText(melody, TimeSignature.waltzTime34);

      expect(measures.length, 2);
      expect(measures[0].timeSignature, TimeSignature.waltzTime34);
      expect(measures[0].notes.fold<int>(0, (acc, n) => acc + n.durationTicks), 12);
      expect(measures[1].notes.fold<int>(0, (acc, n) => acc + n.durationTicks), 12);
    });

    test('decomposeCustomScore produces isolated stems as requested', () {
      final measures = SongDecomposerService.parseMelodyText('Do4:4 Re4:4 Mi4:4 Fa4:4', TimeSignature.commonTime44);

      final package = SongDecomposerService.decomposeCustomScore(
        title: 'Estudio de Violín',
        composer: 'Niccolò Paganini',
        bpm: 130,
        timeSignature: TimeSignature.commonTime44,
        measures: measures,
        includeLead: true,
        includePiano: true,
        includeBass: false,
        includeRhythm: true,
      );

      expect(package.title, 'Estudio de Violín');
      expect(package.composer, 'Niccolò Paganini');
      expect(package.defaultBpm, 130);
      expect(package.tracks.length, 3); // Lead, Piano, Rhythm
      expect(package.tracks.any((t) => t.id == 'lead_stem'), isTrue);
      expect(package.tracks.any((t) => t.id == 'harmony_stem'), isTrue);
      expect(package.tracks.any((t) => t.id == 'bass_stem'), isFalse);
      expect(package.tracks.any((t) => t.id == 'rhythm_stem'), isTrue);
    });

    test('getDecompositionTemplates provides canonical pedagogical templates', () {
      final templates = SongDecomposerService.getDecompositionTemplates();
      expect(templates.isNotEmpty, isTrue);
      expect(templates.any((t) => t.title.contains('Estrellita')), isTrue);
      expect(templates.any((t) => t.composer.contains('Bach')), isTrue);
      expect(templates.any((t) => t.composer.contains('Vivaldi')), isTrue);
    });
  });
}
