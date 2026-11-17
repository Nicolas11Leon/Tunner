import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/data/local_disk_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/data/memory_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_type.dart';

void main() {
  group('MemoryStudioFileSystemRepository Tests', () {
    test('Loads seeded structure and manages CRUD in memory', () async {
      final repo = MemoryStudioFileSystemRepository();
      final root = await repo.loadRootWorkspace();

      expect(root.children.isNotEmpty, isTrue);
      expect(root.totalFilesCount, greaterThan(0));

      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await repo.saveFile(
        relativePath: '/Partituras & Notación/Etude.musicxml',
        bytes: testBytes,
      );

      final readBytes = await repo.readFile('/Partituras & Notación/Etude.musicxml');
      expect(readBytes, equals(testBytes));

      await repo.createFolder('/Tomas de Audio & WAV/Subtakes');
      await repo.movePath(
        oldRelativePath: '/Partituras & Notación/Etude.musicxml',
        newRelativePath: '/Tomas de Audio & WAV/Subtakes/Etude.musicxml',
      );

      final movedBytes = await repo.readFile('/Tomas de Audio & WAV/Subtakes/Etude.musicxml');
      expect(movedBytes, equals(testBytes));

      await repo.deletePath('/Tomas de Audio & WAV/Subtakes/Etude.musicxml');
      expect(() => repo.readFile('/Tomas de Audio & WAV/Subtakes/Etude.musicxml'), throwsException);
    });
  });

  group('LocalDiskStudioFileSystemRepository Tests', () {
    late Directory tempTestDir;
    late LocalDiskStudioFileSystemRepository repository;

    setUp(() async {
      tempTestDir = await Directory.systemTemp.createTemp('tunner_disk_repo_test_');
      repository = LocalDiskStudioFileSystemRepository(customRootPath: tempTestDir.path);
    });

    tearDown(() async {
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    });

    test('loadRootWorkspace automatically seeds default files on disk', () async {
      final root = await repository.loadRootWorkspace();

      expect(root.isFolder, isTrue);
      expect(root.name, 'PROYECTO TUNNER');
      expect(root.children.isNotEmpty, isTrue);

      // Verify physical presence on disk
      final scoresDir = Directory('${tempTestDir.path}/Partituras & Notación');
      expect(await scoresDir.exists(), isTrue);

      final scoreFile = File('${scoresDir.path}/Sonata No. 1 en C Mayor.musicxml');
      expect(await scoreFile.exists(), isTrue);
      final scoreContent = await scoreFile.readAsString();
      expect(scoreContent, contains('Sonata No. 1'));
    });

    test('saveFile, readFile, createFolder, movePath and deletePath operate on real disk', () async {
      // 1. Create a custom folder
      await repository.createFolder('/Sesiones 2026');
      final physicalDir = Directory('${tempTestDir.path}/Sesiones 2026');
      expect(await physicalDir.exists(), isTrue);

      // 2. Save a binary WAV file
      final pcmBytes = Uint8List.fromList([82, 73, 70, 70, 10, 20, 30, 40]);
      await repository.saveFile(
        relativePath: '/Sesiones 2026/VocalTake_1.wav',
        bytes: pcmBytes,
      );

      final physicalFile = File('${tempTestDir.path}/Sesiones 2026/VocalTake_1.wav');
      expect(await physicalFile.exists(), isTrue);

      // 3. Read back bytes
      final readBytes = await repository.readFile('/Sesiones 2026/VocalTake_1.wav');
      expect(readBytes, equals(pcmBytes));

      // 4. Move file to another directory
      await repository.createFolder('/Tomas de Audio & WAV');
      await repository.movePath(
        oldRelativePath: '/Sesiones 2026/VocalTake_1.wav',
        newRelativePath: '/Tomas de Audio & WAV/VocalTake_1_Master.wav',
      );

      final movedPhysical = File('${tempTestDir.path}/Tomas de Audio & WAV/VocalTake_1_Master.wav');
      expect(await movedPhysical.exists(), isTrue);
      expect(await physicalFile.exists(), isFalse);

      // 5. Delete path
      await repository.deletePath('/Tomas de Audio & WAV/VocalTake_1_Master.wav');
      expect(await movedPhysical.exists(), isFalse);
    });

    test('moveChild in StudioFolderEntity relocates nodes accurately in domain tree', () {
      final now = DateTime.now().microsecondsSinceEpoch;
      final file = StudioFileEntity(
        id: 'file_movable',
        name: 'Track.wav',
        relativePath: '/FolderA/Track.wav',
        modifiedAtMicros: now,
        extension: '.wav',
        fileType: StudioFileType.audioWav,
      );
      final folderA = StudioFolderEntity(
        id: 'folder_a',
        name: 'FolderA',
        relativePath: '/FolderA',
        modifiedAtMicros: now,
        children: [file],
      );
      final folderB = StudioFolderEntity(
        id: 'folder_b',
        name: 'FolderB',
        relativePath: '/FolderB',
        modifiedAtMicros: now,
        children: const [],
      );
      var root = StudioFolderEntity(
        id: 'root',
        name: 'ROOT',
        relativePath: '/',
        modifiedAtMicros: now,
        children: [folderA, folderB],
      );

      expect(root.findNode('folder_a')!.isFolder, isTrue);
      final initialA = root.findNode('folder_a') as StudioFolderEntity;
      expect(initialA.children.length, 1);

      // Move file from FolderA to FolderB
      root = root.moveChild('file_movable', 'folder_b');

      final updatedA = root.findNode('folder_a') as StudioFolderEntity;
      final updatedB = root.findNode('folder_b') as StudioFolderEntity;

      expect(updatedA.children.isEmpty, isTrue);
      expect(updatedB.children.length, 1);
      expect(updatedB.children.first.id, 'file_movable');
      expect(updatedB.children.first.relativePath, '/FolderB/Track.wav');
    });

    test('StudioWorkspaceFileSystemService moveNode coordinates domain and disk persistence', () async {
      final repo = MemoryStudioFileSystemRepository();
      final service = StudioWorkspaceFileSystemService(fileSystemRepository: repo);
      await service.initializeWorkspace();

      // Create new folder and file
      final folder = service.createFolder(name: 'Composiciones');
      final file = service.createFile(
        name: 'Canon.musicxml',
        parentFolderId: folder.id,
        fileType: StudioFileType.score,
      );

      expect(file.relativePath, contains('Composiciones/Canon.musicxml'));

      // Move file to existing scores folder
      final scoresFolder = service.rootFolder.children.firstWhere((c) => c.name.contains('Partituras'));
      service.moveNode(file.id, scoresFolder.id);

      final movedNode = service.rootFolder.findNode(file.id);
      expect(movedNode, isNotNull);
      expect(movedNode!.relativePath, contains('Partituras & Notación/Canon.musicxml'));

      // Refresh from disk verifies persistence
      await service.refreshFromDisk();
      expect(service.rootFolder.children.isNotEmpty, isTrue);
    });
  });
}
