import 'dart:typed_data';

import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';

/// Shared no-op [IPitchDetectorService] fake for widget and unit tests.
class StudioFakePitchDetectorService extends IPitchDetectorService {
  bool started = false;
  bool stopped = false;

  @override
  Future<void> startRecording() async {
    started = true;
  }

  @override
  Future<void> stopRecording() async {
    stopped = true;
  }
}

/// Shared [IPlatformFileGateway] fake for deterministic offline tests.
class StudioFakePlatformFileGateway implements IPlatformFileGateway {
  final PlatformPickedFile? fileToReturn;
  final String docsPath;
  final String tempPath;

  const StudioFakePlatformFileGateway({
    this.fileToReturn,
    this.docsPath = '/tmp/tunner_test_docs',
    this.tempPath = '/tmp/tunner_test_temp',
  });

  @override
  Future<String> getDocumentsDirectoryPath() async => docsPath;

  @override
  Future<String> getTemporaryDirectoryPath() async => tempPath;

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async =>
      fileToReturn;

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async =>
      '$tempPath/$fileName';
}
