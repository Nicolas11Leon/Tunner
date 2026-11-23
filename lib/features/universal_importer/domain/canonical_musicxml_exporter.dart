import 'dart:math' as math;
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import 'canonical_pitch_notation_codec.dart';

/// Serializador canónico en Pure Dart de partituras a estándar W3C MusicXML 3.1/4.0.
/// Produce un archivo XML estructurado y compatible con MuseScore, Sibelius, Dorico y Finale.
/// Preserva armaduras (`keySignatureFifths`), ligaduras (`isTied`), múltiples voces (`voice`)
/// y múltiples pentagramas (`staff` / Grand Staff).
class CanonicalMusicXmlExporter {
  const CanonicalMusicXmlExporter();

  /// Exporta un [SongPackage] a una cadena formateada en formato MusicXML estándar.
  String exportToMusicXml(SongPackage package) {
    return exportScore(
      score: package.score,
      title: package.title,
      composer: package.composer,
    );
  }

  /// Exporta un [HierarchicalScore] a formato MusicXML.
  String exportScore({
    required HierarchicalScore score,
    String title = "Composición Tunner",
    String composer = "Tunner Music Studio",
  }) {
    final buffer = StringBuffer();

    // Determinar el número efectivo de pentagramas en la partitura (Grand Staff / multi-staff)
    int maxStaffInNotes = 1;
    for (final m in score.measures) {
      for (final n in m.notes) {
        if (n.staff > maxStaffInNotes) {
          maxStaffInNotes = n.staff;
        }
      }
    }
    final effectiveStaffCount = math.max(score.staffCount, maxStaffInNotes);

    // Cabecera canónica XML y DOCTYPE MusicXML
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">');
    buffer.writeln('<score-partwise version="3.1">');

    // Metadatos de la obra
    buffer.writeln('  <work>');
    buffer.writeln('    <work-title>${_escapeXml(title)}</work-title>');
    buffer.writeln('  </work>');
    buffer.writeln('  <identification>');
    buffer.writeln('    <creator type="composer">${_escapeXml(composer)}</creator>');
    buffer.writeln('    <encoding>');
    buffer.writeln('      <software>Tunner Open Source Music Engine</software>');
    buffer.writeln('    </encoding>');
    buffer.writeln('  </identification>');

    // Lista de partes (1 instrumento principal con 1 o más pentagramas)
    buffer.writeln('  <part-list>');
    buffer.writeln('    <score-part id="P1">');
    buffer.writeln('      <part-name>${_escapeXml(title)}</part-name>');
    buffer.writeln('    </score-part>');
    buffer.writeln('  </part-list>');

    // Contenido de la parte musical
    buffer.writeln('  <part id="P1">');

    TimeSignature? previousTimeSignature;
    int? previousKeyFifths;
    for (int mIdx = 0; mIdx < score.measures.length; mIdx++) {
      final measure = score.measures[mIdx];
      final measureNum = mIdx + 1;
      final ts = measure.timeSignature;
      final keyFifths = measure.keySignatureFifths.clamp(-7, 7);

      buffer.writeln('    <measure number="$measureNum">');

      // Atributos iniciales en el compas 1 o cambios de metrica/armadura inter-compas
      if (mIdx == 0) {
        buffer.writeln('      <attributes>');
        buffer.writeln('        <divisions>4</divisions>'); // 4 divisiones por negra (base semicorchea = 1 tick)
        buffer.writeln('        <key>');
        buffer.writeln('          <fifths>$keyFifths</fifths>');
        buffer.writeln('        </key>');
        buffer.writeln('        <time>');
        buffer.writeln('          <beats>${ts.numerator}</beats>');
        buffer.writeln('          <beat-type>${ts.denominator}</beat-type>');
        buffer.writeln('        </time>');
        if (effectiveStaffCount > 1) {
          buffer.writeln('        <staves>$effectiveStaffCount</staves>');
          for (int s = 1; s <= effectiveStaffCount; s++) {
            final isBass = (s == 2);
            buffer.writeln('        <clef number="$s">');
            buffer.writeln('          <sign>${isBass ? 'F' : 'G'}</sign>');
            buffer.writeln('          <line>${isBass ? '4' : '2'}</line>');
            buffer.writeln('        </clef>');
          }
        } else {
          buffer.writeln('        <clef>');
          buffer.writeln('          <sign>G</sign>');
          buffer.writeln('          <line>2</line>');
          buffer.writeln('        </clef>');
        }
        buffer.writeln('      </attributes>');
        buffer.writeln('      <direction placement="above">');
        buffer.writeln('        <sound tempo="${score.baseBpm}"/>');
        buffer.writeln('      </direction>');
      } else if (ts != previousTimeSignature || keyFifths != previousKeyFifths) {
        buffer.writeln('      <attributes>');
        if (keyFifths != previousKeyFifths) {
          buffer.writeln('        <key>');
          buffer.writeln('          <fifths>$keyFifths</fifths>');
          buffer.writeln('        </key>');
        }
        if (ts != previousTimeSignature) {
          buffer.writeln('        <time>');
          buffer.writeln('          <beats>${ts.numerator}</beats>');
          buffer.writeln('          <beat-type>${ts.denominator}</beat-type>');
          buffer.writeln('        </time>');
        }
        buffer.writeln('      </attributes>');
      }
      previousTimeSignature = ts;
      previousKeyFifths = keyFifths;

      // Agrupar notas por flujo independiente (staff, voice) para emitir <backup> en polifonía
      if (measure.notes.isEmpty) {
        buffer.write(_serializeNoteXml(
          HierarchicalNote.rest(startTick: 0, durationTicks: ts.totalTicks),
          includeStaffElement: effectiveStaffCount > 1,
        ));
      } else {
        final streams = <(int, int), List<HierarchicalNote>>{};
        for (final note in measure.notes) {
          streams.putIfAbsent((note.staff, note.voice), () => []).add(note);
        }
        final sortedStreamKeys = streams.keys.toList()
          ..sort((a, b) {
            final staffCmp = a.$1.compareTo(b.$1);
            if (staffCmp != 0) return staffCmp;
            return a.$2.compareTo(b.$2);
          });

        int cursorTick = 0;
        for (int sIdx = 0; sIdx < sortedStreamKeys.length; sIdx++) {
          final streamKey = sortedStreamKeys[sIdx];
          final streamNotes = List<HierarchicalNote>.from(streams[streamKey]!)
            ..sort((a, b) {
              final tickCmp = a.startTick.compareTo(b.startTick);
              if (tickCmp != 0) return tickCmp;
              final aRest = _isRestNote(a);
              final bRest = _isRestNote(b);
              if (aRest != bRest) return aRest ? 1 : -1;
              return 0;
            });

          if (sIdx > 0 && cursorTick > 0) {
            buffer.writeln('      <backup>');
            buffer.writeln('        <duration>$cursorTick</duration>');
            buffer.writeln('      </backup>');
            cursorTick = 0;
          }

          int? activeChordStartTick;
          for (final note in streamNotes) {
            final isRest = _isRestNote(note);
            final isChord = !isRest && (activeChordStartTick == note.startTick);

            if (!isChord && note.startTick > cursorTick) {
              final gap = note.startTick - cursorTick;
              buffer.writeln('      <forward>');
              buffer.writeln('        <duration>$gap</duration>');
              buffer.writeln('      </forward>');
              cursorTick = note.startTick;
            }

            if (isRest) {
              if (activeChordStartTick == note.startTick) {
                continue;
              }
              buffer.write(_serializeNoteXml(
                note,
                includeStaffElement: effectiveStaffCount > 1 || note.staff != 1,
              ));
              cursorTick = note.startTick + note.durationTicks;
            } else {
              if (!isChord) {
                activeChordStartTick = note.startTick;
                cursorTick = note.startTick + note.durationTicks;
              }
              buffer.write(_serializeNoteXml(
                note,
                isChord: isChord,
                includeStaffElement: effectiveStaffCount > 1 || note.staff != 1,
              ));
            }
          }
        }
      }

      buffer.writeln('    </measure>');
    }

    buffer.writeln('  </part>');
    buffer.writeln('</score-partwise>');

    return buffer.toString();
  }

