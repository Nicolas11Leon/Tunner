import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/audio/domain/offline_wav_decoder.dart';
import 'multitrack_session_entity.dart';

/// Informe detallado generado por [OfflinePracticeTakeAnalyzer] a partir de un WAV en disco.
class OfflineTakeAnalysisReport {
  final PracticeTakeEntity take;
  final int sampleRate;
  final int channels;
  final int durationMs;
  final double rms;
  final double peak;

  const OfflineTakeAnalysisReport({
    required this.take,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required this.rms,
    required this.peak,
  });

  Map<String, dynamic> toJson() => {
        'takeId': take.id,
        'takeName': take.name,
        'filePath': take.filePath,
        'sampleRate': sampleRate,
        'channels': channels,
        'durationMs': durationMs,
        'rms': rms,
        'peak': peak,
        'averagePitchDeviationCents': take.averagePitchDeviationCents,
        'averageSpectralCentroidHz': take.averageSpectralCentroidHz,
        'pitchSamplesCount': take.pitchTrack.length,
        'spectralSamplesCount': take.spectralTrack.length,
      };
}

/// Analizador Pure Dart offline que decodifica bytes WAV mediante [OfflineWavDecoder]
/// y construye un [PracticeTakeEntity] con metricas acusticas reales (duracion, RMS,
/// pico, forma de onda, contorno de tono NSDF/MPM y centroide espectral FFT)
/// sin requerir microfono ni dependencias de Flutter.
class OfflinePracticeTakeAnalyzer {
  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Ventana de analisis NSDF de 2048 muestras (~46.4 ms a 44.1 kHz, permite resolver hasta ~50 Hz).
  final int windowSize;

  /// Paso temporal entre cuadros de analisis en milisegundos (default 50 ms = 20 Hz).
  final int timeStepMs;

  /// Frecuencia de referencia para A4 en Hz (default 440.0 Hz).
  final double a4ReferenceHz;

  /// Umbral RMS minimo por debajo del cual una ventana se considera silenciosa.
  final double silenceThresholdRms;

  /// Frecuencia minima analizable en Hz (cubre bajo vocal/instrumentos graves).
  final double minFrequencyHz;

  /// Frecuencia maxima analizable en Hz (cubre soprano e instrumentos agudos).
  final double maxFrequencyHz;

  /// Numero de cubetas para el perfil de forma de onda (`waveformPeaks`).
  final int waveformBuckets;

  const OfflinePracticeTakeAnalyzer({
    this.windowSize = 2048,
    this.timeStepMs = 50,
    this.a4ReferenceHz = 440.0,
    this.silenceThresholdRms = 0.005,
    this.minFrequencyHz = 50.0,
    this.maxFrequencyHz = 2000.0,
    this.waveformBuckets = 64,
  });

  /// Decodifica [wavBytes] y retorna el [PracticeTakeEntity] listo para sesiones multipista
  /// y comparacion espectral en [SpectralComparatorService].
  PracticeTakeEntity analyzeWavBytes(
    Uint8List wavBytes, {
    required String takeId,
    required String takeName,
    String filePath = '',
    DateTime? timestamp,
  }) {
    return analyzeWavBytesDetailed(
      wavBytes,
      takeId: takeId,
      takeName: takeName,
      filePath: filePath,
      timestamp: timestamp,
    ).take;
  }

  /// Decodifica [wavBytes] y retorna el informe detallado con RMS global, pico y entidad de toma.
  OfflineTakeAnalysisReport analyzeWavBytesDetailed(
    Uint8List wavBytes, {
    required String takeId,
    required String takeName,
    String filePath = '',
    DateTime? timestamp,
  }) {
    final decoded = OfflineWavDecoder.decode(wavBytes);
    final samples = decoded.samples;
    final int sampleRate = decoded.sampleRate;
    final int durationMs = (decoded.durationSeconds * 1000.0).round();

    // 1. Metricas globales: RMS y pico
    double sumSquares = 0.0;
    double peak = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double s = samples[i];
      sumSquares += s * s;
      final double absS = s.abs();
      if (absS > peak) peak = absS;
    }
    final double globalRms =
        samples.isNotEmpty ? math.sqrt(sumSquares / samples.length) : 0.0;

    // 2. Forma de onda submuestreada
    final List<double> peaks = _computeWaveformPeaks(samples, waveformBuckets);

    // 3. Analisis por ventana deslizante (contorno de pitch + centroide espectral)
    final pitchTrack = <TimedPitchSample>[];
    final spectralTrack = <TimedSpectralSample>[];

