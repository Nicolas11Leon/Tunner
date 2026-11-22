import 'dart:math' as math;
import 'dart:typed_data';

/// Motor DSP en Pure Dart para modificacion tonal mediante TD-PSOLA
/// (Time-Domain Pitch Synchronous Overlap-Add) con preservacion espectral
/// de formantes por liftering cepstral y soporte de rango 27.5..4186.0 Hz.
class TdPsolaPitchShifter {
  /// Limite inferior del rango musical canonicamente soportado: A0 = 27.5 Hz.
  static const double minSupportedPitchHz = 27.5;

  /// Limite superior del rango musical canonicamente soportado: C8 = 4186.0 Hz.
  static const double maxSupportedPitchHz = 4186.0;

  const TdPsolaPitchShifter();

  /// Desplaza la afinacion del buffer de audio [inputSamples] segun [pitchShiftRatio]
  /// a la frecuencia fundamental [detectedPitchHz].
  ///
  /// Cuando [preserveFormants] es `true`, preserva los granos sin re-escalar
  /// temporalmente y aplica transferencia de envolvente espectral cepstral
  /// sobre ventanas STFT para conservar la estructura de formantes del tracto vocal.
  /// Cuando [preserveFormants] es `false`, aplica re-muestreo directo de cada
  /// grano mediante interpolacion lineal en dominio temporal.
  Float64List shiftPitch({
    required Float64List inputSamples,
    required double pitchShiftRatio,
    required double detectedPitchHz,
    required int sampleRate,
    bool preserveFormants = true,
    double leadVocalMix = 1.0,
  }) {
    final int len = inputSamples.length;
    if (len == 0) return Float64List(0);
    if (len < 48) return Float64List.fromList(inputSamples);

    // Bypass transparente si no hay tono vocal o el cambio es imperceptible
    if (detectedPitchHz <= 20.0 || (pitchShiftRatio - 1.0).abs() < 0.005) {
      if ((leadVocalMix - 1.0).abs() < 0.001) {
        return Float64List.fromList(inputSamples);
      }
    }

    final double effectivePitch =
        detectedPitchHz.clamp(minSupportedPitchHz, maxSupportedPitchHz);
    final double rawP0 = sampleRate / effectivePitch;
    final int maxPeriod = math.max(4, len ~/ 3);
    final int p0 = rawP0.round().clamp(4, maxPeriod);

    // Periodo de sintesis modificado por el ratio de afinacion
    final double clampedRatio = pitchShiftRatio.clamp(0.5, 2.0);
    final double rawPs = rawP0 / clampedRatio;
    final int ps = rawPs.round().clamp(3, math.max(3, len ~/ 2));

    // Si los periodos son invalidos, devolver copia
    if (p0 <= 0 || ps <= 0 || len < p0 * 2) {
      return Float64List.fromList(inputSamples);
    }

    // Identificacion de marcas de analisis glotico sincronicas (t_a)
    final List<int> analysisMarks = _findAnalysisMarks(inputSamples, len, p0);
    if (analysisMarks.isEmpty) {
      return Float64List.fromList(inputSamples);
    }

    final Float64List output = Float64List(len);
    final Float64List normWeights = Float64List(len);

    if (preserveFormants) {
      _synthesizeFormantPreservedGrains(
        inputSamples: inputSamples,
        analysisMarks: analysisMarks,
        len: len,
        p0: p0,
        rawPs: rawPs,
        output: output,
        normWeights: normWeights,
      );
    } else {
      _synthesizeResampledGrains(
        inputSamples: inputSamples,
        analysisMarks: analysisMarks,
        len: len,
        p0: p0,
        ps: ps,
        rawPs: rawPs,
        clampedRatio: clampedRatio,
        output: output,
        normWeights: normWeights,
      );
    }

    // Normalizacion de energia y reconstruccion de senal sintetizada
    final Float64List synthBuffer = Float64List(len);
    for (int i = 0; i < len; i++) {
      final double weightAlpha = normWeights[i].clamp(0.0, 1.0);
      final double normalizedSynth = normWeights[i] > 1e-4
          ? (output[i] / normWeights[i])
          : inputSamples[i];
      synthBuffer[i] =
          normalizedSynth * weightAlpha + inputSamples[i] * (1.0 - weightAlpha);
    }

    // Transferencia de envolvente espectral cepstral cuando preserveFormants == true
    // y el periodo glotico permite separar armonicos del tracto vocal (p0 >= 20).
    final Float64List formantAdjusted = (preserveFormants && len >= 128 && p0 >= 20)
        ? _preserveSpectralEnvelope(
            inputSamples: inputSamples,
            synthSamples: synthBuffer,
            sampleRate: sampleRate,
            p0: p0,
          )
        : synthBuffer;

    // Mezcla Dry/Wet final con proteccion de rango [-1.0, 1.0]
    final double wet = leadVocalMix.clamp(0.0, 1.0);
    final double dry = 1.0 - wet;

    final Float64List finalBuffer = Float64List(len);
    for (int i = 0; i < len; i++) {
      final double mixed = (inputSamples[i] * dry) + (formantAdjusted[i] * wet);
      finalBuffer[i] = mixed.clamp(-1.0, 1.0);
    }

    return finalBuffer;
  }

