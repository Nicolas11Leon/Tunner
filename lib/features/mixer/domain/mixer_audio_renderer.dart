import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/audio/domain/offline_wav_decoder.dart';
import 'mixer_track_entity.dart';

/// Resultado inmutable de un renderizado multipista del mezclador.
class MixerRenderResult {
  /// Buffer WAV estereo PCM 16-bit listo para escritura en disco o transporte.
  final Uint8List wavBytes;

  /// Muestras estereo intercaladas [L0, R0, L1, R1, ...] en rango [-1.0, 1.0].
  final Float32List interleavedStereo;

  /// Frecuencia de muestreo de salida en Hz.
  final int sampleRate;

  /// Numero total de cuadros estereo (frames).
  final int frameCount;

  /// Duracion total en milisegundos.
  final int durationMs;

  /// Amplitud pico lineal observada en el bus maestro [0.0, 1.0].
  final double peakAmplitude;

  /// Nivel pico en dBFS (acotado a -120.0 dBFS en silencio absoluto).
  final double peakDbfs;

  const MixerRenderResult({
    required this.wavBytes,
    required this.interleavedStereo,
    required this.sampleRate,
    required this.frameCount,
    required this.durationMs,
    required this.peakAmplitude,
    required this.peakDbfs,
  });

  Map<String, dynamic> toJson() => {
        'bytesWritten': wavBytes.length,
        'sampleRate': sampleRate,
        'frameCount': frameCount,
        'durationMs': durationMs,
        'peakAmplitude': peakAmplitude,
        'peakDbfs': peakDbfs,
      };
}

/// Motor Pure Dart de mezcla multipista estereo con ley de paneo de potencia constante.
///
/// Aplica por cada pista:
/// - Ganancia efectiva segun volumen, estado `isMuted` y estado `isSolo` global.
/// - Ley de potencia constante para paneo `pan` en `[-1.0, +1.0]`:
///   `theta = ((pan + 1.0) / 2.0) * (pi / 2.0)`
///   `gainLeft = cos(theta)`, `gainRight = sin(theta)`
///   garantizando `gainLeft^2 + gainRight^2 == 1.0`.
/// - Limitador maestro de rodilla suave (soft-knee) a partir de 0.90 FS para preservar
///   linealidad exacta bajo niveles nominales y evitar recorte digital duro a 0 dBFS.
class MixerAudioRenderer {
  /// Umbral lineal a partir del cual se activa la saturacion suave (aprox. -0.92 dBFS).
  static const double _softKneeThreshold = 0.90;

  /// Rango de headroom disponible sobre el umbral de rodilla suave (1.0 - 0.90).
  static const double _softKneeHeadroom = 0.10;

  const MixerAudioRenderer();

  /// Calcula el par de ganancias (izquierda, derecha) bajo ley de potencia constante
  /// para un valor [pan] en `[-1.0, +1.0]`.
  static ({double left, double right}) computeConstantPowerPanGains(double pan) {
    final double clampedPan = pan.isFinite ? pan.clamp(-1.0, 1.0) : 0.0;
    final double theta = ((clampedPan + 1.0) * 0.5) * (math.pi * 0.5);
    return (left: math.cos(theta), right: math.sin(theta));
  }

  /// Mezcla pistas monofonicas PCM (`trackId -> Float64List`) usando la configuracion
  /// de [console] y devuelve el resultado completo con WAV estereo PCM 16-bit.
  MixerRenderResult render({
    required MixerConsoleEntity console,
    required Map<String, Float64List> trackSamples,
    int sampleRate = 44100,
    double masterGain = 1.0,
  }) {
    final int safeSampleRate = sampleRate > 0 ? sampleRate : 44100;
    final double safeMasterGain =
        masterGain.isFinite ? masterGain.clamp(0.0, 2.0) : 1.0;

    final List<AudioTrack> allTracks = [console.metronomeTrack, ...console.stems];
    final bool hasAnySolo = console.hasAnySolo;

    int maxFrames = 0;
    for (final track in allTracks) {
      final buf = trackSamples[track.id];
      if (buf != null && buf.length > maxFrames) {
        maxFrames = buf.length;
      }
    }

    final Float64List accumLeft = Float64List(maxFrames);
    final Float64List accumRight = Float64List(maxFrames);

    for (final track in allTracks) {
      final buf = trackSamples[track.id];
      if (buf == null || buf.isEmpty) continue;

      final double effectiveGain = track.getEffectiveGain(hasAnySolo: hasAnySolo);
      if (effectiveGain <= 0.0) continue;

      final panGains = computeConstantPowerPanGains(track.pan);
      final double gainL = effectiveGain * panGains.left * safeMasterGain;
      final double gainR = effectiveGain * panGains.right * safeMasterGain;

      final int len = buf.length;
      for (int i = 0; i < len; i++) {
        final double s = buf[i];
        accumLeft[i] += s * gainL;
        accumRight[i] += s * gainR;
      }
    }

    final Float32List interleaved = Float32List(maxFrames * 2);
    double peak = 0.0;

    for (int i = 0; i < maxFrames; i++) {
      final double l = _softLimit(accumLeft[i]);
      final double r = _softLimit(accumRight[i]);
      interleaved[i * 2] = l;
      interleaved[i * 2 + 1] = r;

      final double absL = l.abs();
      final double absR = r.abs();
      if (absL > peak) peak = absL;
      if (absR > peak) peak = absR;
    }

    final Uint8List wavBytes = encodeStereoPcm16Wav(
      interleavedStereo: interleaved,
      sampleRate: safeSampleRate,
    );

    final int durationMs =
        maxFrames == 0 ? 0 : ((maxFrames / safeSampleRate) * 1000.0).round();
    final double peakDbfs =
        peak > 1e-6 ? 20.0 * (math.log(peak) / math.ln10) : -120.0;

    return MixerRenderResult(
      wavBytes: wavBytes,
      interleavedStereo: interleaved,
      sampleRate: safeSampleRate,
      frameCount: maxFrames,
      durationMs: durationMs,
      peakAmplitude: peak,
      peakDbfs: peakDbfs,
    );
  }

