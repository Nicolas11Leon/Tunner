import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/file_system/domain/i_studio_workspace_file_system.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/presentation/studio_vscode_explorer_widget.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/song_library/presentation/studio_assets_modals.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/domain/parsed_score_result_entity.dart';

class _FakeFolderEntity implements StudioFolderEntity {
  @override
  List<StudioFileSystemNode> get children => const [];

  @override
  int get totalFilesCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWorkspaceFileSystem extends ChangeNotifier
    implements IStudioWorkspaceFileSystem {
  final _root = _FakeFolderEntity();

  @override
  String get searchQuery => '';

  @override
  StudioFolderEntity get filteredRootFolder => _root;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioTrack implements AudioTrack {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSongPackage implements SongPackage {
  @override
  final String title;

  @override
  final List<AudioTrack> tracks;

  _FakeSongPackage({
    required this.title,
    required this.tracks,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeParsedScoreResult implements ParsedScoreResult {
  @override
  final SongPackage package;

  @override
  final int totalMeasures;

  _FakeParsedScoreResult({
    required this.package,
    required this.totalMeasures,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTunerViewModel extends ChangeNotifier implements TunerViewModel {
  ParsedScoreResult? nextImportResult;
  Object? nextImportError;

  @override
  String? lastImportError;

  @override
  Future<ParsedScoreResult?> importScoreFromFilePicker() async {
    if (nextImportError != null) {
      throw nextImportError!;
    }
    return nextImportResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('US-FS-05 Explorer Import Button & Import Telemetry UI', () {
    testWidgets(
      'StudioVsCodeExplorerWidget renderiza btn_import_external_file y ejecuta onImportExternalFile al tocarlo',
      (tester) async {
        final fs = _FakeWorkspaceFileSystem();
        var importTappedCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 480,
                child: StudioVsCodeExplorerWidget(
                  service: fs,
                  onImportExternalFile: () => importTappedCount++,
                ),
              ),
            ),
          ),
        );

        final importButton = find.byKey(const Key('btn_import_external_file'));
        expect(importButton, findsOneWidget);

        await tester.tap(importButton);
        await tester.pump();

        expect(importTappedCount, 1);
      },
    );

    testWidgets(
      'StudioAssetsModals.showImportScoreDialog muestra SnackBar con titulo, compases y pistas al completar importacion',
      (tester) async {
        final fakeViewModel = _FakeTunerViewModel()
          ..nextImportResult = _FakeParsedScoreResult(
            package: _FakeSongPackage(
              title: 'Sonata en Do',
              tracks: [_FakeAudioTrack(), _FakeAudioTrack()],
            ),
            totalMeasures: 16,
          );

        SongPackage? importedPackage;
        int? navigatedTab;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        StudioAssetsModals.showImportScoreDialog(
                          context: context,
                          viewModel: fakeViewModel,
                          onNavigateToTab: (tab) => navigatedTab = tab,
                          onScoreImported: (pkg) => importedPackage = pkg,
                        );
                      },
                      child: const Text('Importar'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Importar'));
        await tester.pumpAndSettle();

        expect(importedPackage?.title, 'Sonata en Do');
        expect(navigatedTab, 4);
        expect(
          find.text('Importado: "Sonata en Do" (16 compases, 2 pistas).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'StudioAssetsModals.showImportScoreDialog muestra SnackBar informativo cuando falla la importacion',
      (tester) async {
        final fakeViewModel = _FakeTunerViewModel()
          ..nextImportResult = null
          ..lastImportError = 'Formato de archivo corrupto';

        SongPackage? importedPackage;
        int? navigatedTab;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        StudioAssetsModals.showImportScoreDialog(
                          context: context,
                          viewModel: fakeViewModel,
                          onNavigateToTab: (tab) => navigatedTab = tab,
                          onScoreImported: (pkg) => importedPackage = pkg,
                        );
                      },
                      child: const Text('Importar'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Importar'));
        await tester.pumpAndSettle();

        expect(importedPackage, isNull);
        expect(navigatedTab, isNull);
        expect(
          find.text(
            'No se pudo importar o decodificar el archivo: Formato de archivo corrupto',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