  List<int> _findAnalysisMarks(Float64List inputSamples, int len, int p0) {
    final List<int> marks = [];
    final int searchRadius = (p0 * 0.25).round().clamp(1, 40);
    for (int t = p0; t < len - p0; t += p0) {
      int bestT = t;
      double maxAmp = -1.0;
      final int startSearch = (t - searchRadius).clamp(0, len - 1);
      final int endSearch = (t + searchRadius).clamp(0, len - 1);
      for (int k = startSearch; k <= endSearch; k++) {
        final double amp = inputSamples[k].abs();
        if (amp > maxAmp) {
          maxAmp = amp;
          bestT = k;
        }
      }
      marks.add(bestT);
    }
    return marks;
  }

  int _findNearestMark(List<int> analysisMarks, double targetPos) {
    int nearestAnalysis = analysisMarks.first;
    double minDiff = (targetPos - nearestAnalysis).abs();
    for (int i = 1; i < analysisMarks.length; i++) {
      final double diff = (targetPos - analysisMarks[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearestAnalysis = analysisMarks[i];
      } else {
        break;
      }
    }
    return nearestAnalysis;
  }

  Float64List _buildHannWindow(int size) {
    final Float64List window = Float64List(size);
    for (int i = 0; i < size; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / size));
    }
    return window;
  }

  /// Sintesis TD-PSOLA conservando la escala temporal 1:1 de cada grano para
  /// mantener intacta la respuesta impulsiva del tracto vocal.
  void _synthesizeFormantPreservedGrains({
    required Float64List inputSamples,
    required List<int> analysisMarks,
    required int len,
    required int p0,
    required double rawPs,
    required Float64List output,
    required Float64List normWeights,
  }) {
    final int halfWin =
        math.max(p0, (rawPs * 0.55).ceil()).clamp(p0, math.max(p0, len ~/ 2));
    final Float64List window = _buildHannWindow(halfWin * 2);

    double synthMarkFrac = p0.toDouble();
    while (synthMarkFrac < (len - p0).toDouble()) {
      final int synthMark = synthMarkFrac.round();
      final int nearestAnalysis = _findNearestMark(analysisMarks, synthMark.toDouble());

      for (int i = -halfWin; i < halfWin; i++) {
        final int inIdx = nearestAnalysis + i;
        final int outIdx = synthMark + i;
        if (inIdx >= 0 && inIdx < len && outIdx >= 0 && outIdx < len) {
          final double w = window[i + halfWin];
          output[outIdx] += inputSamples[inIdx] * w;
          normWeights[outIdx] += w;
        }
      }
      synthMarkFrac += rawPs;
    }
  }

  /// Re-muestreo directo en dominio temporal sobre cada grano usando interpolacion
  /// lineal al factor [clampedRatio], desplazando conjuntamente tono y formantes.
  void _synthesizeResampledGrains({
    required Float64List inputSamples,
    required List<int> analysisMarks,
    required int len,
    required int p0,
    required int ps,
    required double rawPs,
    required double clampedRatio,
    required Float64List output,
    required Float64List normWeights,
  }) {
    final int synthHalfWin = ps;
    final Float64List window = _buildHannWindow(synthHalfWin * 2);

    double synthMarkFrac = p0.toDouble();
    while (synthMarkFrac < (len - p0).toDouble()) {
      final int synthMark = synthMarkFrac.round();
      final int nearestAnalysis = _findNearestMark(analysisMarks, synthMark.toDouble());

      for (int i = -synthHalfWin; i < synthHalfWin; i++) {
        final int outIdx = synthMark + i;
        if (outIdx < 0 || outIdx >= len) continue;

        final double srcPos = nearestAnalysis + (i * clampedRatio);
        if (srcPos >= 0.0 && srcPos < len - 1) {
          final int idx0 = srcPos.floor();
          final double frac = srcPos - idx0;
          final double interpolated =
              inputSamples[idx0] * (1.0 - frac) + inputSamples[idx0 + 1] * frac;
          final double w = window[i + synthHalfWin];
          output[outIdx] += interpolated * w;
          normWeights[outIdx] += w;
        }
      }
      synthMarkFrac += rawPs;
    }
  }

  /// Transfiere la envolvente espectral suave (liftering cepstral de baja quefrency)
  /// de [inputSamples] hacia [synthSamples] en bloques STFT con ventana de Hann,
  /// preservando los formantes vocales y la energia RMS de cada marco.
  Float64List _preserveSpectralEnvelope({
    required Float64List inputSamples,
    required Float64List synthSamples,
    required int sampleRate,
    required int p0,
  }) {
    final int len = inputSamples.length;
    final int frameSize = len >= 1024 ? 1024 : (len >= 512 ? 512 : 256);
    final int hop = frameSize ~/ 4;
    final Float64List hann = _buildHannWindow(frameSize);

    // Cutoff de quefrency estrictamente inferior al periodo fundamental P0
    // y acotado a ~2.8 ms para aislar formantes de la estructura armonica.
    final int qCutoff = math
        .min((p0 * 0.65).floor(), (0.0028 * sampleRate).round())
        .clamp(8, frameSize ~/ 4);
    final int taperStart = (qCutoff * 0.75).floor();

    final Float64List shapedOut = Float64List(len);
    final Float64List stftNorm = Float64List(len);

    final Float64List origReal = Float64List(frameSize);
    final Float64List origImag = Float64List(frameSize);
    final Float64List synthReal = Float64List(frameSize);
    final Float64List synthImag = Float64List(frameSize);
    final Float64List envOrigReal = Float64List(frameSize);
    final Float64List envOrigImag = Float64List(frameSize);
    final Float64List envSynthReal = Float64List(frameSize);
    final Float64List envSynthImag = Float64List(frameSize);

    for (int offset = -(frameSize - hop); offset < len; offset += hop) {
      double synthFrameEnergy = 0.0;
      double origFrameEnergy = 0.0;

      for (int n = 0; n < frameSize; n++) {
        final int idx = offset + n;
        final double w = hann[n];
        final double xOrig = (idx >= 0 && idx < len) ? inputSamples[idx] * w : 0.0;
        final double xSynth = (idx >= 0 && idx < len) ? synthSamples[idx] * w : 0.0;
        origReal[n] = xOrig;
        origImag[n] = 0.0;
        synthReal[n] = xSynth;
        synthImag[n] = 0.0;
        origFrameEnergy += xOrig * xOrig;
        synthFrameEnergy += xSynth * xSynth;
      }

      if (synthFrameEnergy < 1e-10 || origFrameEnergy < 1e-10) {
        for (int n = 0; n < frameSize; n++) {
          final int idx = offset + n;
          if (idx >= 0 && idx < len) {
            final double w = hann[n];
            shapedOut[idx] += synthReal[n] * w;
            stftNorm[idx] += w * w;
          }
        }
        continue;
      }

      _fft(origReal, origImag, inverse: false);
      _fft(synthReal, synthImag, inverse: false);

      // Espectros log-magnitud para calculo de cepstrum real
      for (int k = 0; k < frameSize; k++) {
        final double magOrigSq =
            origReal[k] * origReal[k] + origImag[k] * origImag[k];
        final double magSynthSq =
            synthReal[k] * synthReal[k] + synthImag[k] * synthImag[k];
        envOrigReal[k] = 0.5 * math.log(magOrigSq + 1e-12);
        envOrigImag[k] = 0.0;
        envSynthReal[k] = 0.5 * math.log(magSynthSq + 1e-12);
        envSynthImag[k] = 0.0;
      }

      _fft(envOrigReal, envOrigImag, inverse: true);
      _fft(envSynthReal, envSynthImag, inverse: true);

      // Liftering simetrico de baja quefrency con caida coseno suave
      for (int q = 0; q < frameSize; q++) {
        final int dist = q <= frameSize ~/ 2 ? q : frameSize - q;
        double lifter = 1.0;
        if (dist > qCutoff) {
          lifter = 0.0;
        } else if (dist > taperStart) {
          final double span = math.max(1, qCutoff - taperStart).toDouble();
          lifter = 0.5 * (1.0 + math.cos(math.pi * (dist - taperStart) / span));
        }
        envOrigReal[q] *= lifter;
        envOrigImag[q] *= lifter;
        envSynthReal[q] *= lifter;
        envSynthImag[q] *= lifter;
      }

      _fft(envOrigReal, envOrigImag, inverse: false);
      _fft(envSynthReal, envSynthImag, inverse: false);

      // Aplicar ganancia diferencial de envolvente acotada a +/-12 dB ([0.25, 4.0])
      for (int k = 0; k < frameSize; k++) {
        final double deltaLog =
            (envOrigReal[k] - envSynthReal[k]).clamp(-1.386294, 1.386294);
        final double gain = math.exp(deltaLog);
        synthReal[k] *= gain;
        synthImag[k] *= gain;
      }

      _fft(synthReal, synthImag, inverse: true);

      // Igualar energia RMS del marco modificado respecto al marco PSOLA
      double shapedEnergy = 0.0;
      for (int n = 0; n < frameSize; n++) {
        shapedEnergy += synthReal[n] * synthReal[n];
      }
      final double rmsScale = shapedEnergy > 1e-12
          ? math.sqrt(synthFrameEnergy / shapedEnergy).clamp(0.25, 4.0)
          : 1.0;

      for (int n = 0; n < frameSize; n++) {
        final int idx = offset + n;
        if (idx >= 0 && idx < len) {
          final double w = hann[n];
          shapedOut[idx] += synthReal[n] * rmsScale * w;
          stftNorm[idx] += w * w;
        }
      }
    }

    final Float64List result = Float64List(len);
    for (int i = 0; i < len; i++) {
      result[i] = stftNorm[i] > 1e-6 ? (shapedOut[i] / stftNorm[i]) : synthSamples[i];
    }
    return result;
  }

  /// FFT Cooley-Tukey Radix-2 in-place sobre arreglos de longitud potencia de 2.
  void _fft(Float64List real, Float64List imag, {required bool inverse}) {
    final int n = real.length;
    if (n <= 1) return;

    // Reordenamiento bit-reversal
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final double tr = real[i];
        final double ti = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tr;
        imag[j] = ti;
      }
    }

    final double sign = inverse ? 1.0 : -1.0;
    for (int stageLen = 2; stageLen <= n; stageLen <<= 1) {
      final int halfLen = stageLen >> 1;
      final double angleStep = sign * 2.0 * math.pi / stageLen;
      final double wLenR = math.cos(angleStep);
      final double wLenI = math.sin(angleStep);

      for (int start = 0; start < n; start += stageLen) {
        double wR = 1.0;
        double wI = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final int evenIdx = start + k;
          final int oddIdx = evenIdx + halfLen;
          final double tR = real[oddIdx] * wR - imag[oddIdx] * wI;
          final double tI = real[oddIdx] * wI + imag[oddIdx] * wR;
          real[oddIdx] = real[evenIdx] - tR;
          imag[oddIdx] = imag[evenIdx] - tI;
          real[evenIdx] += tR;
          imag[evenIdx] += tI;

          final double nextWR = wR * wLenR - wI * wLenI;
          wI = wR * wLenI + wI * wLenR;
          wR = nextWR;
        }
      }
    }

    if (inverse) {
      final double invN = 1.0 / n;
      for (int i = 0; i < n; i++) {
        real[i] *= invN;
        imag[i] *= invN;
      }
    }
  }
}
