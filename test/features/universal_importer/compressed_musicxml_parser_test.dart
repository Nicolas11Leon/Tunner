import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/universal_importer/data/compressed_musicxml_parser.dart';

void main() {
  group('CompressedMusicXmlParser (.mxl) Tests', () {
    late CompressedMusicXmlParser parser;

    const sampleMusicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Minueto en Sol</work-title></work>
  <identification><creator type="composer">J. S. Bach</creator></identification>
  <part-list>
    <score-part id="P1"><part-name>Clavecín</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>3</beats><beat-type>4</beat-type></time>
      </attributes>
      <sound tempo="126"/>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
  </part>
</score-partwise>''';

    const containerXml = '''<?xml version="1.0" encoding="UTF-8"?>
<container>
  <rootfiles>
    <rootfile full-path="music/score.xml" media-type="application/vnd.recordare.musicxml+xml"/>
  </rootfiles>
</container>''';

    setUp(() {
      parser = const CompressedMusicXmlParser();
    });

    test('canParse identifies .mxl extensions and PK zip header bytes', () {
      expect(parser.canParse('bach_minuet.mxl', Uint8List(0)), isTrue);
      expect(parser.canParse('bach_minuet.MXL', Uint8List(0)), isTrue);
      expect(parser.canParse('file.bin', Uint8List.fromList([0x50, 0x4B, 0x03, 0x04])), isTrue);
      expect(parser.canParse('file.xml', Uint8List.fromList([0x3C, 0x3F, 0x78])), isFalse);
    });

    test('parseScoreData uncompresses in-memory zip and extracts score via container.xml', () async {
      final archive = Archive();
      final containerBytes = utf8.encode(containerXml);
      final scoreBytes = utf8.encode(sampleMusicXml);

      archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));
      archive.addFile(ArchiveFile('music/score.xml', scoreBytes.length, scoreBytes));

      final zipData = Uint8List.fromList(ZipEncoder().encode(archive));

      final result = await parser.parseScoreData(
        bytes: zipData,
        fileName: 'bach_minuet.mxl',
      );

      expect(result.package.title, equals('Minueto en Sol'));
      expect(result.package.composer, equals('J. S. Bach'));
      expect(result.package.defaultBpm, equals(126));
      expect(result.totalMeasures, equals(1));
      expect(result.totalNotes, equals(3));
    });

    test('parseScoreData falls back to finding .xml inside zip if container.xml is absent', () async {
      final archive = Archive();
      final scoreBytes = utf8.encode(sampleMusicXml);
      archive.addFile(ArchiveFile('my_score.musicxml', scoreBytes.length, scoreBytes));

      final zipData = Uint8List.fromList(ZipEncoder().encode(archive));

      final result = await parser.parseScoreData(
        bytes: zipData,
        fileName: 'standalone.mxl',
      );

      expect(result.package.title, equals('Minueto en Sol'));
      expect(result.totalNotes, equals(3));
    });

    test('parseScoreData throws FormatException on empty or corrupted zip', () async {
      expect(
        () => parser.parseScoreData(bytes: Uint8List(0), fileName: 'empty.mxl'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => parser.parseScoreData(bytes: Uint8List.fromList([1, 2, 3, 4]), fileName: 'corrupt.mxl'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
