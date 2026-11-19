import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/packaging/domain/tunner_package_exceptions.dart';
import 'package:tunner/core/packaging/domain/tunner_project_manifest_entity.dart';
import 'package:tunner/core/packaging/domain/tunner_project_package_entity.dart';
import 'package:tunner/core/packaging/infrastructure/tunner_package_codec_service.dart';

void main() {
  group('TunnerPackageCodecService Security Hardening Tests (Ola 1)', () {
    const codec = TunnerPackageCodecService();

    test('Rejects packages containing Zip-Slip paths', () {
      final archive = Archive();
      final manifest = TunnerProjectManifestEntity(
        id: 'slip_test',
        title: 'Zip Slip Test',
        author: 'Tester',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      final manifestBytes = utf8.encode(manifest.serializeJson());
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // Malicious path escaping project sandbox
      final evilBytes = utf8.encode('malicious content');
      archive.addFile(ArchiveFile('../../etc/cron.d/evil', evilBytes.length, evilBytes));

      final zipEncoder = ZipEncoder();
      final encodedZip = Uint8List.fromList(zipEncoder.encode(archive));

      expect(
        () => codec.decodePackage(encodedZip, verifyHashes: false),
        throwsA(isA<TunnerPackageCorruptedException>().having(
          (e) => e.actualHash,
          'actualHash',
          'ZIP_SLIP_ATTEMPT',
        )),
      );

      expect(
        () => codec.readManifest(encodedZip),
        throwsA(isA<TunnerPackageCorruptedException>().having(
          (e) => e.actualHash,
          'actualHash',
          'ZIP_SLIP_ATTEMPT',
        )),
      );
    });

    test('Rejects packages with empty hashes when verifyHashes is true', () {
      final manifest = TunnerProjectManifestEntity(
        id: 'no_hash_test',
        title: 'No Hash',
        author: 'Tester',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        fileHashes: const {}, // empty
      );
      final archive = Archive();
      final manifestBytes = utf8.encode(manifest.serializeJson());
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      final scoreBytes = utf8.encode('{"title":"test"}');
      archive.addFile(ArchiveFile('notation/score.json', scoreBytes.length, scoreBytes));

      final zipEncoder = ZipEncoder();
      final encodedZip = Uint8List.fromList(zipEncoder.encode(archive));

      expect(
        () => codec.decodePackage(encodedZip, verifyHashes: true),
        throwsA(isA<TunnerPackageCorruptedException>().having(
          (e) => e.actualHash,
          'actualHash',
          'HASHES_VACIOS',
        )),
      );
    });

    test('Rejects packages exceeding decompression size limit (Zip-Bomb prevention)', () {
      final archive = Archive();
      final manifest = TunnerProjectManifestEntity(
        id: 'bomb_test',
        title: 'Zip Bomb Test',
        author: 'Tester',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      final manifestBytes = utf8.encode(manifest.serializeJson());
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // Entry claiming size > 250 MB
      final fakeLargeFile = ArchiveFile('audio_vault/stems/huge.wav', 300 * 1024 * 1024, Uint8List(10));
      archive.addFile(fakeLargeFile);

      final zipEncoder = ZipEncoder();
      final encodedZip = Uint8List.fromList(zipEncoder.encode(archive));

      expect(
        () => codec.decodePackage(encodedZip, verifyHashes: false),
        throwsA(isA<TunnerPackageInvalidFormatException>()),
      );
    });

    test('Valid package encodes and decodes with 100% fidelity', () {
      final now = DateTime.now();
      final manifest = TunnerProjectManifestEntity(
        id: 'valid_pkg_1',
        title: 'Masterpiece in D Minor',
        author: 'Beethoven',
        createdAt: now,
        modifiedAt: now,
        bpm: 132.0,
        timeSignature: '3/4',
      );

      final pkg = TunnerProjectPackageEntity(
        manifest: manifest,
        scoreJson: {
          'title': 'Symphony No. 9',
          'measures': [
            {'index': 1, 'notes': ['D4', 'F4', 'A4']},
          ],
        },
        synthPresetJson: {'waveform': 'triangle', 'cutoff': 2500},
        audioFiles: {
          'cellos.wav': Uint8List.fromList([1, 2, 3, 4]),
        },
      );

      final encoded = codec.encodePackage(pkg);
      expect(encoded, isNotEmpty);

      final decoded = codec.decodePackage(encoded, verifyHashes: true);
      expect(decoded.manifest.id, 'valid_pkg_1');
      expect(decoded.manifest.bpm, 132.0);
      expect(decoded.manifest.timeSignature, '3/4');
      expect(decoded.scoreJson?['title'], 'Symphony No. 9');
      expect(decoded.audioFiles.containsKey('cellos.wav'), isTrue);
    });
  });
}
