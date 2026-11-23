import 'dart:math' as math;
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../tuner/domain/note_entity.dart';

/// Operaciones puras de edición y mutación inmutable del árbol de partituras (Score Tree).
/// Pure Dart: Cero dependencias de Flutter UI.
class ScoreEditorOperations {
  const ScoreEditorOperations();

  /// Inserta o actualiza una nota en un compás y posición temporal específicos.
  /// Resuelve automáticamente los solapamientos con notas preexistentes dentro de la misma
  /// combinación `(staff, voice)` del compás, preservando intactas las demás voces/pentagramas.
  SongPackage insertOrUpdateNote({
    required SongPackage package,
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required String noteName,
    int voice = 1,
    int staff = 1,
    bool isTied = false,
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
    final effectiveStaff = staff < 1 ? 1 : staff;
    final effectiveVoice = voice < 1 ? 1 : voice;

    // Filtrar y recortar solo notas preexistentes en la misma (staff, voice)
    final newNotes = _splitOverlappingNotes(
      targetMeasure.notes,
      clampedStartTick,
      newEndTick,
      staff: effectiveStaff,
      voice: effectiveVoice,
    );

    // Insertar la nueva nota
    newNotes.add(HierarchicalNote(
      startTick: clampedStartTick,
      durationTicks: clampedDuration,
      noteName: noteName,
      isRest: noteName == "--",
      isTied: noteName == "--" ? false : isTied,
      voice: effectiveVoice,
      staff: effectiveStaff,
    ));

    // Ordenar cronológicamente por startTick, luego por staff y voice
    newNotes.sort((a, b) {
      final tickComp = a.startTick.compareTo(b.startTick);
      if (tickComp != 0) return tickComp;
      final staffComp = a.staff.compareTo(b.staff);
      if (staffComp != 0) return staffComp;
      return a.voice.compareTo(b.voice);
    });

    // Crear el compás actualizado
    final updatedMeasure = targetMeasure.copyWith(notes: newNotes);

    final updatedMeasures = List<MeasureEntity>.from(package.score.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    final updatedStaffCount = math.max(package.score.staffCount, effectiveStaff);

    return package.copyWith(
      score: package.score.copyWith(
        measures: updatedMeasures,
        staffCount: updatedStaffCount,
      ),
    );
  }

  /// Inserta un acorde (múltiples notas simultáneas en el mismo startTick y duración)
  /// en un compás específico, resolviendo solapamientos rítmicos únicamente en la misma `(staff, voice)`.
  SongPackage insertChordNotes({
    required SongPackage package,
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required List<String> noteNames,
    int voice = 1,
    int staff = 1,
    bool isTied = false,
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
    final effectiveStaff = staff < 1 ? 1 : staff;
    final effectiveVoice = voice < 1 ? 1 : voice;

    // Filtrar y recortar solo notas preexistentes en la misma (staff, voice)
    final newNotes = _splitOverlappingNotes(
      targetMeasure.notes,
      clampedStartTick,
      newEndTick,
      staff: effectiveStaff,
      voice: effectiveVoice,
    );

    // Insertar las notas del acorde
    final filteredNoteNames = noteNames.where((n) => n.isNotEmpty && n != '--').toSet().toList();
    if (filteredNoteNames.isEmpty) {
      newNotes.add(HierarchicalNote(
        startTick: clampedStartTick,
        durationTicks: clampedDuration,
        noteName: "--",
        isRest: true,
        voice: effectiveVoice,
        staff: effectiveStaff,
      ));
    } else {
      for (final noteName in filteredNoteNames) {
        newNotes.add(HierarchicalNote(
          startTick: clampedStartTick,
          durationTicks: clampedDuration,
          noteName: noteName,
          isRest: false,
          isTied: isTied,
          voice: effectiveVoice,
          staff: effectiveStaff,
        ));
      }
    }

    // Ordenar cronológicamente por startTick, staff, voice y luego alfabéticamente
    newNotes.sort((a, b) {
      final tickComp = a.startTick.compareTo(b.startTick);
      if (tickComp != 0) return tickComp;
      final staffComp = a.staff.compareTo(b.staff);
      if (staffComp != 0) return staffComp;
      final voiceComp = a.voice.compareTo(b.voice);
      if (voiceComp != 0) return voiceComp;
      return a.noteName.compareTo(b.noteName);
    });

    final updatedMeasure = targetMeasure.copyWith(notes: newNotes);
    final updatedMeasures = List<MeasureEntity>.from(package.score.measures);
    updatedMeasures[measureIndex] = updatedMeasure;

    final updatedStaffCount = math.max(package.score.staffCount, effectiveStaff);

    return package.copyWith(
      score: package.score.copyWith(
        measures: updatedMeasures,
        staffCount: updatedStaffCount,
      ),
    );
  }

  /// Elimina la nota en el tick dado reemplazándola por un silencio ("--").
  /// Si se especifican [voice] o [staff], únicamente reemplaza notas coincidentes.
  SongPackage deleteNoteAt({
    required SongPackage package,
    required int measureIndex,
    required int startTick,
    int? voice,
    int? staff,
  }) {
    if (measureIndex < 0 || measureIndex >= package.score.measures.length) {
      return package;
    }

    final targetMeasure = package.score.measures[measureIndex];
    final updatedNotes = targetMeasure.notes.map((n) {
      final matchesVoice = voice == null || n.voice == voice;
      final matchesStaff = staff == null || n.staff == staff;
      if (n.startTick == startTick && matchesVoice && matchesStaff) {
        return n.copyWith(noteName: "--", isRest: true, isTied: false);
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
          isRest: true,
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
        if (note.isRest ||
            note.noteName.isEmpty ||
            note.noteName == "--" ||
            note.noteName.toLowerCase() == "rest") {
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

  /// Recorta notas existentes al insertar un nuevo rango `[clampedStartTick, newEndTick)`
  /// únicamente para notas pertenecientes a la misma combinación `(staff, voice)`,
  /// preservando tanto la cabeza previa como la cola posterior si una nota larga lo envuelve.
  static List<HierarchicalNote> _splitOverlappingNotes(
    List<HierarchicalNote> existingNotes,
    int clampedStartTick,
    int newEndTick, {
    int staff = 1,
    int voice = 1,
  }) {
    final newNotes = <HierarchicalNote>[];
    for (final existing in existingNotes) {
      if (existing.staff != staff || existing.voice != voice) {
        newNotes.add(existing);
        continue;
      }

      final existingStart = existing.startTick;
      final existingEnd = existing.startTick + existing.durationTicks;

      if (existingEnd <= clampedStartTick || existingStart >= newEndTick) {
        newNotes.add(existing);
        continue;
      }

      if (existingStart < clampedStartTick && existingEnd > clampedStartTick) {
        final shortenedDuration = clampedStartTick - existingStart;
        if (shortenedDuration > 0) {
          newNotes.add(existing.copyWith(durationTicks: shortenedDuration));
        }
      }

      if (existingEnd > newEndTick) {
        final remainingDuration = existingEnd - newEndTick;
        if (remainingDuration > 0) {
          newNotes.add(existing.copyWith(
            startTick: newEndTick,
            durationTicks: remainingDuration,
          ));
        }
      }
    }
    return newNotes;
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
