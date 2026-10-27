import 'dart:convert';
import 'dart:typed_data';
import 'package:xml/xml.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';

/// Decodificador especializado en especificaciones MusicXML (.musicxml / .xml).
/// Procesa árboles DOM XML en Dart puro sin dependencias nativas.
class MusicXmlScoreParser implements IScoreParserService {
  const MusicXmlScoreParser();

  @override
  bool canParse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.musicxml') || lower.endsWith('.xml')) {
      return true;
    }
    // Detección por firma en bytes (cabecera XML)
    if (bytes.length >= 5) {
      final header = String.fromCharCodes(bytes.take(200));
      return header.contains('<?xml') || header.contains('<score-partwise');
    }
    return false;
  }

  @override
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final xmlContent = utf8.decode(bytes, allowMalformed: true);
    final document = XmlDocument.parse(xmlContent);

    // 1. Metadatos de la Obra
    String title = _extractTitle(document, fileName);
    String composer = _extractComposer(document);
    int bpm = _extractTempo(document);

    // 2. Extracción de Compases y Notas
    final measures = <MeasureEntity>[];
    int divisions = 4; // Divisiones por negra por defecto
    TimeSignature currentTimeSignature = TimeSignature.commonTime44;
    int totalNotesCount = 0;
    final warnings = <String>[];

    final xmlMeasures = document.findAllElements('measure');
    if (xmlMeasures.isEmpty) {
      throw const FormatException('El archivo MusicXML no contiene ningún elemento <measure>.');
    }

    int measureIndex = 0;
    for (final measureNode in xmlMeasures) {
      // Atributos de compás (divisions, time)
      final attributesNode = measureNode.getElement('attributes');
      if (attributesNode != null) {
        final divNode = attributesNode.getElement('divisions');
        if (divNode != null) {
          final parsedDiv = int.tryParse(divNode.innerText.trim());
          if (parsedDiv != null && parsedDiv > 0) {
            divisions = parsedDiv;
          }
        }

        final timeNode = attributesNode.getElement('time');
        if (timeNode != null) {
          currentTimeSignature = _parseTimeSignature(timeNode);
        }
      }

      // Procesar notas del compás
      final notes = <HierarchicalNote>[];
      int currentTick = 0;
      final maxTicks = currentTimeSignature.totalTicks;

      for (final noteNode in measureNode.findElements('note')) {
        // Ignorar notas de gracia o voces secundarias si superan el tiempo
        if (currentTick >= maxTicks) break;

        final isRest = noteNode.getElement('rest') != null;
        final durationNode = noteNode.getElement('duration');
        final durationXml = int.tryParse(durationNode?.innerText.trim() ?? '') ?? divisions;

        // Convertir duración XML a ticks de semicorchea de Tunner (4 ticks por negra)
        int durationTicks = ((durationXml * 4) / divisions).round();
        if (durationTicks <= 0) durationTicks = 1;
        if (currentTick + durationTicks > maxTicks) {
          durationTicks = maxTicks - currentTick;
        }

        if (isRest) {
          notes.add(HierarchicalNote.rest(
            startTick: currentTick,
            durationTicks: durationTicks,
          ));
        } else {
          final pitchNode = noteNode.getElement('pitch');
          final noteName = _parsePitch(pitchNode);
          notes.add(HierarchicalNote.note(
            startTick: currentTick,
            durationTicks: durationTicks,
            noteName: noteName,
          ));
          totalNotesCount++;
        }

        currentTick += durationTicks;
      }

      // Si el compás quedó incompleto, rellenar con silencios canónicos
      if (currentTick < maxTicks) {
        notes.add(HierarchicalNote.rest(
          startTick: currentTick,
          durationTicks: maxTicks - currentTick,
        ));
      }

      // Si el compás estaba completamente vacío, crear silencio de compás entero
      if (notes.isEmpty) {
        notes.add(HierarchicalNote.rest(
          startTick: 0,
          durationTicks: maxTicks,
        ));
      }

      measures.add(MeasureEntity(
        index: measureIndex,
        timeSignature: currentTimeSignature,
        notes: notes,
      ));
      measureIndex++;
    }

    final score = HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures,
    );

    final cleanId = "import_${DateTime.now().millisecondsSinceEpoch}";
    final songPackage = SongPackage(
      id: cleanId,
      title: title,
      composer: composer,
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      score: score,
      tracks: const [
        AudioTrack(
          id: "melody",
          title: "Melodía Principal",
          instrumentIcon: "music_note",
          volume: 0.9,
        ),
      ],
    );

    return ParsedScoreResult(
      package: songPackage,
      format: 'MusicXML',
      totalMeasures: measures.length,
      totalNotes: totalNotesCount,
      warnings: warnings,
    );
  }

  String _extractTitle(XmlDocument doc, String fallbackFileName) {
    final workTitle = doc.findAllElements('work-title').firstOrNull?.innerText.trim();
    if (workTitle != null && workTitle.isNotEmpty) return workTitle;

    final movementTitle = doc.findAllElements('movement-title').firstOrNull?.innerText.trim();
    if (movementTitle != null && movementTitle.isNotEmpty) return movementTitle;

    // Fallback: nombre del archivo sin extensión
    final clean = fallbackFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return clean.isEmpty ? 'Partitura Importada' : clean;
  }

  String _extractComposer(XmlDocument doc) {
    for (final creator in doc.findAllElements('creator')) {
      if (creator.getAttribute('type') == 'composer') {
        final text = creator.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    final creator = doc.findAllElements('creator').firstOrNull?.innerText.trim();
    if (creator != null && creator.isNotEmpty) return creator;
    return 'Compositor Tradicional';
  }

  int _extractTempo(XmlDocument doc) {
    final soundNode = doc.findAllElements('sound').firstOrNull;
    final tempoAttr = soundNode?.getAttribute('tempo');
    if (tempoAttr != null) {
      final parsed = double.tryParse(tempoAttr);
      if (parsed != null && parsed > 20 && parsed < 300) {
        return parsed.round();
      }
    }

    final perMinute = doc.findAllElements('per-minute').firstOrNull?.innerText.trim();
    if (perMinute != null) {
      final parsed = int.tryParse(perMinute);
      if (parsed != null && parsed > 20 && parsed < 300) {
        return parsed;
      }
    }

    return 100; // Tempo estándar por defecto
  }

  TimeSignature _parseTimeSignature(XmlElement timeNode) {
    final beats = int.tryParse(timeNode.getElement('beats')?.innerText.trim() ?? '4') ?? 4;
    final beatType = int.tryParse(timeNode.getElement('beat-type')?.innerText.trim() ?? '4') ?? 4;

    if (beats == 3 && beatType == 4) return TimeSignature.waltzTime34;
    if (beats == 2 && beatType == 4) return TimeSignature.marchTime24;
    if (beats == 6 && beatType == 8) return TimeSignature.compoundTime68;
    return TimeSignature.commonTime44;
  }

  String _parsePitch(XmlElement? pitchNode) {
    if (pitchNode == null) return "Do4";

    final step = pitchNode.getElement('step')?.innerText.trim().toUpperCase() ?? 'C';
    final alter = int.tryParse(pitchNode.getElement('alter')?.innerText.trim() ?? '0') ?? 0;
    final octave = int.tryParse(pitchNode.getElement('octave')?.innerText.trim() ?? '4') ?? 4;

    // Conversión de Step a nombre de nota silábica Tunner
    String baseName;
    switch (step) {
      case 'C':
        baseName = alter == 1 ? "Do#" : (alter == -1 ? "Si" : "Do");
        break;
      case 'D':
        baseName = alter == 1 ? "Re#" : (alter == -1 ? "Do#" : "Re");
        break;
      case 'E':
        baseName = alter == 1 ? "Fa" : (alter == -1 ? "Re#" : "Mi");
        break;
      case 'F':
        baseName = alter == 1 ? "Fa#" : (alter == -1 ? "Mi" : "Fa");
        break;
      case 'G':
        baseName = alter == 1 ? "Sol#" : (alter == -1 ? "Fa#" : "Sol");
        break;
      case 'A':
        baseName = alter == 1 ? "La#" : (alter == -1 ? "Sol#" : "La");
        break;
      case 'B':
        baseName = alter == 1 ? "Do" : (alter == -1 ? "La#" : "Si");
        break;
      default:
        baseName = "Do";
    }

    return "$baseName$octave";
  }
}
