import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/audio/domain/offline_wav_decoder.dart';
import '../../tuner/domain/mcleod_pitch_method.dart';
import '../../tuner/domain/offline_pitch_contour_analyzer.dart';

/// Representa una barra armónica individual dentro del espectrograma.
class HarmonicBarEntity {
  final int harmonicNumber;
  final double frequencyHz;
  final double relativeAmplitude; // Normalizado 0.0 a 1.0
  final double dbLevel; // Escala logarítmica de decibelios
  final String intervalLabel;

  const HarmonicBarEntity({
    required this.harmonicNumber,
    required this.frequencyHz,
    required this.relativeAmplitude,
    required this.dbLevel,
    required this.intervalLabel,
  });

  Map<String, dynamic> toJson() => {
        'harmonicNumber': harmonicNumber,
        'frequencyHz': frequencyHz,
        'relativeAmplitude': relativeAmplitude,
        'dbLevel': dbLevel,
        'intervalLabel': intervalLabel,
      };

  factory HarmonicBarEntity.fromJson(Map<String, dynamic> json) {
    final k = (json['harmonicNumber'] as num?)?.toInt() ?? 1;
    return HarmonicBarEntity(
      harmonicNumber: k,
      frequencyHz: (json['frequencyHz'] as num?)?.toDouble() ?? 0.0,
      relativeAmplitude: (json['relativeAmplitude'] as num?)?.toDouble() ?? 0.0,
      dbLevel: (json['dbLevel'] as num?)?.toDouble() ?? -60.0,
      intervalLabel: json['intervalLabel'] as String? ?? getLabelForHarmonic(k),
    );
  }

  static String getLabelForHarmonic(int k) {
    switch (k) {
      case 1:
        return "1 (Fundamental)";
      case 2:
        return "2 (Octava)";
      case 3:
        return "3 (Quinta Justa)";
      case 4:
        return "4 (2da Octava)";
      case 5:
        return "5 (Tercera Mayor)";
      case 6:
        return "6 (3ra Quinta)";
      case 7:
        return "7 (Séptima Menor)";
      case 8:
        return "8 (3ra Octava)";
      default:
        return "$k (Sobretono)";
    }
  }
}

/// Resultado integral del análisis acústico y timbral.
class TimbreAnalysisResult {
  final double fundamentalHz;
  final List<HarmonicBarEntity> harmonics;
  final double spectralCentroidHz;
  final double totalHarmonicDistortionPercent; // THD en porcentaje
  final String timbreClassification;

  const TimbreAnalysisResult({
    required this.fundamentalHz,
    required this.harmonics,
    required this.spectralCentroidHz,
    required this.totalHarmonicDistortionPercent,
    required this.timbreClassification,
  });

  static const TimbreAnalysisResult empty = TimbreAnalysisResult(
    fundamentalHz: 0.0,
    harmonics: [],
    spectralCentroidHz: 0.0,
    totalHarmonicDistortionPercent: 0.0,
    timbreClassification: "Sin señal acústica",
  );

  Map<String, dynamic> toJson() => {
        'fundamentalHz': fundamentalHz,
        'harmonics': harmonics.map((h) => h.toJson()).toList(growable: false),
        'spectralCentroidHz': spectralCentroidHz,
        'totalHarmonicDistortionPercent': totalHarmonicDistortionPercent,
        'timbreClassification': timbreClassification,
      };

  factory TimbreAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawHarmonics = json['harmonics'] as List<dynamic>? ?? const [];
    return TimbreAnalysisResult(
      fundamentalHz: (json['fundamentalHz'] as num?)?.toDouble() ?? 0.0,
      harmonics: rawHarmonics
          .whereType<Map<String, dynamic>>()
          .map(HarmonicBarEntity.fromJson)
          .toList(growable: false),
      spectralCentroidHz: (json['spectralCentroidHz'] as num?)?.toDouble() ?? 0.0,
      totalHarmonicDistortionPercent:
          (json['totalHarmonicDistortionPercent'] as num?)?.toDouble() ?? 0.0,
      timbreClassification:
          json['timbreClassification'] as String? ?? 'Sin señal acústica',
    );
  }
}

/// Analizador de la serie armónica y pureza de timbre mediante Transformada Discreta de Fourier dirigida (DFT).
/// Pure Dart: Cero dependencias de Flutter UI.
class HarmonicSeriesAnalyzer {
  static final Map<int, Float64List> _hannCache = <int, Float64List>{};
  static final Map<int, double> _hannSumCache = <int, double>{};

