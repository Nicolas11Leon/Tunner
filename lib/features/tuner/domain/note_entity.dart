import 'dart:math';

class NoteEntity {
  final String name;
  final double frequency;
  final double cents; // Desviación precisa de -50 a +50

  NoteEntity({required this.name, required this.frequency, required this.cents});

  static NoteEntity fromFrequency(double freq, {double a4Ref = 440.0}) {
    if (freq <= 0 || freq.isNaN || freq.isInfinite) {
      return NoteEntity(name: "--", frequency: 0.0, cents: 0.0);
    }

    final notes = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"];
    
    // Fórmula matemática estándar MIDI con tono de concierto parametrizable: 12 * log2(f / a4Ref) + 69
    final double safeRef = (a4Ref <= 0 || a4Ref.isNaN || a4Ref.isInfinite) ? 440.0 : a4Ref;
    double midi = 12 * (log(freq / safeRef) / log(2)) + 69;
    int roundedMidi = midi.round();
    double centsDeviation = (midi - roundedMidi) * 100;

    String noteName = notes[roundedMidi % 12];
    int octave = (roundedMidi / 12).floor() - 1;

    return NoteEntity(
      name: "$noteName$octave",
      frequency: freq,
      cents: centsDeviation,
    );
  }

  /// Calcula la frecuencia matemática teórica (en Hz) para un nombre de nota dado (ej: "La4", "Do4", "Mi4")
  /// basada en la afinación temperada con concierto A4 = 440.0 Hz (o personalizable).
  static double frequencyForNote(String noteWithNameAndOctave, {double a4Ref = 440.0}) {
    if (noteWithNameAndOctave == "--" || noteWithNameAndOctave.isEmpty) return 0.0;

    final notes = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"];

    // Separar nombre de nota y octava (ej: "Do4" -> note: "Do", octave: 4; "Fa#5" -> note: "Fa#", octave: 5)
    final match = RegExp(r'^([A-Za-z#]+)(-?\d+)$').firstMatch(noteWithNameAndOctave);
    if (match == null) return 0.0;

    final noteNamePart = match.group(1);
    final octavePart = int.tryParse(match.group(2) ?? "");
    if (noteNamePart == null || octavePart == null) return 0.0;

    final noteIndex = notes.indexWhere((n) => n.toLowerCase() == noteNamePart.toLowerCase());
    if (noteIndex == -1) return 0.0;

    // Fórmula estándar: número MIDI = (octava + 1) * 12 + noteIndex
    final int midi = (octavePart + 1) * 12 + noteIndex;

    // Frecuencia = a4Ref * 2^((midi - 69) / 12)
    return a4Ref * pow(2.0, (midi - 69) / 12.0);
  }
}