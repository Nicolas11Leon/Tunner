import 'dart:math' as math;
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../tuner/domain/note_entity.dart';

/// Operaciones puras de edición y mutación inmutable del árbol de partituras (Score Tree).
/// Pure Dart: Cero dependencias de Flutter UI.
class ScoreEditorOperations {
  const ScoreEditorOperations();

  /// Inserta o actualiza una nota en un compás y posición temporal específicos.
  /// Resuelve automáticamente los solapamientos con notas preexistentes dentro del compás.
  SongPackage insertOrUpdateNote({
    required SongPackage package,
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required String noteName,
  }) {
    if (measureIndex < 0 || measureIndex >= package.score.measures.length) {
      return package;
    }

    final targetMeasure = package.score.measures[measureIndex];
    final maxTicks = targetMeasure.timeSignature.totalTicks;

    final clampedStartTick = startTick.clamp(0, maxTicks - 1);
    final clampedDuration = math.min(durationTicks, maxTicks - clampedStartTick);
    if (clampedDuration <= 0) return package;

    final newEndTick = clampedStartTick + clampedDuration;

    // Filtrar y recortar notas preexistentes que se solapen
    final newNotes = <HierarchicalNote>[];
    for (final existing in targetMeasure.notes) {
      final existingStart = existing.startTick;
      final existingEnd = existing.startTick + existing.durationTicks;

      // Caso 1: La nota existente está completamente antes o después del nuevo rango
      if (existingEnd <= clampedStartTick || existingStart >= newEndTick) {
        newNotes.add(existing);
      }
      // Caso 2: La nota existente comienza antes del nuevo rango pero se solapa al final
      else if (existingStart < clampedStartTick && existingEnd > clampedStartTick) {
        final shortenedDuration = clampedStartTick - existingStart;
        if (shortenedDuration > 0) {
          newNotes.add(existing.copyWith(durationTicks: shortenedDuration));
        }
      }
      // Caso 3: La nota existente comienza dentro del nuevo rango pero termina después
      else if (existingStart >= clampedStartTick && existingEnd > newEndTick) {
        final remainingStart = newEndTick;
        final remainingDuration = existingEnd - newEndTick;
        if (remainingDuration > 0) {
          newNotes.add(existing.copyWith(
            startTick: remainingStart,
            durationTicks: remainingDuration,
          ));
        }
      }
    }

    // Insertar la nueva nota
    newNotes.add(HierarchicalNote(
      startTick: clampedStartTick,
      durationTicks: clampedDuration,
      noteName: noteName,
    ));

    // Ordenar cronológicamente por startTick
    newNotes.sort((a, b) => a.startTick.compareTo(b.startTick));

    // Crear el compás actualizado
    final updatedMeasure = targetMeasure.copyWith(notes: newNotes);

    final updatedMeasures = List<MeasureEntity>.from(package.score.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    return package.copyWith(
      score: package.score.copyWith(measures: updatedMeasures),
    );
  }

  /// Elimina la nota en el tick dado reemplazándola por un silencio ("--").
  SongPackage deleteNoteAt({
    required SongPackage package,
    required int measureIndex,
    required int startTick,
  }) {
    if (measureIndex < 0 || measureIndex >= package.score.measures.length) {
      return package;
    }

    final targetMeasure = package.score.measures[measureIndex];
    final updatedNotes = targetMeasure.notes.map((n) {
      if (n.startTick == startTick) {
        return n.copyWith(noteName: "--");
      }
      return n;
    }).toList();

    final updatedMeasures = List<MeasureEntity>.from(package.score.measures);
    updatedMeasures[measureIndex] = targetMeasure.copyWith(notes: updatedNotes);

    return package.copyWith(
      score: package.score.copyWith(measures: updatedMeasures),
    );
  }

  /// Añade un compás vacío al final de la partitura con la métrica indicada.
  SongPackage addMeasure({
    required SongPackage package,
    TimeSignature? timeSignature,
  }) {
    final ts = timeSignature ??
        (package.score.measures.isNotEmpty
            ? package.score.measures.last.timeSignature
            : TimeSignature.commonTime44);

    final newIndex = package.score.measures.length;
    final emptyMeasure = MeasureEntity(
      index: newIndex,
      timeSignature: ts,
      notes: [
        HierarchicalNote(
          startTick: 0,
          durationTicks: ts.totalTicks,
          noteName: "--", // Silencio de compás completo
        ),
      ],
    );

    final updatedMeasures = [...package.score.measures, emptyMeasure];
    return package.copyWith(
      score: package.score.copyWith(measures: updatedMeasures),
    );
  }

  /// Elimina el compás en el índice especificado (preservando siempre al menos 1 compás).
  SongPackage removeMeasure({
    required SongPackage package,
    required int measureIndex,
  }) {
    if (package.score.measures.length <= 1) return package;
    if (measureIndex < 0 || measureIndex >= package.score.measures.length) return package;

    final updatedMeasures = List<MeasureEntity>.from(package.score.measures);
    updatedMeasures.removeAt(measureIndex);

    // Re-indexar compases restantes
    final reindexed = <MeasureEntity>[];
    for (int i = 0; i < updatedMeasures.length; i++) {
      reindexed.add(updatedMeasures[i].copyWith(index: i));
    }

    return package.copyWith(
      score: package.score.copyWith(measures: reindexed),
    );
  }

  /// Transpone todas las notas melódicas activas de la partitura por una cantidad de semitonos.
  SongPackage transposeScore({
    required SongPackage package,
    required int semitones,
  }) {
    if (semitones == 0) return package;

    final updatedMeasures = package.score.measures.map((measure) {
      final updatedNotes = measure.notes.map((note) {
        if (note.noteName == "--" || note.noteName.toLowerCase() == "rest") {
          return note;
        }
        final transposedName = _transposeNoteName(note.noteName, semitones);
        return note.copyWith(noteName: transposedName);
      }).toList();

      return measure.copyWith(notes: updatedNotes);
    }).toList();

    return package.copyWith(
      score: package.score.copyWith(measures: updatedMeasures),
    );
  }

  static String _transposeNoteName(String noteName, int semitones) {
    try {
      final freq = NoteEntity.frequencyForNote(noteName);
      if (freq <= 0) return noteName;
      final transposedFreq = freq * math.pow(2.0, semitones / 12.0);
      final entity = NoteEntity.fromFrequency(transposedFreq);
      return entity.name;
    } catch (_) {
      return noteName;
    }
  }
}

/// Gestor de transacciones con patrón Memento para Deshacer / Rehacer (Undo / Redo).
class ScoreUndoRedoHistory {
  final int maxHistoryLength;
  final List<SongPackage> _undoStack = [];
  final List<SongPackage> _redoStack = [];

  ScoreUndoRedoHistory({this.maxHistoryLength = 50});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// Registra el estado actual antes de aplicar una mutación.
  void recordState(SongPackage currentState) {
    _undoStack.add(currentState);
    if (_undoStack.length > maxHistoryLength) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Deshace la última mutación y retorna el estado previo.
  SongPackage? undo(SongPackage currentState) {
    if (_undoStack.isEmpty) return null;
    final previousState = _undoStack.removeLast();
    _redoStack.add(currentState);
    return previousState;
  }

  /// Rehace la última mutación revertida y retorna el estado siguiente.
  SongPackage? redo(SongPackage currentState) {
    if (_redoStack.isEmpty) return null;
    final nextState = _redoStack.removeLast();
    _undoStack.add(currentState);
    return nextState;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
