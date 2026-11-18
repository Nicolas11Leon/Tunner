import 'dart:math' as math;
import 'vocal_evaluation_result.dart';
export 'vocal_evaluation_result.dart';

/// Evaluador de estabilidad fonatoria y afinación vocal de conservatorio.
/// Procesa series temporales de frecuencia y amplitud para extraer Jitter %,
/// Shimmer %, parámetros de vibrato y generar un índice ponderado de estabilidad vocal.
class VocalStabilityEvaluator {
  /// Frecuencia de muestreo o tasa de fotogramas de análisis en Hertz (por defecto 50 Hz = 20 ms por frame).
  final double analysisFrameRateHz;

  const VocalStabilityEvaluator({
    this.analysisFrameRateHz = 50.0,
  });

  /// Evalúa una secuencia fonatoria continua frente a una frecuencia nominal [targetFrequencyHz].
  VocalEvaluationResult evaluate({
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
    String? evaluationId,
    DateTime? timestamp,
  }) {
    if (frequenciesHz.isEmpty || amplitudes.isEmpty) {
      throw ArgumentError('Las secuencias de frecuencia y amplitud no pueden estar vacias');
    }
    if (frequenciesHz.length != amplitudes.length) {
      throw ArgumentError('Las listas de frecuencias y amplitudes deben tener la misma longitud');
    }
    if (targetFrequencyHz <= 0.0) {
      throw ArgumentError('La frecuencia target debe ser estrictamente positiva');
    }

    final validFrequencies = <double>[];
    final validAmplitudes = <double>[];

    // Filtrar silencio o fotogramas no fonatorios
    for (int i = 0; i < frequenciesHz.length; i++) {
      final f = frequenciesHz[i];
      final a = amplitudes[i];
      if (f > 20.0 && f < 5000.0 && a > 0.001) {
        validFrequencies.add(f);
        validAmplitudes.add(a);
      }
    }

    if (validFrequencies.length < 5) {
      // Si casi no hay muestras válidas, retornar evaluación base
      final now = timestamp ?? DateTime.now();
      return VocalEvaluationResult(
        evaluationId: evaluationId ?? 'VOCAL-${now.millisecondsSinceEpoch}',
        timestamp: now,
        targetFrequencyHz: targetFrequencyHz,
        measuredMeanFrequencyHz: targetFrequencyHz,
        centsDeviation: 0.0,
        jitterPercent: 0.0,
        shimmerPercent: 0.0,
        vibratoRateHz: 0.0,
        vibratoDepthCents: 0.0,
        overallScore: 50.0,
        classificationLabel: 'En Desarrollo / Nivel Inicial',
      );
    }

    // 1. Frecuencia media y desviación en cents
    double sumFreq = 0.0;
    for (final f in validFrequencies) {
      sumFreq += f;
    }
    final meanFreq = sumFreq / validFrequencies.length;
    final centsDeviation = 1200.0 * (math.log(meanFreq / targetFrequencyHz) / math.ln2);

    // 2. Cálculo de Jitter relativo (%)
    final jitterPercent = _computeJitter(validFrequencies);

    // 3. Cálculo de Shimmer relativo (%)
    final shimmerPercent = _computeShimmer(validAmplitudes);

    // 4. Extracción de Vibrato (Tasa y Amplitud)
    final vibrato = _analyzeVibrato(validFrequencies, analysisFrameRateHz);

    // 5. Puntuación global ponderada (0 - 100)
    final score = _computeOverallScore(
      centsDeviation: centsDeviation,
      jitterPercent: jitterPercent,
      shimmerPercent: shimmerPercent,
      vibratoRateHz: vibrato.rateHz,
      vibratoDepthCents: vibrato.depthCents,
    );

    final String label;
    if (score >= 90.0) {
      label = 'Excelente / Nivel Profesional';
    } else if (score >= 80.0) {
      label = 'Notable / Nivel Avanzado';
    } else if (score >= 65.0) {
      label = 'Aceptable / Nivel Intermedio';
    } else {
      label = 'En Desarrollo / Nivel Inicial';
    }

    final now = timestamp ?? DateTime.now();
    return VocalEvaluationResult(
      evaluationId: evaluationId ?? 'VOCAL-${now.millisecondsSinceEpoch}',
      timestamp: now,
      targetFrequencyHz: targetFrequencyHz,
      measuredMeanFrequencyHz: meanFreq,
      centsDeviation: centsDeviation,
      jitterPercent: jitterPercent,
      shimmerPercent: shimmerPercent,
      vibratoRateHz: vibrato.rateHz,
      vibratoDepthCents: vibrato.depthCents,
      overallScore: score,
      classificationLabel: label,
    );
  }

