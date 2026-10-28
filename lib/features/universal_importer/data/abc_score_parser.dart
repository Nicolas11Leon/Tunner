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

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%')) {
        continue; // Comentarios o líneas vacías
      }

      if (line.startsWith('T:')) {
        title = line.substring(2).trim();
      } else if (line.startsWith('C:')) {
        composer = line.substring(2).trim();
      } else if (line.startsWith('M:')) {
        final meter = line.substring(2).trim();
        if (meter == '3/4') {
          timeSignature = TimeSignature.waltzTime34;
        } else if (meter == '6/8') {
          timeSignature = TimeSignature.compoundTime68;
        } else {
          timeSignature = TimeSignature.commonTime44;
        }
      } else if (line.startsWith('L:')) {
        final lenStr = line.substring(2).trim();
        if (lenStr == '1/8') {
          unitLengthTicks = 2.0;
        } else if (lenStr == '1/16') {
          unitLengthTicks = 1.0;
        } else if (lenStr == '1/2') {
          unitLengthTicks = 8.0;
        } else {
          unitLengthTicks = 4.0;
        }
      } else if (line.startsWith('Q:')) {
        final tempoStr = line.substring(2).trim();
        if (tempoStr.contains('=')) {
          final afterEqual = tempoStr.split('=').last.trim();
          final match = RegExp(r'\d+').firstMatch(afterEqual);
          if (match != null) {
            bpm = int.tryParse(match.group(0)!) ?? 120;
          }
        } else {
          final match = RegExp(r'\d+').firstMatch(tempoStr);
          if (match != null) {
            bpm = int.tryParse(match.group(0)!) ?? 120;
          }
        }
      } else if (line.startsWith('K:')) {
        // Fin de cabecera principal, las líneas siguientes son música
        continue;
      } else if (!RegExp(r'^[A-Za-z]:').hasMatch(line)) {
        melodyLines.add(line);
      }
    }

    final rawMusic = melodyLines.join(' ');
    final measures = _parseMelodyToMeasures(rawMusic, unitLengthTicks, timeSignature);

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
    TimeSignature timeSignature,
  ) {
    // Normalizar delimitadores compuestos (|], [|, :|, |:) por barra simple |
    final cleanMusic = rawMusic.replaceAll(RegExp(r'\[\||\|\]|:\||\|:'), '|');
    final rawBarTokens = cleanMusic.split('|');
    final measures = <MeasureEntity>[];
    int measureIndex = 0;

    for (final rawBar in rawBarTokens) {
      final barContent = rawBar.trim();
      if (barContent.isEmpty) continue;

      final notes = _parseNotesInBar(barContent, unitLengthTicks, timeSignature.totalTicks);
      if (notes.isNotEmpty) {
        measures.add(MeasureEntity(
          index: measureIndex++,
          timeSignature: timeSignature,
          notes: notes,
        ));
      }
    }

    return measures;
  }

  List<HierarchicalNote> _parseNotesInBar(String barText, double unitLengthTicks, int maxTicks) {
    final notes = <HierarchicalNote>[];
    // Expresión regular para tokens de notas ABC en comillas dobles
    final tokenRegex = RegExp(r"(\^{1,2}|_{1,2}|={0,1})([A-Ga-gzx])([,']*)(\d*(?:\/\d*)?)");
    final matches = tokenRegex.allMatches(barText);
    if (matches.isEmpty) return const [];

    int currentTick = 0;

    for (final match in matches) {
      final accidental = match.group(1) ?? '';
      final noteChar = match.group(2)!;
      final octaveMod = match.group(3) ?? '';
      final durationMod = match.group(4) ?? '';

      // 1. Calcular duración en sub-ticks (base 16)
      double durationTicksDouble = unitLengthTicks;
      if (durationMod.isNotEmpty) {
        if (durationMod.contains('/')) {
          final parts = durationMod.split('/');
          final num = parts[0].isEmpty ? 1.0 : (double.tryParse(parts[0]) ?? 1.0);
          final den = parts[1].isEmpty ? 2.0 : (double.tryParse(parts[1]) ?? 2.0);
          durationTicksDouble = unitLengthTicks * (num / den);
        } else {
          final mul = double.tryParse(durationMod) ?? 1.0;
          durationTicksDouble = unitLengthTicks * mul;
        }
      }

      int durationTicks = durationTicksDouble.round().clamp(1, 16);

      // 2. Determinar si es silencio o nota
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

    // Rellenar con silencio canónico si el compás no alcanza maxTicks
    if (currentTick < maxTicks) {
      notes.add(HierarchicalNote.rest(
        startTick: currentTick,
        durationTicks: maxTicks - currentTick,
      ));
    }

    return notes;
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

    // Octava base: mayúscula = 4, minúscula = 5
    int octave = (noteChar == noteChar.toLowerCase()) ? 5 : 4;
    for (int i = 0; i < octaveMod.length; i++) {
      if (octaveMod[i] == ',') {
        octave--;
      } else if (octaveMod[i] == "'") {
        octave++;
      }
    }
    octave = octave.clamp(1, 8);

    return '$baseSolfege$accSymbol$octave';
  }
}
