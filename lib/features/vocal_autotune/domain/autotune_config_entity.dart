/// Tipos de escala musical soportados para la cuantización tonal en Vocal AutoTune.
enum VocalScaleType {
  chromatic,
  major,
  naturalMinor,
  harmonicMinor,
  majorPentatonic,
  minorPentatonic,
  blues,
}

extension VocalScaleTypeExtension on VocalScaleType {
  String get displayName {
    switch (this) {
      case VocalScaleType.chromatic:
        return 'Cromática (12 Semitonos)';
      case VocalScaleType.major:
        return 'Mayor Natural (Jónica)';
      case VocalScaleType.naturalMinor:
        return 'Menor Natural (Eólica)';
      case VocalScaleType.harmonicMinor:
        return 'Menor Armónica';
      case VocalScaleType.majorPentatonic:
        return 'Pentatónica Mayor';
      case VocalScaleType.minorPentatonic:
        return 'Pentatónica Menor';
      case VocalScaleType.blues:
        return 'Escala Blues';
    }
  }

  /// Patrón de intervalos en semitonos relativos a la tónica.
  List<int> get intervals {
    switch (this) {
      case VocalScaleType.chromatic:
        return const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      case VocalScaleType.major:
        return const [0, 2, 4, 5, 7, 9, 11];
      case VocalScaleType.naturalMinor:
        return const [0, 2, 3, 5, 7, 8, 10];
      case VocalScaleType.harmonicMinor:
        return const [0, 2, 3, 5, 7, 8, 11];
      case VocalScaleType.majorPentatonic:
        return const [0, 2, 4, 7, 9];
      case VocalScaleType.minorPentatonic:
        return const [0, 3, 5, 7, 10];
      case VocalScaleType.blues:
        return const [0, 3, 5, 6, 7, 10];
    }
  }
}

/// Nombres de notas musicales estándar para la raíz o tónica.
const List<String> kChromaticNoteNames = [
  'Do',
  'Do#',
  'Re',
  'Re#',
  'Mi',
  'Fa',
  'Fa#',
  'Sol',
  'Sol#',
  'La',
  'La#',
  'Si',
];

const List<String> kChromaticNoteNamesInternational = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

/// Entidad inmutable que encapsula todos los parámetros acústicos de configuración de AutoTune.
class AutoTuneConfigEntity {
  final bool isEnabled;
  final int scaleRoot; // 0 = Do (C), ..., 11 = Si (B)
  final VocalScaleType scaleType;
  final double retuneSpeedMs; // 0.0 = Hard Tune instantáneo, 15-50 = Natural
  final double correctionAmount; // 0.0 (bypass) a 1.0 (100% afinado)
  final bool formantPreservation; // Preservación espectral del tracto vocal
  final double leadVocalMix; // 0.0 (seco/dry) a 1.0 (procesado/wet)
  final double a4Reference; // Frecuencia de concierto A4 calibrada (default 440.0 Hz)

  const AutoTuneConfigEntity({
    this.isEnabled = false,
    this.scaleRoot = 0,
    this.scaleType = VocalScaleType.chromatic,
    this.retuneSpeedMs = 25.0,
    this.correctionAmount = 1.0,
    this.formantPreservation = true,
    this.leadVocalMix = 1.0,
    this.a4Reference = 440.0,
  });

  /// Nombre legible de la nota raíz activa (ej. "Do / C").
  String get rootNoteDisplayName {
    final idx = (scaleRoot % 12 + 12) % 12;
    return '${kChromaticNoteNames[idx]} (${kChromaticNoteNamesInternational[idx]})';
  }

  /// Conjunto de clases de altura (0 a 11) permitidas por la escala y tónica activa.
  Set<int> get allowedPitchClasses {
    final set = <int>{};
    for (final interval in scaleType.intervals) {
      set.add((scaleRoot + interval) % 12);
    }
    return set;
  }

  /// Comprueba si una clase de altura dada (0..11) pertenece a la escala configurada.
  bool isPitchClassAllowed(int pitchClass) {
    final normalized = (pitchClass % 12 + 12) % 12;
    return allowedPitchClasses.contains(normalized);
  }

