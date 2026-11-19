import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_engine.dart';
import 'package:tunner/core/channels/data/studio_patchbay_routing_service.dart';
import 'package:tunner/core/design_system/data/studio_theme_catalog_service.dart';
import 'package:tunner/core/design_system/domain/studio_theme_skin_entity.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';

class _FakePlatformFileGateway implements IPlatformFileGateway {
  final PlatformPickedFile? fileToReturn;

  const _FakePlatformFileGateway({
    this.fileToReturn,
  });

  @override
  Future<String> getDocumentsDirectoryPath() async => '/tmp/tunner_test_docs';

  @override
  Future<String> getTemporaryDirectoryPath() async => '/tmp/tunner_test_temp';

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async {
    return fileToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioCompositionRoot & Isolated Services Tests (Ola 3)', () {
    test('StudioCompositionRoot wires shared audioMatrixService and IPlatformFileGateway into TunerViewModel', () {
      const fakeGateway = _FakePlatformFileGateway();
      final root = StudioCompositionRoot.create(platformFileGateway: fakeGateway);
      final vm = root.createTunerViewModel(seedDefaults: false);

      expect(vm.audioDeviceMatrixService, same(root.audioMatrixService));

      vm.dispose();
      root.dispose();
    });

    test('Isolated constructors prevent state leakage between instances', () {
      final patchA = StudioPatchbayRoutingService.isolated();
      final patchB = StudioPatchbayRoutingService.isolated();
      patchA.createCustomChannel(name: 'Solo A');
      expect(patchA.channels.any((c) => c.name == 'Solo A'), isTrue);
      expect(patchB.channels.any((c) => c.name == 'Solo A'), isFalse);

      final themeA = StudioThemeCatalogService.isolated();
      final themeB = StudioThemeCatalogService.isolated();
      final neveId = StudioThemeSkinEntity.neve88rs.id;
      themeA.selectSkin(neveId);
      expect(themeA.activeSkin.id, equals(neveId));
      expect(themeB.activeSkin.id, isNot(equals(neveId)));

      final fsA = StudioWorkspaceFileSystemService.isolated();
      final fsB = StudioWorkspaceFileSystemService.isolated();
      fsA.setSearchQuery('test_isolation');
      expect(fsB.searchQuery, isEmpty);

      final engA = StudioAudioEngine.isolated();
      final engB = StudioAudioEngine.isolated();
      expect(identical(engA, engB), isFalse);

      patchA.dispose();
      patchB.dispose();
      fsA.dispose();
      fsB.dispose();
      engA.dispose();
      engB.dispose();
    });

    test('TunerViewModel delegates importScoreFromFilePicker to injected IPlatformFileGateway', () async {
      const sampleXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list><score-part id="P1"><part-name>Flute</part-name></score-part></part-list>
  <part id="P1"><measure number="1"><note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure></part>
</score-partwise>''';

      final fakeGateway = _FakePlatformFileGateway(
        fileToReturn: PlatformPickedFile(
          name: 'isolated_score.musicxml',
          bytes: Uint8List.fromList(sampleXml.codeUnits),
        ),
      );
      final root = StudioCompositionRoot.create(platformFileGateway: fakeGateway);
      final vm = root.createTunerViewModel(seedDefaults: false);

      final parsed = await vm.importScoreFromFilePicker();
      expect(parsed, isNotNull);

      vm.dispose();
      root.dispose();
    });
  });
}
