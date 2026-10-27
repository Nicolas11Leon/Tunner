import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';

/// Evento interno para la secuenciación de bytes MIDI.
class _MidiEvent {
  final int absoluteTick;
  final List<int> data;

  _MidiEvent({required this.absoluteTick, required this.data});
}

/// Serializador canónico en Pure Dart de partituras a archivos Standard MIDI File (SMF Format 0).
/// Produce un [Uint8List] binario reproducible en cualquier DAW o reproductor multimedia.
class CanonicalMidiExporter {
  /// Pulsos por negra (PPQN - Pulses Per Quarter Note).
  static const int ppqn = 480;

  /// Relación de ticks: en Tunner 1 negra = 4 ticks -> cada tick equivale a 120 ticks MIDI.
  static const int midiTicksPerTunnerTick = 120;

  const CanonicalMidiExporter();

  /// Exporta un [SongPackage] a un arreglo binario Standard MIDI File.
  Uint8List exportToMidi(SongPackage package) {
    return exportScore(
      score: package.score,
      bpm: package.defaultBpm,
      trackName: package.title,
    );
  }

  /// Exporta un [HierarchicalScore] a bytes Standard MIDI File.
  Uint8List exportScore({
    required HierarchicalScore score,
    int bpm = 75,
    String trackName = "Tunner Composition",
    int programNumber = 73, // Flauta (General MIDI 73)
  }) {
    final events = <_MidiEvent>[];

    // 1. Meta Evento: Nombre de la pista en tick 0
    final nameBytes = trackName.codeUnits;
    events.add(_MidiEvent(
      absoluteTick: 0,
      data: [0xFF, 0x03, ...encodeVlq(nameBytes.length), ...nameBytes],
    ));

    // 2. Meta Evento: Compás métrico (Time Signature) en tick 0
    final firstTs = score.measures.isNotEmpty
        ? score.measures.first.timeSignature
        : TimeSignature.commonTime44;
    int denomPower = 2; // 2^2 = 4 (denominador de negras)
    if (firstTs.denominator == 2) denomPower = 1;
    if (firstTs.denominator == 8) denomPower = 3;
    if (firstTs.denominator == 16) denomPower = 4;

    events.add(_MidiEvent(
      absoluteTick: 0,
      data: [0xFF, 0x58, 0x04, firstTs.numerator, denomPower, 24, 8],
    ));

    // 3. Meta Evento: Tempo (Microsegundos por negra)
    final safeBpm = bpm.clamp(20, 300);
    final int usPerBeat = (60000000 / safeBpm).round();
    events.add(_MidiEvent(
      absoluteTick: 0,
      data: [
        0xFF,
        0x51,
        0x03,
        (usPerBeat >> 16) & 0xFF,
        (usPerBeat >> 8) & 0xFF,
        usPerBeat & 0xFF,
      ],
    ));

    // 4. Program Change (Instrumento Flauta en Canal 0)
    events.add(_MidiEvent(
      absoluteTick: 0,
      data: [0xC0, programNumber.clamp(0, 127)],
    ));

    // 5. Generar eventos NoteOn y NoteOff para cada compás y nota
    int measureBaseTick = 0;
    for (int mIdx = 0; mIdx < score.measures.length; mIdx++) {
      final measure = score.measures[mIdx];
      final measureTicksTotal = measure.timeSignature.totalTicks * midiTicksPerTunnerTick;

      for (final note in measure.notes) {
        final isRest = note.noteName == "--" ||
            note.noteName.toLowerCase() == "rest" ||
            note.noteName.isEmpty;

        if (!isRest) {
          final midiPitch = noteNameToMidiPitch(note.noteName);
          final startMidiTick = measureBaseTick + (note.startTick * midiTicksPerTunnerTick);
          final durationMidiTicks = note.durationTicks * midiTicksPerTunnerTick;
          final endMidiTick = startMidiTick + durationMidiTicks;

          // Note On (Canal 0, Velocidad 96)
          events.add(_MidiEvent(
            absoluteTick: startMidiTick,
            data: [0x90, midiPitch, 96],
          ));

          // Note Off (Canal 0, Velocidad 0)
          events.add(_MidiEvent(
            absoluteTick: endMidiTick,
            data: [0x80, midiPitch, 0],
          ));
        }
      }

      measureBaseTick += measureTicksTotal;
    }

    // 6. Ordenar todos los eventos cronológicamente por absoluteTick
    events.sort((a, b) => a.absoluteTick.compareTo(b.absoluteTick));

    // 7. Meta Evento: End of Track
    final int finalTick = events.isNotEmpty ? events.last.absoluteTick : 0;
    events.add(_MidiEvent(
      absoluteTick: finalTick,
      data: [0xFF, 0x2F, 0x00],
    ));

    // 8. Construir bytes del Chunk MTrk con Delta-Times en VLQ
    final trackBytes = BytesBuilder(copy: false);
    int previousTick = 0;

    for (final event in events) {
      final int deltaTick = event.absoluteTick - previousTick;
      final vlqDelta = encodeVlq(deltaTick);
      trackBytes.add(vlqDelta);
      trackBytes.add(event.data);
      previousTick = event.absoluteTick;
    }

    final trackData = trackBytes.toBytes();

    // 9. Construir archivo MIDI completo (MThd + MTrk)
    final midiFile = BytesBuilder(copy: false);

    // MThd Header (14 bytes)
    midiFile.add([0x4D, 0x54, 0x68, 0x64]); // "MThd"
    midiFile.add([0x00, 0x00, 0x00, 0x06]); // Chunk length = 6
    midiFile.add([0x00, 0x00]);             // Format 0 (Single track)
    midiFile.add([0x00, 0x01]);             // 1 Track
    midiFile.add([(ppqn >> 8) & 0xFF, ppqn & 0xFF]); // 480 PPQN

    // MTrk Header (8 bytes) + Data
    midiFile.add([0x4D, 0x54, 0x72, 0x6B]); // "MTrk"
    final trackLength = trackData.length;
    midiFile.add([
      (trackLength >> 24) & 0xFF,
      (trackLength >> 16) & 0xFF,
      (trackLength >> 8) & 0xFF,
      trackLength & 0xFF,
    ]);
    midiFile.add(trackData);

    return midiFile.toBytes();
  }

