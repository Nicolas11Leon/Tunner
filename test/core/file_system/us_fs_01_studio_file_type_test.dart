import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/data/local_disk_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_type.dart';

void main() {
  group('US-FS-01 StudioFileType taxonomy & extension extraction', () {
    test('fromFileName clasifica extensiones de audio soportadas como audioWav (case-insensitive)', () {
      const audioFiles = [
        'toma.wav',
        'toma.pcm',
        'toma.aif',
        'toma.aiff',
        'cancion.mp3',
        'CANCION.MP3',
        'master.flac',
        'pista.ogg',
        'voz.m4a',
        'mezcla.aac',
        'loop.opus',
        'demo.wma',
        'stream.webm',
      ];

      for (final fileName in audioFiles) {
        expect(
          StudioFileType.fromFileName(fileName),
          StudioFileType.audioWav,
          reason: 'Se esperaba StudioFileType.audioWav para $fileName',
        );
      }
    });

    test('fromFileName clasifica extensiones de partitura y notación soportadas como score (case-insensitive)', () {
      const scoreFiles = [
        'sonata.musicxml',
        'sonata.mxl',
        'sonata.xml',
        'obra.mid',
        'OBRA.MIDI',
        'melodia.abc',
        'PARTITURA.PDF',
      ];

      for (final fileName in scoreFiles) {
        expect(
          StudioFileType.fromFileName(fileName),
          StudioFileType.score,
          reason: 'Se esperaba StudioFileType.score para $fileName',
        );
      }
    });

    test('fromFileName mantiene intactas las extensiones nativas y el fallback genericFile', () {
      expect(StudioFileType.fromFileName('sesion.tunner'), StudioFileType.project);
      expect(StudioFileType.fromFileName('modulo.tnt'), StudioFileType.rackTool);
      expect(StudioFileType.fromFileName('pitagorico.tpreset'), StudioFileType.tuningPreset);
      expect(StudioFileType.fromFileName('consola.djblueprint'), StudioFileType.djBlueprint);
      expect(StudioFileType.fromFileName('mapa.djkeymap'), StudioFileType.djBlueprint);
      expect(StudioFileType.fromFileName('archivo.desconocido'), StudioFileType.genericFile);
      expect(StudioFileType.fromFileName('sin_extension'), StudioFileType.genericFile);
    });

    test('extractExtension preserva la extensión real en minúsculas y usa fallbackType cuando no hay extensión', () {
      expect(StudioFileType.extractExtension('cancion.mp3', StudioFileType.audioWav), '.mp3');
      expect(StudioFileType.extractExtension('CANCION.MP3', StudioFileType.audioWav), '.mp3');
      expect(StudioFileType.extractExtension('obra.mid', StudioFileType.score), '.mid');
      expect(StudioFileType.extractExtension('partitura.PDF', StudioFileType.score), '.pdf');
      expect(StudioFileType.extractExtension('mi.obra.maestra.flac', StudioFileType.audioWav), '.flac');

      expect(
        StudioFileType.extractExtension('sin_extension', StudioFileType.audioWav),
        StudioFileType.audioWav.extension,
      );
      expect(
        StudioFileType.extractExtension('archivo.', StudioFileType.score),
        StudioFileType.score.extension,
      );
      expect(
        StudioFileType.extractExtension('.oculto', StudioFileType.genericFile),
        StudioFileType.genericFile.extension,
      );
    });

    test('LocalDiskStudioFileSystemRepository preserva la extensión real en disco al escanear archivos', () async {
      final tempDir = await Directory.systemTemp.createTemp('us_fs_01_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File('${tempDir.path}/pista.mp3').writeAsBytes([1, 2, 3]);
      await File('${tempDir.path}/grabacion.FLAC').writeAsBytes([4, 5, 6]);
      await File('${tempDir.path}/secuencia.mid').writeAsBytes([7, 8, 9]);
      await File('${tempDir.path}/guia.PDF').writeAsBytes([10, 11, 12]);

      final repo = LocalDiskStudioFileSystemRepository(customRootPath: tempDir.path);
      final root = await repo.loadRootWorkspace();
      final filesByName = <String, StudioFileEntity>{
        for (final node in root.children.whereType<StudioFileEntity>()) node.name: node,
      };

      expect(filesByName['pista.mp3']?.fileType, StudioFileType.audioWav);
      expect(filesByName['pista.mp3']?.extension, '.mp3');

      expect(filesByName['grabacion.FLAC']?.fileType, StudioFileType.audioWav);
      expect(filesByName['grabacion.FLAC']?.extension, '.flac');

      expect(filesByName['secuencia.mid']?.fileType, StudioFileType.score);
      expect(filesByName['secuencia.mid']?.extension, '.mid');

      expect(filesByName['guia.PDF']?.fileType, StudioFileType.score);
      expect(filesByName['guia.PDF']?.extension, '.pdf');
    });
  });
}
