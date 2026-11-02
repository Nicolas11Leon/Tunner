/// Modelos de dominio inmutables para el perfilado y adaptación acústica del micrófono.
class MicrophoneCalibrationProfile {
  /// Multiplicador de ganancia de entrada digital aplicada antes del análisis (0.2x a 5.0x).
  final double digitalGain;

  /// Umbral de corte de potencia RMS para el Noise Gate adaptativo (0.001 a 0.100).
  final double noiseGateThreshold;

  /// Si es true, activa el filtro IIR de eliminación de polarización de corriente directa (DC-offset).
  final bool enableDcBlocker;

  /// ID o nombre del dispositivo de hardware seleccionado (vacío si es el predeterminado del sistema).
  final String deviceId;

  /// Nivel RMS promedio del piso de ruido medido en la última calibración.
  final double measuredNoiseFloorRms;

  const MicrophoneCalibrationProfile({
    this.digitalGain = 1.0,
    this.noiseGateThreshold = 0.005, // Aprox. -46 dBFS
    this.enableDcBlocker = true,
    this.deviceId = '',
    this.measuredNoiseFloorRms = 0.002,
  });

  MicrophoneCalibrationProfile copyWith({
    double? digitalGain,
    double? noiseGateThreshold,
    bool? enableDcBlocker,
    String? deviceId,
    double? measuredNoiseFloorRms,
  }) {
    return MicrophoneCalibrationProfile(
      digitalGain: digitalGain ?? this.digitalGain,
      noiseGateThreshold: noiseGateThreshold ?? this.noiseGateThreshold,
      enableDcBlocker: enableDcBlocker ?? this.enableDcBlocker,
      deviceId: deviceId ?? this.deviceId,
      measuredNoiseFloorRms: measuredNoiseFloorRms ?? this.measuredNoiseFloorRms,
    );
  }

  Map<String, dynamic> toJson() => {
        'digitalGain': digitalGain,
        'noiseGateThreshold': noiseGateThreshold,
        'enableDcBlocker': enableDcBlocker,
        'deviceId': deviceId,
        'measuredNoiseFloorRms': measuredNoiseFloorRms,
      };

  factory MicrophoneCalibrationProfile.fromJson(Map<String, dynamic> json) {
    return MicrophoneCalibrationProfile(
      digitalGain: (json['digitalGain'] as num?)?.toDouble() ?? 1.0,
      noiseGateThreshold: (json['noiseGateThreshold'] as num?)?.toDouble() ?? 0.005,
      enableDcBlocker: json['enableDcBlocker'] as bool? ?? true,
      deviceId: json['deviceId'] as String? ?? '',
      measuredNoiseFloorRms: (json['measuredNoiseFloorRms'] as num?)?.toDouble() ?? 0.002,
    );
  }
}

/// Informe de resultados tras una medición del ruido de fondo de la sala.
class NoiseProfileReport {
  final double meanRms;
  final double peakRms;
  final double recommendedNoiseGate;
  final double detectedDcOffset;
  final int totalFramesAnalyzed;

  const NoiseProfileReport({
    required this.meanRms,
    required this.peakRms,
    required this.recommendedNoiseGate,
    required this.detectedDcOffset,
    required this.totalFramesAnalyzed,
  });
}