  /// Calcula el jitter relativo ciclo a ciclo:
  /// Jitter(%) = (sum(|T_i - T_{i+1}|) / (N-1)) / mean(T) * 100
  static double _computeJitter(List<double> frequencies) {
    if (frequencies.length < 2) return 0.0;

    final periods = <double>[];
    double sumPeriod = 0.0;
    for (final f in frequencies) {
      final t = 1.0 / f;
      periods.add(t);
      sumPeriod += t;
    }
    final meanPeriod = sumPeriod / periods.length;

    double diffSum = 0.0;
    for (int i = 0; i < periods.length - 1; i++) {
      diffSum += (periods[i] - periods[i + 1]).abs();
    }
    final avgDiff = diffSum / (periods.length - 1);

    final jitter = (avgDiff / meanPeriod) * 100.0;
    return jitter.clamp(0.0, 50.0);
  }

  /// Calcula el shimmer relativo ciclo a ciclo:
  /// Shimmer(%) = (sum(|A_i - A_{i+1}|) / (N-1)) / mean(A) * 100
  static double _computeShimmer(List<double> amplitudes) {
    if (amplitudes.length < 2) return 0.0;

    double sumAmp = 0.0;
    for (final a in amplitudes) {
      sumAmp += a;
    }
    final meanAmp = sumAmp / amplitudes.length;
    if (meanAmp == 0.0) return 0.0;

    double diffSum = 0.0;
    for (int i = 0; i < amplitudes.length - 1; i++) {
      diffSum += (amplitudes[i] - amplitudes[i + 1]).abs();
    }
    final avgDiff = diffSum / (amplitudes.length - 1);

    final shimmer = (avgDiff / meanAmp) * 100.0;
    return shimmer.clamp(0.0, 50.0);
  }

  /// Analiza la tasa y profundidad del vibrato mediante análisis temporal de paso por cero.
  static ({double rateHz, double depthCents}) _analyzeVibrato(
    List<double> frequencies,
    double frameRate,
  ) {
    if (frequencies.length < 15) {
      return (rateHz: 0.0, depthCents: 0.0);
    }

    double sum = 0.0;
    for (final f in frequencies) {
      sum += f;
    }
    final mean = sum / frequencies.length;

    // Detrending: restar frecuencia base
    final detrended = frequencies.map((f) => f - mean).toList();

    // Contar cruces por cero en la modulación
    int zeroCrossings = 0;
    for (int i = 0; i < detrended.length - 1; i++) {
      if ((detrended[i] >= 0.0 && detrended[i + 1] < 0.0) ||
          (detrended[i] < 0.0 && detrended[i + 1] >= 0.0)) {
        zeroCrossings++;
      }
    }

    final durationSeconds = frequencies.length / frameRate;
    if (durationSeconds <= 0.0) {
      return (rateHz: 0.0, depthCents: 0.0);
    }

    final double rate = (zeroCrossings / 2.0) / durationSeconds;

    // Calcular profundidad pico a valle en cents
    double minF = frequencies[0];
    double maxF = frequencies[0];
    for (final f in frequencies) {
      if (f < minF) minF = f;
      if (f > maxF) maxF = f;
    }

    double depthCents = 0.0;
    if (minF > 0.0 && maxF > minF) {
      depthCents = (1200.0 * (math.log(maxF / minF) / math.ln2)) / 2.0;
    }

    // Si la tasa está en el rango fisiológico de vibrato (3.5 - 8.5 Hz) y la profundidad es >= 15 cents
    if (rate >= 3.5 && rate <= 8.5 && depthCents >= 15.0) {
      return (rateHz: rate, depthCents: depthCents.clamp(0.0, 200.0));
    }

    // Straight tone (sin vibrato apreciable)
    return (rateHz: 0.0, depthCents: 0.0);
  }

  /// Calcula la puntuación integral sobre 100 ponderando afinación, jitter, shimmer y vibrato.
  static double _computeOverallScore({
    required double centsDeviation,
    required double jitterPercent,
    required double shimmerPercent,
    required double vibratoRateHz,
    required double vibratoDepthCents,
  }) {
    // Afinación (40%): 0 cents = 100, 50 cents = 0
    final tuningScore = (100.0 - centsDeviation.abs() * 2.0).clamp(0.0, 100.0);

    // Jitter (25%): 0.5% = 100, 3.0% = 0
    final jitterScore = (100.0 - (jitterPercent - 0.5).clamp(0.0, 50.0) * 40.0).clamp(0.0, 100.0);

    // Shimmer (20%): 1.0% = 100, 6.0% = 0
    final shimmerScore = (100.0 - (shimmerPercent - 1.0).clamp(0.0, 50.0) * 20.0).clamp(0.0, 100.0);

    // Vibrato (15%):
    double vibratoScore = 80.0; // Straight tone bien ejecutado recibe 80
    if (vibratoRateHz >= 4.5 && vibratoRateHz <= 7.0 && vibratoDepthCents >= 25.0 && vibratoDepthCents <= 75.0) {
      vibratoScore = 100.0; // Vibrato óptimo de conservatorio
    } else if (vibratoRateHz > 0.0) {
      vibratoScore = 85.0;
    }

    final total = 0.40 * tuningScore + 0.25 * jitterScore + 0.20 * shimmerScore + 0.15 * vibratoScore;
    return total.clamp(0.0, 100.0);
  }
}
