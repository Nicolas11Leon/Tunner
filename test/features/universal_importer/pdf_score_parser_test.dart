import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/universal_importer/data/pdf_score_parser.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

void main() {
  group('PdfScoreParser Tests', () {
    const parser = PdfScoreParser();

    // Helper para generar PDFs de prueba válidos sintéticamente
    Uint8List generateTestPdf({
      required String streamContent,
      String? title,
      bool compressFlate = false,
    }) {
      final streamRawBytes = utf8.encode(streamContent);
      List<int> finalStreamBytes;
      String filterString = '';

      if (compressFlate) {
        finalStreamBytes = ZLibEncoder().encode(streamRawBytes);
        filterString = '/Filter /FlateDecode';
      } else {
        finalStreamBytes = streamRawBytes;
      }

      final streamLength = finalStreamBytes.length;
      final infoDict = title != null ? '/Info << /Title ($title) >>' : '';

      final header = '%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n';
      final pageTree = '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n';
      final page = '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 500 400] /Contents 4 0 R >>\nendobj\n';
      final streamObjHeader = '4 0 obj\n<< /Length $streamLength $filterString >>\nstream\n';
      final streamObjFooter = '\nendstream\nendobj\n';
      final trailer = 'xref\n0 5\ntrailer\n<< /Size 5 /Root 1 0 R $infoDict >>\nstartxref\n400\n%%EOF';

      final List<int> fullBytes = [
        ...utf8.encode(header),
        ...utf8.encode(pageTree),
        ...utf8.encode(page),
        ...utf8.encode(streamObjHeader),
        ...finalStreamBytes,
        ...utf8.encode(streamObjFooter),
        ...utf8.encode(trailer),
      ];

      return Uint8List.fromList(fullBytes);
    }

    test('canParse correctly detects .pdf extension and magic byte signature', () {
      expect(parser.canParse('score.pdf', Uint8List(0)), isTrue);
      expect(parser.canParse('SCORE.PDF', Uint8List(0)), isTrue);
      expect(
        parser.canParse('document.bin', Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D])),
        isTrue,
      );
      expect(
        parser.canParse('song.mid', Uint8List.fromList([0x4D, 0x54, 0x68, 0x64])),
        isFalse,
      );
    });

    test('parseScoreData extracts uncompressed vector drawing streams and builds score', () async {
      const drawing = '''
50 100 m 450 100 l S
50 110 m 450 110 l S
50 120 m 450 120 l S
50 130 m 450 130 l S
50 140 m 450 140 l S
250 100 m 250 140 l S
450 100 m 450 140 l S
96 96 8 8 re f
196 106 8 8 re f
296 116 8 8 re f
396 126 8 8 re f
''';

      final pdfBytes = generateTestPdf(
        streamContent: drawing,
        title: 'Estudio de Beethoven',
      );

      final result = await parser.parseScoreData(
        bytes: pdfBytes,
        fileName: 'beethoven.pdf',
      );

      expect(result.format, equals('PDF (Vector OMR)'));
      expect(result.package.title, equals('Estudio de Beethoven'));
      expect(result.totalMeasures, greaterThanOrEqualTo(2));
      expect(result.totalNotes, greaterThan(0));
      expect(result.package.tracks, isNotEmpty);
      expect(result.package.tracks.first.title, equals('Partitura OMR'));
    });

    test('parseScoreData extracts and decompresses FlateDecode (zlib) streams', () async {
      const drawing = '''
50 100 m 450 100 l S
50 110 m 450 110 l S
50 120 m 450 120 l S
50 130 m 450 130 l S
50 140 m 450 140 l S
250 100 m 250 140 l S
100 100 10 10 re f
300 120 10 10 re f
''';

      final pdfBytes = generateTestPdf(
        streamContent: drawing,
        title: 'Pieza Comprimida Flate',
        compressFlate: true,
      );

      final result = await parser.parseScoreData(
        bytes: pdfBytes,
        fileName: 'flate_score.pdf',
      );

      expect(result.format, equals('PDF (Vector OMR)'));
      expect(result.package.title, equals('Pieza Comprimida Flate'));
      expect(result.totalMeasures, greaterThanOrEqualTo(1));
    });

    test('Throws FormatException for empty bytes or invalid non-PDF stream', () async {
      expect(
        () => parser.parseScoreData(bytes: Uint8List(0), fileName: 'empty.pdf'),
        throwsA(isA<FormatException>()),
      );

      final invalidBytes = Uint8List.fromList(utf8.encode('Hello World this is not a PDF'));
      expect(
        () => parser.parseScoreData(bytes: invalidBytes, fileName: 'corrupt.pdf'),
        throwsA(isA<FormatException>()),
      );
    });

    test('UniversalScoreImporterService delegates PDF files seamlessly', () async {
      const importer = UniversalScoreImporterService();
      const drawing = '''
50 100 m 450 100 l S
50 110 m 450 110 l S
50 120 m 450 120 l S
50 130 m 450 130 l S
50 140 m 450 140 l S
100 100 8 8 re f
''';

      final pdfBytes = generateTestPdf(streamContent: drawing, title: 'Servicio Universal PDF');

      expect(importer.canParse('test.pdf', pdfBytes), isTrue);

      final result = await importer.parseScoreData(
        bytes: pdfBytes,
        fileName: 'test.pdf',
      );

      expect(result.format, equals('PDF (Vector OMR)'));
      expect(result.package.title, equals('Servicio Universal PDF'));
    });
  });
}
