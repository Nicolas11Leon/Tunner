import 'dart:convert';
import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import 'canonical_pitch_notation_codec.dart';

/// Evento interno para la secuenciación de bytes MIDI.
class _MidiEvent {
  final int absoluteTick;
  final List<int> data;

  _MidiEvent({required this.absoluteTick, required this.data});
}

/// Serializador canónico en Pure Dart de partituras a archivos Standard MIDI File (SMF Format 0 y Format 1).
/// Produce un [Uint8List] binario reproducible en cualquier DAW o reproductor multimedia,
/// soportando multipista por `(staff, voice)` y Program Change dinámico configurable.
class CanonicalMidiExporter {
  /// Pulsos por negra (PPQN - Pulses Per Quarter Note).
  static const int ppqn = 480;

  /// Relación de ticks: en Tunner 1 negra = 4 ticks -> cada tick equivale a 120 ticks MIDI.
  static const int midiTicksPerTunnerTick = 120;

  const CanonicalMidiExporter();

  /// Exporta un [SongPackage] a un arreglo binario Standard MIDI File.
  /// Si [programNumber] no se especifica, infiere un programa General MIDI coherente
  /// a partir de las pistas del paquete (por defecto 0 = Acoustic Grand Piano).
  Uint8List exportToMidi(
    SongPackage package, {
    int? programNumber,
    int? format,
    Map<int, int>? staffProgramNumbers,
  }) {
    final resolvedProgram = programNumber ?? _inferGeneralMidiProgram(package);
    return exportScore(
      score: package.score,
      bpm: package.defaultBpm,
      trackName: package.title,
      programNumber: resolvedProgram,
      format: format,
      staffProgramNumbers: staffProgramNumbers,
    );
  }

  /// Exporta un [HierarchicalScore] a bytes Standard MIDI File.
  /// - Cuando la partitura tiene múltiples flujos `(staff, voice)`, `staffCount > 1` o `format == 1`,
  ///   emite **SMF Format 1** (pista 0 de tempo/métrica/armadura + 1 pista por `(staff, voice)`).
  /// - En partituras de un solo flujo y `format != 1`, emite **SMF Format 0** (1 pista consolidada).
  Uint8List exportScore({
    required HierarchicalScore score,
    int bpm = 75,
    String trackName = "Tunner Composition",
    int programNumber = 0, // General MIDI 0 (Acoustic Grand Piano) por defecto, configurable
    int? format,
    Map<int, int>? staffProgramNumbers,
  }) {
    final streamSet = <(int, int)>{};
    for (final measure in score.measures) {
      for (final note in measure.notes) {
        if (!_isRestNote(note)) {
          streamSet.add((note.staff, note.voice));
        }
      }
    }
    if (streamSet.isEmpty) {
      streamSet.add((1, 1));
    }
    final streams = streamSet.toList()
      ..sort((a, b) {
        final staffCmp = a.$1.compareTo(b.$1);
        if (staffCmp != 0) return staffCmp;
        return a.$2.compareTo(b.$2);
      });

    final useFormat1 = (format == 1) ||
        (format == null && (streams.length > 1 || score.staffCount > 1));

    if (useFormat1) {
      return _exportSmfFormat1(
        score: score,
        bpm: bpm,
        trackName: trackName,
        defaultProgramNumber: programNumber,
        staffProgramNumbers: staffProgramNumbers,
        streams: streams,
      );
    }

    return _exportSmfFormat0(
      score: score,
      bpm: bpm,
      trackName: trackName,
      programNumber: programNumber,
    );
  }

  Uint8List _exportSmfFormat0({
    required HierarchicalScore score,
    required int bpm,
    required String trackName,
    required int programNumber,
  }) {
    final events = <_MidiEvent>[];

    // 1. Meta Eventos globales (nombre, métrica, armadura, tempo)
    events.addAll(_buildGlobalMetaEvents(score: score, bpm: bpm, trackName: trackName));

    // 2. Program Change configurable en Canal 0
    events.add(_MidiEvent(
      absoluteTick: 0,
      data: [0xC0, programNumber.clamp(0, 127)],
    ));

    // 3. Eventos NoteOn y NoteOff para todas las notas
    events.addAll(_buildNoteEvents(score: score, channel: 0));

    final trackData = _serializeTrackEvents(events);
    return _assembleMidiFile(format: 0, tracks: [trackData]);
  }

