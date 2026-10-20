import 'score_tree.dart';

class SongNote {
  final int startTick;     // En qué sub-pulso inicia
  final int durationTicks; // Cuántos sub-pulsos dura la figura
  final String noteName;   // Nombre de la nota (ej: "Mi4"). Si es silencio, puede ser ""
  final bool isRest;       // True si es un silencio de cualquier tipo

  SongNote({
    required this.startTick,
    required this.durationTicks,
    required this.noteName,
    this.isRest = false,
  });

  static List<SongNote> getMockRhythms() {
    return [
      SongNote(startTick: 0, durationTicks: 4, noteName: "Do4"),
      SongNote(startTick: 4, durationTicks: 4, noteName: "", isRest: true),
      SongNote(startTick: 8, durationTicks: 2, noteName: "Re4"),
      SongNote(startTick: 10, durationTicks: 2, noteName: "Mi4"),
      SongNote(startTick: 12, durationTicks: 1, noteName: "Fa4"),
      SongNote(startTick: 13, durationTicks: 1, noteName: "Sol4"),
      SongNote(startTick: 14, durationTicks: 1, noteName: "La4"),
      SongNote(startTick: 15, durationTicks: 1, noteName: "Si4"),
    ];
  }
}

class SongEntity {
  final String title;
  final List<SongNote> notes;
  final TimeSignature timeSignature;
  final List<MeasureEntity> measures;

  SongEntity({
    required this.title,
    required this.notes,
    this.timeSignature = TimeSignature.commonTime44,
    this.measures = const [],
  });

  int get totalMeasures => measures.isNotEmpty ? measures.length : 1;

  /// Obtiene las notas de un compás específico en formato SongNote
  List<SongNote> notesForMeasure(int measureIndex) {
    if (measures.isEmpty || measureIndex < 0 || measureIndex >= measures.length) {
      return notes;
    }
    return measures[measureIndex].notes.map((hNote) {
      return SongNote(
        startTick: hNote.startTick,
        durationTicks: hNote.durationTicks,
        noteName: hNote.noteName,
        isRest: hNote.isRest,
      );
    }).toList();
  }

  /// Obtiene la métrica de un compás específico
  TimeSignature timeSignatureForMeasure(int measureIndex) {
    if (measures.isEmpty || measureIndex < 0 || measureIndex >= measures.length) {
      return timeSignature;
    }
    return measures[measureIndex].timeSignature;
  }

  static List<SongEntity> getMockSongs() {
    final hierarchicalStudies = HierarchicalScore.getMockStudies();

    return hierarchicalStudies.map((study) {
      final firstMeasure = study.measures.first;
      final songNotes = firstMeasure.notes.map((hNote) {
        return SongNote(
          startTick: hNote.startTick,
          durationTicks: hNote.durationTicks,
          noteName: hNote.noteName,
          isRest: hNote.isRest,
        );
      }).toList();

      return SongEntity(
        title: study.title,
        notes: songNotes,
        timeSignature: firstMeasure.timeSignature,
        measures: study.measures,
      );
    }).toList();
  }
}