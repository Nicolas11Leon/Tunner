import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';

/// Serializador canónico en Pure Dart de partituras a estándar de texto plano ABC Notation.
/// Produce una representación tipográfica textual estructurada, legible y compatible con editores ABC.
class CanonicalAbcExporter {
  const CanonicalAbcExporter();

  /// Exporta un [SongPackage] a una cadena formateada en estándar ABC.
  String exportToAbc(SongPackage package) {
    return exportScore(
      score: package.score,
      title: package.title,
      composer: package.composer,
    );
  }

  /// Exporta un [HierarchicalScore] a estándar ABC.
  String exportScore({
    required HierarchicalScore score,
    String title = 'Composición Tunner',
    String composer = 'Tunner Music Studio',
  }) {
    final buffer = StringBuffer();

    // 1. Cabeceras estándar ABC
    buffer.writeln('X: 1');
    buffer.writeln('T: $title');
    buffer.writeln('C: $composer');
    buffer.writeln('M: 4/4');
    buffer.writeln('L: 1/4');
    buffer.writeln('Q: 1/4=${score.baseBpm}');
    buffer.writeln('K: C');

    // 2. Transcripción de compases y notas
    final measureTokens = <String>[];
    for (final measure in score.measures) {
      final barBuffer = StringBuffer();
      for (final note in measure.notes) {
        barBuffer.write(_formatAbcNote(note));
        barBuffer.write(' ');
      }
      final barStr = barBuffer.toString().trim();
      measureTokens.add(barStr.isNotEmpty ? barStr : 'z4');
    }

    if (measureTokens.isNotEmpty) {
      // Agrupar en líneas de hasta 4 compases por línea
      for (int i = 0; i < measureTokens.length; i += 4) {
        final end = (i + 4 < measureTokens.length) ? i + 4 : measureTokens.length;
        final lineBars = measureTokens.sublist(i, end).join(' | ');
        buffer.write(lineBars);
        if (end == measureTokens.length) {
          buffer.writeln(' |]');
        } else {
          buffer.writeln(' |');
        }
      }
    } else {
      buffer.writeln('z4 |]');
    }

    return buffer.toString();
  }

  String _formatAbcNote(HierarchicalNote note) {
    final durationStr = _ticksToDuration(note.durationTicks);
    if (note.isRest || note.noteName.isEmpty) {
      return 'z$durationStr';
    }

    final parsed = _parseSolfegeNote(note.noteName);
    final buffer = StringBuffer();

    // 1. Alteraciones
    if (parsed.alter == 1) {
      buffer.write('^');
    } else if (parsed.alter == 2) {
      buffer.write('^^');
    } else if (parsed.alter == -1) {
      buffer.write('_');
    } else if (parsed.alter == -2) {
      buffer.write('__');
    }

    // 2. Letra y Octava
    final step = parsed.step;
    if (parsed.octave >= 5) {
      buffer.write(step.toLowerCase());
      for (int i = 5; i < parsed.octave; i++) {
        buffer.write("'");
      }
    } else {
      buffer.write(step.toUpperCase());
      for (int i = 4; i > parsed.octave; i--) {
        buffer.write(',');
      }
    }

    // 3. Duración
    buffer.write(durationStr);

    return buffer.toString();
  }

  String _ticksToDuration(int ticks) {
    // En L: 1/4 (negra = 4 ticks):
    if (ticks == 4) return '';
    if (ticks == 8) return '2';
    if (ticks == 12) return '3';
    if (ticks == 16) return '4';
    if (ticks == 2) return '/2';
    if (ticks == 1) return '/4';
    if (ticks == 6) return '3/2';
    return (ticks / 4.0).toStringAsFixed(1);
  }

  ({String step, int alter, int octave}) _parseSolfegeNote(String rawName) {
    String name = rawName.trim();
    if (name.isEmpty) return (step: 'C', alter: 0, octave: 4);

    const solfegeMap = {
      'DO': 'C',
      'RE': 'D',
      'MI': 'E',
      'FA': 'F',
      'SOL': 'G',
      'LA': 'A',
      'SI': 'B',
    };

    final upper = name.toUpperCase();
    String step = 'C';
    for (final entry in solfegeMap.entries) {
      if (upper.startsWith(entry.key)) {
        step = entry.value;
        name = name.substring(entry.key.length);
        break;
      }
    }

    int alter = 0;
    while (name.startsWith('#')) {
      alter++;
      name = name.substring(1);
    }
    while (name.startsWith('b') || name.startsWith('B')) {
      alter--;
      name = name.substring(1);
    }

    int octave = int.tryParse(name) ?? 4;
    return (step: step, alter: alter, octave: octave);
  }
}