  Uint8List _exportSmfFormat1({
    required HierarchicalScore score,
    required int bpm,
    required String trackName,
    required int defaultProgramNumber,
    required Map<int, int>? staffProgramNumbers,
    required List<(int, int)> streams,
  }) {
    final tracks = <Uint8List>[];

    // Pista 0: Conductor / Meta Track (Nombre, Tempo, Time Signatures, Key Signatures)
    final metaEvents = _buildGlobalMetaEvents(score: score, bpm: bpm, trackName: trackName);
    tracks.add(_serializeTrackEvents(metaEvents));

    // Pistas 1..N: Una pista MTrk por cada flujo (staff, voice)
    for (int i = 0; i < streams.length; i++) {
      final stream = streams[i];
      final staff = stream.$1;
      final voice = stream.$2;
      // Evitar canal 9 (percusión GM) en asignación melódica automática
      int channel = i % 15;
      if (channel >= 9) channel += 1;

      final streamProgram = (staffProgramNumbers != null && staffProgramNumbers.containsKey(staff))
          ? staffProgramNumbers[staff]!.clamp(0, 127)
          : defaultProgramNumber.clamp(0, 127);

      final trackEvents = <_MidiEvent>[];
      final subTrackName = utf8.encode('$trackName - Staff $staff Voice $voice');
      trackEvents.add(_MidiEvent(
        absoluteTick: 0,
        data: [0xFF, 0x03, ...encodeVlq(subTrackName.length), ...subTrackName],
      ));
      trackEvents.add(_MidiEvent(
        absoluteTick: 0,
        data: [0xC0 | channel, streamProgram],
      ));
      trackEvents.addAll(_buildNoteEvents(
        score: score,
        channel: channel,
        filterStaff: staff,
        filterVoice: voice,
      ));

      tracks.add(_serializeTrackEvents(trackEvents));
    }

    return _assembleMidiFile(format: 1, tracks: tracks);
  }

  List<_MidiEvent> _buildGlobalMetaEvents({
    required HierarchicalScore score,
    required int bpm,
    required String trackName,
  }) {
    final events = <_MidiEvent>[];

    // Nombre de la pista en tick 0 (UTF-8)
    final nameBytes = utf8.encode(trackName);
    events.add(_MidiEvent(
      absoluteTick: 0,
      data: [0xFF, 0x03, ...encodeVlq(nameBytes.length), ...nameBytes],
    ));

    // Tempo (Microsegundos por negra)
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

    if (score.measures.isEmpty) {
      events.add(_timeSignatureEvent(0, TimeSignature.commonTime44));
      events.add(_keySignatureEvent(0, 0));
      return events;
    }

    int measureBaseTick = 0;
    TimeSignature? prevTs;
    int? prevKeyFifths;
    for (final measure in score.measures) {
      if (prevTs == null || measure.timeSignature != prevTs) {
        events.add(_timeSignatureEvent(measureBaseTick, measure.timeSignature));
        prevTs = measure.timeSignature;
      }
      final clampedFifths = measure.keySignatureFifths.clamp(-7, 7);
      if (prevKeyFifths == null || clampedFifths != prevKeyFifths) {
        events.add(_keySignatureEvent(measureBaseTick, clampedFifths));
        prevKeyFifths = clampedFifths;
      }
      measureBaseTick += measure.timeSignature.totalTicks * midiTicksPerTunnerTick;
    }

    return events;
  }

  _MidiEvent _timeSignatureEvent(int absoluteTick, TimeSignature ts) {
    int denomPower = 2; // 2^2 = 4 (denominador de negras)
    if (ts.denominator == 1) denomPower = 0;
    if (ts.denominator == 2) denomPower = 1;
    if (ts.denominator == 8) denomPower = 3;
    if (ts.denominator == 16) denomPower = 4;

    return _MidiEvent(
      absoluteTick: absoluteTick,
      data: [0xFF, 0x58, 0x04, ts.numerator, denomPower, 24, 8],
    );
  }

  _MidiEvent _keySignatureEvent(int absoluteTick, int fifths) {
    final sfByte = fifths < 0 ? (256 + fifths) & 0xFF : fifths & 0xFF;
    return _MidiEvent(
      absoluteTick: absoluteTick,
      data: [0xFF, 0x59, 0x02, sfByte, 0x00],
    );
  }

  List<_MidiEvent> _buildNoteEvents({
    required HierarchicalScore score,
    required int channel,
    int? filterStaff,
    int? filterVoice,
  }) {
    final events = <_MidiEvent>[];
    int measureBaseTick = 0;

    for (final measure in score.measures) {
      final measureTicksTotal = measure.timeSignature.totalTicks * midiTicksPerTunnerTick;

      for (final note in measure.notes) {
        if (_isRestNote(note)) continue;
        if (filterStaff != null && note.staff != filterStaff) continue;
        if (filterVoice != null && note.voice != filterVoice) continue;

        final midiPitch = noteNameToMidiPitch(note.noteName);
        final startMidiTick = measureBaseTick + (note.startTick * midiTicksPerTunnerTick);
        final durationMidiTicks = note.durationTicks * midiTicksPerTunnerTick;
        final endMidiTick = startMidiTick + durationMidiTicks;

        events.add(_MidiEvent(
          absoluteTick: startMidiTick,
          data: [0x90 | channel, midiPitch, 96],
        ));
        events.add(_MidiEvent(
          absoluteTick: endMidiTick,
          data: [0x80 | channel, midiPitch, 0],
        ));
      }

      measureBaseTick += measureTicksTotal;
    }

    return events;
  }

