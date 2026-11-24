import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/data/memory_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_type.dart';
import 'package:tunner/core/file_system/presentation/studio_file_tree_tile.dart';

void main() {
  late StudioWorkspaceFileSystemService fsService;

  setUp(() {
    fsService = StudioWorkspaceFileSystemService.isolated(
      fileSystemRepository: MemoryStudioFileSystemRepository(),
    );
  });

  tearDown(() {
    fsService.dispose();
  });

  Widget buildTileHarness(StudioFileEntity file) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: StudioFileTreeTile(
            file: file,
            service: fsService,
          ),
        ),
      ),
    );
  }

  group('US-UX-03: Acciones Musicales Contextuales en Explorador Lateral', () {
    testWidgets(
      'Al abrir el menú contextual de un archivo audioWav aparecen las 3 acciones musicales contextuales',
      (WidgetTester tester) async {
        const audioFile = StudioFileEntity(
          id: 'file_wav_1',
          name: 'Beat_Demo.wav',
          relativePath: '/Tomas de Audio & WAV/Beat_Demo.wav',
          modifiedAtMicros: 0,
          extension: '.wav',
          fileType: StudioFileType.audioWav,
          sizeBytes: 4096,
        );

        await tester.pumpWidget(buildTileHarness(audioFile));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Transformar a Partitura y 4 Stems'), findsOneWidget);
        expect(find.text('Cargar en Deck A (Consola DJ)'), findsOneWidget);
        expect(find.text('Cargar en Deck B (Consola DJ)'), findsOneWidget);
        expect(find.text('Renombrar'), findsOneWidget);
        expect(find.text('Mover a...'), findsOneWidget);
        expect(find.text('Eliminar'), findsOneWidget);
      },
    );

    testWidgets(
      'Al seleccionar "Transformar a Partitura y 4 Stems" dispara onFileMusicalAction con transformToScoreAndStems sin disparar onOpenFile',
      (WidgetTester tester) async {
        const audioFile = StudioFileEntity(
          id: 'file_wav_2',
          name: 'Melodia_Test.wav',
          relativePath: '/Tomas de Audio & WAV/Melodia_Test.wav',
          modifiedAtMicros: 0,
          extension: '.wav',
          fileType: StudioFileType.audioWav,
          sizeBytes: 8192,
        );

        StudioFileEntity? receivedFile;
        StudioFileMusicalAction? receivedAction;
        bool openFileCalled = false;
        fsService.onOpenFile = (_) {
          openFileCalled = true;
        };
        fsService.onFileMusicalAction = (file, action) {
          receivedFile = file;
          receivedAction = action;
        };

        await tester.pumpWidget(buildTileHarness(audioFile));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Transformar a Partitura y 4 Stems'));
        await tester.pumpAndSettle();

        expect(receivedFile?.id, audioFile.id);
        expect(receivedAction, StudioFileMusicalAction.transformToScoreAndStems);
        expect(openFileCalled, isFalse);
        expect(fsService.selectedNodeId, audioFile.id);
      },
    );

    testWidgets(
      'Al seleccionar "Cargar en Deck B (Consola DJ)" dispara onFileMusicalAction con loadInDjDeckB',
      (WidgetTester tester) async {
        const audioFile = StudioFileEntity(
          id: 'file_wav_3',
          name: 'Track_Club.wav',
          relativePath: '/Tomas de Audio & WAV/Track_Club.wav',
          modifiedAtMicros: 0,
          extension: '.wav',
          fileType: StudioFileType.audioWav,
          sizeBytes: 16384,
        );

        StudioFileEntity? receivedFile;
        StudioFileMusicalAction? receivedAction;
        fsService.onFileMusicalAction = (file, action) {
          receivedFile = file;
          receivedAction = action;
        };

        await tester.pumpWidget(buildTileHarness(audioFile));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cargar en Deck B (Consola DJ)'));
        await tester.pumpAndSettle();

        expect(receivedFile?.id, audioFile.id);
        expect(receivedAction, StudioFileMusicalAction.loadInDjDeckB);
        expect(fsService.selectedNodeId, audioFile.id);
      },
    );

    testWidgets(
      'Al hacer clic derecho sobre un archivo score muestra "Abrir en Editor de Partituras" y dispara openInScoreEditor',
      (WidgetTester tester) async {
        const scoreFile = StudioFileEntity(
          id: 'file_score_1',
          name: 'Estudio_Do.musicxml',
          relativePath: '/Partituras & Notación/Estudio_Do.musicxml',
          modifiedAtMicros: 0,
          extension: '.musicxml',
          fileType: StudioFileType.score,
          sizeBytes: 2048,
        );

        StudioFileMusicalAction? receivedAction;
        fsService.onFileMusicalAction = (_, action) {
          receivedAction = action;
        };

        await tester.pumpWidget(buildTileHarness(scoreFile));
        final center = tester.getCenter(find.text('Estudio_Do.musicxml'));
        await tester.tapAt(center, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('Abrir en Editor de Partituras'), findsOneWidget);
        await tester.tap(find.text('Abrir en Editor de Partituras'));
        await tester.pumpAndSettle();

        expect(receivedAction, StudioFileMusicalAction.openInScoreEditor);
      },
    );
  });
}
