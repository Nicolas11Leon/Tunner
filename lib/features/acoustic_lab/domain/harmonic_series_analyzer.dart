import 'dart:math' as math;

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
}

/// Analizador de la serie armónica y pureza de timbre mediante Transformada Discreta de Fourier dirigida (DFT).
/// Pure Dart: Cero dependencias de Flutter UI.
class HarmonicSeriesAnalyzer {
  final int maxHarmonics;

  const HarmonicSeriesAnalyzer({this.maxHarmonics = 8});

  /// Analiza los primeros [maxHarmonics] armónicos a partir de la frecuencia fundamental
  /// y de las muestras PCM normalizadas [-1.0, 1.0].
  TimbreAnalysisResult analyze({
    required double fundamentalHz,
    List<double>? samples,
    double sampleRate = 44100.0,
  }) {
    if (fundamentalHz <= 20.0) {
      return TimbreAnalysisResult.empty;
    }

    final amplitudes = <double>[];

    if (samples != null && samples.length >= 64) {
      // Evaluación exacta de DFT dirigida para cada armónico k * fundamental
      final n = samples.length;
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
          final sample = samples[i];
          sumCos += sample * math.cos(omega * i);
          sumSin += sample * math.sin(omega * i);
        }

        final mag = (2.0 / n) * math.sqrt(sumCos * sumCos + sumSin * sumSin);
        amplitudes.add(mag);
      }
    } else {
      // Modelo de decaimiento acústico natural cuando no se suministra buffer crudo
      for (int k = 1; k <= maxHarmonics; k++) {
        amplitudes.add(1.0 / math.pow(k, 1.2));
      }
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