  Uint8List _serializeTrackEvents(List<_MidiEvent> events) {
    // Ordenar cronológicamente por absoluteTick; a mismo tick, NoteOff precede a NoteOn
    events.sort((a, b) {
      final tickCmp = a.absoluteTick.compareTo(b.absoluteTick);
      if (tickCmp != 0) return tickCmp;
      final aIsOff = a.data.isNotEmpty &&
          ((a.data[0] & 0xF0) == 0x80 ||
              ((a.data[0] & 0xF0) == 0x90 && a.data.length > 2 && a.data[2] == 0));
      final bIsOff = b.data.isNotEmpty &&
          ((b.data[0] & 0xF0) == 0x80 ||
              ((b.data[0] & 0xF0) == 0x90 && b.data.length > 2 && b.data[2] == 0));
      if (aIsOff != bIsOff) return aIsOff ? -1 : 1;
      return 0;
    });

    final int finalTick = events.isNotEmpty ? events.last.absoluteTick : 0;
    events.add(_MidiEvent(
      absoluteTick: finalTick,
      data: [0xFF, 0x2F, 0x00],
    ));

    final trackBytes = BytesBuilder(copy: false);
    int previousTick = 0;

    for (final event in events) {
      final int deltaTick = event.absoluteTick - previousTick;
      trackBytes.add(encodeVlq(deltaTick));
      trackBytes.add(event.data);
      previousTick = event.absoluteTick;
    }

    return trackBytes.toBytes();
  }

  Uint8List _assembleMidiFile({
    required int format,
    required List<Uint8List> tracks,
  }) {
    final midiFile = BytesBuilder(copy: false);
    final trackCount = tracks.length;

    // MThd Header (14 bytes)
    midiFile.add([0x4D, 0x54, 0x68, 0x64]); // "MThd"
    midiFile.add([0x00, 0x00, 0x00, 0x06]); // Chunk length = 6
    midiFile.add([(format >> 8) & 0xFF, format & 0xFF]); // Format 0 o 1
    midiFile.add([(trackCount >> 8) & 0xFF, trackCount & 0xFF]); // Track count
    midiFile.add([(ppqn >> 8) & 0xFF, ppqn & 0xFF]); // 480 PPQN

    for (final trackData in tracks) {
      midiFile.add([0x4D, 0x54, 0x72, 0x6B]); // "MTrk"
      final trackLength = trackData.length;
      midiFile.add([
        (trackLength >> 24) & 0xFF,
        (trackLength >> 16) & 0xFF,
        (trackLength >> 8) & 0xFF,
        trackLength & 0xFF,
      ]);
      midiFile.add(trackData);
    }

    return midiFile.toBytes();
  }

  static bool _isRestNote(HierarchicalNote note) {
    return note.isRest ||
        note.noteName == "--" ||
        note.noteName.toLowerCase() == "rest" ||
        note.noteName.isEmpty;
  }

  static int _inferGeneralMidiProgram(SongPackage package) {
    final hints = <String>[
      package.title.toLowerCase(),
      ...package.tracks.map((t) => '${t.title} ${t.instrumentIcon}'.toLowerCase()),
    ].join(' ');

    if (hints.contains('piano') || hints.contains('teclado') || hints.contains('clave')) return 0;
    if (hints.contains('guitar') || hints.contains('guitarra')) return 24;
    if (hints.contains('bass') || hints.contains('bajo')) return 32;
    if (hints.contains('violin') || hints.contains('violín')) return 40;
    if (hints.contains('cello') || hints.contains('violonchelo')) return 42;
    if (hints.contains('trumpet') || hints.contains('trompeta')) return 56;
    if (hints.contains('sax')) return 65;
    if (hints.contains('flute') || hints.contains('flauta')) return 73;
    return 0; // Acoustic Grand Piano por defecto
  }

  /// Codifica un número entero a representación MIDI de longitud variable (VLQ)
  /// de forma segura para compilación Web (32-bit) y sin bucles `while (true)`.
  static List<int> encodeVlq(int value) {
    if (value <= 0) return [0];
    final reversed = <int>[value & 0x7F];
    int remaining = value >> 7;
    while (remaining > 0) {
      reversed.add((remaining & 0x7F) | 0x80);
      remaining >>= 7;
    }
    return reversed.reversed.toList();
  }

  /// Convierte un nombre de nota musical (ej: "Do4", "Fa#5", "A4", "Bb3")
  /// a número de nota MIDI estándar [0..127]. Do4 / C4 = 60, La4 / A4 = 69.
  static int noteNameToMidiPitch(String rawName) {
    return CanonicalPitchNotationCodec.parseOrDefault(rawName).midiNumber;
  }
}