  /// Convenience wrapper que retorna directamente los bytes WAV estereo PCM 16-bit.
  Uint8List renderToWav({
    required MixerConsoleEntity console,
    required Map<String, Float64List> trackSamples,
    int sampleRate = 44100,
    double masterGain = 1.0,
  }) {
    return render(
      console: console,
      trackSamples: trackSamples,
      sampleRate: sampleRate,
      masterGain: masterGain,
    ).wavBytes;
  }

  /// Decodifica pistas WAV individuales mediante [OfflineWavDecoder] y renderiza
  /// la mezcla estereo PCM 16-bit aplicando el estado de [console].
  MixerRenderResult renderWavTracks({
    required MixerConsoleEntity console,
    required Map<String, Uint8List> trackWavBytes,
    int sampleRate = 44100,
    double masterGain = 1.0,
  }) {
    final int targetRate = sampleRate > 0 ? sampleRate : 44100;
    final decodedMap = <String, Float64List>{};

    for (final entry in trackWavBytes.entries) {
      final decoded = OfflineWavDecoder.decode(entry.value);
      if (decoded.sampleRate == targetRate) {
        decodedMap[entry.key] = decoded.samples;
      } else {
        decodedMap[entry.key] = _resampleLinear(
          decoded.samples,
          decoded.sampleRate,
          targetRate,
        );
      }
    }

    return render(
      console: console,
      trackSamples: decodedMap,
      sampleRate: targetRate,
      masterGain: masterGain,
    );
  }

  /// Codifica muestras estereo intercaladas [-1.0, 1.0] en formato RIFF/WAVE PCM 16-bit.
  static Uint8List encodeStereoPcm16Wav({
    required Float32List interleavedStereo,
    int sampleRate = 44100,
  }) {
    const int numChannels = 2;
    const int bitsPerSample = 16;
    const int bytesPerSample = bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bytesPerSample;
    final int byteRate = sampleRate * blockAlign;
    final int dataSize = interleavedStereo.length * bytesPerSample;
    final int fileSize = 36 + dataSize;

    final byteData = ByteData(44 + dataSize);

    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, dataSize, Endian.little);

    int offset = 44;
    for (int i = 0; i < interleavedStereo.length; i++) {
      final double clamped = interleavedStereo[i].clamp(-1.0, 1.0);
      final int pcm = clamped < 0.0
          ? (clamped * 32768.0).round().clamp(-32768, 32767)
          : (clamped * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(offset, pcm, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  static double _softLimit(double sample) {
    if (!sample.isFinite) return 0.0;
    final double absVal = sample.abs();
    if (absVal <= _softKneeThreshold) return sample;

    final double excess = (absVal - _softKneeThreshold) / _softKneeHeadroom;
    // tanh(x) = (e^(2x) - 1) / (e^(2x) + 1)
    final double exp2x = math.exp((2.0 * excess).clamp(-40.0, 40.0));
    final double tanhVal = (exp2x - 1.0) / (exp2x + 1.0);
    final double limited = _softKneeThreshold + _softKneeHeadroom * tanhVal;
    return sample.isNegative ? -limited : limited;
  }

  static Float64List _resampleLinear(
    Float64List input,
    int sourceRate,
    int targetRate,
  ) {
    if (input.isEmpty || sourceRate <= 0 || targetRate <= 0) {
      return Float64List(0);
    }
    final double ratio = sourceRate / targetRate;
    final int outLen = math.max(1, (input.length / ratio).round());
    final output = Float64List(outLen);
    for (int i = 0; i < outLen; i++) {
      final double srcPos = i * ratio;
      final int idx0 = srcPos.floor();
      if (idx0 >= input.length) break;
      final int idx1 = math.min(idx0 + 1, input.length - 1);
      final double frac = srcPos - idx0;
      output[i] = input[idx0] + (input[idx1] - input[idx0]) * frac;
    }
    return output;
  }
}
