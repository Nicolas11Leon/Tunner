import 'dart:math' as math;
import 'dart:typed_data';

/// Contenedor inmutable de audio WAV decodificado en punto flotante normalizado [-1.0, 1.0].
/// Pure Dart: cero dependencias de Flutter ni plugins nativos.
class DecodedWavAudio {
  /// Muestras monofonicas normalizadas (downmix promediado si channels > 1).
  final Float64List samples;

  /// Muestras separadas por canal (longitud igual a [channels]).
  final List<Float64List> channelSamples;

  /// Frecuencia de muestreo en Hz (ej. 44100, 48000).
  final int sampleRate;

  /// Numero de canales (1 = mono, 2 = estereo, etc.).
  final int channels;

  /// Profundidad de bits por muestra (16, 24 o 32).
  final int bitsPerSample;

  /// Codigo de formato WAV (1 = PCM entero, 3 = IEEE Float).
  final int audioFormat;

  /// Duracion total en segundos calculada como frameCount / sampleRate.
  final double durationSeconds;

  const DecodedWavAudio({
    required this.samples,
    required this.channelSamples,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.audioFormat,
    required this.durationSeconds,
  });

  /// Numero total de cuadros (frames) por canal.
  int get frameCount => samples.length;

  /// Indica si el flujo decodificado es estereo.
  bool get isStereo => channels == 2;

  /// Indica si el formato original era IEEE 32-bit float.
  bool get isFloat => audioFormat == OfflineWavDecoder.formatIeeeFloat;

  /// Serializa los metadatos del audio decodificado (sin incluir el arreglo crudo de muestras).
  Map<String, dynamic> toJson() => {
        'sampleRate': sampleRate,
        'channels': channels,
        'bitsPerSample': bitsPerSample,
        'audioFormat': audioFormat,
        'frameCount': frameCount,
        'durationSeconds': durationSeconds,
      };
}

/// Decodificador canonico compartido de archivos RIFF/WAVE en Pure Dart.
///
/// Soporta:
/// - PCM 16-bit entero con signo little-endian (escala 1 / 2^15 = 1 / 32768.0).
/// - PCM 24-bit entero con signo little-endian (escala 1 / 2^23 = 1 / 8388608.0).
/// - IEEE Float 32-bit little-endian (formato 3).
/// - WAVE_FORMAT_EXTENSIBLE (0xFFFE) delegando al subformato PCM o IEEE Float.
/// - Audio mono, estereo y multicanal con downmix monofonico exacto.
class OfflineWavDecoder {
  static const int formatPcm = 1;
  static const int formatIeeeFloat = 3;
  static const int formatExtensible = 0xFFFE;

  /// Escala de normalizacion para PCM 16-bit con signo: 2^15.
  static const double _pcm16Scale = 32768.0;

  /// Escala de normalizacion para PCM 24-bit con signo: 2^23.
  static const double _pcm24Scale = 8388608.0;

  const OfflineWavDecoder();

  /// Metodo de instancia delegando a [decode] para inyeccion de dependencias.
  DecodedWavAudio decodeBytes(Uint8List wavBytes) => decode(wavBytes);

