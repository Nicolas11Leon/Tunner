import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_type.dart';
import 'package:tunner/core/file_system/presentation/studio_explorer_action_header.dart';
import 'package:tunner/core/file_system/presentation/studio_vscode_explorer_widget.dart';

void main() {
  group('StudioFileType Domain Tests', () {
    test('Correctly deduces file type from filename extensions', () {
      expect(StudioFileType.fromFileName('obra.tunner'), StudioFileType.project);
      expect(StudioFileType.fromFileName('sonata.musicxml'), StudioFileType.score);
      expect(StudioFileType.fromFileName('score.mxl'), StudioFileType.score);
      expect(StudioFileType.fromFileName('audio.wav'), StudioFileType.audioWav);
      expect(StudioFileType.fromFileName('synth.tnt'), StudioFileType.rackTool);
      expect(StudioFileType.fromFileName('temperamento.tpreset'), StudioFileType.tuningPreset);
      expect(StudioFileType.fromFileName('consola.djblueprint'), StudioFileType.djBlueprint);
      expect(StudioFileType.fromFileName('datos.bin'), StudioFileType.genericFile);
    });
  });

  group('StudioFileSystemNode Domain Operations Tests', () {
    test('Performs recursive folder insertion, expansion, and removal cleanly', () {
      var root = const StudioFolderEntity(
        id: 'root',
        name: 'ROOT',
        relativePath: '/',
        modifiedAtMicros: 1000,
        children: [],
      );

      // Insert subfolder
      const subFolder = StudioFolderEntity(
        id: 'sub_1',
        name: 'Partituras',
        relativePath: '/Partituras',
        modifiedAtMicros: 1000,
        children: [],
      );
      root = root.insertChild('root', subFolder);
      expect(root.children.length, 1);

      // Insert file inside subfolder
      const scoreFile = StudioFileEntity(
        id: 'file_1',
        name: 'Sonata.musicxml',
        relativePath: '/Partituras/Sonata.musicxml',
        modifiedAtMicros: 1000,
        extension: '.musicxml',
        fileType: StudioFileType.score,
        sizeBytes: 2048,
      );
      root = root.insertChild('sub_1', scoreFile);
      expect(root.totalFilesCount, 1);

      // Find node
      final found = root.findNode('file_1');
      expect(found, isNotNull);
      expect(found!.name, 'Sonata.musicxml');
      expect((found as StudioFileEntity).formattedSize, '2.0 KB');

      // Toggle expansion
      root = root.toggleFolderExpansion('sub_1');
      final sub = root.findNode('sub_1') as StudioFolderEntity;
      expect(sub.isExpanded, isFalse);

      // Remove node
      root = root.removeChild('file_1');
      expect(root.totalFilesCount, 0);
    });
  });

  group('StudioWorkspaceFileSystemService Operations Tests', () {
    late StudioWorkspaceFileSystemService service;

    setUp(() {
      service = StudioWorkspaceFileSystemService();
      service.resetToDefaults();
    });

    test('Creates new files with proper relative paths and formats', () {
      final file = service.createFile(
        name: 'Minueto_en_Sol.musicxml',
        parentFolderId: 'folder_scores',
        fileType: StudioFileType.score,
      );

      expect(file.id.startsWith('file_'), isTrue);
      expect(file.name, 'Minueto_en_Sol.musicxml');
      expect(file.relativePath, contains('Minueto_en_Sol.musicxml'));
      expect(file.fileType, StudioFileType.score);

      // Verify file is present in root
      final node = service.rootFolder.findNode(file.id);
      expect(node, isNotNull);
    });

    test('Creates nested folders and allows renaming nodes', () {
      final newFolder = service.createFolder(
        name: 'Acto 1 Bocetos',
        parentFolderId: 'folder_scores',
      );

      expect(newFolder.name, 'Acto 1 Bocetos');
      expect(service.rootFolder.findNode(newFolder.id), isNotNull);

      // Rename folder
      service.renameNode(newFolder.id, 'Acto 1 Finalizado');
      final renamedFolder = service.rootFolder.findNode(newFolder.id);
      expect(renamedFolder!.name, 'Acto 1 Finalizado');
    });

    test('Deletes nodes cleanly', () {
      final file = service.createFile(
        name: 'Borrador_Temporal.wav',
        parentFolderId: 'folder_recordings',
      );
      expect(service.rootFolder.findNode(file.id), isNotNull);

      service.deleteNode(file.id);
      expect(service.rootFolder.findNode(file.id), isNull);
    });

    test('Filters tree in real time based on search query', () {
      service.createFile(name: 'Violin_Solo_Take1.wav', parentFolderId: 'folder_recordings');
      service.createFile(name: 'Guitarra_Ritmo_Take1.wav', parentFolderId: 'folder_recordings');

      // Filter by 'violin'
      service.setSearchQuery('violin');
      final filtered = service.filteredRootFolder;

      final recordingsFolder = filtered.children.firstWhere((c) => c.id == 'folder_recordings') as StudioFolderEntity;
      expect(recordingsFolder.children.any((c) => c.name.contains('Violin')), isTrue);
      expect(recordingsFolder.children.any((c) => c.name.contains('Guitarra')), isFalse);

      // Clear search
      service.setSearchQuery('');
      expect(service.filteredRootFolder.children.length, service.rootFolder.children.length);
    });

    test('Dispatches onOpenFile callback when selecting a file', () {
      StudioFileEntity? openedFile;
      service.onOpenFile = (file) => openedFile = file;

      service.selectNode('file_demo_sonata');
      expect(openedFile, isNotNull);
      expect(openedFile!.id, 'file_demo_sonata');
      expect(openedFile!.name, contains('Sonata'));
    });
  });

  group('StudioVsCodeExplorerWidget UI Tests', () {
    testWidgets('Renders action header, folders, files, and status bar', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = StudioWorkspaceFileSystemService();
      service.resetToDefaults();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: StudioVsCodeExplorerWidget(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.byType(StudioExplorerActionHeader), findsOneWidget);
      expect(find.text('EXPLORADOR DE PROYECTO'), findsOneWidget);
      expect(find.byKey(const Key('btn_new_file')), findsOneWidget);
      expect(find.byKey(const Key('btn_new_folder')), findsOneWidget);
      expect(find.byKey(const Key('btn_toggle_search')), findsOneWidget);

      // Verify Folders rendered
      expect(find.text('Partituras & Notación'), findsOneWidget);
      expect(find.text('Tomas de Audio & WAV'), findsOneWidget);
      expect(find.text('Presets de Afinación'), findsOneWidget);

      // Verify Files rendered
      expect(find.text('Sonata No. 1 en C Mayor.musicxml'), findsOneWidget);

      // Tap search toggle
      await tester.tap(find.byKey(const Key('btn_toggle_search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('file_explorer_search_input')), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byKey(const Key('file_explorer_search_input')), 'Sonata');
      await tester.pumpAndSettle();

      expect(find.text('Sonata No. 1 en C Mayor.musicxml'), findsOneWidget);
      expect(find.text('Toma_Acustica_440Hz.wav'), findsNothing);
    });
  });
}