  final int maxHarmonics;

  const HarmonicSeriesAnalyzer({this.maxHarmonics = 8});

  /// Retorna la ventana de Hann cacheada para el tamano [n].
  static Float64List getHannWindow(int n) {
    final cached = _hannCache[n];
    if (cached != null) return cached;

    final weights = Float64List(n);
    double sum = 0.0;
    if (n == 1) {
      weights[0] = 1.0;
      sum = 1.0;
    } else {
      for (int i = 0; i < n; i++) {
        final w = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (n - 1)));
        weights[i] = w;
        sum += w;
      }
    }
    _hannCache[n] = weights;
    _hannSumCache[n] = sum;
    return weights;
  }

  /// Verifica si existe una ventana de Hann en cache para el tamano [n].
  static bool hasCachedHannWindow(int n) => _hannCache.containsKey(n);

  /// Ejecuta [analyze] fuera del hilo de UI mediante [Isolate.run].
  Future<TimbreAnalysisResult> analyzeAsync({
    required double fundamentalHz,
    List<double>? samples,
    double sampleRate = 44100.0,
  }) {
    final maxH = maxHarmonics;
    final copiedSamples = samples == null ? null : List<double>.from(samples, growable: false);
    return Isolate.run(() {
      final analyzer = HarmonicSeriesAnalyzer(maxHarmonics: maxH);
      return analyzer.analyze(
        fundamentalHz: fundamentalHz,
        samples: copiedSamples,
        sampleRate: sampleRate,
      );
    });
  }

  /// Decodifica un archivo WAV (16/24/32-bit float) mediante [OfflineWavDecoder],
  /// auto-detecta la frecuencia fundamental mediante [OfflinePitchContourAnalyzer] / [McleodPitchMethod]
  /// si [fundamentalHz] no se suministra, y calcula la serie armonica y metricas timbrales.
  TimbreAnalysisResult analyzeWavBytes(
    Uint8List wavBytes, {
    double? fundamentalHz,
    int windowSize = 4096,
    int startTimeMs = 0,
    McleodPitchMethod? pitchDetector,
  }) {
    final decoded = OfflineWavDecoder.decode(wavBytes);
    if (decoded.samples.length < 64) {
      return TimbreAnalysisResult.empty;
    }

    final int startSample = ((math.max(0, startTimeMs) / 1000.0) * decoded.sampleRate)
        .round()
        .clamp(0, math.max(0, decoded.samples.length - 64));
    final int effectiveWindow = math.min(
      math.max(64, windowSize),
      decoded.samples.length - startSample,
    );
    final windowSamples = Float64List.sublistView(
      decoded.samples,
      startSample,
      startSample + effectiveWindow,
    );

    double resolvedFundamental = fundamentalHz ?? 0.0;
    if (resolvedFundamental <= 20.0) {
      final detector = pitchDetector ?? const McleodPitchMethod();
      final directDetection = detector.estimatePitch(
        windowSamples,
        sampleRate: decoded.sampleRate,
      );
      if (directDetection.pitched && directDetection.pitchHz > 20.0) {
        resolvedFundamental = directDetection.pitchHz;
      } else {
        final contourAnalyzer = OfflinePitchContourAnalyzer(pitchDetector: detector);
        final contour = contourAnalyzer.analyzeSamples(
          decoded.samples,
          sampleRate: decoded.sampleRate,
          windowSize: effectiveWindow,
          hopSize: math.max(256, effectiveWindow ~/ 4),
        );
        if (contour.hasVoicedFrames && contour.medianPitchHz > 20.0) {
          resolvedFundamental = contour.medianPitchHz;
        }
      }
    }

    if (resolvedFundamental <= 20.0) {
      return TimbreAnalysisResult.empty;
    }

    return analyze(
      fundamentalHz: resolvedFundamental,
      samples: windowSamples,
      sampleRate: decoded.sampleRate.toDouble(),
    );
  }

  /// Analiza los primeros [maxHarmonics] armónicos a partir de la frecuencia fundamental
  /// y de las muestras PCM normalizadas [-1.0, 1.0].
  /// Aplica una ventana de Hann simétrica para prevenir spectral leakage.
  /// Si no se suministran muestras reales válidas, retorna [TimbreAnalysisResult.empty].
  TimbreAnalysisResult analyze({
    required double fundamentalHz,
    List<double>? samples,
    double sampleRate = 44100.0,
  }) {
    if (fundamentalHz <= 20.0 || samples == null || samples.length < 64) {
      return TimbreAnalysisResult.empty;
    }

    final amplitudes = <double>[];
    final n = samples.length;

    // Obtener ventana de Hann cacheada y suma de pesos coherentes
    final windowWeights = getHannWindow(n);
    final windowSum = _hannSumCache[n] ?? 0.0;
    final normFactor = windowSum > 1e-6 ? (2.0 / windowSum) : (2.0 / n);

    // Evaluación exacta de DFT dirigida para cada armónico k * fundamental
    for (int k = 1; k <= maxHarmonics; k++) {
      final targetFreq = fundamentalHz * k;
      if (targetFreq >= sampleRate / 2.0) {
        amplitudes.add(0.0);
        continue;
      }

      final omega = 2.0 * math.pi * targetFreq / sampleRate;
      double sumCos = 0.0;
      double sumSin = 0.0;

      for (int i = 0; i < n; i++) {
        final sample = samples[i] * windowWeights[i];
        sumCos += sample * math.cos(omega * i);
        sumSin += sample * math.sin(omega * i);
      }

      final mag = normFactor * math.sqrt(sumCos * sumCos + sumSin * sumSin);
      amplitudes.add(mag);
    }

    // Normalización de amplitud respecto a la fundamental
    final fundamentalAmp = amplitudes.isNotEmpty && amplitudes[0] > 0.00001 ? amplitudes[0] : 1.0;
    final maxAmp = amplitudes.fold<double>(0.0, (prev, val) => math.max(prev, val));
    final safeMax = maxAmp > 0.00001 ? maxAmp : 1.0;

    final bars = <HarmonicBarEntity>[];
    double numeratorCentroid = 0.0;
    double sumAmplitudes = 0.0;
    double sumOvertonesSquared = 0.0;

    for (int k = 1; k <= maxHarmonics; k++) {
      final freq = fundamentalHz * k;
      final rawAmp = k - 1 < amplitudes.length ? amplitudes[k - 1] : 0.0;
      final normalizedAmp = (rawAmp / safeMax).clamp(0.0, 1.0);

      // Conversión a escala logarítmica de decibelios (dBFS)
      final safeNorm = math.max(normalizedAmp, 0.0001);
      final db = 20.0 * (math.log(safeNorm) / math.ln10);

      bars.add(HarmonicBarEntity(
        harmonicNumber: k,
        frequencyHz: freq,
        relativeAmplitude: normalizedAmp,
        dbLevel: db.clamp(-60.0, 0.0),
        intervalLabel: HarmonicBarEntity.getLabelForHarmonic(k),
      ));

      numeratorCentroid += freq * rawAmp;
      sumAmplitudes += rawAmp;

      if (k > 1) {
        sumOvertonesSquared += rawAmp * rawAmp;
      }
    }

    // Cálculo del Centroide Espectral
    final centroid = sumAmplitudes > 0.00001 ? numeratorCentroid / sumAmplitudes : fundamentalHz;

    // Cálculo de la Distorsión Armónica Total (THD %)
    final thdRatio = math.sqrt(sumOvertonesSquared) / fundamentalAmp;
    final thdPercent = (thdRatio * 100.0).clamp(0.0, 100.0);

    // Clasificación de cualidad timbral
    String timbreQuality;
    if (thdPercent < 8.0) {
      timbreQuality = "Puro y Suave (Tipo Senoidal / Flauta Dulce)";
    } else if (thdPercent < 25.0) {
      timbreQuality = "Cálido y Redondo (Flauta Traversa / Voz Media)";
    } else if (thdPercent < 55.0) {
      timbreQuality = "Brillante y Resonante (Violín / Vientos Madera)";
    } else {
      timbreQuality = "Penetrante y Armónico (Trompeta / Caña Doble)";
    }

    return TimbreAnalysisResult(
      fundamentalHz: fundamentalHz,
      harmonics: bars,
      spectralCentroidHz: centroid,
      totalHarmonicDistortionPercent: thdPercent,
      timbreClassification: timbreQuality,
    );
  }
}
