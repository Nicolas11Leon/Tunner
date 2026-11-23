import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Entidad inmutable que encapsula las métricas biomecánicas y de afinación
/// obtenidas tras una evaluación de estabilidad vocal de conservatorio.
class VocalEvaluationResult {
  final String evaluationId;
  final DateTime timestamp;
  final double targetFrequencyHz;
  final double measuredMeanFrequencyHz;
  final double centsDeviation;
  final double jitterPercent;
  final double shimmerPercent;
  final double vibratoRateHz;
  final double vibratoDepthCents;
  final double overallScore;
  final String classificationLabel;
  final String payloadHashSha256;

  VocalEvaluationResult({
    required this.evaluationId,
    required this.timestamp,
    required this.targetFrequencyHz,
    required this.measuredMeanFrequencyHz,
    required this.centsDeviation,
    required this.jitterPercent,
    required this.shimmerPercent,
    required this.vibratoRateHz,
    required this.vibratoDepthCents,
    required this.overallScore,
    required this.classificationLabel,
    String? payloadHashSha256,
  })  : assert(targetFrequencyHz > 0.0, 'La frecuencia target debe ser positiva'),
        assert(measuredMeanFrequencyHz >= 0.0, 'La frecuencia medida no puede ser negativa'),
        assert(overallScore >= 0.0 && overallScore <= 100.0, 'El puntaje debe estar entre 0 y 100'),
        payloadHashSha256 = payloadHashSha256 ??
            _computeSha256Payload(
              evaluationId,
              timestamp,
              targetFrequencyHz,
              measuredMeanFrequencyHz,
              centsDeviation,
              jitterPercent,
              shimmerPercent,
              vibratoRateHz,
              vibratoDepthCents,
              overallScore,
            );

  static String _computeSha256Payload(
    String id,
    DateTime time,
    double targetF,
    double meanF,
    double cents,
    double jitter,
    double shimmer,
    double vibRate,
    double vibDepth,
    double score,
  ) {
    final raw = '$id|${time.toIso8601String()}|${targetF.toStringAsFixed(2)}|'
        '${meanF.toStringAsFixed(2)}|${cents.toStringAsFixed(2)}|'
        '${jitter.toStringAsFixed(4)}|${shimmer.toStringAsFixed(4)}|'
        '${vibRate.toStringAsFixed(2)}|${vibDepth.toStringAsFixed(2)}|'
        '${score.toStringAsFixed(1)}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'evaluationId': evaluationId,
      'timestamp': timestamp.toIso8601String(),
      'targetFrequencyHz': targetFrequencyHz,
      'measuredMeanFrequencyHz': measuredMeanFrequencyHz,
      'centsDeviation': centsDeviation,
      'jitterPercent': jitterPercent,
      'shimmerPercent': shimmerPercent,
      'vibratoRateHz': vibratoRateHz,
      'vibratoDepthCents': vibratoDepthCents,
      'overallScore': overallScore,
      'classificationLabel': classificationLabel,
      'payloadHashSha256': payloadHashSha256,
    };
  }

  factory VocalEvaluationResult.fromJson(Map<String, dynamic> json) {
    return VocalEvaluationResult(
      evaluationId: json['evaluationId'] as String? ?? 'vocal_eval',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      targetFrequencyHz: (json['targetFrequencyHz'] as num?)?.toDouble() ?? 440.0,
      measuredMeanFrequencyHz: (json['measuredMeanFrequencyHz'] as num?)?.toDouble() ?? 0.0,
      centsDeviation: (json['centsDeviation'] as num?)?.toDouble() ?? 0.0,
      jitterPercent: (json['jitterPercent'] as num?)?.toDouble() ?? 0.0,
      shimmerPercent: (json['shimmerPercent'] as num?)?.toDouble() ?? 0.0,
      vibratoRateHz: (json['vibratoRateHz'] as num?)?.toDouble() ?? 0.0,
      vibratoDepthCents: (json['vibratoDepthCents'] as num?)?.toDouble() ?? 0.0,
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0.0,
      classificationLabel: json['classificationLabel'] as String? ?? '',
      payloadHashSha256: json['payloadHashSha256'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocalEvaluationResult &&
          runtimeType == other.runtimeType &&
          evaluationId == other.evaluationId &&
          timestamp == other.timestamp &&
          targetFrequencyHz == other.targetFrequencyHz &&
          measuredMeanFrequencyHz == other.measuredMeanFrequencyHz &&
          centsDeviation == other.centsDeviation &&
          jitterPercent == other.jitterPercent &&
          shimmerPercent == other.shimmerPercent &&
          vibratoRateHz == other.vibratoRateHz &&
          vibratoDepthCents == other.vibratoDepthCents &&
          overallScore == other.overallScore &&
          classificationLabel == other.classificationLabel &&
          payloadHashSha256 == other.payloadHashSha256;

  @override
  int get hashCode => Object.hash(
        evaluationId,
        timestamp,
        targetFrequencyHz,
        measuredMeanFrequencyHz,
        centsDeviation,
        jitterPercent,
        shimmerPercent,
        vibratoRateHz,
        vibratoDepthCents,
        overallScore,
        classificationLabel,
        payloadHashSha256,
      );

  @override
  String toString() =>
      'VocalEvaluationResult(id: $evaluationId, score: ${overallScore.toStringAsFixed(1)}/100, '
      'cents: ${centsDeviation.toStringAsFixed(1)}, jitter: ${jitterPercent.toStringAsFixed(2)}%, '
      'shimmer: ${shimmerPercent.toStringAsFixed(2)}%, hash: ${payloadHashSha256.substring(0, 8)}...)';
}
