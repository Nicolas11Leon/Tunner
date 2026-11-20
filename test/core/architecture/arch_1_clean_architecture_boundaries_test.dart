import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/app/studio_workspace_seed_provider.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-1 Clean Architecture Boundaries & DIP Verification', () {
    test('Domain layer has zero imports from Flutter UI, dart:io, data, or presentation', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final violations = <String>[];
      final forbiddenPattern = RegExp(
        r"import\s+'(package:flutter/|dart:ui|dart:io|.*(/data/|/presentation/|/application/))",
      );

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        if (!normalized.contains('/domain/')) continue;

        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') && forbiddenPattern.hasMatch(line)) {
            violations.add('$normalized:${i + 1}: $line');
          }
        }
      }

      expect(violations, isEmpty, reason: 'Violaciones encontradas en /domain/: $violations');
    });

    test('Core layer has zero imports from features/', () {
      final coreDir = Directory('lib/core');
      expect(coreDir.existsSync(), isTrue);

      final violations = <String>[];
      for (final entity in coreDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') && line.contains('features/')) {
            violations.add('${entity.path}:${i + 1}: $line');
          }
        }
      }

      expect(violations, isEmpty, reason: 'Inversiones core -> features encontradas: $violations');
    });

    test('Presentation layer has zero direct imports from data/ and TunerViewModel has zero data/infrastructure imports', () {
      final libDir = Directory('lib');
      final violations = <String>[];
      final dataImport = RegExp(r"import\s+'.*/data/");
      final dataOrInfraImport = RegExp(r"import\s+'.*(/data/|/infrastructure/)");

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        final isTunerVm = normalized.endsWith('tuner_viewmodel.dart');
        final isPresentation = normalized.contains('/presentation/') ||
            isTunerVm ||
            normalized.endsWith('tuner_screen.dart');
        if (!isPresentation) continue;

        final pattern = isTunerVm ? dataOrInfraImport : dataImport;
        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') && pattern.hasMatch(line)) {
            violations.add('$normalized:${i + 1}: $line');
          }
        }
      }

      expect(violations, isEmpty, reason: 'Imports directos presentation -> data: $violations');
    });

    test('ViewModels instantiate cleanly with pure domain NoOp fallbacks without platform side effects', () {
      final tvm = TunerViewModel();
      expect(tvm.platformFileGateway, isA<NoOpPlatformFileGateway>());
      tvm.dispose();

      final mv = MediaVaultViewModel();
      mv.dispose();

      const logger = NoOpStudioLogger();
      logger.warning('test', 'ok');
      logger.error('test', 'ok');
    });

    test('StudioCompositionRoot wires full production graph and seed provider cleanly', () async {
      final root = StudioCompositionRoot.create(isolatedServices: true);
      final tvm = root.createTunerViewModel(seedDefaults: false);
      final dj = root.createDjConsoleViewModel();
      final mv = root.createMediaVaultViewModel();

      expect(tvm.platformFileGateway, isNot(isA<NoOpPlatformFileGateway>()));
      expect(dj.fileGateway, isNot(isA<NoOpPlatformFileGateway>()));

      const seeder = StudioWorkspaceSeedProvider();
      final seeds = await seeder.buildSeedBinaryFiles();
      expect(seeds.keys, contains('Tomas de Audio & WAV/Toma_Acustica_440Hz.wav'));
      expect(seeds.keys, contains('Tomas de Audio & WAV/Loop_Club_Groove_124BPM.wav'));

      mv.dispose();
      dj.dispose();
      tvm.dispose();
      root.dispose();
    });
  });
}
