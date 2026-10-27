import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/score_editor/domain/score_editor_domain.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';

void main() {
  group('ScoreEditorOperations & UndoRedoHistory Domain Tests', () {
    const ops = ScoreEditorOperations();

    late SongPackage initialPackage;

    setUp(() {
      initialPackage = SongPackage(
        id: 'test_score',
        title: 'Estudio de Prueba',
        composer: 'Composer',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 80,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Estudio de Prueba',
          baseBpm: 80,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
                HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Re4'),
                HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Mi4'),
                HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'Fa4'),
              ],
            ),
          ],
        ),
      );
    });

    test('insertOrUpdateNote updates existing note at same tick cleanly', () {
      final updated = ops.insertOrUpdateNote(
        package: initialPackage,
        measureIndex: 0,
        startTick: 4,
        durationTicks: 4,
        noteName: 'Sol4',
      );

      final measureNotes = updated.score.measures.first.notes;
      expect(measureNotes.length, 4);
      expect(measureNotes[1].noteName, 'Sol4');
      expect(measureNotes[1].startTick, 4);
      expect(measureNotes[1].durationTicks, 4);
    });

    test('insertOrUpdateNote splits and truncates overlapping notes', () {
      // Overwrite from tick 2 to 6 (duration 4) -> overlaps Do4 (0..4) and Re4 (4..8)
      final updated = ops.insertOrUpdateNote(
        package: initialPackage,
        measureIndex: 0,
        startTick: 2,
        durationTicks: 4,
        noteName: 'La4',
      );

      final notes = updated.score.measures.first.notes;
      // Note 0: Do4 shortened to duration 2 (ticks 0..2)
      expect(notes[0].noteName, 'Do4');
      expect(notes[0].startTick, 0);
      expect(notes[0].durationTicks, 2);

      // Note 1: La4 (ticks 2..6)
      expect(notes[1].noteName, 'La4');
      expect(notes[1].startTick, 2);
      expect(notes[1].durationTicks, 4);

      // Note 2: Re4 shortened (ticks 6..8)
      expect(notes[2].noteName, 'Re4');
      expect(notes[2].startTick, 6);
      expect(notes[2].durationTicks, 2);
    });

    test('deleteNoteAt replaces note with rest symbol "--"', () {
      final updated = ops.deleteNoteAt(
        package: initialPackage,
        measureIndex: 0,
        startTick: 8,
      );

      final notes = updated.score.measures.first.notes;
      expect(notes[2].noteName, '--');
      expect(notes[2].startTick, 8);
    });

    test('addMeasure and removeMeasure manipulate score measures count correctly', () {
      expect(initialPackage.score.measures.length, 1);

      final added = ops.addMeasure(package: initialPackage);
      expect(added.score.measures.length, 2);
      expect(added.score.measures.last.index, 1);
      expect(added.score.measures.last.notes.first.noteName, '--'); // Empty rest

      final removed = ops.removeMeasure(package: added, measureIndex: 1);
      expect(removed.score.measures.length, 1);

      // Cannot remove the only remaining measure
      final cantRemoveLast = ops.removeMeasure(package: removed, measureIndex: 0);
      expect(cantRemoveLast.score.measures.length, 1);
    });

    test('transposeScore shifts all melodic notes by given semitones', () {
      final transposed = ops.transposeScore(package: initialPackage, semitones: 2);
      final notes = transposed.score.measures.first.notes;

      // Do4 + 2 semitones -> Re4
      expect(notes[0].noteName, contains('Re'));
      // Re4 + 2 semitones -> Mi4
      expect(notes[1].noteName, contains('Mi'));
    });

    test('ScoreUndoRedoHistory supports bidirectional undo and redo', () {
      final history = ScoreUndoRedoHistory();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);

      // 1. Record initial state before edit
      history.recordState(initialPackage);

      // 2. Perform edit
      final edit1 = ops.insertOrUpdateNote(
        package: initialPackage,
        measureIndex: 0,
        startTick: 0,
        durationTicks: 4,
        noteName: 'Si4',
      );

      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      // 3. Undo
      final reverted = history.undo(edit1);
      expect(reverted, isNotNull);
      expect(reverted!.score.measures.first.notes.first.noteName, 'Do4');
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);

      // 4. Redo
      final reapplied = history.redo(reverted);
      expect(reapplied, isNotNull);
      expect(reapplied!.score.measures.first.notes.first.noteName, 'Si4');
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });
  });
}
