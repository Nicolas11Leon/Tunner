import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  group('Studio Dynamic Assets and Empty State Tests', () {
    testWidgets('empty folder displays emptyActions and header action button', (tester) async {
      bool actionNewClicked = false;
      bool actionImportClicked = false;
      bool headerActionClicked = false;

      final emptyFolder = StudioTreeFolder(
        id: 'folder_scores',
        title: 'Partituras & Notación (0)',
        headerAction: IconButton(
          key: const Key('header_add_btn'),
          icon: const Icon(Icons.add, size: 14),
          onPressed: () => headerActionClicked = true,
        ),
        items: const [],
        emptyActions: [
          StudioTreeItem(
            id: 'act_new',
            title: '[+] Nueva Partitura en Blanco...',
            icon: Icons.note_add_outlined,
            onSelect: () => actionNewClicked = true,
          ),
          StudioTreeItem(
            id: 'act_imp',
            title: '[⬇] Importar MusicXML / Catálogo...',
            icon: Icons.file_download_outlined,
            onSelect: () => actionImportClicked = true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioTreeView(
              selectedItemId: '',
              sections: [
                StudioTreeSection(
                  title: 'Assets',
                  folders: [emptyFolder],
                ),
              ],
            ),
          ),
        ),
      );

      // Verifica presencia del folder y su header action
      expect(find.text('Partituras & Notación (0)'), findsOneWidget);
      expect(find.byKey(const Key('header_add_btn')), findsOneWidget);

      // Verifica que al estar vacía renderiza las dos acciones dinámicas
      expect(find.text('[+] Nueva Partitura en Blanco...'), findsOneWidget);
      expect(find.text('[⬇] Importar MusicXML / Catálogo...'), findsOneWidget);

      // Clic en Crear
      await tester.tap(find.text('[+] Nueva Partitura en Blanco...'));
      await tester.pumpAndSettle();
      expect(actionNewClicked, isTrue);

      // Clic en Importar
      await tester.tap(find.text('[⬇] Importar MusicXML / Catálogo...'));
      await tester.pumpAndSettle();
      expect(actionImportClicked, isTrue);

      // Clic en botón + de la cabecera
      await tester.tap(find.byKey(const Key('header_add_btn')));
      await tester.pumpAndSettle();
      expect(headerActionClicked, isTrue);
    });

    testWidgets('folder with items renders its items and hides emptyActions', (tester) async {
      final populatedFolder = StudioTreeFolder(
        id: 'folder_scores',
        title: 'Partituras (1)',
        items: [
          StudioTreeItem(
            id: 'doc_1',
            title: 'Mi Preludio en Sol',
            icon: Icons.article_outlined,
            timestamp: '120 BPM',
            onSelect: () {},
          ),
        ],
        emptyActions: [
          StudioTreeItem(
            id: 'act_new',
            title: '[+] Nueva Partitura...',
            icon: Icons.note_add_outlined,
            onSelect: () {},
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioTreeView(
              selectedItemId: 'doc_1',
              sections: [
                StudioTreeSection(
                  title: 'Assets',
                  folders: [populatedFolder],
                ),
              ],
            ),
          ),
        ),
      );

      // El ítem real se muestra
      expect(find.text('Mi Preludio en Sol'), findsOneWidget);
      expect(find.text('120 BPM'), findsOneWidget);

      // Las acciones de carpeta vacía quedan ocultas porque ya contiene ítems
      expect(find.text('[+] Nueva Partitura...'), findsNothing);
    });
  });
}
