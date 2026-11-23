import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/docking/domain/studio_dock_layout_entity.dart';
import 'package:tunner/core/docking/domain/studio_dock_zone.dart';
import 'package:tunner/core/docking/presentation/studio_dockable_panel_entity.dart';
import 'package:tunner/core/docking/presentation/studio_workspace_docking_container.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_repository.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/domain/in_memory_media_vault_repository.dart';
import 'package:tunner/features/media_vault/domain/media_synergy_target.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/universal_instrument_search_modal.dart';

class _SpyFileSystemRepository implements StudioFileSystemRepository {
  final Map<String, Uint8List> savedFiles = <String, Uint8List>{};

  @override
  Future<void> createFolder(String relativePath) async {}

  @override
  Future<void> deletePath(String relativePath) async {
    savedFiles.remove(relativePath);
  }

  @override
  Future<StudioFolderEntity> loadRootWorkspace() async =>
      const StudioFolderEntity(
        id: 'root',
        name: 'Root',
        relativePath: '/',
        modifiedAtMicros: 0,
      );

  @override
  Future<void> movePath({
    required String oldRelativePath,
    required String newRelativePath,
  }) async {
    final data = savedFiles.remove(oldRelativePath);
    if (data != null) {
      savedFiles[newRelativePath] = data;
    }
  }

  @override
  Future<Uint8List> readFile(String relativePath) async =>
      savedFiles[relativePath] ?? Uint8List(0);

  @override
  Future<void> saveFile({
    required String relativePath,
    required Uint8List bytes,
  }) async {
    savedFiles[relativePath] = bytes;
  }

  @override
  Future<bool> openInSystemExplorer(String relativePath) async => false;
}

