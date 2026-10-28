import 'drone_timbre.dart';

/// Configuracion inmutable para el generador de tono pedal en el estudio de dron armónico.
/// Pure Dart: Cero dependencias de Flutter UI.
class HarmonicDroneConfig {
  /// Indice de la nota fundamental dentro de la escala cromatica (0: Do, 1: Do#, ..., 9: La, 11: Si).
  final int rootNoteIndex;

  /// Octava de registro acustico (tipicamente 2, 3 o 4 para instrumentos de conservatorio).
  final int octave;

  /// Indica si se incluye la quinta armonica superior (7 semitonos por encima de la fundamental).
  final bool includeFifth;

  /// Indica si se incluye la octava superior de refuerzo (12 semitonos por encima).
  final bool includeOctave;

  /// Timbre sintetizado de la envolvente sonora.
  final DroneTimbre timbre;

  /// Ganancia general normalizada (0.0 a 1.0).
  final double volume;

  /// Balance armónico entre la fundamental y las componentes secundarias (0.0 a 1.0).
  final double harmonicBalance;

  const HarmonicDroneConfig({
    this.rootNoteIndex = 0, // Do
    this.octave = 3,
    this.includeFifth = true,
    this.includeOctave = false,
    this.timbre = DroneTimbre.warmFlute,
    this.volume = 0.7,
    this.harmonicBalance = 0.35,
  })  : assert(rootNoteIndex >= 0 && rootNoteIndex <= 11),
        assert(octave >= 1 && octave <= 6),
        assert(volume >= 0.0 && volume <= 1.0),
        assert(harmonicBalance >= 0.0 && harmonicBalance <= 1.0);

  static const List<String> chromaticNoteNames = [
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

  /// Nombre de conservatorio de la nota fundamental con su octava (ej. "Do3", "La2", "Re4").
  String get rootDisplayName => '${chromaticNoteNames[rootNoteIndex]}$octave';

  /// Nombre de la quinta armónica generada (ej. si la raíz es Do, la quinta es Sol).
  String get fifthDisplayName => '${chromaticNoteNames[(rootNoteIndex + 7) % 12]}${rootNoteIndex + 7 >= 12 ? octave + 1 : octave}';

  /// Nombre de la octava superior generada (ej. si la raíz es Do3, la octava es Do4).
  String get octaveDisplayName => '${chromaticNoteNames[rootNoteIndex]}${octave + 1}';

  /// Calcula el numero de nota MIDI absoluto para la fundamental.
  /// En estandar MIDI, Do4 (C4) es 60, Do3 (C3) es 48, Do2 (C2) es 36.
  int get rootMidiNumber => (octave + 1) * 12 + rootNoteIndex;

  /// Crea una copia inmutable modificando unicamente los campos provistos.
  HarmonicDroneConfig copyWith({
    int? rootNoteIndex,
    int? octave,
    bool? includeFifth,
    bool? includeOctave,
    DroneTimbre? timbre,
    double? volume,
    double? harmonicBalance,
  }) {
    return HarmonicDroneConfig(
      rootNoteIndex: rootNoteIndex ?? this.rootNoteIndex,
      octave: octave ?? this.octave,
      includeFifth: includeFifth ?? this.includeFifth,
      includeOctave: includeOctave ?? this.includeOctave,
      timbre: timbre ?? this.timbre,
      volume: volume ?? this.volume,
      harmonicBalance: harmonicBalance ?? this.harmonicBalance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HarmonicDroneConfig &&
          runtimeType == other.runtimeType &&
          rootNoteIndex == other.rootNoteIndex &&
          octave == other.octave &&
          includeFifth == other.includeFifth &&
          includeOctave == other.includeOctave &&
          timbre == other.timbre &&
          volume == other.volume &&
          harmonicBalance == other.harmonicBalance;

  @override
  int get hashCode =>
      rootNoteIndex.hashCode ^
      octave.hashCode ^
      includeFifth.hashCode ^
      includeOctave.hashCode ^
      timbre.hashCode ^
      volume.hashCode ^
      harmonicBalance.hashCode;
}
