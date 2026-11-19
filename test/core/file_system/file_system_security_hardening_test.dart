import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/data/local_disk_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';

void main() {
  group('FileSystem Security & Hardening Tests (Ola 1)', () {
    late Directory tempDir;
    late LocalDiskStudioFileSystemRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_sec_test_');
      repo = LocalDiskStudioFileSystemRepository(customRootPath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Root folder ID is canonically "root" and root deletion is rejected', () async {
      final root = await repo.loadRootWorkspace();
      expect(root.id, 'root');
      expect(root.relativePath, '/');

      expect(
        () => repo.deletePath('/'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.deletePath(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.deletePath('.'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Path traversal attempts in repository operations throw ArgumentError', () async {
      expect(
        () => repo.createFolder('../escape_folder'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.saveFile(relativePath: '../../outside.wav', bytes: Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.readFile('../../../etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.deletePath('../../forbidden'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.movePath(oldRelativePath: 'valid', newRelativePath: '../invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('StudioWorkspaceFileSystemService rejects invalid names with slashes, backslashes and dot-dot', () {
      final service = StudioWorkspaceFileSystemService.isolated(fileSystemRepository: repo);

      expect(
        () => service.createFolder(name: '../hacked'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.createFolder(name: 'sub/folder'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.createFolder(name: 'sub\\folder'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.createFile(name: '../../script.sh'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.renameNode('root', 'NewRoot'),
        returnsNormally,
      );
      expect(service.rootFolder.id, 'root');
    });

    test('Renaming a folder recursively updates relativePath of all children', () {
      final service = StudioWorkspaceFileSystemService.isolated(fileSystemRepository: repo);
      final parentFolder = service.createFolder(name: 'OriginalFolder');
      final childFile = service.createFile(name: 'take.wav', parentFolderId: parentFolder.id);
      final subFolder = service.createFolder(name: 'Nested', parentFolderId: parentFolder.id);
      final nestedFile = service.createFile(name: 'nested.wav', parentFolderId: subFolder.id);

      service.renameNode(parentFolder.id, 'RenamedFolder');

      final updatedRoot = service.rootFolder;
      final updatedParent = updatedRoot.findNode(parentFolder.id) as StudioFolderEntity?;
      expect(updatedParent, isNotNull);
      expect(updatedParent!.name, 'RenamedFolder');
      expect(updatedParent.relativePath, '/RenamedFolder');

      // Recursively verified
      final updatedChild = updatedRoot.findNode(childFile.id) as StudioFileEntity?;
      expect(updatedChild, isNotNull);
      expect(updatedChild!.relativePath, '/RenamedFolder/take.wav');

      final updatedNested = updatedRoot.findNode(nestedFile.id) as StudioFileEntity?;
      expect(updatedNested, isNotNull);
      expect(updatedNested!.relativePath, '/RenamedFolder/Nested/nested.wav');
    });
  });
}