  /// Decodifica un buffer binario RIFF/WAVE completo en [DecodedWavAudio].
  /// Lanza [FormatException] si la cabecera es invalida o el formato no esta soportado.
  static DecodedWavAudio decode(Uint8List wavBytes) {
    if (wavBytes.length < 44) {
      throw const FormatException(
        'Buffer WAV demasiado corto: se requieren al menos 44 bytes.',
      );
    }

    final riffTag = String.fromCharCodes(wavBytes.sublist(0, 4));
    final waveTag = String.fromCharCodes(wavBytes.sublist(8, 12));
    if (riffTag != 'RIFF' || waveTag != 'WAVE') {
      throw FormatException(
        'Cabecera RIFF/WAVE invalida: "$riffTag" / "$waveTag".',
      );
    }

    final view = ByteData.sublistView(wavBytes);

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    int cursor = 12;
    while (cursor + 8 <= wavBytes.length) {
      final chunkId = String.fromCharCodes(wavBytes.sublist(cursor, cursor + 4));
      final chunkSize = view.getUint32(cursor + 4, Endian.little);
      final chunkDataStart = cursor + 8;

      if (chunkDataStart > wavBytes.length) break;
      final availableBytes = wavBytes.length - chunkDataStart;
      final safeChunkSize = math.min(chunkSize, availableBytes);

      if (chunkId == 'fmt ') {
        if (safeChunkSize < 16) {
          throw const FormatException('Chunk "fmt " truncado (< 16 bytes).');
        }
        int parsedFormat = view.getUint16(chunkDataStart, Endian.little);
        channels = view.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = view.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = view.getUint16(chunkDataStart + 14, Endian.little);

        if (parsedFormat == formatExtensible && safeChunkSize >= 40) {
          // SubFormat GUID: los primeros 2 bytes indican el codigo de formato canonico
          parsedFormat = view.getUint16(chunkDataStart + 24, Endian.little);
        }
        audioFormat = parsedFormat;
      } else if (chunkId == 'data') {
        dataOffset = chunkDataStart;
        dataSize = safeChunkSize;
        if (audioFormat != null) break;
      }

      // Los chunks RIFF se alinean a fronteras pares de 2 bytes
      final paddedSize = chunkSize + (chunkSize & 1);
      final nextCursor = chunkDataStart + paddedSize;
      if (nextCursor <= cursor) break;
      cursor = nextCursor;
    }

    if (audioFormat == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null) {
      throw const FormatException('Chunk "fmt " ausente en archivo WAV.');
    }

    if (dataOffset == null || dataSize == null) {
      throw const FormatException('Chunk "data" ausente en archivo WAV.');
    }

    if (channels <= 0) {
      throw FormatException('Numero de canales invalido: $channels.');
    }

    if (sampleRate <= 0) {
      throw FormatException('Frecuencia de muestreo invalida: $sampleRate.');
    }

    final bool isPcm16 = audioFormat == formatPcm && bitsPerSample == 16;
    final bool isPcm24 = audioFormat == formatPcm && bitsPerSample == 24;
    final bool isFloat32 = audioFormat == formatIeeeFloat && bitsPerSample == 32;

    if (!isPcm16 && !isPcm24 && !isFloat32) {
      throw FormatException(
        'Formato WAV no soportado: audioFormat=$audioFormat, bitsPerSample=$bitsPerSample. '
        'Soportados: PCM 16-bit, PCM 24-bit e IEEE Float 32-bit.',
      );
    }

    final int bytesPerSample = bitsPerSample ~/ 8;
    final int frameStride = bytesPerSample * channels;
    final int frameCount = frameStride > 0 ? dataSize ~/ frameStride : 0;

    final channelBuffers = List<Float64List>.generate(
      channels,
      (_) => Float64List(frameCount),
      growable: false,
    );
    final monoSamples = Float64List(frameCount);

    final double invChannels = 1.0 / channels;

    for (int frame = 0; frame < frameCount; frame++) {
      final int frameByteOffset = dataOffset + frame * frameStride;
      double monoSum = 0.0;

      for (int ch = 0; ch < channels; ch++) {
        final int sampleByteOffset = frameByteOffset + ch * bytesPerSample;
        final double sample;

        if (isPcm16) {
          final raw = view.getInt16(sampleByteOffset, Endian.little);
          sample = raw / _pcm16Scale;
        } else if (isPcm24) {
          final b0 = wavBytes[sampleByteOffset];
          final b1 = wavBytes[sampleByteOffset + 1];
          final b2 = wavBytes[sampleByteOffset + 2];
          int signed24 = b0 | (b1 << 8) | (b2 << 16);
          if ((signed24 & 0x800000) != 0) {
            signed24 |= ~0xFFFFFF;
          }
          sample = signed24 / _pcm24Scale;
        } else {
          final rawFloat = view.getFloat32(sampleByteOffset, Endian.little);
          sample = rawFloat.isFinite ? rawFloat.clamp(-1.0, 1.0) : 0.0;
        }

        channelBuffers[ch][frame] = sample;
        monoSum += sample;
      }

      monoSamples[frame] = channels == 1 ? monoSum : monoSum * invChannels;
    }

    final double durationSeconds = frameCount / sampleRate;

    return DecodedWavAudio(
      samples: monoSamples,
      channelSamples: channelBuffers,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      audioFormat: audioFormat,
      durationSeconds: durationSeconds,
    );
  }
}
