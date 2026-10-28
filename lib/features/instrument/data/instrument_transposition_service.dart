import 'dart:math';
import '../domain/i_instrument_transposition_service.dart';
import '../domain/instrument_profile_entity.dart';

/// Implementación canónica del servicio de transposición musical por instrumento.
/// Soporta notación solfeo (Do, Re, Mi...) y anglosajona (C, D, E...), bemoles (b, ♭) y sostenidos (#, ♯).
class InstrumentTranspositionService implements IInstrumentTranspositionService {
  static const List<String> _chromaticScale = [
    'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'
  ];

  const InstrumentTranspositionService();

  int? _noteNameToMidi(String note) {
    if (note == '--' || note.isEmpty) return null;

    final trimmed = note.trim();
    // Reemplazar símbolos tipográficos Unicode comunes
    final sanitized = trimmed.replaceAll('♭', 'b').replaceAll('♯', '#');

    final match = RegExp(r'^([A-Za-z#]+)(-?\d+)$').firstMatch(sanitized);
    if (match == null) return null;

    final noteNamePart = match.group(1);
    final octavePart = int.tryParse(match.group(2) ?? '');
    if (noteNamePart == null || octavePart == null) return null;

    // 1. Mapeo anglosajón a Solfeo si aplica (e.g. C4 -> Do4, Bb3 -> Sib3)
    const englishToSolfege = {
      'C': 'Do',
      'D': 'Re',
      'E': 'Mi',
      'F': 'Fa',
      'G': 'Sol',
      'A': 'La',
      'B': 'Si',
    };

    String normalizedName = noteNamePart;
    final upperFirst = normalizedName[0].toUpperCase();
    if (englishToSolfege.containsKey(upperFirst) &&
        (normalizedName.length == 1 || normalizedName[1] == '#' || normalizedName[1].toLowerCase() == 'b')) {
      final solfegeBase = englishToSolfege[upperFirst]!;
      final accidental = normalizedName.length > 1 ? normalizedName.substring(1) : '';
      normalizedName = '$solfegeBase$accidental';
    }

    // 2. Normalizar enarmonías de bemoles a sostenidos estándar
    final lower = normalizedName.toLowerCase();
    if (lower == 'sib') {
      normalizedName = 'La#';
    } else if (lower == 'mib') {
      normalizedName = 'Re#';
    } else if (lower == 'lab') {
      normalizedName = 'Sol#';
    } else if (lower == 'reb') {
      normalizedName = 'Do#';
    } else if (lower == 'solb') {
      normalizedName = 'Fa#';
    } else if (lower == 'dob') {
      normalizedName = 'Si';
    } else if (lower == 'fab') {
      normalizedName = 'Mi';
    }

    final index = _chromaticScale.indexWhere(
      (n) => n.toLowerCase() == normalizedName.toLowerCase(),
    );
    if (index == -1) return null;

    return (octavePart + 1) * 12 + index;
  }

  String _midiToNoteName(int midi) {
    final noteIndex = midi % 12;
    final octave = (midi ~/ 12) - 1;
    return '${_chromaticScale[noteIndex]}$octave';
  }

  @override
  String getSoundingNote(String writtenNote, InstrumentProfileEntity instrument) {
    final midi = _noteNameToMidi(writtenNote);
    if (midi == null) return writtenNote;

    final soundingMidi = midi + instrument.transpositionSemitones;
    return _midiToNoteName(soundingMidi);
  }

  @override
  double getSoundingFrequency(
    String writtenNote,
    InstrumentProfileEntity instrument, {
    double a4Ref = 440.0,
  }) {
    final midi = _noteNameToMidi(writtenNote);
    if (midi == null) return 0.0;

    final soundingMidi = midi + instrument.transpositionSemitones;
    return a4Ref * pow(2.0, (soundingMidi - 69) / 12.0);
  }

  @override
  String getWrittenNote(String soundingNote, InstrumentProfileEntity instrument) {
    final midi = _noteNameToMidi(soundingNote);
    if (midi == null) return soundingNote;

    final writtenMidi = midi - instrument.transpositionSemitones;
    return _midiToNoteName(writtenMidi);
  }
}
