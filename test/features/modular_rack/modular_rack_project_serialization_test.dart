import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/project_format/domain/project_storage_repository.dart';
import 'package:tunner/features/project_format/domain/tunner_project_package.dart';
import 'package:tunner/features/project_format/domain/tunner_tool_preset.dart';
import 'package:tunner/features/project_format/data/tunner_binary_project_codec.dart';

class InMemoryProjectStorageRepository implements ProjectStorageRepository {
  final TunnerBinaryProjectCodec codec = TunnerBinaryProjectCodec();
  final Map<String, Uint8List> storage = {};

  @override
  Uint8List encodeProjectToBytes(TunnerProjectPackage project) => codec.encodeProject(project);

  @override
  TunnerProjectPackage loadProjectFromBytes(Uint8List bytes) => codec.decodeProject(bytes);

  @override
  Uint8List encodeToolPresetToBytes(TunnerToolPreset tool) => codec.encodeToolPreset(tool);

  @override
  TunnerToolPreset loadToolPresetFromBytes(Uint8List bytes) => codec.decodeToolPreset(bytes);

  @override
  Future<void> saveProject(String filePath, TunnerProjectPackage project) async {
    storage[filePath] = encodeProjectToBytes(project);
  }

  @override
  Future<TunnerProjectPackage> loadProject(String filePath) async {
    final bytes = storage[filePath];
    if (bytes == null) throw StateError('File not found: $filePath');
    return loadProjectFromBytes(bytes);
  }

  @override
  Future<void> saveToolPreset(String filePath, TunnerToolPreset tool) async {
    storage[filePath] = encodeToolPresetToBytes(tool);
  }

  @override
  Future<TunnerToolPreset> loadToolPreset(String filePath) async {
    final bytes = storage[filePath];
    if (bytes == null) throw StateError('File not found: $filePath');
    return loadToolPresetFromBytes(bytes);
  }
}

void main() {
  group('ModularRackViewModel Project & Tool Serialization Tests', () {
    late InMemoryProjectStorageRepository storage;
    late ModularRackViewModel viewModel;

    setUp(() {
      storage = InMemoryProjectStorageRepository();
      viewModel = ModularRackViewModel(storageRepository: storage);
    });

    test('renaming a module updates its title and propagates to listeners', () {
      final initialModule = viewModel.activeModules.first;
      expect(initialModule.title, isNot(equals('Mi Afinador Personalizado')));

      viewModel.renameModule(initialModule.moduleId, 'Mi Afinador Personalizado');
      final updatedModule = viewModel.activeModules.first;
      expect(updatedModule.title, equals('Mi Afinador Personalizado'));
    });

    test('exports and imports a single tool preset (.tnt)', () async {
      final initialModule = viewModel.activeModules.first;
      viewModel.renameModule(initialModule.moduleId, 'Super Tuner Pro');

      await viewModel.exportToolPresetToFile(initialModule.moduleId, '/presets/tuner.tnt');
      expect(storage.storage.containsKey('/presets/tuner.tnt'), isTrue);

      final countBefore = viewModel.activeModules.length;
      await viewModel.importToolPresetFromFile('/presets/tuner.tnt');
      expect(viewModel.activeModules.length, equals(countBefore + 1));
      expect(viewModel.activeModules.last.title, equals('Super Tuner Pro'));
    });

    test('saves and loads an entire compressed project (.tunner) with hyper-synced patch connections', () async {
      // Customise names
      viewModel.renameModule(viewModel.activeModules[0].moduleId, 'Afinador Lead Master');
      viewModel.renameModule(viewModel.activeModules[2].moduleId, 'Partitura Transcripcion');

      // Save project
      await viewModel.saveProjectToFile(filePath: '/projects/sesion1.tunner', projectName: 'Sesion Magistral');
      final projectBytes = storage.storage['/projects/sesion1.tunner']!;
      expect(projectBytes.length, greaterThan(20));

      // Re-instantiate a fresh ViewModel
      final restoredVm = ModularRackViewModel(storageRepository: storage);
      await restoredVm.loadProjectFromFile('/projects/sesion1.tunner');

      // Assert module count and custom titles restored
      expect(restoredVm.activeModules.length, equals(viewModel.activeModules.length));
      expect(restoredVm.activeModules[0].title, equals('Afinador Lead Master'));
      expect(restoredVm.activeModules[2].title, equals('Partitura Transcripcion'));

      // Assert patchbay connections restored in SignalBus
      expect(restoredVm.signalBus.activeConnections.length, greaterThanOrEqualTo(2));
    });
  });
}