  /// Codifica un número entero a representación MIDI de longitud variable (VLQ).
  static List<int> encodeVlq(int value) {
    if (value <= 0) return [0];
    int buffer = value & 0x7F;
    final bytes = <int>[];
    while ((value >>= 7) > 0) {
      buffer <<= 8;
      buffer |= (value & 0x7F) | 0x80;
    }
    while (true) {
      bytes.add(buffer & 0xFF);
      if ((buffer & 0x80) != 0) {
        buffer >>= 8;
      } else {
        break;
      }
    }
    return bytes;
  }

  /// Convierte un nombre de nota musical (ej: "Do4", "Fa#5", "A4", "Bb3")
  /// a número de nota MIDI estándar [0..127]. Do4 / C4 = 60, La4 / A4 = 69.
  static int noteNameToMidiPitch(String rawName) {
    String name = rawName.trim();
    if (name.isEmpty) return 60;

    final Map<String, int> solfegeOffsets = {
      'DO': 0,
      'RE': 2,
      'MI': 4,
      'FA': 5,
      'SOL': 7,
      'LA': 9,
      'SI': 11,
    };

    final Map<String, int> letterOffsets = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };

    String upper = name.toUpperCase();
    int semitone = 0;
    int octave = 4;

    bool found = false;
    for (final entry in solfegeOffsets.entries) {
      if (upper.startsWith(entry.key)) {
        semitone = entry.value;
        name = name.substring(entry.key.length);
        found = true;
        break;
      }
    }

    if (!found && name.isNotEmpty) {
      final firstChar = name[0].toUpperCase();
      if (letterOffsets.containsKey(firstChar)) {
        semitone = letterOffsets[firstChar]!;
        name = name.substring(1);
      }
    }

    if (name.contains('#') || name.contains('♯')) {
      semitone += 1;
      name = name.replaceAll('#', '').replaceAll('♯', '');
    } else if (name.contains('b') || name.contains('♭')) {
      semitone -= 1;
      name = name.replaceAll('b', '').replaceAll('♭', '');
    }

    final octMatch = RegExp(r'\d+').firstMatch(name);
    if (octMatch != null) {
      octave = int.tryParse(octMatch.group(0)!) ?? 4;
    }

    final midiNumber = (octave + 1) * 12 + semitone;
    return midiNumber.clamp(0, 127);
  }
}
