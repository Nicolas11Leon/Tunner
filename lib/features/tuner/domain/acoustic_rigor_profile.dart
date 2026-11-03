import 'package:flutter/material.dart';

/// Presets de contexto y nivel de rigurosidad acústica para la ingesta del micrófono.
enum AcousticRigorPreset {
  beginner,
  balancedRehearsal,
  studioRecording,
  noisyStage,
  conservatoryMastery,
  custom;

  String get displayName {
    switch (this) {
      case AcousticRigorPreset.beginner:
        return 'Fácil / Principiante';
      case AcousticRigorPreset.balancedRehearsal:
        return 'Ensayo Equilibrado';
      case AcousticRigorPreset.studioRecording:
        return 'Grabación / Estudio';
      case AcousticRigorPreset.noisyStage:
        return 'Escenario / En Vivo';
      case AcousticRigorPreset.conservatoryMastery:
        return 'Conservatorio';
      case AcousticRigorPreset.custom:
        return 'Personalizado';
    }
  }

  String get subtitle {
    switch (this) {
      case AcousticRigorPreset.beginner:
        return 'Máxima sensibilidad y tolerancia';
      case AcousticRigorPreset.balancedRehearsal:
        return 'Balance ideal para práctica diaria';
      case AcousticRigorPreset.studioRecording:
        return 'Alta pureza y rechazo de ruido';
      case AcousticRigorPreset.noisyStage:
        return 'Inmunidad a batería y público';
      case AcousticRigorPreset.conservatoryMastery:
        return 'Precisión microtonal quirúrgica';
      case AcousticRigorPreset.custom:
        return 'Parámetros ajustados manualmente';
    }
  }

  String get description {
    switch (this) {
      case AcousticRigorPreset.beginner:
        return 'Ideal para principiantes, niños o sonido inestable. Respuesta inmediata en 1 frame y alta tolerancia en cents.';
      case AcousticRigorPreset.balancedRehearsal:
        return 'Configuración estándar. Discrimina ruido ambiental moderado sin comprometer la rapidez de afinación.';
      case AcousticRigorPreset.studioRecording:
        return 'Optimizado para salas acústicas y home-studio. Filtra ventiladores y soplidos con claridad elevada (0.86).';
      case AcousticRigorPreset.noisyStage:
        return 'Compuerta estricta y Tone Lock de 3 frames (~70ms) para evitar disparos por amplificadores o batería cercana.';
      case AcousticRigorPreset.conservatoryMastery:
        return 'Exigencia absoluta para instrumentistas avanzados. Exige claridad >= 0.92 y fluctuaciones <= 15 cents.';
      case AcousticRigorPreset.custom:
        return 'Control granular de todos los parámetros de DSP por el usuario o productor musical.';
    }
  }

  IconData get icon {
    switch (this) {
      case AcousticRigorPreset.beginner:
        return Icons.sentiment_satisfied_alt;
      case AcousticRigorPreset.balancedRehearsal:
        return Icons.music_note;
      case AcousticRigorPreset.studioRecording:
        return Icons.mic;
      case AcousticRigorPreset.noisyStage:
        return Icons.speaker_group;
      case AcousticRigorPreset.conservatoryMastery:
        return Icons.verified;
      case AcousticRigorPreset.custom:
        return Icons.tune;
    }
  }
}

/// Perfil acústico inmutable con parámetros de DSP y sensibilidad de micrófono.
class AcousticRigorProfile {
  final AcousticRigorPreset preset;
  final bool isAdvancedMode;
  final double minClarity;
  final int minConsecutiveFrames;
  final double maxCentsDeviation;
  final double noiseGateThreshold;
  final double digitalGain;
  final bool enableDcBlocker;
  final bool enableInstrumentIsolation;

  const AcousticRigorProfile({
    this.preset = AcousticRigorPreset.balancedRehearsal,
    this.isAdvancedMode = false,
    this.minClarity = 0.82,
    this.minConsecutiveFrames = 2,
    this.maxCentsDeviation = 35.0,
    this.noiseGateThreshold = 0.005,
    this.digitalGain = 1.0,
    this.enableDcBlocker = true,
    this.enableInstrumentIsolation = true,
  });

