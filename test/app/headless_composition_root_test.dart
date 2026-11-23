import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/headless_composition_root.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/file_system/data/posix_file_gateway.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/core/logging/infrastructure/studio_stderr_logger.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';

void main() {
  group('PosixFileGateway', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_posix_gw_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves documents/temp directories and saves exported bytes safely', () async {
      final gateway = PosixFileGateway(rootDirectory: tempDir);

      expect(await gateway.pickFile(), isNull);
      expect(await gateway.getDocumentsDirectoryPath(), equals(tempDir.path));

      final tmpPath = await gateway.getTemporaryDirectoryPath();
      expect(Directory(tmpPath).existsSync(), isTrue);

      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final savedPath = await gateway.saveExportedBytes('../evil/export test.mid', payload);
      final savedFile = File(savedPath);

      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.parent.path, equals(tempDir.path));
      expect(await savedFile.readAsBytes(), equals(payload));
    });
  });

  group('HeadlessCompositionRoot', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_headless_root_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('wires all pure Dart services, executes TunnerOsKernel commands, and disposes cleanly', () async {
      final root = HeadlessCompositionRoot(
        workspaceDirectory: tempDir,
        logger: const NoOpStudioLogger(),
      );

      expect(root.platformFileGateway, isA<PosixFileGateway>());
      expect(root.audioMatrixService, isA<StudioAudioDeviceMatrixService>());
      expect((root.audioMatrixService as StudioAudioDeviceMatrixService).isHeadless, isTrue);
      expect(root.kernelBridge.matrixService, same(root.audioMatrixService));
      expect(root.kernelBridge.clockService, same(root.masterClockService));
      expect(root.scoreEditorController, isNotNull);
      expect(root.scoreImporterService, isNotNull);
      expect(root.projectStorageRepository, isNotNull);
      expect(root.songDecomposerService, isNotNull);
      expect(root.djBlueprintStorageService, isNotNull);
      expect(root.djKeymapPersistenceService, isNotNull);
      expect(root.scoreTerminalAdapter, isNotNull);
      expect(root.earTrainingTerminalAdapter, isNotNull);
      expect(root.vocalPedagogyTerminalAdapter, isNotNull);

      // 1. Verificar comandos de diagnostico DSP y reloj
      final dspRes = await root.terminalKernel.execute('dsp');
      expect(dspRes.isSuccess, isTrue);
      expect(dspRes.message, contains('EN LINEA (FULL-DUPLEX)'));

      final clockRes = await root.terminalKernel.execute('clock bpm 132');
      expect(clockRes.isSuccess, isTrue);
      expect(root.masterClockService.bpm, closeTo(132.0, 0.01));

      // 2. Verificar puente DSL -> matriz y reloj mediante interfaces DIP
      final dslRes = await root.terminalKernel.execute('dsl tempo 128; set @eq.low = 3.0 dB;');
      expect(dslRes.isSuccess, isTrue);
      expect(root.masterClockService.bpm, closeTo(128.0, 0.01));
      expect(root.audioMatrixService.matrix.eqLowDb, closeTo(3.0, 0.01));

      // 3. Verificar adaptador de entrenamiento auditivo y sistema de archivos
      final trainRes = await root.terminalKernel.execute('train status');
      expect(trainRes.isSuccess, isTrue);
      expect(trainRes.message, contains('EBBINGHAUS'));

      final fsRes = await root.terminalKernel.execute('fs ls');
      expect(fsRes.isSuccess, isTrue);

      // 4. Verificar persistencia atomica en workspaceDirectory
      const customSettings = AppUserSettingsEntity(referencePitch: 442.0);
      await root.persistenceService.saveSettings(customSettings);
      final loaded = await root.persistenceService.loadSettings();
      expect(loaded.referencePitch, closeTo(442.0, 0.01));

      // 5. Liberacion determinista e idempotente
      root.dispose();
      root.dispose();
      expect(root.isDisposed, isTrue);
    });

    test('uses StudioStderrLogger by default', () {
      final root = HeadlessCompositionRoot(workspaceDirectory: tempDir);
      expect(root.logger, isA<StudioStderrLogger>());
      root.dispose();
    });
  });
}