    if (samples.isNotEmpty) {
      final int effectiveWindow = math.min(windowSize, samples.length);
      final int hopSamples =
          math.max(1, ((sampleRate * timeStepMs) / 1000.0).round());

      for (int start = 0; start + effectiveWindow <= samples.length; start += hopSamples) {
        final int timeMs = ((start / sampleRate) * 1000.0).round();
        final double winRms = _computeWindowRms(samples, start, effectiveWindow);

        if (winRms < silenceThresholdRms) {
          pitchTrack.add(
            TimedPitchSample(
              timeMs: timeMs,
              frequencyHz: 0.0,
              centsDeviation: 0.0,
              targetNoteName: '--',
              isSilent: true,
            ),
          );
          spectralTrack.add(
            TimedSpectralSample(
              timeMs: timeMs,
              spectralCentroidHz: 0.0,
              thdPercent: 0.0,
              rmsEnergy: winRms,
            ),
          );
          continue;
        }

        final double? detectedHz = _estimatePitchNsdf(
          samples,
          start,
          effectiveWindow,
          sampleRate,
        );

        if (detectedHz != null && detectedHz >= minFrequencyHz && detectedHz <= maxFrequencyHz) {
          final double midiFloat =
              69.0 + 12.0 * (math.log(detectedHz / a4ReferenceHz) / math.ln2);
          final int nearestMidi = midiFloat.round();
          final double cents = (midiFloat - nearestMidi) * 100.0;
          pitchTrack.add(
            TimedPitchSample(
              timeMs: timeMs,
              frequencyHz: detectedHz,
              centsDeviation: cents,
              targetNoteName: _midiToNoteName(nearestMidi),
              isSilent: false,
            ),
          );
        } else {
          pitchTrack.add(
            TimedPitchSample(
              timeMs: timeMs,
              frequencyHz: 0.0,
              centsDeviation: 0.0,
              targetNoteName: '--',
              isSilent: true,
            ),
          );
        }

        final double centroidHz = _computeSpectralCentroidHz(
          samples,
          start,
          effectiveWindow,
          sampleRate,
        );

        spectralTrack.add(
          TimedSpectralSample(
            timeMs: timeMs,
            spectralCentroidHz: centroidHz,
            thdPercent: 0.0,
            rmsEnergy: winRms,
          ),
        );
      }
    }

    final take = PracticeTakeEntity(
      id: takeId,
      name: takeName,
      timestamp: timestamp ?? DateTime.now().toUtc(),
      duration: Duration(milliseconds: durationMs),
      filePath: filePath,
      waveformPeaks: peaks,
      pitchTrack: pitchTrack,
      spectralTrack: spectralTrack,
    );

