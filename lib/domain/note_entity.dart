import 'dart:math';

class NoteEntity {
  final String name;
  final double frequency;
  final double cents; // Desviación precisa de -50 a +50

  NoteEntity({required this.name, required this.frequency, required this.cents});

  static NoteEntity fromFrequency(double freq) {
    if (freq <= 0 || freq.isNaN || freq.isInfinite) {
      return NoteEntity(name: "--", frequency: 0.0, cents: 0.0);
    }

    final notes = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"];
    
    // Fórmula matemática estándar MIDI: 12 * log2(f / 440) + 69
    double midi = 12 * (log(freq / 440.0) / log(2)) + 69;
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
}