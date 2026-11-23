import 'dart:math';

class NoteEntity {
  final String name;
  final double frequency;
  final double cents; // Desviación precisa de -50 a +50
  final int midiNumber;

  NoteEntity({
    required this.name,
    required this.frequency,
    required this.cents,
    this.midiNumber = 69,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'englishName': toEnglishName(),
        'solfegeName': toSolfegeName(),
        'frequency': frequency,
        'cents': cents,
        'midiNumber': midiNumber,
      };

  factory NoteEntity.fromJson(Map<String, dynamic> json) => NoteEntity(
        name: json['name'] as String? ?? '--',
        frequency: (json['frequency'] as num?)?.toDouble() ?? 0.0,
        cents: (json['cents'] as num?)?.toDouble() ?? 0.0,
        midiNumber: (json['midiNumber'] as num?)?.toInt() ?? 69,
      );

  static NoteEntity fromFrequency(double freq, {double a4Ref = 440.0}) {
    if (freq <= 0 || freq.isNaN || freq.isInfinite) {
      return NoteEntity(name: "--", frequency: 0.0, cents: 0.0, midiNumber: 0);
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
      midiNumber: roundedMidi,
    );
  }

  /// Diccionario canónico de resolución cromática para notación silábica (Do-Re-Mi)
  /// y notación anglosajona (C-D-E), con soporte para sostenidos (#) y bemoles (b).
  static int? parseNoteIndex(String rawName) {
    final lower = rawName.toLowerCase();
    switch (lower) {
      case 'c':
      case 'do':
      case 'b#':
      case 'si#':
        return 0;
      case 'c#':
      case 'db':
      case 'do#':
      case 'reb':
        return 1;
      case 'd':
      case 're':
        return 2;
      case 'd#':
      case 'eb':
      case 're#':
      case 'mib':
        return 3;
      case 'e':
      case 'mi':
      case 'fb':
      case 'fab':
        return 4;
      case 'f':
      case 'fa':
      case 'e#':
      case 'mi#':
        return 5;
      case 'f#':
      case 'gb':
      case 'fa#':
      case 'solb':
        return 6;
      case 'g':
      case 'sol':
        return 7;
      case 'g#':
      case 'ab':
      case 'sol#':
      case 'lab':
        return 8;
      case 'a':
      case 'la':
        return 9;
      case 'a#':
      case 'bb':
      case 'la#':
      case 'sib':
        return 10;
      case 'b':
      case 'si':
      case 'cb':
      case 'dob':
        return 11;
      default:
        return null;
    }
  }

  /// Retorna la representación anglosajona de la nota (ej: "A4", "C#3", "Bb5").
  String toEnglishName() {
    if (name == '--') return '--';
    final match = RegExp(r'^([A-Za-z#]+)(-?\d+)$').firstMatch(name);
    if (match == null) return name;
    final notePart = match.group(1)!;
    final octave = match.group(2)!;
    final idx = parseNoteIndex(notePart);
    if (idx == null) return name;
    const englishNotes = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];
    return '${englishNotes[idx]}$octave';
  }

  /// Retorna la representación silábica latina de la nota (ej: "La4", "Do#3", "Sib5").
  String toSolfegeName() {
    if (name == '--') return '--';
    final match = RegExp(r'^([A-Za-z#]+)(-?\d+)$').firstMatch(name);
    if (match == null) return name;
    final notePart = match.group(1)!;
    final octave = match.group(2)!;
    final idx = parseNoteIndex(notePart);
    if (idx == null) return name;
    const solfegeNotes = ['Do', 'Do#', 'Re', 'Mib', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'Sib', 'Si'];
    return '${solfegeNotes[idx]}$octave';
  }

  /// Calcula la frecuencia matemática teórica (en Hz) para un nombre de nota dado (ej: "La4", "Do4", "Mi4", "A4", "Bb3", "Cb4", "B#3")
  /// basada en la afinación temperada con concierto A4 = 440.0 Hz (o personalizable).
  static double frequencyForNote(String noteWithNameAndOctave, {double a4Ref = 440.0}) {
    if (noteWithNameAndOctave == "--" || noteWithNameAndOctave.isEmpty) return 0.0;

    final normalized = noteWithNameAndOctave.trim().replaceAll('♭', 'b').replaceAll('♯', '#');
    // Separar nombre de nota y octava (ej: "Do4" -> note: "Do", octave: 4; "Fa#5" -> note: "Fa#", octave: 5; "Bb3" -> note: "Bb", octave: 3)
    final match = RegExp(r'^([A-Za-z#]+)(-?\d+)$').firstMatch(normalized);
    if (match == null) return 0.0;

    final noteNamePart = match.group(1);
    final octavePart = int.tryParse(match.group(2) ?? "");
    if (noteNamePart == null || octavePart == null) return 0.0;

    final noteIndex = parseNoteIndex(noteNamePart);
    if (noteIndex == null) return 0.0;

    final lowerNote = noteNamePart.toLowerCase();
    int octaveOffset = 0;
    if (lowerNote == 'cb' || lowerNote == 'dob') {
      octaveOffset = -1;
    } else if (lowerNote == 'b#' || lowerNote == 'si#') {
      octaveOffset = 1;
    }

    // Fórmula estándar: número MIDI = (octava + octaveOffset + 1) * 12 + noteIndex
    final int midi = (octavePart + octaveOffset + 1) * 12 + noteIndex;

    // Frecuencia = a4Ref * 2^((midi - 69) / 12)
    return a4Ref * pow(2.0, (midi - 69) / 12.0);
  }
}