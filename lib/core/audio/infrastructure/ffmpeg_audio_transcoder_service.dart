import 'dart:io';
import 'dart:typed_data';

import '../../logging/domain/i_studio_logger.dart';
import '../../logging/infrastructure/studio_stderr_logger.dart';
import '../domain/i_audio_transcoder_port.dart';

/// Servicio de infraestructura que decodifica MP3, FLAC, OGG, M4A, AAC y OPUS
/// a PCM WAV 16-bit de forma 100% local utilizando `ffmpeg` del sistema.
class FfmpegAudioTranscoderService implements IAudioTranscoderPort {
  final String ffmpegExecutable;
  final IStudioLogger _logger;

  const FfmpegAudioTranscoderService({
    this.ffmpegExecutable = 'ffmpeg',
    IStudioLogger logger = StudioStderrLogger.instance,
  }) : _logger = logger;

  @override
  bool isSupportedCompressedExtension(String extension) {
    final clean = extension.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return IAudioTranscoderPort.compressedAudioExtensions.contains(clean);
  }

  @override
  Future<Uint8List?> transcodeToWav16BitPcm(
    Uint8List inputBytes, {
    required String fileExtension,
    int targetSampleRate = 44100,
    int channels = 1,
  }) async {
    if (inputBytes.isEmpty) return null;
    final cleanExt = fileExtension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanExt.isEmpty) return null;

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('tunner_transcode_');
      final inFile = File('${tempDir.path}${Platform.pathSeparator}input.$cleanExt');
      final outFile = File('${tempDir.path}${Platform.pathSeparator}output.wav');
      await inFile.writeAsBytes(inputBytes, flush: true);

      final result = await Process.run(
        ffmpegExecutable,
        <String>[
          '-y',
          '-v',
          'error',
          '-i',
          inFile.path,
          '-vn',
          '-ac',
          channels.clamp(1, 2).toString(),
          '-ar',
          targetSampleRate.clamp(8000, 96000).toString(),
          '-f',
          'wav',
          '-acodec',
          'pcm_s16le',
          outFile.path,
        ],
      );

      if (result.exitCode != 0 || !await outFile.exists()) {
        _logger.warning(
          'FfmpegAudioTranscoderService',
          'ffmpeg fallo decodificando .$cleanExt (exit=${result.exitCode}): ${result.stderr}',
        );
        return null;
      }

      final wavBytes = await outFile.readAsBytes();
      return wavBytes.isEmpty ? null : wavBytes;
    } catch (e, st) {
      _logger.warning(
        'FfmpegAudioTranscoderService',
        'Error ejecutando ffmpeg para .$cleanExt: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    } finally {
      if (tempDir != null) {
        try {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {
          // Ignorar fallo de limpieza temporal
        }
      }
    }
  }
}
