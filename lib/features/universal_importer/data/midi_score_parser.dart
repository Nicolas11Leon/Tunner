import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';

/// Decodificador binario en Dart puro para archivos MIDI estándar (.mid / .midi).
/// Parsea cabeceras MThd, pistas MTrk y eventos de canal NoteOn/NoteOff sin dependencias externas.
class MidiScoreParser implements IScoreParserService {
  const MidiScoreParser();

  @override
  bool canParse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mid') || lower.endsWith('.midi')) {
      return true;
    }
    // Detección por firma mágica MIDI: "MThd" (0x4D, 0x54, 0x68, 0x64)
    if (bytes.length >= 4) {
      return bytes[0] == 0x4D && bytes[1] == 0x54 && bytes[2] == 0x68 && bytes[3] == 0x64;
    }
    return false;
  }

  @override
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.length < 14) {
      throw const FormatException('El archivo MIDI es demasiado corto o está corrupto.');
    }

    final byteData = ByteData.sublistView(bytes);

    // 1. Validar Cabecera MThd
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'MThd') {
      throw const FormatException('Cabecera MThd no encontrada. Archivo MIDI no válido.');
    }

    final int headerLength = byteData.getUint32(4);
    // ignore: unused_local_variable
    final int formatType = byteData.getUint16(8);
    final int numTracks = byteData.getUint16(10);
    final int rawDivision = byteData.getUint16(12);

    // PPQ (Pulses Per Quarter Note) protegido contra división por cero
    final int ppq = ((rawDivision & 0x8000) == 0 && rawDivision > 0) ? rawDivision : 480;

    int offset = 8 + headerLength;
    int bpm = 120;
    String songTitle = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (songTitle.isEmpty) songTitle = 'Secuencia MIDI';

    final List<_RawMidiNote> rawNotes = [];
    final List<AudioTrack> stemTracks = [];
    TimeSignature detectedTimeSignature = TimeSignature.commonTime44;

    // 2. Procesar cada Track Chunk (MTrk)
    for (int t = 0; t < numTracks && offset + 8 <= bytes.length; t++) {
      final trackMagic = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final trackLength = byteData.getUint32(offset + 4);
      offset += 8;

      if (trackMagic != 'MTrk') {
        offset += trackLength;
        continue;
      }

      final trackEnd = (offset + trackLength).clamp(0, bytes.length);
      int trackCursor = offset;
      int absoluteTicks = 0;
      int runningStatus = 0;

      final Map<int, int> activeNotesStart = {}; // pitch -> startTick
      String trackTitle = 'Pista ${t + 1}';

      while (trackCursor < trackEnd) {
        // Leer Delta-time de longitud variable
        final delta = _readVariableLength(bytes, trackCursor);
        absoluteTicks += delta.value;
        trackCursor = delta.nextOffset;

        if (trackCursor >= trackEnd) break;

        int status = bytes[trackCursor];
        if (status < 0x80) {
          // Running status
          if (runningStatus == 0) break;
          status = runningStatus;
        } else {
          trackCursor++;
          runningStatus = status >= 0xF0 ? 0 : status;
        }

        final eventType = status & 0xF0;

        if (status == 0xFF) {
          // Meta-evento
          if (trackCursor >= trackEnd) break;
          final metaType = bytes[trackCursor++];
          final len = _readVariableLength(bytes, trackCursor);
          trackCursor = len.nextOffset;

          final dataEnd = (trackCursor + len.value).clamp(0, trackEnd);
          final metaBytes = bytes.sublist(trackCursor, dataEnd);
          trackCursor = dataEnd;

          if (metaType == 0x03) {
            // Track Name
            final name = String.fromCharCodes(metaBytes).trim();
            if (name.isNotEmpty) trackTitle = name;
          } else if (metaType == 0x51 && metaBytes.length >= 3) {
            // Set Tempo
            final microsecs = (metaBytes[0] << 16) | (metaBytes[1] << 8) | metaBytes[2];
            if (microsecs > 0) {
              bpm = (60000000 / microsecs).round().clamp(20, 300);
            }
          } else if (metaType == 0x58 && metaBytes.length >= 2) {
            // Time Signature (metaBytes[1] representa potencia de 2: 0..4 => 1, 2, 4, 8, 16)
            final num = metaBytes[0];
            final denShift = metaBytes[1];
            if (num > 0 && denShift <= 4) {
              final den = 1 << denShift;
              if (num == 4 && den == 4) {
                detectedTimeSignature = TimeSignature.commonTime44;
              } else if (num == 3 && den == 4) {
                detectedTimeSignature = TimeSignature.waltzTime34;
              } else if (num == 2 && den == 4) {
                detectedTimeSignature = TimeSignature.marchTime24;
              } else if (num == 6 && den == 8) {
                detectedTimeSignature = TimeSignature.compoundTime68;
              } else if (num == 9 && den == 8) {
                detectedTimeSignature = TimeSignature.compoundTime98;
              } else if (num == 12 && den == 8) {
                detectedTimeSignature = TimeSignature.compoundTime128;
              } else if (num == 5 && den == 4) {
                detectedTimeSignature = TimeSignature.complexTime54;
              } else {
                detectedTimeSignature = TimeSignature(num, den);
              }
            }
          }
        } else if (status == 0xF0 || status == 0xF7) {
          // SysEx event
          final len = _readVariableLength(bytes, trackCursor);
          trackCursor = (len.nextOffset + len.value).clamp(0, trackEnd);
        } else if (eventType == 0x90 || eventType == 0x80) {
          // Note On o Note Off
          if (trackCursor + 1 >= trackEnd) break;
          final pitch = bytes[trackCursor++];
          final velocity = bytes[trackCursor++];

          final isNoteOn = eventType == 0x90 && velocity > 0;

          if (isNoteOn) {
            activeNotesStart[pitch] = absoluteTicks;
          } else {
            final start = activeNotesStart.remove(pitch);
            if (start != null && absoluteTicks > start) {
              rawNotes.add(_RawMidiNote(
                pitch: pitch,
                startTick: start,
                durationTicks: absoluteTicks - start,
                trackIndex: t,
              ));
            }
          }
        } else if (eventType == 0xC0 || eventType == 0xD0) {
          // Program Change / Channel Pressure (1 byte dato)
          if (trackCursor < trackEnd) trackCursor++;
        } else if (eventType == 0xA0 || eventType == 0xB0 || eventType == 0xE0) {
          // Aftertouch / Control Change / Pitch Bend (2 bytes dato)
          if (trackCursor + 1 < trackEnd) trackCursor += 2;
        }
      }

      stemTracks.add(AudioTrack(
        id: "midi_track_$t",
        title: trackTitle,
        instrumentIcon: t == 0 ? "music_note" : (t % 2 == 0 ? "piano" : "equalizer"),
        volume: 0.85,
      ));

      offset = trackEnd;
    }

    // 3. Cuantizar notas y estructurar compases
    final measures = _quantizeToMeasures(rawNotes, ppq, bpm, detectedTimeSignature);

    final score = HierarchicalScore(
      title: songTitle,
      baseBpm: bpm,
      measures: measures,
    );

    final cleanId = "midi_${DateTime.now().millisecondsSinceEpoch}";
    final songPackage = SongPackage(
      id: cleanId,
      title: songTitle,
      composer: "Secuencia MIDI",
      genre: MusicGenre.contemporary,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      score: score,
      tracks: stemTracks.isNotEmpty
          ? stemTracks
          : const [
              AudioTrack(id: "main", title: "Pista MIDI", instrumentIcon: "music_note", volume: 0.9),
            ],
    );

    return ParsedScoreResult(
      package: songPackage,
      format: 'MIDI',
      totalMeasures: measures.length,
      totalNotes: rawNotes.length,
    );
  }

  static _VlqResult _readVariableLength(Uint8List bytes, int offset) {
    int value = 0;
    int cursor = offset;
    for (int i = 0; i < 4 && cursor < bytes.length; i++) {
      final b = bytes[cursor++];
      value = (value << 7) | (b & 0x7F);
      if ((b & 0x80) == 0) break;
    }
    return _VlqResult(value, cursor);
  }

  List<MeasureEntity> _quantizeToMeasures(
    List<_RawMidiNote> rawNotes,
    int ppq,
    int bpm,
    TimeSignature timeSignature,
  ) {
    final measureTicks = timeSignature.totalTicks > 0 ? timeSignature.totalTicks : 16;
    if (rawNotes.isEmpty) {
      // Compas vacio por defecto
      return [
        MeasureEntity(
          index: 0,
          timeSignature: timeSignature,
          notes: [HierarchicalNote.rest(startTick: 0, durationTicks: measureTicks)],
        )
      ];
    }

    // Ordenar notas cronologicamente y por altura ascendente
    rawNotes.sort((a, b) {
      final tickCmp = a.startTick.compareTo(b.startTick);
      if (tickCmp != 0) return tickCmp;
      return a.pitch.compareTo(b.pitch);
    });

    // Cuantizar ticks MIDI a cuadricula de Tunner (4 ticks por negra).
    final safePpq = ppq > 0 ? ppq : 480;
    final ticksPerMeasureMidi =
        ((safePpq * 4 * timeSignature.numerator) / timeSignature.denominator)
            .round()
            .clamp(1, 1 << 24);
    final maxMidiTick =
        rawNotes.map((n) => n.startTick + n.durationTicks).reduce((a, b) => a > b ? a : b);
    final totalMeasuresCount = ((maxMidiTick / ticksPerMeasureMidi).ceil()).clamp(1, 4096);

    final measures = <MeasureEntity>[];

    for (int m = 0; m < totalMeasuresCount; m++) {
      final measureStartMidi = m * ticksPerMeasureMidi;
      final measureEndMidi = measureStartMidi + ticksPerMeasureMidi;

      // Notas que inician dentro de este compas, agrupadas por startTick cuantizado
      final groupedByStartTick = <int, List<_RawMidiNote>>{};
      for (final raw in rawNotes) {
        if (raw.startTick >= measureStartMidi && raw.startTick < measureEndMidi) {
          final localMidiStart = raw.startTick - measureStartMidi;
          final quantizedStartTick =
              ((localMidiStart * 4) / safePpq).round().clamp(0, measureTicks - 1);
          groupedByStartTick.putIfAbsent(quantizedStartTick, () => []).add(raw);
        }
      }

      final sortedTicks = groupedByStartTick.keys.toList()..sort();
      final measureNotes = <HierarchicalNote>[];
      int timelineCursor = 0;

      for (final groupStartTick in sortedTicks) {
        // Rellenar silencio previo o intermedio si hay hueco temporal sin notas activas
        if (groupStartTick > timelineCursor) {
          measureNotes.add(HierarchicalNote.rest(
            startTick: timelineCursor,
            durationTicks: groupStartTick - timelineCursor,
          ));
          timelineCursor = groupStartTick;
        }

        final chordEvents = groupedByStartTick[groupStartTick]!
          ..sort((a, b) => a.pitch.compareTo(b.pitch));

        int maxGroupEndTick = groupStartTick;
        for (final raw in chordEvents) {
          final duration = ((raw.durationTicks * 4) / safePpq)
              .round()
              .clamp(1, measureTicks - groupStartTick);
          final noteName = _midiPitchToNoteName(raw.pitch);

          measureNotes.add(HierarchicalNote.note(
            startTick: groupStartTick,
            durationTicks: duration,
            noteName: noteName,
          ));

          final noteEndTick = groupStartTick + duration;
          if (noteEndTick > maxGroupEndTick) {
            maxGroupEndTick = noteEndTick;
          }
        }

        if (maxGroupEndTick > timelineCursor) {
          timelineCursor = maxGroupEndTick;
        }
      }

      // Rellenar resto del compas con silencio si no completo measureTicks
      if (timelineCursor < measureTicks) {
        measureNotes.add(HierarchicalNote.rest(
          startTick: timelineCursor,
          durationTicks: measureTicks - timelineCursor,
        ));
      }

      measures.add(MeasureEntity(
        index: m,
        timeSignature: timeSignature,
        notes: measureNotes,
      ));
    }

    return measures;
  }

  static String _midiPitchToNoteName(int pitch) {
    const noteNames = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"];
    final safePitch = pitch.clamp(0, 127);
    final name = noteNames[safePitch % 12];
    final octave = ((safePitch / 12).floor() - 1).clamp(0, 8);
    return "$name$octave";
  }
}

class _RawMidiNote {
  final int pitch;
  final int startTick;
  final int durationTicks;
  final int trackIndex;

  const _RawMidiNote({
    required this.pitch,
    required this.startTick,
    required this.durationTicks,
    required this.trackIndex,
  });
}

class _VlqResult {
  final int value;
  final int nextOffset;
  const _VlqResult(this.value, this.nextOffset);
}
