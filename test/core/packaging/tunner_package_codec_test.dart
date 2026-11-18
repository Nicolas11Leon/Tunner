import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:tunner/core/packaging/domain/tunner_project_manifest_entity.dart';
import 'package:tunner/core/packaging/domain/tunner_project_package_entity.dart';
import 'package:tunner/core/packaging/domain/tunner_package_exceptions.dart';
import 'package:tunner/core/packaging/infrastructure/tunner_package_codec_service.dart';

void main() {
  group('TunnerProjectManifestEntity Unit Tests', () {
    test('JSON serialization and deserialization preserves all metadata accurately', () {
      final now = DateTime.now();
      final manifest = TunnerProjectManifestEntity(
        id: 'proj_symphony_001',
        title: 'Sinfonía en Re Mayor',
        author: 'Maestro Beethoven',
        version: '1.0.0',
        createdAt: now,
        modifiedAt: now,
        bpm: 132.5,
        timeSignature: '3/4',
        sampleRate: 48000,
        fileHashes: {'notation/score.json': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'},
        metadata: {'genre': 'Classical', 'movement': 1},
      );

      final json = manifest.toJson();
      final restored = TunnerProjectManifestEntity.fromJson(json);

      expect(restored.id, 'proj_symphony_001');
      expect(restored.title, 'Sinfonía en Re Mayor');
      expect(restored.author, 'Maestro Beethoven');
      expect(restored.version, '1.0.0');
      expect(restored.bpm, 132.5);
      expect(restored.timeSignature, '3/4');
      expect(restored.sampleRate, 48000);
      expect(restored.fileHashes['notation/score.json'], 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(restored.metadata['genre'], 'Classical');
    });

    test('copyWith modifies selected fields and preserves immutability', () {
      final now = DateTime.now();
      final manifest = TunnerProjectManifestEntity(
        id: 'proj_01',
        title: 'Original Title',
        createdAt: now,
        modifiedAt: now,
      );

      final updated = manifest.copyWith(title: 'Updated Title', bpm: 140.0);
      expect(updated.title, 'Updated Title');
      expect(updated.bpm, 140.0);
      expect(updated.id, 'proj_01');
      expect(manifest.title, 'Original Title');
    });
  });

  group('TunnerPackageCodecService Unit Tests', () {
    const codec = TunnerPackageCodecService();

    test('Encodes and decodes complete project package losslessly (Roundtrip)', () {
      final now = DateTime.now();
      final manifest = TunnerProjectManifestEntity(
        id: 'test_project_alpha',
        title: 'Alpha Electronic Suite',
        author: 'Studio Engineer',
        createdAt: now,
        modifiedAt: now,
        bpm: 128.0,
      );

      final sampleWavBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0x01, 0x02, 0x03, 0x04]);
      final sampleScore = {'tempo': 128, 'measures': [{'index': 1, 'notes': ['C4', 'E4', 'G4']}]};
      final sampleMatrix = {'master_gain': 0.85, 'eq': {'low': 2.0, 'mid': 0.0, 'high': -1.5}};
      final sampleSynth = {'waveform': 'sawtooth', 'attack': 0.02, 'release': 0.25};
      final sampleDj = {'deckA': {'bpm': 128.0}, 'deckB': {'bpm': 128.0}};

      final package = TunnerProjectPackageEntity(
        manifest: manifest,
        routingMatrixJson: sampleMatrix,
        scoreJson: sampleScore,
        synthPresetJson: sampleSynth,
        djSessionJson: sampleDj,
        audioFiles: {'lead_synth.wav': sampleWavBytes},
      );

      // Codificación binaria a archivo .tunner
      final encodedBytes = codec.encodePackage(package);
      expect(encodedBytes, isNotEmpty);

      // Inspección rápida del manifiesto sin desempaquetar audio
      final quickManifest = codec.readManifest(encodedBytes);
      expect(quickManifest.title, 'Alpha Electronic Suite');
      expect(quickManifest.fileHashes, isNotEmpty);
      expect(quickManifest.fileHashes.containsKey('routing_matrix.json'), isTrue);
      expect(quickManifest.fileHashes.containsKey('notation/score.json'), isTrue);
      expect(quickManifest.fileHashes.containsKey('instruments/synth_preset.json'), isTrue);
      expect(quickManifest.fileHashes.containsKey('dj_workstation/session.json'), isTrue);
      expect(quickManifest.fileHashes.containsKey('audio_vault/stems/lead_synth.wav'), isTrue);

      // Decodificación íntegra con verificación criptográfica SHA-256
      final restored = codec.decodePackage(encodedBytes, verifyHashes: true);
      expect(restored.manifest.id, 'test_project_alpha');
      expect(restored.scoreJson?['measures'], isNotNull);
      expect(restored.routingMatrixJson?['master_gain'], 0.85);
      expect(restored.synthPresetJson?['waveform'], 'sawtooth');
      expect(restored.djSessionJson?['deckA']?['bpm'], 128.0);
      expect(restored.audioFiles['lead_synth.wav'], equals(sampleWavBytes));
      expect(restored.totalAudioBytes, sampleWavBytes.lengthInBytes);
    });

    test('Throws TunnerPackageCorruptedException if internal file content is tampered with', () {
      final now = DateTime.now();
      final manifest = TunnerProjectManifestEntity(
        id: 'tamper_test',
        title: 'Tamper Project',
        createdAt: now,
        modifiedAt: now,
      );

      final originalScore = {'title': 'Genuine Work', 'notes': ['A4']};
      final package = TunnerProjectPackageEntity(
        manifest: manifest,
        scoreJson: originalScore,
      );

      final encodedBytes = codec.encodePackage(package);

      // Descomprimir, alterar un byte de score.json y volver a comprimir
      final archive = ZipDecoder().decodeBytes(encodedBytes);
      final tamperedScoreJson = utf8.encode(jsonEncode({'title': 'Malicious Tamper', 'notes': ['F#4']}));

      final tamperedArchive = Archive();
      for (final f in archive.files) {
        if (f.name == 'notation/score.json') {
          tamperedArchive.addFile(ArchiveFile(f.name, tamperedScoreJson.length, tamperedScoreJson));
        } else {
          tamperedArchive.addFile(f);
        }
      }

      final tamperedBytes = Uint8List.fromList(ZipEncoder().encode(tamperedArchive));

      // La decodificación con verificación debe abortar inmediatamente
      expect(
        () => codec.decodePackage(tamperedBytes, verifyHashes: true),
        throwsA(isA<TunnerPackageCorruptedException>()),
      );
    });

    test('Throws TunnerPackageCorruptedException if declared file in manifest is missing', () {
      final now = DateTime.now();
      final manifest = TunnerProjectManifestEntity(
        id: 'missing_file_test',
        title: 'Missing File Test',
        createdAt: now,
        modifiedAt: now,
      );

      final package = TunnerProjectPackageEntity(
        manifest: manifest,
        scoreJson: {'valid': true},
        routingMatrixJson: {'valid': true},
      );

      final encodedBytes = codec.encodePackage(package);
      final archive = ZipDecoder().decodeBytes(encodedBytes);

      // Crear archivo ZIP omitiendo routing_matrix.json pero dejando el manifiesto que lo espera
      final tamperedArchive = Archive();
      for (final f in archive.files) {
        if (f.name != 'routing_matrix.json') {
          tamperedArchive.addFile(f);
        }
      }

      final corruptedBytes = Uint8List.fromList(ZipEncoder().encode(tamperedArchive));

      expect(
        () => codec.decodePackage(corruptedBytes, verifyHashes: true),
        throwsA(isA<TunnerPackageCorruptedException>()),
      );
    });

    test('Throws TunnerPackageInvalidFormatException when input is empty or invalid zip', () {
      expect(
        () => codec.decodePackage(Uint8List(0)),
        throwsA(isA<TunnerPackageInvalidFormatException>()),
      );

      expect(
        () => codec.decodePackage(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<TunnerPackageInvalidFormatException>()),
      );
    });

    test('Throws TunnerPackageInvalidFormatException when manifest.json is absent in zip', () {
      final archive = Archive();
      archive.addFile(ArchiveFile('random.txt', 4, utf8.encode('test')));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => codec.decodePackage(bytes),
        throwsA(isA<TunnerPackageInvalidFormatException>()),
      );
    });
  });
}
