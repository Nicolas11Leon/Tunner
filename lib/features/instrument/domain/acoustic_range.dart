/// Definición inmutable del rango acústico y afinación estándar de un instrumento.
library;

/// Rango tonal, frecuencias extremas en Hz y afinación base de cuerdas/parches.
class AcousticRange {
  /// Frecuencia mínima fundamental producible en Hertz.
  final double minFrequencyHz;

  /// Frecuencia máxima fundamental producible en Hertz.
  final double maxFrequencyHz;

  /// Nota MIDI mínima ejecutable (ej. 40 para E2 de guitarra, 21 para A0 de piano).
  final int minMidiNote;

  /// Nota MIDI máxima ejecutable (ej. 88 para E6 de guitarra, 108 para C8 de piano).
  final int maxMidiNote;

  /// Frecuencias estándar de las cuerdas al aire o alturas nominales (en Hz).
  final List<double> standardTuningFrequencies;

  /// Nombres de las notas de afinación estándar (ej. ["E2", "A2", "D3", "G3", "B3", "E4"]).
  final List<String> standardTuningNoteNames;

  const AcousticRange({
    required this.minFrequencyHz,
    required this.maxFrequencyHz,
    required this.minMidiNote,
    required this.maxMidiNote,
    this.standardTuningFrequencies = const [],
    this.standardTuningNoteNames = const [],
  }) : assert(minFrequencyHz > 0.0),
       assert(maxFrequencyHz >= minFrequencyHz),
       assert(minMidiNote >= 0 && minMidiNote <= 127),
       assert(maxMidiNote >= minMidiNote && maxMidiNote <= 127);

  /// Verifica si una frecuencia en Hz se encuentra dentro del registro físico del instrumento.
  bool containsFrequency(double freqHz) {
    return freqHz >= (minFrequencyHz * 0.95) && freqHz <= (maxFrequencyHz * 1.05);
  }

  /// Verifica si una nota MIDI se encuentra dentro de la tesitura del instrumento.
  bool containsMidiNote(int midiNote) {
    return midiNote >= minMidiNote && midiNote <= maxMidiNote;
  }
}
