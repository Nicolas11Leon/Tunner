import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/i_audio_transcoder_port.dart';
import 'package:tunner/core/file_system/data/memory_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

class _FakePlatformFileGateway extends NoOpPlatformFileGateway {
  PlatformPickedFile? nextPickedFile;

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async {
    return nextPickedFile;
  }
}

class _FakeAudioTranscoder extends NoOpAudioTranscoderPort {
  const _FakeAudioTranscoder({this.shouldFail = false});

  final bool shouldFail;

  @override
  bool isSupportedCompressedExtension(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'mp3' || ext == 'flac' || ext == 'ogg' || ext == 'm4a';
  }

  @override
  Future<Uint8List?> transcodeToWav16BitPcm(
    Uint8List sourceBytes, {
    required String fileExtension,
    int targetSampleRate = 44100,
    int channels = 1,
  }) async {
    if (shouldFail) return null;
    // Minimal valid 44-byte WAV header + 4 bytes of 16-bit PCM silence
    final wav = ByteData(48);
    // "RIFF"
    wav.setUint8(0, 0x52);
    wav.setUint8(1, 0x49);
    wav.setUint8(2, 0x46);
    wav.setUint8(3, 0x46);
    wav.setUint32(4, 40, Endian.little);
    // "WAVE"
    wav.setUint8(8, 0x57);
    wav.setUint8(9, 0x41);
    wav.setUint8(10, 0x56);
    wav.setUint8(11, 0x45);
    // "fmt "
    wav.setUint8(12, 0x66);
    wav.setUint8(13, 0x6D);
    wav.setUint8(14, 0x74);
    wav.setUint8(15, 0x20);
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little); // PCM
    wav.setUint16(22, 1, Endian.little); // mono
    wav.setUint32(24, 44100, Endian.little); // sample rate
    wav.setUint32(28, 88200, Endian.little); // byte rate
    wav.setUint16(32, 2, Endian.little); // block align
    wav.setUint16(34, 16, Endian.little); // bits per sample
    // "data"
    wav.setUint8(36, 0x64);
    wav.setUint8(37, 0x61);
    wav.setUint8(38, 0x74);
    wav.setUint8(39, 0x61);
    wav.setUint32(40, 4, Endian.little);
    return wav.buffer.asUint8List();
  }
}

StudioFileEntity? _findFileInFolder(StudioFolderEntity folder, String expectedPath) {
  for (final child in folder.children) {
    if (child is StudioFileEntity && child.relativePath == expectedPath) {
      return child;
    }
    if (child is StudioFolderEntity) {
      final nested = _findFileInFolder(child, expectedPath);
      if (nested != null) return nested;
    }
  }
  return null;
}

const _sampleMusicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Estudio de Prueba</work-title></work>
  <part-list><score-part id="P1"><part-name>Flauta</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
    </measure>
  </part>
</score-partwise>''';

void main() {
  group('US-FS-03 Copy-on-Import y Diagnóstico de Importación', () {
    test('Persiste automáticamente una partitura MusicXML en /Partituras & Notación/', () async {
      final repo = MemoryStudioFileSystemRepository();
      final workspaceFs = StudioWorkspaceFileSystemService.isolated(
        fileSystemRepository: repo,
      );
      await workspaceFs.initializeWorkspace();

      final vm = TunerViewModel(
        scoreImporterService: const UniversalScoreImporterService(),
        workspaceFileSystem: workspaceFs,
      );
      addTearDown(vm.dispose);

      final importingStates = <bool>[];
      vm.addListener(() {
        importingStates.add(vm.isImportingFile);
      });

      final xmlBytes = Uint8List.fromList(utf8.encode(_sampleMusicXml));
      final result = await vm.importScoreFromBytes(xmlBytes, 'obra_prueba.musicxml');

      expect(result, isNotNull);
      expect(vm.lastImportError, isNull);
      expect(vm.isImportingFile, isFalse);
      expect(importingStates, contains(true));
      expect(importingStates.last, isFalse);

      await workspaceFs.refreshFromDisk();
      final persistedFile = _findFileInFolder(
        workspaceFs.rootFolder,
        '/Partituras & Notación/obra_prueba.musicxml',
      );
      expect(persistedFile, isNotNull);
      expect(persistedFile!.name, 'obra_prueba.musicxml');
      expect(persistedFile.sizeBytes, xmlBytes.length);
    });

    test('Persiste automáticamente un audio importado en /Tomas de Audio & WAV/', () async {
      final repo = MemoryStudioFileSystemRepository();
      final workspaceFs = StudioWorkspaceFileSystemService.isolated(
        fileSystemRepository: repo,
      );
      await workspaceFs.initializeWorkspace();

      final vm = TunerViewModel(
        scoreImporterService: const UniversalScoreImporterService(),
        audioTranscoder: _FakeAudioTranscoder(),
        workspaceFileSystem: workspaceFs,
      );
      addTearDown(vm.dispose);

      final mp3DummyBytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00]);
      final result = await vm.importScoreFromBytes(mp3DummyBytes, 'pista_ensayo.mp3');

      expect(result, isNotNull);
      expect(vm.lastImportError, isNull);
      expect(vm.isImportingFile, isFalse);

      await workspaceFs.refreshFromDisk();
      final persistedAudio = _findFileInFolder(
        workspaceFs.rootFolder,
        '/Tomas de Audio & WAV/pista_ensayo.wav',
      );
      expect(persistedAudio, isNotNull);
      expect(persistedAudio!.name, 'pista_ensayo.wav');
    });

    test('Registra mensaje diagnóstico en lastImportError cuando falla la importación y permanece null al cancelar pickFile', () async {
      final gateway = _FakePlatformFileGateway();
      final vm = TunerViewModel(
        scoreImporterService: const UniversalScoreImporterService(),
        audioTranscoder: _FakeAudioTranscoder(shouldFail: true),
        platformFileGateway: gateway,
      );
      addTearDown(vm.dispose);

      // 1) Fallo de decodificación de audio comprimido
      final failAudioResult = await vm.importScoreFromBytes(
        Uint8List.fromList([1, 2, 3]),
        'corrupto.mp3',
      );
      expect(failAudioResult, isNull);
      expect(vm.lastImportError, isNotNull);
      expect(vm.lastImportError, contains('corrupto.mp3'));
      expect(vm.isImportingFile, isFalse);

      // 2) Cancelación de pickFile (retorna null) limpia/deja lastImportError en null
      gateway.nextPickedFile = null;
      final cancelledResult = await vm.importScoreFromFilePicker();
      expect(cancelledResult, isNull);
      expect(vm.lastImportError, isNull);

      // 3) Archivo seleccionado con bytes vacíos reporta error diagnóstico
      gateway.nextPickedFile = PlatformPickedFile(
        name: 'vacio.musicxml',
        bytes: Uint8List(0),
      );
      final emptyResult = await vm.importScoreFromFilePicker();
      expect(emptyResult, isNull);
      expect(vm.lastImportError, isNotNull);
      expect(vm.lastImportError, contains('vacio.musicxml'));

      // 4) Archivo inválido que falla en parseScoreData reporta error en lastImportError
      final invalidResult = await vm.importScoreFromBytes(
        Uint8List.fromList(utf8.encode('not valid musicxml')),
        'roto.musicxml',
      );
      expect(invalidResult, isNull);
      expect(vm.lastImportError, isNotNull);
      expect(vm.lastImportError, contains('roto.musicxml'));
      expect(vm.isImportingFile, isFalse);
    });
  });
}
