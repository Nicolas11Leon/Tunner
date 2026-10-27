import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';

/// Serializador canónico en Pure Dart de partituras a estándar W3C MusicXML 3.1/4.0.
/// Produce un archivo XML estructurado y compatible con MuseScore, Sibelius, Dorico y Finale.
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

    // Lista de partes (1 instrumento principal)
    buffer.writeln('  <part-list>');
    buffer.writeln('    <score-part id="P1">');
    buffer.writeln('      <part-name>${_escapeXml(title)}</part-name>');
    buffer.writeln('    </score-part>');
    buffer.writeln('  </part-list>');

    // Contenido de la parte musical
    buffer.writeln('  <part id="P1">');

    for (int mIdx = 0; mIdx < score.measures.length; mIdx++) {
      final measure = score.measures[mIdx];
      final measureNum = mIdx + 1;

      buffer.writeln('    <measure number="$measureNum">');

      // Atributos iniciales en el compás 1
      if (mIdx == 0) {
        final ts = measure.timeSignature;
        buffer.writeln('      <attributes>');
        buffer.writeln('        <divisions>4</divisions>'); // 4 divisiones por negra (16 ticks por compás 4/4)
        buffer.writeln('        <key>');
        buffer.writeln('          <fifths>0</fifths>'); // Do Mayor por defecto
        buffer.writeln('        </key>');
        buffer.writeln('        <time>');
        buffer.writeln('          <beats>${ts.numerator}</beats>');
        buffer.writeln('          <beat-type>${ts.denominator}</beat-type>');
        buffer.writeln('        </time>');
        buffer.writeln('        <clef>');
        buffer.writeln('          <sign>G</sign>');
        buffer.writeln('          <line>2</line>');
        buffer.writeln('        </clef>');
        buffer.writeln('      </attributes>');
      }

      // Notas del compás
      for (final note in measure.notes) {
        buffer.write(_serializeNoteXml(note));
      }

      buffer.writeln('    </measure>');
    }

    buffer.writeln('  </part>');
    buffer.writeln('</score-partwise>');

    return buffer.toString();
  }

  /// Serializa una [HierarchicalNote] individual al nodo XML `<note>`.
  String _serializeNoteXml(HierarchicalNote note) {
    final sb = StringBuffer();
    sb.writeln('      <note>');

    final isRest = note.noteName == "--" ||
        note.noteName.toLowerCase() == "rest" ||
        note.noteName.isEmpty;

    if (isRest) {
      sb.writeln('        <rest/>');
    } else {
      final pitchParts = _parseNoteName(note.noteName);
      sb.writeln('        <pitch>');
      sb.writeln('          <step>${pitchParts.step}</step>');
      if (pitchParts.alter != 0) {
        sb.writeln('          <alter>${pitchParts.alter}</alter>');
      }
      sb.writeln('          <octave>${pitchParts.octave}</octave>');
      sb.writeln('        </pitch>');
      if (pitchParts.alter != 0) {
        final accName = pitchParts.alter > 0 ? "sharp" : "flat";
        sb.writeln('        <accidental>$accName</accidental>');
      }
    }

    sb.writeln('        <duration>${note.durationTicks}</duration>');
    sb.writeln('        <voice>1</voice>');
    sb.writeln('        <type>${_ticksToNoteType(note.durationTicks)}</type>');
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

  /// Descompone un nombre musical (ej: "Fa#5", "Sib4", "Do4", "A4", "F#5", "Bb3")
  /// en Step (A-G), alteración (-1, 0, 1) y octava entera.
  static ({String step, int alter, int octave}) _parseNoteName(String rawName) {
    String name = rawName.trim();
    if (name.isEmpty) return (step: 'C', alter: 0, octave: 4);

    // Mapeo silábico (Do, Re, Mi, Fa, Sol, La, Si) a anglosajón (C, D, E, F, G, A, B)
    final Map<String, String> solfegeMap = {
      'DO': 'C',
      'RE': 'D',
      'MI': 'E',
      'FA': 'F',
      'SOL': 'G',
      'LA': 'A',
      'SI': 'B',
    };

    String upper = name.toUpperCase();
    String step = 'C';
    int alter = 0;
    int octave = 4;

    bool matchedSolfege = false;
    for (final entry in solfegeMap.entries) {
      if (upper.startsWith(entry.key)) {
        step = entry.value;
        name = name.substring(entry.key.length);
        matchedSolfege = true;
        break;
      }
    }

    if (!matchedSolfege && name.isNotEmpty && "ABCDEFG".contains(name[0].toUpperCase())) {
      step = name[0].toUpperCase();
      name = name.substring(1);
    }

    if (name.contains('#') || name.contains('♯')) {
      alter = 1;
      name = name.replaceAll('#', '').replaceAll('♯', '');
    } else if (name.contains('b') || name.contains('♭')) {
      alter = -1;
      name = name.replaceAll('b', '').replaceAll('♭', '');
    }

    final octMatch = RegExp(r'\d+').firstMatch(name);
    if (octMatch != null) {
      octave = int.tryParse(octMatch.group(0)!) ?? 4;
    }

    return (step: step, alter: alter, octave: octave);
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
