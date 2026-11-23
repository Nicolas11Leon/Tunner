import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/project_format/data/local_project_storage_repository.dart';
import 'package:tunner/features/project_format/data/tunner_binary_project_codec.dart';
import 'package:tunner/features/project_format/domain/tunner_project_package.dart';
import 'package:tunner/features/score_editor/domain/score_editor_domain.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_decomposer_service.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/universal_importer/data/musicxml_score_parser.dart';
import 'package:tunner/features/universal_importer/domain/canonical_abc_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_midi_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_musicxml_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_pdf_exporter.dart';

void main() {
  group('Ola 1A - Polifonia Real y Grand Staff (Piano 3/4)', () {
    const ops = ScoreEditorOperations();

    test('HierarchicalNote soporta voice, staff, isDotted, ==, hashCode y roundtrip JSON retrocompatible', () {
      const n1 = HierarchicalNote(
        startTick: 0,
        durationTicks: 12,
        noteName: 'Sol4',
        isTied: true,
        voice: 2,
        staff: 2,
      );
      const n2 = HierarchicalNote(
        startTick: 0,
        durationTicks: 12,
        noteName: 'Sol4',
        isTied: true,
        voice: 2,
        staff: 2,
      );
      final n3 = n1.copyWith(voice: 1);

      expect(n1, equals(n2));
      expect(n1.hashCode, equals(n2.hashCode));
      expect(n1, isNot(equals(n3)));
      expect(n1.isDotted, isTrue);

      final roundtrip = HierarchicalNote.fromMap(n1.toMap());
      expect(roundtrip, equals(n1));

      // Retrocompatibilidad cuando voice y staff no existen en mapas legacy
      final legacy = HierarchicalNote.fromMap({
        'startTick': 4,
        'durationTicks': 4,
        'noteName': 'Do4',
        'isRest': false,
        'isTied': false,
      });
      expect(legacy.voice, equals(1));
      expect(legacy.staff, equals(1));
    });

    test('Composicion polifonica de vals de piano en 3/4 con 2 staves/voces sin recorte entre voces', () {
      var pkg = SongPackage(
        id: 'piano_waltz_3_4',
        title: 'Vals de Piano en Sol Mayor',
        composer: 'Tunner Studio',
        genre: MusicGenre.romantic,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: 108,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Vals de Piano en Sol Mayor',
          baseBpm: 108,
          staffCount: 2,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.waltzTime34,
              keySignatureFifths: 1,
              notes: [
                HierarchicalNote.rest(startTick: 0, durationTicks: 12, staff: 1, voice: 1),
              ],
            ),
          ],
        ),
      );

      // Mano derecha (staff 1, voice 1): blanca con puntillo (ticks 0..12)
      pkg = ops.insertOrUpdateNote(
        package: pkg,
        measureIndex: 0,
        startTick: 0,
        durationTicks: 12,
        noteName: 'Re5',
        staff: 1,
        voice: 1,
        isTied: true,
      );

      // Mano izquierda (staff 2, voice 2): bajo en tick 0 + acordes en ticks 4 y 8
      pkg = ops.insertOrUpdateNote(
        package: pkg,
        measureIndex: 0,
        startTick: 0,
        durationTicks: 4,
        noteName: 'Sol2',
        staff: 2,
        voice: 2,
      );
      pkg = ops.insertChordNotes(
        package: pkg,
        measureIndex: 0,
        startTick: 4,
        durationTicks: 4,
        noteNames: const ['Si3', 'Re4'],
        staff: 2,
        voice: 2,
      );
      pkg = ops.insertChordNotes(
        package: pkg,
        measureIndex: 0,
        startTick: 8,
        durationTicks: 4,
        noteNames: const ['Si3', 'Re4'],
        staff: 2,
        voice: 2,
      );

      final notes = pkg.score.measures.first.notes;
      final rightHand = notes.where((n) => n.staff == 1 && n.voice == 1).toList();
      final leftHand = notes.where((n) => n.staff == 2 && n.voice == 2).toList();

      // La blanca con puntillo de mano derecha NO debe haberse recortado
      expect(rightHand.length, equals(1));
      expect(rightHand.first.noteName, equals('Re5'));
      expect(rightHand.first.durationTicks, equals(12));
      expect(rightHand.first.isTied, isTrue);

      // Mano izquierda conserva bajo (1) + 2 acordes de 2 notas (4) = 5 notas
      expect(leftHand.length, equals(5));
      expect(pkg.score.staffCount, equals(2));
      expect(pkg.score.isValidScore, isTrue);

      // Recorte dentro de la MISMA (staff, voice) sigue funcionando correctamente
      pkg = ops.insertOrUpdateNote(
        package: pkg,
        measureIndex: 0,
        startTick: 4,
        durationTicks: 4,
        noteName: 'Mi5',
        staff: 1,
        voice: 1,
      );
      final rightAfterClip = pkg.score.measures.first.notes
          .where((n) => n.staff == 1 && n.voice == 1)
          .toList();
      expect(rightAfterClip.length, equals(3)); // cabeza 0..4, nueva 4..8, cola 8..12
      expect(rightAfterClip[0].durationTicks, equals(4));
      expect(rightAfterClip[1].noteName, equals('Mi5'));
      expect(rightAfterClip[2].startTick, equals(8));
      expect(rightAfterClip[2].durationTicks, equals(4));
    });
  });

  group('Ola 1A - Exportadores (MusicXML, ABC, MIDI Format 1, PDF) y MusicXmlScoreParser', () {
    final grandStaffWaltz = HierarchicalScore(
      title: 'Vals Polifonico',
      baseBpm: 108,
      staffCount: 2,
      measures: [
        MeasureEntity(
          index: 0,
          timeSignature: TimeSignature.waltzTime34,
          keySignatureFifths: 1, // Sol Mayor (1 sostenido)
          notes: const [
            HierarchicalNote(
              startTick: 0,
              durationTicks: 12,
              noteName: 'Re5',
              isTied: true,
              voice: 1,
              staff: 1,
            ),
            HierarchicalNote(
              startTick: 0,
              durationTicks: 4,
              noteName: 'Sol2',
              voice: 2,
              staff: 2,
            ),
            HierarchicalNote(
              startTick: 4,
              durationTicks: 4,
              noteName: 'Si3',
              voice: 2,
              staff: 2,
            ),
            HierarchicalNote(
              startTick: 4,
              durationTicks: 4,
              noteName: 'Re4',
              voice: 2,
              staff: 2,
            ),
            HierarchicalNote(
              startTick: 8,
              durationTicks: 4,
              noteName: 'Si3',
              voice: 2,
              staff: 2,
            ),
            HierarchicalNote(
              startTick: 8,
              durationTicks: 4,
              noteName: 'Re4',
              voice: 2,
              staff: 2,
            ),
          ],
        ),
      ],
    );

    test('CanonicalMusicXmlExporter preserva fifths, isTied, voice, staff y staves con backup', () async {
      const exporter = CanonicalMusicXmlExporter();
      final xml = exporter.exportScore(score: grandStaffWaltz, title: 'Vals Polifonico');

      expect(xml, contains('<fifths>1</fifths>'));
      expect(xml, contains('<staves>2</staves>'));
      expect(xml, contains('<tie type="start"/>'));
      expect(xml, contains('<tied type="start"/>'));
      expect(xml, contains('<voice>1</voice>'));
      expect(xml, contains('<voice>2</voice>'));
      expect(xml, contains('<staff>1</staff>'));
      expect(xml, contains('<staff>2</staff>'));
      expect(xml, contains('<backup>'));
      expect(xml, contains('<chord/>'));

      // Round-trip con MusicXmlScoreParser
      const parser = MusicXmlScoreParser();
      final parsed = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(xml)),
        fileName: 'vals.musicxml',
      );
      expect(parsed.package.score.staffCount, equals(2));
      expect(parsed.package.score.measures.first.keySignatureFifths, equals(1));
      expect(
        parsed.package.score.measures.first.notes.any((n) => n.staff == 1 && n.voice == 1 && n.isTied),
        isTrue,
      );
      expect(
        parsed.package.score.measures.first.notes.any((n) => n.staff == 2 && n.voice == 2),
        isTrue,
      );
    });

    test('CanonicalAbcExporter preserva keySignatureFifths, isTied, voice y staff', () {
      const exporter = CanonicalAbcExporter();
      final abc = exporter.exportScore(score: grandStaffWaltz, title: 'Vals Polifonico');

      expect(abc, contains('K: G'));
      expect(abc, contains('V:S1V1 clef=treble'));
      expect(abc, contains('V:S2V2 clef=bass'));
      expect(abc, contains('[V:S1V1]'));
      expect(abc, contains('[V:S2V2]'));
      expect(abc, contains('d3-')); // Re5 blanca con puntillo ligada
    });

    test('CanonicalMidiExporter genera SMF Format 1 multipista con Program Change configurable', () {
      const exporter = CanonicalMidiExporter();
      final bytes = exporter.exportScore(
        score: grandStaffWaltz,
        bpm: 108,
        trackName: 'Vals Piano',
        programNumber: 0, // Acoustic Grand Piano (no 73 hardcodeado)
        staffProgramNumbers: const {1: 0, 2: 42}, // Piano + Cello
      );

      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('MThd'));
      // Format 1
      expect(bytes[8], equals(0x00));
      expect(bytes[9], equals(0x01));
      // 3 tracks: Track 0 (meta) + Staff 1 Voice 1 + Staff 2 Voice 2
      expect(bytes[10], equals(0x00));
      expect(bytes[11], equals(0x03));

      // Contar chunks MTrk
      int mtrkCount = 0;
      for (int i = 0; i <= bytes.length - 4; i++) {
        if (bytes[i] == 0x4D && bytes[i + 1] == 0x54 && bytes[i + 2] == 0x72 && bytes[i + 3] == 0x6B) {
          mtrkCount++;
        }
      }
      expect(mtrkCount, equals(3));

      // Verificar Program Change dinamico: canal 0 -> 0 (0xC0 0x00) y canal 1 -> 42 (0xC1 0x2A)
      bool hasProgCh0Piano = false;
      bool hasProgCh1Cello = false;
      bool hasHardcodedFlute = false;
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == 0xC0 && bytes[i + 1] == 0x00) hasProgCh0Piano = true;
        if (bytes[i] == 0xC1 && bytes[i + 1] == 42) hasProgCh1Cello = true;
        if ((bytes[i] & 0xF0) == 0xC0 && bytes[i + 1] == 73) hasHardcodedFlute = true;
      }
      expect(hasProgCh0Piano, isTrue);
      expect(hasProgCh1Cello, isTrue);
      expect(hasHardcodedFlute, isFalse);
    });

    test('CanonicalPdfExporter apila acordes simultaneos en la misma X y renderiza armadura y puntillos', () {
      const exporter = CanonicalPdfExporter();
      final chordScore = HierarchicalScore(
        title: 'Acorde con Armadura y Puntillo',
        baseBpm: 90,
        measures: const [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.waltzTime34,
            keySignatureFifths: 2, // Re Mayor (2 sostenidos)
            notes: [
              HierarchicalNote(startTick: 0, durationTicks: 6, noteName: 'Do4'),
              HierarchicalNote(startTick: 0, durationTicks: 6, noteName: 'Mi4'),
              HierarchicalNote(startTick: 0, durationTicks: 6, noteName: 'Sol4'),
              HierarchicalNote(startTick: 6, durationTicks: 6, noteName: 'La4'),
            ],
          ),
        ],
      );

      final pdfBytes = exporter.exportScore(score: chordScore);
      final pdfText = latin1.decode(pdfBytes, allowInvalid: true);

      // Extraer todas las coordenadas X de cabezas de nota rellenas ('<x-rx> <y> m\n... c f')
      final noteheadMatches = RegExp(r'([0-9]+\.[0-9]+) [0-9]+\.[0-9]+ m\n[^\n]+ c\n[^\n]+ c f')
          .allMatches(pdfText)
          .map((m) => double.parse(m.group(1)!))
          .toList();

      // Las 3 notas del acorde en startTick=0 deben compartir exactamente la misma X
      expect(noteheadMatches.length, greaterThanOrEqualTo(4));
      expect(noteheadMatches[0], closeTo(noteheadMatches[1], 0.001));
      expect(noteheadMatches[1], closeTo(noteheadMatches[2], 0.001));
      // La cuarta nota en startTick=6 debe estar desplazada a la derecha
      expect(noteheadMatches[3], greaterThan(noteheadMatches[0] + 10.0));

      // Armadura de 2 sostenidos (trazos de sostenido '1.6 w')
      expect(pdfText.contains('1.6 w'), isTrue);
    });

    test('MusicXmlScoreParser lee todas las partes (<part>) mapeando staff y voice', () async {
      const multiPartXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Duo Violin y Cello</work-title></work>
  <part-list>
    <score-part id="P1"><part-name>Violin</part-name></score-part>
    <score-part id="P2"><part-name>Cello</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>-1</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note><pitch><step>F</step><octave>5</octave></pitch><duration>16</duration><voice>1</voice></note>
    </measure>
  </part>
  <part id="P2">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>-1</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note><pitch><step>F</step><octave>2</octave></pitch><duration>16</duration><voice>2</voice></note>
    </measure>
  </part>
</score-partwise>''';

      const parser = MusicXmlScoreParser();
      final result = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(multiPartXml)),
        fileName: 'duo.musicxml',
      );

      expect(result.totalNotes, equals(2));
      expect(result.package.score.staffCount, equals(2));
      final m0 = result.package.score.measures.first;
      expect(m0.keySignatureFifths, equals(-1));
      expect(m0.notes.any((n) => n.noteName == 'Fa5' && n.staff == 1 && n.voice == 1), isTrue);
      expect(m0.notes.any((n) => n.noteName == 'Fa2' && n.staff == 2 && n.voice == 2), isTrue);
    });
  });

  group('Ola 1A - Contenedor .tunner, Seguridad Path Traversal y SongDecomposerService', () {
    test('TunnerProjectPackage serializa songPackages con retrocompatibilidad v1', () {
      final sampleSong = SongDecomposerService.getCuratedLibrary().first;
      final project = TunnerProjectPackage(
        projectId: 'proj_songs_01',
        projectName: 'Proyecto con Partituras',
        tools: const [],
        songPackages: [sampleSong],
        createdAtMicros: 1000,
        updatedAtMicros: 2000,
      );

      final codec = TunnerBinaryProjectCodec();
      final encoded = codec.encodeProject(project);
      final decoded = codec.decodeProject(encoded);

      expect(decoded.songPackages.length, equals(1));
      expect(decoded.songPackages.first.id, equals(sampleSong.id));
      expect(decoded.songPackages.first.title, equals(sampleSong.title));

      // JSON v1 sin campo songPackages decodifica a lista vacia
      final legacyJson = Map<String, dynamic>.from(project.toJson())..remove('songPackages');
      final legacyDecoded = TunnerProjectPackage.fromJson(legacyJson);
      expect(legacyDecoded.songPackages, isEmpty);
    });

    test('LocalProjectStorageRepository bloquea Path Traversal y lista proyectos .tunner', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_wave1a_sec_');
      try {
        final repo = LocalProjectStorageRepository(baseDirectoryPath: tempDir.path);
        const project = TunnerProjectPackage(
          projectId: 'sec_01',
          projectName: 'Proyecto Seguro',
          tools: [],
          createdAtMicros: 10,
          updatedAtMicros: 20,
        );

        // Guardado valido dentro del directorio base
        await repo.saveProject('waltz.tunner', project);
        await repo.saveProject('sub/etude.tunner', project);

        // Archivo no-.tunner ignorado por listProjects
        await File('${tempDir.path}${Platform.pathSeparator}notes.txt').writeAsString('ignore');

        final listed = await repo.listProjects();
        expect(listed.length, equals(2));
        expect(listed.every((p) => p.endsWith('.tunner')), isTrue);

        // Lectura valida
        final loaded = await repo.loadProject('waltz.tunner');
        expect(loaded.projectId, equals('sec_01'));

        // Bloqueo de Path Traversal relativo y absoluto
        await expectLater(
          () => repo.saveProject('../escape.tunner', project),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          () => repo.loadProject('sub/../../etc/passwd'),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          () => repo.loadProject('/etc/passwd'),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          () => repo.saveProject('bad\u0000name.tunner', project),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('SongDecomposerService preserva stemScores y construye triadas diatonicas segun tonalidad/modo', () {
      // Obra en La menor (0 alteraciones, modo menor) -> acorde sobre La4 debe ser La-Do-Mi (menor), NO La-Do#-Mi
      final minorMeasures = [
        MeasureEntity(
          index: 0,
          timeSignature: TimeSignature.waltzTime34,
          keySignatureFifths: 0,
          notes: [
            HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'La4'),
            HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Do5'),
            HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Mi5'),
          ],
        ),
      ];

      final decomposed = SongDecomposerService.decomposeCustomScore(
        title: 'Vals en La Menor',
        composer: 'Tunner',
        bpm: 96,
        timeSignature: TimeSignature.waltzTime34,
        measures: minorMeasures,
      );

      final harmonyNotes = decomposed.stemScores['harmony_stem']!.measures.first.notes;
      expect(harmonyNotes.length, equals(3));
      // Tercera menor sobre La4 = Do5 (no Do#5)
      expect(harmonyNotes[1].noteName, equals('Do5'));
      expect(harmonyNotes[2].noteName, equals('Mi5'));

      // adaptSongPackageToInstrument debe preservar todos los stemScores
      const cello = InstrumentProfileEntity(
        id: 'cello_test',
        name: 'Violonchelo',
        family: InstrumentFamily.strings,
        key: InstrumentKey.concertC,
        clef: InstrumentClef.bass,
        transpositionSemitones: 0,
        minFrequencyHz: 65.41, // Do2
        maxFrequencyHz: 659.25, // Mi5
      );
      final adapted = SongDecomposerService.adaptSongPackageToInstrument(decomposed, cello);

      expect(adapted.stemScores.keys, containsAll(decomposed.stemScores.keys));
      expect(adapted.stemScores['harmony_stem'], isNotNull);
      expect(adapted.stemScores['bass_stem'], isNotNull);
      expect(adapted.stemScores['rhythm_stem'], isNotNull);
      expect(adapted.stemScores['lead_stem'], isNotNull);
    });
  });
}