    return OfflineTakeAnalysisReport(
      take: take,
      sampleRate: sampleRate,
      channels: decoded.channels,
      durationMs: durationMs,
      rms: globalRms,
      peak: peak,
    );
  }

  double _computeWindowRms(Float64List samples, int start, int length) {
    double sumSq = 0.0;
    final int end = start + length;
    for (int i = start; i < end; i++) {
      final double v = samples[i];
      sumSq += v * v;
    }
    return math.sqrt(sumSq / length);
  }

  /// Estimacion de frecuencia fundamental mediante Normalized Square Difference Function (NSDF).
  double? _estimatePitchNsdf(
    Float64List samples,
    int start,
    int length,
    int sampleRate,
  ) {
    final int minLag = math.max(2, (sampleRate / maxFrequencyHz).floor());
    final int maxLag = math.min(length ~/ 2, (sampleRate / minFrequencyHz).ceil());
    if (maxLag <= minLag) return null;

    final nsdf = Float64List(maxLag + 1);
    for (int tau = minLag; tau <= maxLag; tau++) {
      double acf = 0.0;
      double norm = 0.0;
      final int limit = length - tau;
      for (int i = 0; i < limit; i++) {
        final double x0 = samples[start + i];
        final double x1 = samples[start + i + tau];
        acf += x0 * x1;
        norm += (x0 * x0) + (x1 * x1);
      }
      nsdf[tau] = norm > 1e-12 ? (2.0 * acf) / norm : 0.0;
    }

    // Buscar maximos locales positivos y seleccionar el primero por encima de 0.85 * maxPeak
    final peakIndices = <int>[];
    double maxPeakVal = 0.0;
    for (int tau = minLag + 1; tau < maxLag; tau++) {
      final double v = nsdf[tau];
      if (v > 0.0 && v >= nsdf[tau - 1] && v >= nsdf[tau + 1]) {
        peakIndices.add(tau);
        if (v > maxPeakVal) maxPeakVal = v;
      }
    }

    // Umbral de claridad minima (0.50) para rechazar ruido aperiodico
    if (peakIndices.isEmpty || maxPeakVal < 0.50) return null;

    final double threshold = maxPeakVal * 0.85;
    int chosenTau = peakIndices.first;
    for (final idx in peakIndices) {
      if (nsdf[idx] >= threshold) {
        chosenTau = idx;
        break;
      }
    }

    // Interpolacion parabolica para precision sub-muestra
    double refinedTau = chosenTau.toDouble();
    if (chosenTau > minLag && chosenTau < maxLag) {
      final double y0 = nsdf[chosenTau - 1];
      final double y1 = nsdf[chosenTau];
      final double y2 = nsdf[chosenTau + 1];
      final double denom = (2.0 * y1) - y0 - y2;
      if (denom.abs() > 1e-9) {
        refinedTau += 0.5 * (y2 - y0) / denom;
      }
    }

    if (refinedTau <= 0.0) return null;
    return sampleRate / refinedTau;
  }

  /// Calcula el centroide espectral en Hz mediante FFT radix-2 de 512 puntos con ventana Hann.
  double _computeSpectralCentroidHz(
    Float64List samples,
    int start,
    int length,
    int sampleRate,
  ) {
    // Potencia de 2 <= min(512, length)
    int fftSize = 512;
    while (fftSize > length && fftSize > 16) {
      fftSize >>= 1;
    }
    if (fftSize < 16) return 0.0;

    final re = Float64List(fftSize);
    final im = Float64List(fftSize);
    final double denom = (fftSize - 1).toDouble();
    for (int i = 0; i < fftSize; i++) {
      final double hann = 0.5 * (1.0 - math.cos((2.0 * math.pi * i) / denom));
      re[i] = samples[start + i] * hann;
    }

    _fftInPlace(re, im);

    double weightedFreqSum = 0.0;
    double magnitudeSum = 0.0;
    final int halfBins = fftSize ~/ 2;
    final double binHz = sampleRate / fftSize;

    for (int k = 1; k < halfBins; k++) {
      final double mag = math.sqrt((re[k] * re[k]) + (im[k] * im[k]));
      weightedFreqSum += (k * binHz) * mag;
      magnitudeSum += mag;
    }

    return magnitudeSum > 1e-9 ? weightedFreqSum / magnitudeSum : 0.0;
  }

  static void _fftInPlace(Float64List re, Float64List im) {
    final int n = re.length;
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final double tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final double ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }

    for (int len = 2; len <= n; len <<= 1) {
      final double ang = -2.0 * math.pi / len;
      final double wLenRe = math.cos(ang);
      final double wLenIm = math.sin(ang);
      final int half = len >> 1;
      for (int i = 0; i < n; i += len) {
        double wRe = 1.0;
        double wIm = 0.0;
        for (int k = 0; k < half; k++) {
          final int u = i + k;
          final int v = u + half;
          final double vRe = re[v] * wRe - im[v] * wIm;
          final double vIm = re[v] * wIm + im[v] * wRe;
          re[v] = re[u] - vRe;
          im[v] = im[u] - vIm;
          re[u] += vRe;
          im[u] += vIm;
          final double nextWRe = wRe * wLenRe - wIm * wLenIm;
          wIm = wRe * wLenIm + wIm * wLenRe;
          wRe = nextWRe;
        }
      }
    }
  }

  static List<double> _computeWaveformPeaks(Float64List samples, int buckets) {
    if (samples.isEmpty || buckets <= 0) return const [];
    final int count = math.min(buckets, samples.length);
    final double step = samples.length / count;
    final peaks = List<double>.filled(count, 0.0);

    for (int b = 0; b < count; b++) {
      final int start = (b * step).floor();
      final int end = math.min(samples.length, ((b + 1) * step).ceil());
      double maxAbs = 0.0;
      for (int i = start; i < end; i++) {
        final double absVal = samples[i].abs();
        if (absVal > maxAbs) maxAbs = absVal;
      }
      peaks[b] = maxAbs.clamp(0.0, 1.0);
    }
    return peaks;
  }

  static String _midiToNoteName(int midi) {
    final int pitchClass = ((midi % 12) + 12) % 12;
    final int octave = (midi ~/ 12) - 1;
    return '${_noteNames[pitchClass]}$octave';
  }
}
