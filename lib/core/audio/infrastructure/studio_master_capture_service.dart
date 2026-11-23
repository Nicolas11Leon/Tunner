import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../logging/infrastructure/studio_debug_logger.dart';
import '../domain/i_studio_master_capture_service.dart';

/// Implementación en infraestructura de [IStudioMasterCaptureService]
/// que realiza codificación en tiempo real a formato WAV PCM estándar (16-bit little-endian).
class StudioMasterCaptureService implements IStudioMasterCaptureService {
  String? _currentFilePath;
  RandomAccessFile? _randomAccessFile;

  int _sampleRate = 44100;
  int _channels = 2;
  int _totalAudioBytes = 0;
  bool _isCapturing = false;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _durationTicker;
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();

  @override
  bool get isCapturing => _isCapturing;

  @override
  Duration get elapsedDuration => _stopwatch.elapsed;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Future<void> startCapture({
    required String destinationPath,
    int sampleRate = 44100,
    int channels = 2,
  }) async {
    if (_isCapturing) {
      await stopCapture();
    }

    _sampleRate = sampleRate;
    _channels = channels;
    _currentFilePath = destinationPath;
    _totalAudioBytes = 0;

    final file = File(destinationPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    _randomAccessFile = await file.open(mode: FileMode.write);

    // Escribir cabecera WAV provisional de 44 bytes con tamaño 0
    final dummyHeader = _buildWavHeader(dataSizeBytes: 0, sampleRate: _sampleRate, channels: _channels);
    await _randomAccessFile!.writeFrom(dummyHeader);

    _isCapturing = true;
    _stopwatch.reset();
    _stopwatch.start();

    _durationTicker?.cancel();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_durationController.isClosed && _isCapturing) {
        _durationController.add(_stopwatch.elapsed);
      }
    });
  }

  @override
  void appendStereoSamples(List<double> left, List<double> right) {
    if (!_isCapturing || _randomAccessFile == null) return;

    final length = left.length < right.length ? left.length : right.length;
    if (length == 0) return;

    // Codificación PCM signed 16-bit little-endian: 2 bytes por muestra, 4 bytes por frame estéreo
    final byteData = ByteData(length * 4);
    int byteOffset = 0;

    for (int i = 0; i < length; i++) {
      final sL = (left[i].clamp(-1.0, 1.0) * 32767.0).round();
      final sR = (right[i].clamp(-1.0, 1.0) * 32767.0).round();

      byteData.setInt16(byteOffset, sL, Endian.little);
      byteOffset += 2;
      byteData.setInt16(byteOffset, sR, Endian.little);
      byteOffset += 2;
    }

    final bytes = byteData.buffer.asUint8List();
    _totalAudioBytes += bytes.length;
    _randomAccessFile?.writeFromSync(bytes);
  }

  @override
  Future<String?> stopCapture() async {
    if (!_isCapturing) return _currentFilePath;

    _isCapturing = false;
    _stopwatch.stop();
    _durationTicker?.cancel();

    try {
      if (_randomAccessFile != null) {
        // Regresar al inicio del archivo y sobreescribir la cabecera WAV con el tamaño exacto
        await _randomAccessFile!.setPosition(0);
        final finalHeader = _buildWavHeader(
          dataSizeBytes: _totalAudioBytes,
          sampleRate: _sampleRate,
          channels: _channels,
        );
        await _randomAccessFile!.writeFrom(finalHeader);
        await _randomAccessFile!.flush();
        await _randomAccessFile!.close();
        _randomAccessFile = null;
      }
    } catch (e, st) {
      StudioDebugLogger.instance.error(
        'StudioMasterCaptureService',
        'Error al finalizar el archivo WAV maestro',
        error: e,
        stackTrace: st,
      );
    }

    final path = _currentFilePath;
    _currentFilePath = null;
    return path;
  }

  /// Construye una cabecera canónica RIFF WAV estándar de 44 bytes.
  Uint8List _buildWavHeader({
    required int dataSizeBytes,
    required int sampleRate,
    required int channels,
  }) {
    final header = ByteData(44);
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final totalChunkSize = 36 + dataSizeBytes;

    // 0..3: "RIFF"
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'

    // 4..7: ChunkSize
    header.setUint32(4, totalChunkSize, Endian.little);

    // 8..11: "WAVE"
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // 12..15: "fmt "
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '

    // 16..19: Subchunk1Size (16 para PCM)
    header.setUint32(16, 16, Endian.little);

    // 20..21: AudioFormat (1 = PCM lineal sin compresión)
    header.setUint16(20, 1, Endian.little);

    // 22..23: NumChannels
    header.setUint16(22, channels, Endian.little);

    // 24..27: SampleRate
    header.setUint32(24, sampleRate, Endian.little);

    // 28..31: ByteRate
    header.setUint32(28, byteRate, Endian.little);

    // 32..33: BlockAlign
    header.setUint16(32, blockAlign, Endian.little);

    // 34..35: BitsPerSample (16 bits)
    header.setUint16(34, 16, Endian.little);

    // 36..39: "data"
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'

    // 40..43: Subchunk2Size (tamaño de los datos PCM en bytes)
    header.setUint32(40, dataSizeBytes, Endian.little);

    return header.buffer.asUint8List();
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _durationController.close();
    if (_randomAccessFile != null) {
      try {
        _randomAccessFile?.closeSync();
      } catch (e, st) {
        StudioDebugLogger.instance.warning(
          'StudioMasterCaptureService',
          'Failed to close RandomAccessFile during dispose',
          error: e,
          stackTrace: st,
        );
      }
      _randomAccessFile = null;
    }
  }
}
