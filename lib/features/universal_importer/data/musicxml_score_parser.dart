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

    // 2. Extracción de Compases y Notas de TODAS las partes (<part>)
    int totalNotesCount = 0;
    final warnings = <String>[];

    final parts = document.findAllElements('part').toList();
    final partMeasureLists = parts.isNotEmpty
        ? parts.map((p) => p.findElements('measure').toList()).toList()
        : [document.findAllElements('measure').toList()];

    if (partMeasureLists.every((list) => list.isEmpty)) {
      throw const FormatException('El archivo MusicXML no contiene ningún elemento <measure>.');
    }

    final measureNotesByIndex = <int, List<HierarchicalNote>>{};
    final measureTimeSigByIndex = <int, TimeSignature>{};
    final measureKeyFifthsByIndex = <int, int>{};

    int staffOffset = 0;
    int maxMeasureCount = 0;

    for (int pIdx = 0; pIdx < partMeasureLists.length; pIdx++) {
      final xmlMeasures = partMeasureLists[pIdx];
      if (xmlMeasures.length > maxMeasureCount) {
        maxMeasureCount = xmlMeasures.length;
      }

      int divisions = 4; // Divisiones por negra por defecto
      TimeSignature currentTimeSignature = TimeSignature.commonTime44;
      int currentKeyFifths = 0;
      int maxLocalStaffInPart = 1;

      for (int measureIndex = 0; measureIndex < xmlMeasures.length; measureIndex++) {
        final measureNode = xmlMeasures[measureIndex];
        final partMeasureNotes = <HierarchicalNote>[];
        int currentTick = 0;
        int maxTickReached = 0;
        int lastBaseNoteStartTick = 0;
        bool hasBaseNote = false;

        // Procesar elementos hijos en orden de documento (attributes, backup, forward, note)
        for (final child in measureNode.childElements) {
          final tag = child.name.local;

          if (tag == 'attributes') {
            final divNode = child.getElement('divisions');
            if (divNode != null) {
              final parsedDiv = int.tryParse(divNode.innerText.trim());
              if (parsedDiv != null && parsedDiv > 0) {
                divisions = parsedDiv;
              }
            }

            final keyNode = child.getElement('key');
            if (keyNode != null) {
              final fifthsNode = keyNode.getElement('fifths');
              final parsedFifths = int.tryParse(fifthsNode?.innerText.trim() ?? '');
              if (parsedFifths != null) {
                currentKeyFifths = parsedFifths.clamp(-7, 7);
              }
            }

            final timeNode = child.getElement('time');
            if (timeNode != null) {
              currentTimeSignature = _parseTimeSignature(timeNode);
            }

            final stavesNode = child.getElement('staves');
            if (stavesNode != null) {
              final parsedStaves = int.tryParse(stavesNode.innerText.trim());
              if (parsedStaves != null && parsedStaves > maxLocalStaffInPart) {
                maxLocalStaffInPart = parsedStaves;
              }
            }
            continue;
          }

          if (tag == 'backup') {
            final durXml = int.tryParse(child.getElement('duration')?.innerText.trim() ?? '') ?? 0;
            final backupTicks = ((durXml * 4) / divisions).round();
            currentTick = (currentTick - backupTicks).clamp(0, currentTimeSignature.totalTicks);
            hasBaseNote = false;
            continue;
          }

          if (tag == 'forward') {
            final durXml = int.tryParse(child.getElement('duration')?.innerText.trim() ?? '') ?? 0;
            final forwardTicks = ((durXml * 4) / divisions).round();
            final maxTicks = currentTimeSignature.totalTicks > 0 ? currentTimeSignature.totalTicks : 16;
            currentTick = (currentTick + forwardTicks).clamp(0, maxTicks);
            if (currentTick > maxTickReached) maxTickReached = currentTick;
            hasBaseNote = false;
            continue;
          }

          if (tag != 'note') {
            continue;
          }

          // Ignorar notas de gracia que no consumen tiempo metrico
          if (child.getElement('grace') != null) {
            continue;
          }

          final maxTicks = currentTimeSignature.totalTicks > 0 ? currentTimeSignature.totalTicks : 16;
          final isChord = child.getElement('chord') != null;
          final isRest = child.getElement('rest') != null;
          final durationNode = child.getElement('duration');
          final durationXml = int.tryParse(durationNode?.innerText.trim() ?? '') ?? divisions;
          final localStaff = (int.tryParse(child.getElement('staff')?.innerText.trim() ?? '') ?? 1).clamp(1, 16);
          if (localStaff > maxLocalStaffInPart) {
            maxLocalStaffInPart = localStaff;
          }
          final effectiveStaff = staffOffset + localStaff;
          final voice = (int.tryParse(child.getElement('voice')?.innerText.trim() ?? '') ?? 1).clamp(1, 32);
          final isTied = child.findElements('tie').any(
                (t) => t.getAttribute('type')?.trim().toLowerCase() == 'start',
              );

          // Convertir duracion XML a ticks de semicorchea de Tunner (4 ticks por negra)
          int rawDurationTicks = ((durationXml * 4) / divisions).round();
          if (rawDurationTicks <= 0) rawDurationTicks = 1;

          if (isChord) {
            if (!hasBaseNote || isRest || lastBaseNoteStartTick >= maxTicks) {
              continue;
            }
            final chordDuration = rawDurationTicks.clamp(1, maxTicks - lastBaseNoteStartTick);
            final pitchNode = child.getElement('pitch');
            final noteName = _parsePitch(pitchNode);
            partMeasureNotes.add(HierarchicalNote.note(
              startTick: lastBaseNoteStartTick,
              durationTicks: chordDuration,
              noteName: noteName,
              isTied: isTied,
              voice: voice,
              staff: effectiveStaff,
            ));
            totalNotesCount++;
            continue;
          }

          if (currentTick >= maxTicks) {
            hasBaseNote = false;
            continue;
          }

          final durationTicks = rawDurationTicks.clamp(1, maxTicks - currentTick);

          if (isRest) {
            partMeasureNotes.add(HierarchicalNote.rest(
              startTick: currentTick,
              durationTicks: durationTicks,
              voice: voice,
              staff: effectiveStaff,
            ));
            hasBaseNote = false;
          } else {
            final pitchNode = child.getElement('pitch');
            final noteName = _parsePitch(pitchNode);
            partMeasureNotes.add(HierarchicalNote.note(
              startTick: currentTick,
              durationTicks: durationTicks,
              noteName: noteName,
              isTied: isTied,
              voice: voice,
              staff: effectiveStaff,
            ));
            lastBaseNoteStartTick = currentTick;
            hasBaseNote = true;
            totalNotesCount++;
          }

          currentTick += durationTicks;
          if (currentTick > maxTickReached) {
            maxTickReached = currentTick;
          }
        }

        final maxTicks = currentTimeSignature.totalTicks > 0 ? currentTimeSignature.totalTicks : 16;

        // Si el compás de esta parte quedó incompleto, rellenar con silencio canónico
        if (maxTickReached < maxTicks) {
          partMeasureNotes.add(HierarchicalNote.rest(
            startTick: maxTickReached,
            durationTicks: maxTicks - maxTickReached,
            voice: 1,
            staff: staffOffset + 1,
          ));
        }

        if (partMeasureNotes.isEmpty) {
          partMeasureNotes.add(HierarchicalNote.rest(
            startTick: 0,
            durationTicks: maxTicks,
            voice: 1,
            staff: staffOffset + 1,
          ));
        }

        measureNotesByIndex.putIfAbsent(measureIndex, () => []).addAll(partMeasureNotes);
        measureTimeSigByIndex.putIfAbsent(measureIndex, () => currentTimeSignature);
        measureKeyFifthsByIndex.putIfAbsent(measureIndex, () => currentKeyFifths);
      }

      staffOffset += maxLocalStaffInPart;
    }

    final measures = <MeasureEntity>[];
    for (int mIdx = 0; mIdx < maxMeasureCount; mIdx++) {
      final ts = measureTimeSigByIndex[mIdx] ?? TimeSignature.commonTime44;
      final keyFifths = measureKeyFifthsByIndex[mIdx] ?? 0;
      final notes = measureNotesByIndex[mIdx] ??
          [HierarchicalNote.rest(startTick: 0, durationTicks: ts.totalTicks)];
      measures.add(MeasureEntity(
        index: mIdx,
        timeSignature: ts,
        notes: notes,
        keySignatureFifths: keyFifths,
      ));
    }

    final score = HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures,
      staffCount: staffOffset < 1 ? 1 : staffOffset,
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
    final symbol = timeNode.getAttribute('symbol')?.trim().toLowerCase();
    final beatsNode = timeNode.getElement('beats');
    final beatTypeNode = timeNode.getElement('beat-type');

    if (beatsNode == null && beatTypeNode == null) {
      if (symbol == 'cut') return const TimeSignature(2, 2);
      if (symbol == 'common') return TimeSignature.commonTime44;
    }

    final rawBeats = beatsNode?.innerText.trim() ?? '4';
    final int beats;
    if (rawBeats.contains('+')) {
      final sum = rawBeats
          .split('+')
          .map((p) => int.tryParse(p.trim()) ?? 0)
          .fold<int>(0, (acc, v) => acc + v);
      beats = sum > 0 ? sum : 4;
    } else {
      final parsed = int.tryParse(rawBeats) ?? 4;
      beats = parsed > 0 ? parsed : 4;
    }

    final rawBeatType = int.tryParse(beatTypeNode?.innerText.trim() ?? '4') ?? 4;
    // Resolucion de Tunner = 16 semicorcheas por redonda: denominadores validos {1, 2, 4, 8, 16}.
    final beatType = (rawBeatType > 0 && (16 ~/ rawBeatType) > 0 && (16 % rawBeatType) == 0)
        ? rawBeatType
        : 4;

    if (beats == 4 && beatType == 4) return TimeSignature.commonTime44;
    if (beats == 3 && beatType == 4) return TimeSignature.waltzTime34;
    if (beats == 2 && beatType == 4) return TimeSignature.marchTime24;
    if (beats == 6 && beatType == 8) return TimeSignature.compoundTime68;
    if (beats == 9 && beatType == 8) return TimeSignature.compoundTime98;
    if (beats == 12 && beatType == 8) return TimeSignature.compoundTime128;
    if (beats == 5 && beatType == 4) return TimeSignature.complexTime54;
    return TimeSignature(beats, beatType);
  }

  String _parsePitch(XmlElement? pitchNode) {
    if (pitchNode == null) return "Do4";

    final step = pitchNode.getElement('step')?.innerText.trim().toUpperCase() ?? 'C';
    final alterRaw = double.tryParse(pitchNode.getElement('alter')?.innerText.trim() ?? '0') ?? 0.0;
    final alter = alterRaw.round();
    final octave = int.tryParse(pitchNode.getElement('octave')?.innerText.trim() ?? '4') ?? 4;

    const stepToSemitone = <String, int>{
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    const chromaticNames = <String>[
      'Do',
      'Do#',
      'Re',
      'Re#',
      'Mi',
      'Fa',
      'Fa#',
      'Sol',
      'Sol#',
      'La',
      'La#',
      'Si',
    ];

    final baseSemitone = stepToSemitone[step] ?? 0;
    final midi = (octave + 1) * 12 + baseSemitone + alter;
    final noteName = chromaticNames[((midi % 12) + 12) % 12];
    final effectiveOctave = ((midi / 12).floor() - 1).clamp(0, 8);

    return "$noteName$effectiveOctave";
  }
}
