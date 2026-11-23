import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/terminal_feature_adapters.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/packaging/infrastructure/tunner_package_codec_service.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  group('TunnerOsKernel Project Commands (/project) Tests', () {
    late TunerViewModel viewModel;
    late TunnerOsKernel kernel;
    late StudioAudioDeviceMatrixService matrixService;
    late PolyphonicVoicePool voicePool;

    setUp(() {
      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: MemoryAudioHardwarePersistenceService(),
        captureService: MemoryStudioMasterCaptureService(),
      );
      voicePool = PolyphonicVoicePool();
      viewModel = TunerViewModel(
        audioDeviceMatrixService: matrixService,
        polyphonicVoicePool: voicePool,
        packageCodec: const TunnerPackageCodecService(),
      );
      kernel = TunnerOsKernel(
        matrixService: matrixService,
        synthVoicePool: voicePool,
        projectPort: TunerProjectTerminalAdapter(viewModel),
      );
    });

    test('project info returns formatted project telemetry and canonical format status', () async {
      final res = await kernel.execute('project info');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('PROYECTO ACTIVO EN TUNNER STUDIO:'));
      expect(res.message, contains('Titulo:'));
      expect(res.message, contains('BPM'));
      expect(res.message, contains('Matriz de Hardware: Conectada'));
      expect(res.message, contains('Sintetizador Polifonico:'));
      expect(res.message, contains('.tunner v1.0.0 (DEFLATE ZIP con SHA-256)'));
    });

    test('project export generates lossless .tunner package and returns file stats', () async {
      final res = await kernel.execute('project export "Sinfonia Heroica"');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[OK] Proyecto exportado exitosamente a formato canonico .tunner:'));
      expect(res.message, contains('Titulo: Sinfonia Heroica'));
      expect(res.message, contains('Peso del archivo:'));
      expect(res.message, contains('Hashes SHA-256 generados y sellados en manifest.json'));
    });

    test('project with invalid subcommand outputs help and valid options', () async {
      final res = await kernel.execute('project invalid_cmd');
      expect(res.isSuccess, isFalse);
      expect(res.message, contains("Subcomando project desconocido: 'invalid_cmd'"));
      expect(res.message, contains('Opciones validas: info, export'));
    });

    test('project export without viewModel reports descriptive error', () async {
      final headlessKernel = TunnerOsKernel();
      final res = await headlessKernel.execute('project export');
      expect(res.isSuccess, isFalse);
      expect(res.message, contains('No se puede exportar: Puerto de proyecto no enlazado al kernel.'));
    });
  });
}
