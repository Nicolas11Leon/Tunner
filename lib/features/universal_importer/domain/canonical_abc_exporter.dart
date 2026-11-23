import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import 'canonical_pitch_notation_codec.dart';

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
  /// Preserva armaduras (`keySignatureFifths`), ligaduras (`isTied`) y múltiples voces/pentagramas (`voice`/`staff`).
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
    final initialKeyFifths = score.measures.isNotEmpty
        ? score.measures.first.keySignatureFifths.clamp(-7, 7)
        : 0;

    buffer.writeln('X: 1');
    buffer.writeln('T: $title');
    buffer.writeln('C: $composer');
    buffer.writeln('M: ${ts.numerator}/${ts.denominator}');
    buffer.writeln('L: 1/4');
    buffer.writeln('Q: 1/4=${score.baseBpm}');
    buffer.writeln('K: ${_fifthsToAbcKey(initialKeyFifths)}');

    // Detectar flujos únicos (staff, voice) presentes en toda la partitura
    final streamSet = <(int, int)>{};
    for (final m in score.measures) {
      for (final n in m.notes) {
        streamSet.add((n.staff, n.voice));
      }
    }
    final streams = streamSet.toList()
      ..sort((a, b) {
        final staffCmp = a.$1.compareTo(b.$1);
        if (staffCmp != 0) return staffCmp;
        return a.$2.compareTo(b.$2);
      });

    final isMultiVoice = streams.length > 1 || score.staffCount > 1;
    if (!isMultiVoice) {
      _writeVoiceMeasures(
        buffer,
        measures: score.measures,
        filterStaff: null,
        filterVoice: null,
      );
    } else {
      // Declarar cada voz con su clave (clef=treble para staff 1, clef=bass para staff >= 2)
      for (final stream in streams) {
        final staff = stream.$1;
        final voice = stream.$2;
        final clef = staff >= 2 ? 'bass' : 'treble';
        final voiceId = 'S${staff}V$voice';
        buffer.writeln('V:$voiceId clef=$clef name="Staff $staff Voice $voice"');
      }

      for (final stream in streams) {
        final staff = stream.$1;
        final voice = stream.$2;
        final voiceId = 'S${staff}V$voice';
        buffer.writeln('[V:$voiceId]');
        _writeVoiceMeasures(
          buffer,
          measures: score.measures,
          filterStaff: staff,
          filterVoice: voice,
        );
      }
    }

    return buffer.toString();
  }

  void _writeVoiceMeasures(
    StringBuffer buffer, {
    required List<MeasureEntity> measures,
    required int? filterStaff,
    required int? filterVoice,
  }) {
    final measureTokens = <String>[];
    TimeSignature? previousTimeSignature;
    int? previousKeyFifths;

    for (int mIdx = 0; mIdx < measures.length; mIdx++) {
      final measure = measures[mIdx];
      final barBuffer = StringBuffer();
      final keyFifths = measure.keySignatureFifths.clamp(-7, 7);

      if (mIdx > 0 && measure.timeSignature != previousTimeSignature) {
        final mts = measure.timeSignature;
        barBuffer.write('[M:${mts.numerator}/${mts.denominator}] ');
      }
      if (mIdx > 0 && keyFifths != previousKeyFifths) {
        barBuffer.write('[K:${_fifthsToAbcKey(keyFifths)}] ');
      }
      previousTimeSignature = measure.timeSignature;
      previousKeyFifths = keyFifths;

      final voiceNotes = (filterStaff == null && filterVoice == null)
          ? measure.notes
          : measure.notes
              .where((n) => n.staff == filterStaff && n.voice == filterVoice)
              .toList();

      if (voiceNotes.isEmpty) {
        barBuffer.write('z${_ticksToDuration(measure.timeSignature.totalTicks)}');
      } else {
        final groupedByTick = <int, List<HierarchicalNote>>{};
        for (final note in voiceNotes) {
          groupedByTick.putIfAbsent(note.startTick, () => []).add(note);
        }
        final sortedTicks = groupedByTick.keys.toList()..sort();

        for (final tick in sortedTicks) {
          final group = groupedByTick[tick]!;
          final pitchedNotes = group.where((n) => !_isRestNote(n)).toList();

          if (pitchedNotes.length > 1) {
            final firstDur = pitchedNotes.first.durationTicks;
            final sameDuration = pitchedNotes.every((n) => n.durationTicks == firstDur);
            final allTied = pitchedNotes.every((n) => n.isTied);
            barBuffer.write('[');
            if (sameDuration) {
              for (final pNote in pitchedNotes) {
                barBuffer.write(_formatAbcPitchOnly(pNote.noteName));
                if (!allTied && pNote.isTied) {
                  barBuffer.write('-');
                }
              }
              barBuffer.write(']');
              barBuffer.write(_ticksToDuration(firstDur));
              if (allTied) {
                barBuffer.write('-');
              }
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
  }

  static String _fifthsToAbcKey(int fifths) {
    const keyMap = <int, String>{
      -7: 'Cb',
      -6: 'Gb',
      -5: 'Db',
      -4: 'Ab',
      -3: 'Eb',
      -2: 'Bb',
      -1: 'F',
      0: 'C',
      1: 'G',
      2: 'D',
      3: 'A',
      4: 'E',
      5: 'B',
      6: 'F#',
      7: 'C#',
    };
    return keyMap[fifths.clamp(-7, 7)] ?? 'C';
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
    final tieSuffix = note.isTied ? '-' : '';
    return '${_formatAbcPitchOnly(note.noteName)}$durationStr$tieSuffix';
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
    final parsed = CanonicalPitchNotationCodec.parseOrDefault(rawName);
    return (step: parsed.step, alter: parsed.alter, octave: parsed.octave);
  }
}