  static bool _isRestNote(HierarchicalNote note) {
    return note.isRest ||
        note.noteName == "--" ||
        note.noteName.toLowerCase() == "rest" ||
        note.noteName.isEmpty;
  }

  /// Serializa una [HierarchicalNote] individual al nodo XML `<note>`.
  /// Emite `<chord/>` antes de `<pitch>` cuando forma parte de un acorde simultaneo,
  /// y preserva `voice`, `staff` e `isTied`.
  String _serializeNoteXml(
    HierarchicalNote note, {
    bool isChord = false,
    bool includeStaffElement = false,
  }) {
    final sb = StringBuffer();
    sb.writeln('      <note>');

    final isRest = _isRestNote(note);

    if (isRest) {
      sb.writeln('        <rest/>');
    } else {
      if (isChord) {
        sb.writeln('        <chord/>');
      }
      final pitchParts = _parseNoteName(note.noteName);
      sb.writeln('        <pitch>');
      sb.writeln('          <step>${pitchParts.step}</step>');
      if (pitchParts.alter != 0) {
        sb.writeln('          <alter>${pitchParts.alter}</alter>');
      }
      sb.writeln('          <octave>${pitchParts.octave}</octave>');
      sb.writeln('        </pitch>');
      if (pitchParts.alter != 0) {
        final String accName;
        if (pitchParts.alter >= 2) {
          accName = "double-sharp";
        } else if (pitchParts.alter == 1) {
          accName = "sharp";
        } else if (pitchParts.alter <= -2) {
          accName = "flat-flat";
        } else {
          accName = "flat";
        }
        sb.writeln('        <accidental>$accName</accidental>');
      }
    }

    sb.writeln('        <duration>${note.durationTicks}</duration>');
    if (!isRest && note.isTied) {
      sb.writeln('        <tie type="start"/>');
    }
    sb.writeln('        <voice>${note.voice}</voice>');
    sb.writeln('        <type>${_ticksToNoteType(note.durationTicks)}</type>');
    if (note.isDotted) {
      sb.writeln('        <dot/>');
    }
    if (includeStaffElement) {
      sb.writeln('        <staff>${note.staff}</staff>');
    }
    if (!isRest && note.isTied) {
      sb.writeln('        <notations>');
      sb.writeln('          <tied type="start"/>');
      sb.writeln('        </notations>');
    }
    sb.writeln('      </note>');

    return sb.toString();
  }

  /// Convierte ticks (base 4 por negra) a denominación estándar MusicXML.
  static String _ticksToNoteType(int durationTicks) {
    if (durationTicks >= 16) return 'whole';
    if (durationTicks >= 8) return 'half';
    if (durationTicks >= 4) return 'quarter';
    if (durationTicks >= 2) return 'eighth';
    return '16th';
  }

  /// Descompone un nombre musical (ej: "Fa#5", "Sib4", "Do0", "Do8", "A4", "F#5", "Bb3")
  /// en Step (A-G), alteracion (-2..2) y octava entera en rango 0..8.
  static ({String step, int alter, int octave}) _parseNoteName(String rawName) {
    final parsed = CanonicalPitchNotationCodec.parseOrDefault(rawName);
    return (step: parsed.step, alter: parsed.alter, octave: parsed.octave);
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
