import 'tempo_entity.dart';

/// Resultado inmutable que encapsula la medición de un evento de Tap Tempo y su diagnóstico de estabilidad métrica.
class TapTempoResult {
  final int bpm;
  final double exactBpm;
  final int tapCount;
  final double jitterMs;
  final double jitterPercentage;
  final String stabilityDescription;
  final TempoMark tempoMark;

  const TapTempoResult({
    required this.bpm,
    required this.exactBpm,
    required this.tapCount,
    required this.jitterMs,
    required this.jitterPercentage,
    required this.stabilityDescription,
    required this.tempoMark,
  });

  /// Instancia inicial cuando se pulsa el primer toque de una secuencia.
  static final TapTempoResult initial = TapTempoResult(
    bpm: 120,
    exactBpm: 120.0,
    tapCount: 1,
    jitterMs: 0.0,
    jitterPercentage: 0.0,
    stabilityDescription: 'Iniciando medición...',
    tempoMark: TempoMark.fromBpm(120),
  );

  bool get isCalibrated => tapCount >= 2;

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'exactBpm': exactBpm,
        'tapCount': tapCount,
        'isCalibrated': isCalibrated,
        'jitterMs': jitterMs,
        'jitterPercentage': jitterPercentage,
        'stabilityDescription': stabilityDescription,
        'tempoMark': tempoMark.toJson(),
      };

  factory TapTempoResult.fromJson(Map<String, dynamic> json) => TapTempoResult(
        bpm: (json['bpm'] as num?)?.toInt() ?? 120,
        exactBpm: (json['exactBpm'] as num?)?.toDouble() ?? 120.0,
        tapCount: (json['tapCount'] as num?)?.toInt() ?? 1,
        jitterMs: (json['jitterMs'] as num?)?.toDouble() ?? 0.0,
        jitterPercentage: (json['jitterPercentage'] as num?)?.toDouble() ?? 0.0,
        stabilityDescription: json['stabilityDescription'] as String? ?? '',
        tempoMark: json['tempoMark'] is Map<String, dynamic>
            ? TempoMark.fromJson(json['tempoMark'] as Map<String, dynamic>)
            : TempoMark.fromBpm((json['bpm'] as num?)?.toInt() ?? 120),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TapTempoResult &&
          runtimeType == other.runtimeType &&
          bpm == other.bpm &&
          tapCount == other.tapCount;

  @override
  int get hashCode => bpm.hashCode ^ tapCount.hashCode;

  @override
  String toString() =>
      'TapTempoResult($bpm BPM, ${tempoMark.italianName}, jitter: ±${jitterMs.toStringAsFixed(1)} ms, taps: $tapCount)';
}
