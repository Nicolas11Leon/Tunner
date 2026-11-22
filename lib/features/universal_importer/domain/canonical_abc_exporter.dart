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
    final ts = score.measures.isNotEmpty
        ? score.measures.first.timeSignature
        : TimeSignature.commonTime44;
    buffer.writeln('X: 1');
    buffer.writeln('T: $title');
    buffer.writeln('C: $composer');
    buffer.writeln('M: ${ts.numerator}/${ts.denominator}');
    buffer.writeln('L: 1/4');
    buffer.writeln('Q: 1/4=${score.baseBpm}');
    buffer.writeln('K: C');

    // 2. Transcripcion de compases, metricas y acordes agrupados por startTick
    final measureTokens = <String>[];
    TimeSignature? previousTimeSignature;
    for (int mIdx = 0; mIdx < score.measures.length; mIdx++) {
      final measure = score.measures[mIdx];
      final barBuffer = StringBuffer();

      if (mIdx > 0 && measure.timeSignature != previousTimeSignature) {
        final mts = measure.timeSignature;
        barBuffer.write('[M:${mts.numerator}/${mts.denominator}] ');
      }
      previousTimeSignature = measure.timeSignature;

      if (measure.notes.isEmpty) {
        barBuffer.write('z${_ticksToDuration(measure.timeSignature.totalTicks)}');
      } else {
        final groupedByTick = <int, List<HierarchicalNote>>{};
        for (final note in measure.notes) {
          groupedByTick.putIfAbsent(note.startTick, () => []).add(note);
        }
        final sortedTicks = groupedByTick.keys.toList()..sort();

        for (final tick in sortedTicks) {
          final group = groupedByTick[tick]!;
          final pitchedNotes = group.where((n) => !_isRestNote(n)).toList();

          if (pitchedNotes.length > 1) {
            final firstDur = pitchedNotes.first.durationTicks;
            final sameDuration = pitchedNotes.every((n) => n.durationTicks == firstDur);
            barBuffer.write('[');
            if (sameDuration) {
              for (final pNote in pitchedNotes) {
                barBuffer.write(_formatAbcPitchOnly(pNote.noteName));
              }
              barBuffer.write(']');
              barBuffer.write(_ticksToDuration(firstDur));
            } else {
              for (final pNote in pitchedNotes) {
                barBuffer.write(_formatAbcNote(pNote));
              }
              barBuffer.write(']');
            }
            barBuffer.write(' ');
          } else if (pitchedNotes.length == 1) {
            barBuffer.write(_formatAbcNote(pitchedNotes.first));
            barBuffer.write(' ');
          } else {
            final restNote = group.first;
            barBuffer.write('z${_ticksToDuration(restNote.durationTicks)} ');
          }
        }
      }

      final barStr = barBuffer.toString().trim();
      measureTokens.add(
        barStr.isNotEmpty
            ? barStr
            : 'z${_ticksToDuration(measure.timeSignature.totalTicks)}',
      );
    }

    if (measureTokens.isNotEmpty) {
      // Agrupar en lineas de hasta 4 compases por linea
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

  static bool _isRestNote(HierarchicalNote note) {
    return note.isRest ||
        note.noteName == '--' ||
        note.noteName.toLowerCase() == 'rest' ||
        note.noteName.isEmpty;
  }

  String _formatAbcNote(HierarchicalNote note) {
    final durationStr = _ticksToDuration(note.durationTicks);
    if (_isRestNote(note)) {
      return 'z$durationStr';
    }
    return '${_formatAbcPitchOnly(note.noteName)}$durationStr';
  }

  String _formatAbcPitchOnly(String noteName) {
    final parsed = _parseSolfegeNote(noteName);
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

    // 2. Letra y Octava en rango completo 0..8 (C,,,, hasta c''')
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

    return buffer.toString();
  }

  String _ticksToDuration(int ticks) {
    // En L: 1/4 (negra = 4 ticks):
    if (ticks == 4) return '';
    if (ticks % 4 == 0) return '${ticks ~/ 4}';
    if (ticks == 2) return '/2';
    if (ticks == 1) return '/4';
    if (ticks % 2 == 0) return '${ticks ~/ 2}/2';
    return '$ticks/4';
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
    bool matchedSolfege = false;
    for (final entry in solfegeMap.entries) {
      if (upper.startsWith(entry.key)) {
        step = entry.value;
        name = name.substring(entry.key.length);
        matchedSolfege = true;
        break;
      }
    }
    if (!matchedSolfege && name.isNotEmpty && RegExp(r'[A-G]').hasMatch(upper[0])) {
      step = upper[0];
      name = name.substring(1);
    }

    name = name.replaceAll('♯', '#').replaceAll('♭', 'b');
    int alter = 0;
    while (name.startsWith('#')) {
      alter++;
      name = name.substring(1);
    }
    while (name.startsWith('b') || name.startsWith('B')) {
      alter--;
      name = name.substring(1);
    }

    final octMatch = RegExp(r'-?\d+').firstMatch(name);
    final int octave = (octMatch != null ? (int.tryParse(octMatch.group(0)!) ?? 4) : 4).clamp(0, 8);
    return (step: step, alter: alter, octave: octave);
  }
}
