import 'dart:typed_data';

/// Puerto abstracto de dominio (100% Pure Dart) para transcodificación offline
/// de formatos de audio comprimido (MP3, FLAC, OGG, M4A, AAC, OPUS) a PCM WAV 16-bit.
abstract class IAudioTranscoderPort {
  /// Extensiones de audio comprimido soportadas para decodificación a PCM WAV.
  static const Set<String> compressedAudioExtensions = <String>{
    'mp3',
    'flac',
    'ogg',
    'm4a',
    'aac',
    'opus',
    'wma',
    'aiff',
    'aif',
    'webm',
  };

  /// Indica si la extensión (con o sin punto) corresponde a audio comprimido soportado.
  bool isSupportedCompressedExtension(String extension) {
    final clean = extension.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return compressedAudioExtensions.contains(clean);
  }

  /// Convierte los bytes de entrada de audio comprimido a un buffer WAV PCM 16-bit
  /// con la frecuencia de muestreo y canales indicados, o `null` si no es posible.
  Future<Uint8List?> transcodeToWav16BitPcm(
    Uint8List inputBytes, {
    required String fileExtension,
    int targetSampleRate = 44100,
    int channels = 1,
  });
}

/// Implementación neutra de pruebas / entornos sin decodificador nativo.
class NoOpAudioTranscoderPort implements IAudioTranscoderPort {
  const NoOpAudioTranscoderPort();

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
  }) async =>
      null;
}
