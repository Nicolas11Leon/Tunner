import 'dart:math' as math;
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
        assert(octave >= 0 && octave <= 8),
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

  /// Calcula la frecuencia en Hz de la nota fundamental según el registro y la octava.
  /// Fórmula canónica: f = a4Ref * 2^((rootMidiNumber - 69) / 12)
  double calculateFundamentalFrequency([double a4Ref = 440.0]) {
    return a4Ref * math.pow(2.0, (rootMidiNumber - 69.0) / 12.0);
  }

  /// Serializa la configuracion del dron armonico a JSON canonico.
  Map<String, dynamic> toJson() => {
        'rootNoteIndex': rootNoteIndex,
        'octave': octave,
        'includeFifth': includeFifth,
        'includeOctave': includeOctave,
        'timbre': timbre.name,
        'volume': volume,
        'harmonicBalance': harmonicBalance,
      };

  /// Reconstruye una instancia de [HarmonicDroneConfig] desde un mapa JSON.
  factory HarmonicDroneConfig.fromJson(Map<String, dynamic> json) {
    final rawTimbre = json['timbre'] as String?;
    final parsedTimbre = DroneTimbre.values.firstWhere(
      (t) => t.name == rawTimbre,
      orElse: () => DroneTimbre.warmFlute,
    );
    return HarmonicDroneConfig(
      rootNoteIndex: ((json['rootNoteIndex'] as num?)?.toInt() ?? 0).clamp(0, 11),
      octave: ((json['octave'] as num?)?.toInt() ?? 3).clamp(0, 8),
      includeFifth: json['includeFifth'] as bool? ?? true,
      includeOctave: json['includeOctave'] as bool? ?? false,
      timbre: parsedTimbre,
      volume: ((json['volume'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0),
      harmonicBalance: ((json['harmonicBalance'] as num?)?.toDouble() ?? 0.35).clamp(0.0, 1.0),
    );
  }

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