void main() {
  group('US-11.1 & US-11.3: SignalBus, Docking, Rack y MediaVault', () {
    test('SignalBus.clearRoutes limpia rutas sin cerrar streams y permite reutilizar el bus', () async {
      final bus = SignalBus();
      const sourcePort = PortId(
        id: 'pitch.out',
        displayName: 'Pitch Out',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.output,
        ownerModuleId: 'mod_tuner',
      );
      const destPort = PortId(
        id: 'pitch.in',
        displayName: 'Pitch In',
        signalType: SignalType.pitchEvents,
        direction: PortDirection.input,
        ownerModuleId: 'mod_score',
      );

      final receivedBeforeReset = <double>[];
      final receivedAfterReset = <double>[];

      final sub1 = bus.subscribe<double>(destPort).listen(receivedBeforeReset.add);
      bus.addConnection(
        ModuleConnection.pointToPoint(source: sourcePort, destination: destPort),
      );
      bus.emit(sourcePort, 440.0);
      await Future<void>.delayed(Duration.zero);

      expect(receivedBeforeReset, <double>[440.0]);
      expect(bus.activeConnections.length, 1);

      // Reiniciar rutas sin destruir los StreamControllers
      bus.clearRoutes();
      expect(bus.isDisposed, isFalse);
      expect(bus.activeConnections, isEmpty);

      // Reconectar y volver a emitir tras clearRoutes()
      final sub2 = bus.subscribe<double>(destPort).listen(receivedAfterReset.add);
      bus.addConnection(
        ModuleConnection.pointToPoint(source: sourcePort, destination: destPort),
      );
      bus.emit(sourcePort, 523.25);
      await Future<void>.delayed(Duration.zero);

      expect(receivedAfterReset, <double>[523.25]);

      await sub1.cancel();
      await sub2.cancel();
      bus.dispose();
      expect(bus.isDisposed, isTrue);
    });

    test('ModularRackViewModel.loadPreset sucesivo reutiliza SignalBus sin cerrar streams', () {
      final vm = ModularRackViewModel();
      addTearDown(vm.dispose);

      vm.loadPreset('calentamiento');
      expect(vm.signalBus.isDisposed, isFalse);
      expect(vm.activeModules, isNotEmpty);

      vm.loadPreset('orquesta');
      expect(vm.signalBus.isDisposed, isFalse);
      expect(vm.activeModules, isNotEmpty);
    });

    testWidgets('StudioWorkspaceDockingContainer renderiza paneles en StudioDockZone.floating y permite arrastrarlos', (tester) async {
      final panels = <StudioDockablePanelEntity>[
        StudioDockablePanelEntity(
          id: 'panel_main',
          title: 'Panel Principal',
          icon: Icons.music_note,
          currentZone: StudioDockZone.center,
          builder: (_) => const Center(child: Text('Contenido Principal')),
        ),
        StudioDockablePanelEntity(
          id: 'panel_float',
          title: 'Panel Flotante',
          icon: Icons.open_in_new,
          currentZone: StudioDockZone.floating,
          builder: (_) => const Center(child: Text('Contenido Flotante')),
        ),
      ];

      const initialLayout = StudioDockLayoutEntity(
        zonePanelIds: <StudioDockZone, List<String>>{
          StudioDockZone.center: <String>['panel_main'],
          StudioDockZone.left: <String>[],
          StudioDockZone.right: <String>[],
          StudioDockZone.bottom: <String>[],
          StudioDockZone.floating: <String>['panel_float'],
        },
      );

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 780,
                height: 560,
                child: StudioWorkspaceDockingContainer(
                  panels: panels,
                  initialLayout: initialLayout,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final floatingFinder = find.byKey(const ValueKey('floating_panel_panel_float'));
      expect(floatingFinder, findsOneWidget);
      expect(find.text('Contenido Flotante'), findsOneWidget);

      final beforeRect = tester.getRect(floatingFinder);
      await tester.drag(floatingFinder, const Offset(40, 30));
      await tester.pumpAndSettle();
      final afterRect = tester.getRect(floatingFinder);

      expect(afterRect.left, greaterThan(beforeRect.left));
      expect(afterRect.top, greaterThan(beforeRect.top));
    });

    testWidgets('DefaultTabController cambia cantidad de pestañas en una zona sin crash', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final panels = <StudioDockablePanelEntity>[
        StudioDockablePanelEntity(
          id: 'tab_a',
          title: 'Tab A',
          icon: Icons.looks_one,
          builder: (_) => const Center(child: Text('Body A')),
        ),
        StudioDockablePanelEntity(
          id: 'tab_b',
          title: 'Tab B',
          icon: Icons.looks_two,
          builder: (_) => const Center(child: Text('Body B')),
        ),
        StudioDockablePanelEntity(
          id: 'tab_c',
          title: 'Tab C',
          icon: Icons.looks_3,
          builder: (_) => const Center(child: Text('Body C')),
        ),
      ];

      const initialLayout = StudioDockLayoutEntity(
        zonePanelIds: <StudioDockZone, List<String>>{
          StudioDockZone.center: <String>['tab_a', 'tab_b', 'tab_c'],
          StudioDockZone.left: <String>[],
          StudioDockZone.right: <String>[],
          StudioDockZone.bottom: <String>[],
          StudioDockZone.floating: <String>[],
        },
      );

      StudioDockLayoutEntity? latestLayout;

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(),
          child: MaterialApp(
            home: Scaffold(
              body: StudioWorkspaceDockingContainer(
                panels: panels,
                initialLayout: initialLayout,
                onLayoutChanged: (layout) => latestLayout = layout,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tab_ctrl_center_3')), findsOneWidget);

      // Mover el panel activo fuera de la zona central (de 3 pestañas a 2)
      await tester.tap(find.byTooltip('Mover al Panel Izquierdo').first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('tab_ctrl_center_2')), findsOneWidget);
      expect(latestLayout?.zonePanelIds[StudioDockZone.left], contains('tab_a'));
    });

    testWidgets('UniversalInstrumentSearchModal limpia el TextField al pulsar el boton clear', (tester) async {
      final vm = ModularRackViewModel();
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalInstrumentSearchModal(viewModel: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, 'guitarra');
      await tester.pumpAndSettle();

      final clearButtonFinder = find.byIcon(Icons.clear);
      expect(clearButtonFinder, findsOneWidget);

      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      final textFieldWidget = tester.widget<TextField>(textFieldFinder);
      expect(textFieldWidget.controller?.text, isEmpty);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    test('MediaVaultViewModel.exportTimelineToDisk usa relativePath limpio en StudioFileSystemRepository', () async {
      final fsRepo = _SpyFileSystemRepository();
      final vm = MediaVaultViewModel(
        ioService: const UniversalMediaIoService(),
        fileSystemRepository: fsRepo,
      );
      addTearDown(vm.dispose);

      final house = vm.allAssets.firstWhere((a) => a.id == 'seed_house_groove');
      final trackId = vm.timeline.tracks.first.trackId;
      vm.dropAssetOnTrack(asset: house, trackId: trackId, dropMs: 0);

      final savedRelativePath = await vm.exportTimelineToDisk(
        MediaExportFormat.wavMixdown,
      );

      expect(savedRelativePath, isNotNull);
      expect(savedRelativePath, startsWith('exports/'));
      expect(savedRelativePath!.contains('..'), isFalse);
      expect(fsRepo.savedFiles.containsKey(savedRelativePath), isTrue);
      expect(fsRepo.savedFiles[savedRelativePath]!.length, greaterThan(44));
    });

    test('InMemoryMediaVaultRepository materializa PCM de semillas de forma lazy', () {
      final repo = InMemoryMediaVaultRepository();
      expect(repo.isSeeded, isFalse);

      // Solicitar una semilla individual no fuerza el sembrado global
      final house = repo.findById('seed_house_groove');
      expect(house, isNotNull);
      expect(house!.pcmSamples, isNotNull);
      expect(house.pcmSamples!.isNotEmpty, isTrue);
      expect(repo.isSeeded, isFalse);

      // getAll() materializa el catalogo completo
      final all = repo.getAll();
      expect(repo.isSeeded, isTrue);
      expect(all.length, 4);

      // clear() sobre un repositorio recien creado evita generar PCM innecesariamente
      final freshRepo = InMemoryMediaVaultRepository();
      freshRepo.clear();
      expect(freshRepo.isSeeded, isTrue);
      expect(freshRepo.getAll(), isEmpty);
    });
  });
}
