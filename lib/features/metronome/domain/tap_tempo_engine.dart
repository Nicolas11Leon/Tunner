import 'dart:math' as math;
import 'tap_tempo_result.dart';
import 'tempo_entity.dart';

/// Motor matemático determinista para el cálculo de Tap Tempo con promedio móvil ponderado,
/// filtrado de jitter y evaluación de estabilidad métrica.
/// Dominio Puro en Dart: Cero dependencias de Flutter UI.
class TapTempoEngine {
  final int minBpm;
  final int maxBpm;
  final int maxHistoryIntervals;
  final int inactivityTimeoutMs;

  final List<int> _timestampsMs = [];
  final List<double> _intervalsMs = [];

  TapTempoEngine({
    this.minBpm = 30,
    this.maxBpm = 300,
    this.maxHistoryIntervals = 8,
    this.inactivityTimeoutMs = 2500,
  });

  int get tapCount => _timestampsMs.length;
  bool get hasActiveSession => _timestampsMs.isNotEmpty;

  /// Registra una pulsación manual en el instante [timestampMs] (en milisegundos desde epoch).
  /// Si no se suministra, se utiliza `DateTime.now().millisecondsSinceEpoch`.
  TapTempoResult recordTap([int? timestampMs]) {
    final now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

    // 1. Detección de inactividad: Si el intervalo excede el límite, reiniciar secuencia
    if (_timestampsMs.isNotEmpty) {
      final elapsedSinceLast = now - _timestampsMs.last;
      if (elapsedSinceLast > inactivityTimeoutMs || elapsedSinceLast <= 0) {
        reset();
      }
    }

    _timestampsMs.add(now);

    // Primer toque: registrar marca temporal y retornar estado inicial
    if (_timestampsMs.length == 1) {
      return TapTempoResult.initial;
    }

    // Calcular intervalo con el toque precedente
    final prev = _timestampsMs[_timestampsMs.length - 2];
    final interval = (now - prev).toDouble();
    _intervalsMs.add(interval);

    // Mantener tamaño de ventana acotado a los últimos [maxHistoryIntervals]
    if (_intervalsMs.length > maxHistoryIntervals) {
      _intervalsMs.removeAt(0);
    }

    // 2. Cálculo del promedio móvil ponderado (las pulsaciones más recientes pesan más)
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    final int count = _intervalsMs.length;

    for (int i = 0; i < count; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += _intervalsMs[i] * weight;
      totalWeight += weight;
    }

    final meanIntervalMs = weightedSum / totalWeight;
    final exactBpm = 60000.0 / meanIntervalMs;
    final clampedBpm = exactBpm.round().clamp(minBpm, maxBpm);

    // 3. Cálculo de la desviación estándar muestral (Jitter en milisegundos)
    double jitterMs = 0.0;
    double jitterPercentage = 0.0;
    String stability;

    if (count >= 2) {
      double varianceSum = 0.0;
      for (final interval in _intervalsMs) {
        final diff = interval - meanIntervalMs;
        varianceSum += diff * diff;
      }
      jitterMs = math.sqrt(varianceSum / (count - 1));
      jitterPercentage = (jitterMs / meanIntervalMs) * 100.0;

      if (jitterMs <= 15.0) {
        stability = 'Metronómico (Precisión Máxima)';
      } else if (jitterMs <= 35.0) {
        stability = 'Excelente Regularidad';
      } else if (jitterMs <= 60.0) {
        stability = 'Buena Estabilidad';
      } else {
        stability = 'Ajustando Pulso';
      }
    } else {
      stability = 'Calibrando tempo...';
    }

    return TapTempoResult(
      bpm: clampedBpm,
      exactBpm: exactBpm,
      tapCount: _timestampsMs.length,
      jitterMs: jitterMs,
      jitterPercentage: jitterPercentage,
      stabilityDescription: stability,
      tempoMark: TempoMark.fromBpm(clampedBpm),
    );
  }

  /// Limpia la sesión actual de pulsaciones.
  void reset() {
    _timestampsMs.clear();
    _intervalsMs.clear();
  }
}
