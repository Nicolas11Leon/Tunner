class SongNote {
  final int startTick;     // En qué sub-pulso inicia (0 al 15 para un compás de 4/4)
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
      // Ejemplo: Mezcla de Negra, Silencio de Negra, dos Corcheas y cuatro Semicorcheas
      SongNote(startTick: 0, durationTicks: 4, noteName: "Do4"), // Negra (Ocupa ticks 0,1,2,3)
      SongNote(startTick: 4, durationTicks: 4, noteName: "", isRest: true), // Silencio de Negra (ticks 4,5,6,7)
      SongNote(startTick: 8, durationTicks: 2, noteName: "Re4"), // Corchea (ticks 8,9)
      SongNote(startTick: 10, durationTicks: 2, noteName: "Mi4"), // Corchea (ticks 10,11)
      SongNote(startTick: 12, durationTicks: 1, noteName: "Fa4"), // Semicorchea (tick 12)
      SongNote(startTick: 13, durationTicks: 1, noteName: "Sol4"), // Semicorchea (tick 13)
      SongNote(startTick: 14, durationTicks: 1, noteName: "La4"), // Semicorchea (tick 14)
      SongNote(startTick: 15, durationTicks: 1, noteName: "Si4"), // Semicorchea (tick 15)
    ];
  }
}

class SongEntity {
  final String title;
  final List<SongNote> notes;

  SongEntity({required this.title, required this.notes});

  static List<SongEntity> getMockSongs() {
    return [
      SongEntity(
        title: "Estudio de Subdivisiones Rítmicas",
        notes: SongNote.getMockRhythms(),
      ),
    ];
  }
}