  /// Preset: Afinación Transparente de Estudio (Natural).
  factory AutoTuneConfigEntity.naturalStudio({int scaleRoot = 0, VocalScaleType scaleType = VocalScaleType.major}) {
    return AutoTuneConfigEntity(
      isEnabled: true,
      scaleRoot: scaleRoot,
      scaleType: scaleType,
      retuneSpeedMs: 35.0,
      correctionAmount: 0.85,
      formantPreservation: true,
      leadVocalMix: 1.0,
    );
  }

  /// Preset: Pop Suave y Pulido (Transición rápida con formantes naturales).
  factory AutoTuneConfigEntity.smoothPop({int scaleRoot = 0, VocalScaleType scaleType = VocalScaleType.major}) {
    return AutoTuneConfigEntity(
      isEnabled: true,
      scaleRoot: scaleRoot,
      scaleType: scaleType,
      retuneSpeedMs: 15.0,
      correctionAmount: 0.95,
      formantPreservation: true,
      leadVocalMix: 1.0,
    );
  }

  /// Preset: Hard Tune Urbano (Salto instantáneo sin inercia estilo música urbana).
  factory AutoTuneConfigEntity.hardTuneUrban({int scaleRoot = 0, VocalScaleType scaleType = VocalScaleType.naturalMinor}) {
    return AutoTuneConfigEntity(
      isEnabled: true,
      scaleRoot: scaleRoot,
      scaleType: scaleType,
      retuneSpeedMs: 0.0,
      correctionAmount: 1.0,
      formantPreservation: true,
      leadVocalMix: 1.0,
    );
  }

  /// Preset: Armonizador / Vocal Doubler (Mezcla 50/50 seco y afinado).
  factory AutoTuneConfigEntity.vocalDoubler({int scaleRoot = 0, VocalScaleType scaleType = VocalScaleType.chromatic}) {
    return AutoTuneConfigEntity(
      isEnabled: true,
      scaleRoot: scaleRoot,
      scaleType: scaleType,
      retuneSpeedMs: 25.0,
      correctionAmount: 0.70,
      formantPreservation: true,
      leadVocalMix: 0.50,
    );
  }

  AutoTuneConfigEntity copyWith({
    bool? isEnabled,
    int? scaleRoot,
    VocalScaleType? scaleType,
    double? retuneSpeedMs,
    double? correctionAmount,
    bool? formantPreservation,
    double? leadVocalMix,
    double? a4Reference,
  }) {
    return AutoTuneConfigEntity(
      isEnabled: isEnabled ?? this.isEnabled,
      scaleRoot: scaleRoot ?? this.scaleRoot,
      scaleType: scaleType ?? this.scaleType,
      retuneSpeedMs: retuneSpeedMs ?? this.retuneSpeedMs,
      correctionAmount: correctionAmount ?? this.correctionAmount,
      formantPreservation: formantPreservation ?? this.formantPreservation,
      leadVocalMix: leadVocalMix ?? this.leadVocalMix,
      a4Reference: a4Reference ?? this.a4Reference,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'scaleRoot': scaleRoot,
      'scaleType': scaleType.name,
      'retuneSpeedMs': retuneSpeedMs,
      'correctionAmount': correctionAmount,
      'formantPreservation': formantPreservation,
      'leadVocalMix': leadVocalMix,
      'a4Reference': a4Reference,
    };
  }

  factory AutoTuneConfigEntity.fromJson(Map<String, dynamic> json) {
    return AutoTuneConfigEntity(
      isEnabled: json['isEnabled'] as bool? ?? false,
      scaleRoot: json['scaleRoot'] as int? ?? 0,
      scaleType: VocalScaleType.values.firstWhere(
        (v) => v.name == json['scaleType'],
        orElse: () => VocalScaleType.chromatic,
      ),
      retuneSpeedMs: (json['retuneSpeedMs'] as num?)?.toDouble() ?? 25.0,
      correctionAmount: (json['correctionAmount'] as num?)?.toDouble() ?? 1.0,
      formantPreservation: json['formantPreservation'] as bool? ?? true,
      leadVocalMix: (json['leadVocalMix'] as num?)?.toDouble() ?? 1.0,
      a4Reference: (json['a4Reference'] as num?)?.toDouble() ?? 440.0,
    );
  }
}
