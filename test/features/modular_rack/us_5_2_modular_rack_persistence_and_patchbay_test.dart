import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/modular_rack/domain/synergy_policy_engine.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_studio_rack_view.dart';
import 'package:tunner/features/modular_rack/presentation/multitask_master_console_widget.dart';
import 'package:tunner/features/modular_rack/presentation/studio_patchbay_modal.dart';
import 'package:tunner/features/project_format/data/local_project_storage_repository.dart';

class _FakePlatformFileGateway implements IPlatformFileGateway {
  final String docsPath;
  PlatformPickedFile? nextPickedFile;

  _FakePlatformFileGateway(this.docsPath);

  @override
  Future<String> getDocumentsDirectoryPath() async => docsPath;

  @override
  Future<String> getTemporaryDirectoryPath() async => docsPath;

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async =>
      nextPickedFile;

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async =>
      '$docsPath/$fileName';
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_us_5_2_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('US-5.2: pickAndLoadProject y pickAndImportToolPreset usan almacenamiento local real', () async {
    final gateway = _FakePlatformFileGateway(tempDir.path);
    final storage = LocalProjectStorageRepository();
    final vm = ModularRackViewModel(
      storageRepository: storage,
      fileGateway: gateway,
    );

    final initialCount = vm.activeModules.length;
    final firstId = vm.activeModules.first.moduleId;
    final tntPath = '${tempDir.path}/tuner_tool.tnt';
    await vm.exportToolPresetToFile(firstId, tntPath);

    final projectPath = await vm.saveProjectToFile(projectName: 'EnsayoReal');
    expect(projectPath, '${tempDir.path}/ensayoreal.tunner');
    expect(await File(projectPath).exists(), isTrue);

    vm.addModule(RackModuleType.vocalAutoTune);
    expect(vm.activeModules.length, initialCount + 1);

    gateway.nextPickedFile = PlatformPickedFile(name: 'ensayoreal.tunner', path: projectPath);
    final loadedName = await vm.pickAndLoadProject();
    expect(loadedName, 'ensayoreal.tunner');
    expect(vm.activeModules.length, initialCount);

    gateway.nextPickedFile = PlatformPickedFile(name: 'tuner_tool.tnt', path: tntPath);
    final importedName = await vm.pickAndImportToolPreset();
    expect(importedName, 'tuner_tool.tnt');
    expect(vm.activeModules.length, initialCount + 1);

    vm.dispose();
  });

  testWidgets('US-5.2: MultitaskMasterConsoleWidget expone Cargar (.tunner) e Importar (.tnt)', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final gateway = _FakePlatformFileGateway(tempDir.path);
    final storage = LocalProjectStorageRepository();
    final vm = ModularRackViewModel(
      storageRepository: storage,
      fileGateway: gateway,
    );
    final tntPath = '${tempDir.path}/preset_widget.tnt';
    await tester.runAsync(() => vm.exportToolPresetToFile(vm.activeModules.first.moduleId, tntPath));
    gateway.nextPickedFile = PlatformPickedFile(name: 'preset_widget.tnt', path: tntPath);
    final initialCount = vm.activeModules.length;

    await tester.pumpWidget(
      StudioThemeScope(
        controller: StudioThemeController(),
        child: MaterialApp(
          home: Scaffold(
            body: MultitaskMasterConsoleWidget(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.folder_open));
    await tester.pumpAndSettle();

    expect(find.text('Cargar Proyecto (.tunner)'), findsOneWidget);
    expect(find.text('Importar Herramienta Preset (.tnt)'), findsOneWidget);

    await tester.tap(find.text('Importar Herramienta Preset (.tnt)'));
    await tester.pumpAndSettle();

    expect(find.text('EXPLORAR ARCHIVO'), findsOneWidget);
    await tester.runAsync(() async {
      await vm.pickAndImportToolPreset();
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(vm.activeModules.length, initialCount + 1);
    vm.dispose();
  });

  testWidgets('US-5.2: StudioPatchbayModal resalta focusPort y evalua SynergyPolicyEngine', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final vm = ModularRackViewModel();
    for (final c in List.of(vm.signalBus.activeConnections)) {
      vm.disconnect(c.connectionId);
    }
    final tuner = vm.activeModules.firstWhere((m) => m.moduleType == RackModuleType.strobeTuner);
    final focusOut = tuner.outputPorts.first;

    final rejected = SynergyPolicyEngine.validateConnection(
      sourcePort: const PortId(
        id: 'tuned_out',
        displayName: 'Voz Corregida DSP',
        signalType: SignalType.audioPcm,
        direction: PortDirection.output,
        ownerModuleId: 'autotune_1',
      ),
      destinationPort: const PortId(
        id: 'audio_in',
        displayName: 'Entrada Oido',
        signalType: SignalType.audioPcm,
        direction: PortDirection.input,
        ownerModuleId: 'ear_trainer_1',
      ),
    );
    expect(rejected.isApproved, isFalse);
    expect(rejected.rejectionReason, isNotNull);

    await tester.pumpWidget(
      StudioThemeScope(
        controller: StudioThemeController(),
        child: MaterialApp(
          home: Scaffold(
            body: StudioPatchbayModal(viewModel: vm, focusPort: focusOut),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('FOCO ACTIVO: ${focusOut.displayName}'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);

    vm.dispose();
  });

  testWidgets('US-5.2: ModularStudioRackView resuelve StudioCompositionRoot sin NoOpProjectStorageRepository', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late StudioCompositionRoot root;
    await tester.runAsync(() async {
      root = StudioCompositionRoot.create();
    });

    await tester.pumpWidget(
      Provider<StudioCompositionRoot>.value(
        value: root,
        child: StudioThemeScope(
          controller: StudioThemeController(),
          child: const MaterialApp(
            home: Scaffold(
              body: ModularStudioRackView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final context = tester.element(find.byType(MultitaskMasterConsoleWidget));
    final resolvedVm = Provider.of<ModularRackViewModel>(context, listen: false);
    final savedPath = await tester.runAsync(
      () => resolvedVm.saveProjectToFile(
        filePath: '${tempDir.path}/di_check.tunner',
        projectName: 'DICheck',
      ),
    );
    expect(await tester.runAsync(() => File(savedPath!).exists()), isTrue);

    root.dispose();
  });
}
