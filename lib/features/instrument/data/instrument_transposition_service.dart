import 'dart:math';
import '../domain/i_instrument_transposition_service.dart';
import '../domain/instrument_profile_entity.dart';

/// Implementación canónica del servicio de transposición musical por instrumento.
class InstrumentTranspositionService implements IInstrumentTranspositionService {
  static const List<String> _chromaticScale = [
    'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'
  ];

  const InstrumentTranspositionService();

  int? _noteNameToMidi(String note) {
    if (note == '--' || note.isEmpty) return null;

    final match = RegExp(r'^([A-Za-z#]+)(-?\d+)$').firstMatch(note.trim());
    if (match == null) return null;

    final noteNamePart = match.group(1);
    final octavePart = int.tryParse(match.group(2) ?? '');
    if (noteNamePart == null || octavePart == null) return null;

    // Normalizar bemoles comunes si aplican
    String normalizedName = noteNamePart;
    if (normalizedName.toLowerCase() == 'sib') normalizedName = 'La#';
    if (normalizedName.toLowerCase() == 'mib') normalizedName = 'Re#';
    if (normalizedName.toLowerCase() == 'lab') normalizedName = 'Sol#';
    if (normalizedName.toLowerCase() == 'reb') normalizedName = 'Do#';
    if (normalizedName.toLowerCase() == 'solb') normalizedName = 'Fa#';

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
