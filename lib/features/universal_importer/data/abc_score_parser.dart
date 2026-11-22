import 'dart:convert';
import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';

/// Decodificador especializado para partituras en notación de texto plano ABC (.abc).
/// Soporta cabeceras estándar (X, T, C, M, L, Q, K), notas, alteraciones, duraciones relativas y compases.
class AbcScoreParser implements IScoreParserService {
  const AbcScoreParser();

  @override
  bool canParse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.abc')) {
      return true;
    }
    // Detección por cabeceras típicas en las primeras líneas
    if (bytes.isNotEmpty) {
      final text = utf8.decode(bytes.take(500).toList(), allowMalformed: true);
      return text.contains(RegExp(r'(^|\n)X:\s*\d+', multiLine: true)) ||
          (text.contains(RegExp(r'(^|\n)K:\s*[A-Ga-g]', multiLine: true)) &&
              text.contains(RegExp(r'(^|\n)T:', multiLine: true)));
    }
    return false;
  }

  @override
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(content);

    String title = 'Partitura ABC';
    String composer = 'Desconocido';
    int bpm = 120;
    TimeSignature timeSignature = TimeSignature.commonTime44;
    double unitLengthTicks = 4.0; // 4 sub-ticks = 1 negra (1/4)
    final melodyLines = <String>[];
    String keySignature = 'C';
    bool seenKeyHeader = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%')) {
        continue; // Comentarios o lineas vacias
      }

      if (line.startsWith('T:')) {
        title = line.substring(2).trim();
      } else if (line.startsWith('C:')) {
        composer = line.substring(2).trim();
      } else if (line.startsWith('M:')) {
        final parsedMeter = _parseAbcMeter(
          line.substring(2).trim(),
          fallback: timeSignature,
        );
        if (!seenKeyHeader) {
          timeSignature = parsedMeter;
        } else {
          melodyLines.add('[M:${parsedMeter.numerator}/${parsedMeter.denominator}]');
        }
      } else if (line.startsWith('L:')) {
        final lenStr = line.substring(2).trim();
        if (!seenKeyHeader) {
          unitLengthTicks = _parseUnitLengthTicks(lenStr, fallback: unitLengthTicks);
        } else {
          melodyLines.add('[L:$lenStr]');
        }
      } else if (line.startsWith('Q:')) {
        final tempoStr = line.substring(2).trim();
        if (tempoStr.contains('=')) {
          final afterEqual = tempoStr.split('=').last.trim();
          final match = RegExp(r'\d+').firstMatch(afterEqual);
          if (match != null) {
            bpm = (int.tryParse(match.group(0)!) ?? 120).clamp(20, 300);
          }
        } else {
          final match = RegExp(r'\d+').firstMatch(tempoStr);
          if (match != null) {
            bpm = (int.tryParse(match.group(0)!) ?? 120).clamp(20, 300);
          }
        }
      } else if (line.startsWith('K:')) {
        final rawKey = line.substring(2).trim();
        if (!seenKeyHeader) {
          keySignature = rawKey;
          seenKeyHeader = true;
        } else {
          melodyLines.add('[K:$rawKey]');
        }
      } else if (!RegExp(r'^[A-Za-z]:').hasMatch(line)) {
        melodyLines.add(line);
      }
    }

    final rawMusic = melodyLines.join(' ');
    final keyAccidentals = _keySignatureAccidentals(keySignature);
    final measures = _parseMelodyToMeasures(
      rawMusic,
      unitLengthTicks,
      timeSignature,
      keyAccidentals: keyAccidentals,
    );

    if (measures.isEmpty) {
      throw FormatException('El archivo "$fileName" no contiene notación ABC válida.');
    }

    int totalNotes = 0;
    for (final m in measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
    }

    final score = HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures,
    );

    final track = AudioTrack(
      id: 'abc_track_1',
      title: title,
      instrumentIcon: 'music_note',
      volume: 1.0,
    );

    final pkg = SongPackage(
      id: 'abc_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      composer: composer,
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      tracks: [track],
      score: score,
    );

    return ParsedScoreResult(
      package: pkg,
      format: 'ABC',
      totalMeasures: score.measures.length,
      totalNotes: totalNotes,
      warnings: const [],
    );
  }

  List<MeasureEntity> _parseMelodyToMeasures(
    String rawMusic,
    double unitLengthTicks,
    TimeSignature timeSignature, {
    Map<String, String> keyAccidentals = const {},
  }) {
    // Eliminar simbolos de acordes ("Am7") y decoraciones (!fermata!) antes de tokenizar notas
    final sanitizedMusic = rawMusic
        .replaceAll(RegExp(r'"[^"]*"'), ' ')
        .replaceAll(RegExp(r'![^!]*!'), ' ');
    // Normalizar delimitadores compuestos (|], [|, :|, |:, ||) por barra simple |
    final cleanMusic = sanitizedMusic.replaceAll(RegExp(r'\[\||\|\]|:\||\|:|\|\|'), '|');
    final rawBarTokens = cleanMusic.split('|');
    final measures = <MeasureEntity>[];
    int measureIndex = 0;

    var currentTimeSignature = timeSignature;
    var currentUnitLengthTicks = unitLengthTicks;
    var currentKeyAccidentals = keyAccidentals;

    final inlineFieldRegex = RegExp(r'\[([MLK]):([^\]]*)\]');

    for (final rawBar in rawBarTokens) {
      var barContent = rawBar.trim();
      if (barContent.isEmpty) continue;

      // Procesar campos inline [M:...], [L:...], [K:...] antes de parsear las notas del compas
      for (final fieldMatch in inlineFieldRegex.allMatches(barContent)) {
        final fieldKey = fieldMatch.group(1)!;
        final fieldValue = fieldMatch.group(2)!.trim();
        if (fieldKey == 'M') {
          currentTimeSignature = _parseAbcMeter(fieldValue, fallback: currentTimeSignature);
        } else if (fieldKey == 'L') {
          currentUnitLengthTicks = _parseUnitLengthTicks(fieldValue, fallback: currentUnitLengthTicks);
        } else if (fieldKey == 'K') {
          currentKeyAccidentals = _keySignatureAccidentals(fieldValue);
        }
      }

      barContent = barContent
          .replaceAll(inlineFieldRegex, ' ')
          .replaceAll(RegExp(r'\[\d+(?:[-,]\d+)*'), ' ')
          .trim();
      if (barContent.isEmpty) continue;

      final maxTicks = currentTimeSignature.totalTicks > 0 ? currentTimeSignature.totalTicks : 16;
      final notes = _parseNotesInBar(
        barContent,
        currentUnitLengthTicks,
        maxTicks,
        keyAccidentals: currentKeyAccidentals,
      );
      if (notes.isNotEmpty) {
        measures.add(MeasureEntity(
          index: measureIndex++,
          timeSignature: currentTimeSignature,
          notes: notes,
        ));
      }
    }

    return measures;
  }

  List<HierarchicalNote> _parseNotesInBar(
    String barText,
    double unitLengthTicks,
    int maxTicks, {
    Map<String, String> keyAccidentals = const {},
  }) {
    final notes = <HierarchicalNote>[];
    final safeMaxTicks = maxTicks > 0 ? maxTicks : 16;
    final maxSingleNoteTicks = safeMaxTicks > 16 ? safeMaxTicks : 16;

    // Coincide alternativamente con un acorde polifonico entre corchetes ([CEG]2) o una nota/silencio individual.
    final itemRegex = RegExp(
      r"\[([^\]:\[]+)\](\d*(?:/+\d*)?)|(\^{1,2}|_{1,2}|={0,1})([A-Ga-gzx])([,']*)(\d*(?:/+\d*)?)",
    );
    final singleNoteRegex = RegExp(
      r"(\^{1,2}|_{1,2}|={0,1})([A-Ga-gzx])([,']*)(\d*(?:/+\d*)?)",
    );
    final validChordInteriorRegex = RegExp(
      r"^(?:\s*(?:\^{1,2}|_{1,2}|={0,1})[A-Ga-gzx][,']*(?:\d*(?:/+\d*)?))+\s*$",
    );

    final matches = itemRegex.allMatches(barText);
    if (matches.isEmpty) return const [];

    int currentTick = 0;

    for (final match in matches) {
      final chordInterior = match.group(1);
      if (chordInterior != null) {
        if (!validChordInteriorRegex.hasMatch(chordInterior)) {
          continue;
        }
        final trailingMod = match.group(2) ?? '';
        final trailingMultiplier = _parseDurationMultiplier(trailingMod);
        final innerMatches = singleNoteRegex.allMatches(chordInterior).toList();
        if (innerMatches.isEmpty) continue;

        int? chordAdvanceTicks;
        for (final inner in innerMatches) {
          final explicitAccidental = inner.group(1) ?? '';
          final noteChar = inner.group(2)!;
          final accidental = explicitAccidental.isNotEmpty
              ? explicitAccidental
              : (keyAccidentals[noteChar.toUpperCase()] ?? '');
          final octaveMod = inner.group(3) ?? '';
          final innerDurationMod = inner.group(4) ?? '';

          final durationTicksDouble =
              unitLengthTicks * _parseDurationMultiplier(innerDurationMod) * trailingMultiplier;
          final durationTicks = durationTicksDouble.round().clamp(1, maxSingleNoteTicks);

          chordAdvanceTicks ??= durationTicks;

          final isRest = (noteChar == 'z' || noteChar == 'x');
          if (!isRest) {
            final solfege = _mapAbcToSolfege(noteChar, accidental, octaveMod);
            notes.add(HierarchicalNote.note(
              startTick: currentTick,
              durationTicks: durationTicks,
              noteName: solfege,
            ));
          }
        }

        if (chordAdvanceTicks != null) {
          if (!notes.any((n) => n.startTick == currentTick)) {
            notes.add(HierarchicalNote.rest(
              startTick: currentTick,
              durationTicks: chordAdvanceTicks,
            ));
          }
          currentTick += chordAdvanceTicks;
        }
        continue;
      }

      final explicitAccidental = match.group(3) ?? '';
      final noteChar = match.group(4)!;
      final accidental = explicitAccidental.isNotEmpty
          ? explicitAccidental
          : (keyAccidentals[noteChar.toUpperCase()] ?? '');
      final octaveMod = match.group(5) ?? '';
      final durationMod = match.group(6) ?? '';

      final durationTicksDouble = unitLengthTicks * _parseDurationMultiplier(durationMod);
      final durationTicks = durationTicksDouble.round().clamp(1, maxSingleNoteTicks);

      final isRest = (noteChar == 'z' || noteChar == 'x');
      if (isRest) {
        notes.add(HierarchicalNote.rest(
          startTick: currentTick,
          durationTicks: durationTicks,
        ));
      } else {
        final solfege = _mapAbcToSolfege(noteChar, accidental, octaveMod);
        notes.add(HierarchicalNote.note(
          startTick: currentTick,
          durationTicks: durationTicks,
          noteName: solfege,
        ));
      }

      currentTick += durationTicks;
    }

    if (notes.isEmpty) return const [];

    // Rellenar con silencio canonico si el compas no alcanza maxTicks
    if (currentTick < safeMaxTicks) {
      notes.add(HierarchicalNote.rest(
        startTick: currentTick,
        durationTicks: safeMaxTicks - currentTick,
      ));
    }

    return notes;
  }

  double _parseDurationMultiplier(String durationMod) {
    if (durationMod.isEmpty) return 1.0;
    if (RegExp(r'^/+$').hasMatch(durationMod)) {
      return 1.0 / (1 << durationMod.length);
    }
    if (durationMod.contains('/')) {
      final parts = durationMod.split('/');
      final num = parts[0].isEmpty ? 1.0 : (double.tryParse(parts[0]) ?? 1.0);
      final den = parts[1].isEmpty ? 2.0 : (double.tryParse(parts[1]) ?? 2.0);
      final safeDen = (den == 0.0) ? 1.0 : den;
      return num / safeDen;
    }
    return double.tryParse(durationMod) ?? 1.0;
  }

  TimeSignature _parseAbcMeter(
    String meterRaw, {
    TimeSignature fallback = TimeSignature.commonTime44,
  }) {
    final meter = meterRaw.trim();
    if (meter.isEmpty || meter.toLowerCase() == 'none') return fallback;
    if (meter == 'C') return TimeSignature.commonTime44;
    if (meter == 'C|') return const TimeSignature(2, 2);

    if (meter.contains('/')) {
      final parts = meter.split('/');
      if (parts.length == 2) {
        final rawNum = parts[0].trim().replaceAll('(', '').replaceAll(')', '');
        final int num;
        if (rawNum.contains('+')) {
          final sum = rawNum
              .split('+')
              .map((p) => int.tryParse(p.trim()) ?? 0)
              .fold<int>(0, (acc, v) => acc + v);
          num = sum > 0 ? sum : fallback.numerator;
        } else {
          final parsed = int.tryParse(rawNum) ?? 0;
          num = parsed > 0 ? parsed : fallback.numerator;
        }

        final denMatch = RegExp(r'\d+').firstMatch(parts[1].trim());
        final rawDen = denMatch != null ? (int.tryParse(denMatch.group(0)!) ?? 4) : 4;
        final den = (rawDen > 0 && (16 ~/ rawDen) > 0 && (16 % rawDen) == 0) ? rawDen : 4;

        if (num == 4 && den == 4) return TimeSignature.commonTime44;
        if (num == 3 && den == 4) return TimeSignature.waltzTime34;
        if (num == 2 && den == 4) return TimeSignature.marchTime24;
        if (num == 6 && den == 8) return TimeSignature.compoundTime68;
        if (num == 9 && den == 8) return TimeSignature.compoundTime98;
        if (num == 12 && den == 8) return TimeSignature.compoundTime128;
        if (num == 5 && den == 4) return TimeSignature.complexTime54;
        return TimeSignature(num, den);
      }
    }
    return fallback;
  }

  double _parseUnitLengthTicks(String lenRaw, {double fallback = 4.0}) {
    final lenStr = lenRaw.trim();
    if (!lenStr.contains('/')) return fallback;
    final parts = lenStr.split('/');
    if (parts.length != 2) return fallback;
    final num = double.tryParse(parts[0].trim()) ?? 1.0;
    final den = double.tryParse(parts[1].trim()) ?? 4.0;
    if (num <= 0 || den <= 0) return fallback;
    // En Tunner, la redonda (1/1) equivale a 16 sub-ticks de semicorchea.
    return (16.0 * (num / den)).clamp(0.25, 32.0);
  }

  String _mapAbcToSolfege(String noteChar, String accidental, String octaveMod) {
    const letterToSolfege = {
      'C': 'Do',
      'D': 'Re',
      'E': 'Mi',
      'F': 'Fa',
      'G': 'Sol',
      'A': 'La',
      'B': 'Si',
    };

    final upper = noteChar.toUpperCase();
    final baseSolfege = letterToSolfege[upper] ?? 'Do';

    String accSymbol = '';
    if (accidental == '^') accSymbol = '#';
    if (accidental == '^^') accSymbol = '##';
    if (accidental == '_') accSymbol = 'b';
    if (accidental == '__') accSymbol = 'bb';

    // Octava base: mayuscula = 4, minuscula = 5; soporta rango completo 0..8
    int octave = (noteChar == noteChar.toLowerCase()) ? 5 : 4;
    for (int i = 0; i < octaveMod.length; i++) {
      if (octaveMod[i] == ',') {
        octave--;
      } else if (octaveMod[i] == "'") {
        octave++;
      }
    }
    octave = octave.clamp(0, 8);

    return '$baseSolfege$accSymbol$octave';
  }

  /// Resuelve las 15 armaduras estandar (-7 a +7 alteraciones) segun el circulo de quintas,
  /// soportando tonalidades mayores, menores relativas y modos eclesiasticos.
  Map<String, String> _keySignatureAccidentals(String keyRaw) {
    final trimmed = keyRaw.trim();
    if (trimmed.isEmpty) return const {};

    final match = RegExp(r'^([A-Ga-g])([#b]?)\s*([A-Za-z]*)').firstMatch(trimmed);
    if (match == null) return const {};

    final tonic = '${match.group(1)!.toUpperCase()}${match.group(2)!.toLowerCase()}';
    final modeRaw = (match.group(3) ?? '').toLowerCase();

    const majorFifths = <String, int>{
      'Cb': -7,
      'Gb': -6,
      'Db': -5,
      'Ab': -4,
      'Eb': -3,
      'Bb': -2,
      'F': -1,
      'C': 0,
      'G': 1,
      'D': 2,
      'A': 3,
      'E': 4,
      'B': 5,
      'F#': 6,
      'C#': 7,
      'G#': 8,
      'D#': 9,
      'A#': 10,
    };

    final baseFifths = majorFifths[tonic];
    if (baseFifths == null) return const {};

    // Desplazamiento modal en quintas respecto al modo Jonico (Mayor)
    int modeOffset = 0;
    if (modeRaw == 'm' || modeRaw.startsWith('min') || modeRaw.startsWith('aeo')) {
      modeOffset = -3;
    } else if (modeRaw.startsWith('dor')) {
      modeOffset = -2;
    } else if (modeRaw.startsWith('phr')) {
      modeOffset = -4;
    } else if (modeRaw.startsWith('lyd')) {
      modeOffset = 1;
    } else if (modeRaw.startsWith('mix')) {
      modeOffset = -1;
    } else if (modeRaw.startsWith('loc')) {
      modeOffset = -5;
    }

    final fifths = (baseFifths + modeOffset).clamp(-7, 7);
    if (fifths == 0) return const {};

    const sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
    const flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];

    final result = <String, String>{};
    if (fifths > 0) {
      for (int i = 0; i < fifths; i++) {
        result[sharpOrder[i]] = '^';
      }
    } else {
      for (int i = 0; i < -fifths; i++) {
        result[flatOrder[i]] = '_';
      }
    }
    return result;
  }
}
