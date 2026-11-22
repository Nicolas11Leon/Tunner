import 'dart:typed_data';

/// Decodificador determinista de archivos de audio RIFF/WAVE PCM a muestras Float32List normalizadas [-1.0, 1.0].
/// Pure Dart: Cero dependencias de Flutter UI o plugins nativos.
class PcmWavDecoder {
  const PcmWavDecoder();

  /// Decodifica un arreglo de bytes WAV a un búfer monoaural [Float32List] normalizado [-1.0, 1.0].
  /// Soporta codificación de 8 bits sin signo, 16 bits entero con signo y 32 bits IEEE float.
  static Float32List decodeWavToFloat32(Uint8List wavBytes) {
    if (wavBytes.length < 44) return Float32List(0);

    // Validar cabeceras canónicas 'RIFF' y 'WAVE'
    final riffStr = String.fromCharCodes(wavBytes.sublist(0, 4));
    final waveStr = String.fromCharCodes(wavBytes.sublist(8, 12));
    if (riffStr != 'RIFF' || waveStr != 'WAVE') return Float32List(0);

    final view = ByteData.sublistView(wavBytes);
    final channels = view.getUint16(22, Endian.little).clamp(1, 8);
    final bitsPerSample = view.getUint16(34, Endian.little);

    // Localizar sub-chunk 'data'
    int cursor = 12;
    int dataOffset = 44;
    int dataSize = wavBytes.length - 44;

    while (cursor + 8 <= wavBytes.length) {
      final chunkId = String.fromCharCodes(wavBytes.sublist(cursor, cursor + 4));
      final chunkSize = view.getUint32(cursor + 4, Endian.little);
      if (chunkId == 'data') {
        dataOffset = cursor + 8;
        dataSize = chunkSize.clamp(0, wavBytes.length - dataOffset);
        break;
      }
      cursor += 8 + chunkSize + (chunkSize & 1);
    }

    final bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample <= 0) return Float32List(0);
    final totalFrames = dataSize ~/ (bytesPerSample * channels);
    if (totalFrames <= 0) return Float32List(0);

    final pcmView = ByteData.sublistView(wavBytes, dataOffset, dataOffset + dataSize);
    final monoSamples = Float32List(totalFrames);

    if (bitsPerSample == 16) {
      for (int i = 0; i < totalFrames; i++) {
        double sum = 0.0;
        for (int ch = 0; ch < channels; ch++) {
          final s = pcmView.getInt16((i * channels + ch) * 2, Endian.little);
          sum += s / 32768.0;
        }
        monoSamples[i] = sum / channels;
      }
    } else if (bitsPerSample == 8) {
      for (int i = 0; i < totalFrames; i++) {
        double sum = 0.0;
        for (int ch = 0; ch < channels; ch++) {
          final s = pcmView.getUint8(i * channels + ch);
          sum += (s - 128) / 128.0;
        }
        monoSamples[i] = sum / channels;
      }
    } else if (bitsPerSample == 32) {
      for (int i = 0; i < totalFrames; i++) {
        double sum = 0.0;
        for (int ch = 0; ch < channels; ch++) {
          final s = pcmView.getFloat32((i * channels + ch) * 4, Endian.little);
          sum += s;
        }
        monoSamples[i] = sum / channels;
      }
    }

    return monoSamples;
  }
}