  /// Genera un perfil canónico a partir de un preset de contexto.
  factory AcousticRigorProfile.fromPreset(
    AcousticRigorPreset preset, {
    bool isAdvancedMode = false,
    double baseNoiseGate = 0.005,
    double baseGain = 1.0,
  }) {
    switch (preset) {
      case AcousticRigorPreset.beginner:
        return AcousticRigorProfile(
          preset: preset,
          isAdvancedMode: isAdvancedMode,
          minClarity: 0.65,
          minConsecutiveFrames: 1, // Respuesta inmediata
          maxCentsDeviation: 50.0, // Muy tolerante
          noiseGateThreshold: (baseNoiseGate * 0.7).clamp(0.001, 0.080),
          digitalGain: (baseGain * 1.2).clamp(0.2, 5.0),
          enableDcBlocker: true,
          enableInstrumentIsolation: false, // Permisivo
        );
      case AcousticRigorPreset.balancedRehearsal:
        return AcousticRigorProfile(
          preset: preset,
          isAdvancedMode: isAdvancedMode,
          minClarity: 0.80,
          minConsecutiveFrames: 2,
          maxCentsDeviation: 35.0,
          noiseGateThreshold: baseNoiseGate.clamp(0.001, 0.080),
          digitalGain: baseGain.clamp(0.2, 5.0),
          enableDcBlocker: true,
          enableInstrumentIsolation: true,
        );
      case AcousticRigorPreset.studioRecording:
        return AcousticRigorProfile(
          preset: preset,
          isAdvancedMode: isAdvancedMode,
          minClarity: 0.86,
          minConsecutiveFrames: 2,
          maxCentsDeviation: 25.0,
          noiseGateThreshold: (baseNoiseGate * 1.4).clamp(0.001, 0.080),
          digitalGain: baseGain.clamp(0.2, 5.0),
          enableDcBlocker: true,
          enableInstrumentIsolation: true,
        );
      case AcousticRigorPreset.noisyStage:
        return AcousticRigorProfile(
          preset: preset,
          isAdvancedMode: isAdvancedMode,
          minClarity: 0.88,
          minConsecutiveFrames: 3, // Tone lock reforzado
          maxCentsDeviation: 25.0,
          noiseGateThreshold: (baseNoiseGate * 2.0).clamp(0.002, 0.080),
          digitalGain: (baseGain * 0.9).clamp(0.2, 5.0),
          enableDcBlocker: true,
          enableInstrumentIsolation: true,
        );
      case AcousticRigorPreset.conservatoryMastery:
        return AcousticRigorProfile(
          preset: preset,
          isAdvancedMode: isAdvancedMode,
          minClarity: 0.92,
          minConsecutiveFrames: 2,
          maxCentsDeviation: 15.0, // Muy estricto
          noiseGateThreshold: (baseNoiseGate * 1.2).clamp(0.001, 0.080),
          digitalGain: baseGain.clamp(0.2, 5.0),
          enableDcBlocker: true,
          enableInstrumentIsolation: true,
        );
      case AcousticRigorPreset.custom:
        return AcousticRigorProfile(
          preset: preset,
          isAdvancedMode: isAdvancedMode,
          minClarity: 0.82,
          minConsecutiveFrames: 2,
          maxCentsDeviation: 30.0,
          noiseGateThreshold: baseNoiseGate.clamp(0.001, 0.080),
          digitalGain: baseGain.clamp(0.2, 5.0),
          enableDcBlocker: true,
          enableInstrumentIsolation: true,
        );
    }
  }

  AcousticRigorProfile copyWith({
    AcousticRigorPreset? preset,
    bool? isAdvancedMode,
    double? minClarity,
    int? minConsecutiveFrames,
    double? maxCentsDeviation,
    double? noiseGateThreshold,
    double? digitalGain,
    bool? enableDcBlocker,
    bool? enableInstrumentIsolation,
  }) {
    return AcousticRigorProfile(
      preset: preset ?? this.preset,
      isAdvancedMode: isAdvancedMode ?? this.isAdvancedMode,
      minClarity: minClarity ?? this.minClarity,
      minConsecutiveFrames: minConsecutiveFrames ?? this.minConsecutiveFrames,
      maxCentsDeviation: maxCentsDeviation ?? this.maxCentsDeviation,
      noiseGateThreshold: noiseGateThreshold ?? this.noiseGateThreshold,
      digitalGain: digitalGain ?? this.digitalGain,
      enableDcBlocker: enableDcBlocker ?? this.enableDcBlocker,
      enableInstrumentIsolation: enableInstrumentIsolation ?? this.enableInstrumentIsolation,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset.name,
        'isAdvancedMode': isAdvancedMode,
        'minClarity': minClarity,
        'minConsecutiveFrames': minConsecutiveFrames,
        'maxCentsDeviation': maxCentsDeviation,
        'noiseGateThreshold': noiseGateThreshold,
        'digitalGain': digitalGain,
        'enableDcBlocker': enableDcBlocker,
        'enableInstrumentIsolation': enableInstrumentIsolation,
      };

  factory AcousticRigorProfile.fromJson(Map<String, dynamic> json) {
    final presetName = json['preset'] as String? ?? 'balancedRehearsal';
    final matchedPreset = AcousticRigorPreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => AcousticRigorPreset.balancedRehearsal,
    );

    return AcousticRigorProfile(
      preset: matchedPreset,
      isAdvancedMode: json['isAdvancedMode'] as bool? ?? false,
      minClarity: (json['minClarity'] as num?)?.toDouble() ?? 0.82,
      minConsecutiveFrames: (json['minConsecutiveFrames'] as num?)?.toInt() ?? 2,
      maxCentsDeviation: (json['maxCentsDeviation'] as num?)?.toDouble() ?? 35.0,
      noiseGateThreshold: (json['noiseGateThreshold'] as num?)?.toDouble() ?? 0.005,
      digitalGain: (json['digitalGain'] as num?)?.toDouble() ?? 1.0,
      enableDcBlocker: json['enableDcBlocker'] as bool? ?? true,
      enableInstrumentIsolation: json['enableInstrumentIsolation'] as bool? ?? true,
    );
  }
}
