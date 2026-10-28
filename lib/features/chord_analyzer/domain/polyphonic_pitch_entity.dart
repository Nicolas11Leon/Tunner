import 'chord_entity.dart';

/// Entidad inmutable que representa una voz o nota fundamental individual detectada
/// dentro de una señal acústica polifónica simultánea.
class DetectedPolyphonicVoice {
  final String noteName;
  final String noteNameInternational;
  final int octave;
  final int pitchClassIndex;
  final double frequencyHz;
  final int midiNumber;
  final double centsDeviation;
  final double salience;
  final String harmonicRole;

  const DetectedPolyphonicVoice({
    required this.noteName,
    required this.noteNameInternational,
    required this.octave,
    required this.pitchClassIndex,
    required this.frequencyHz,
    required this.midiNumber,
    required this.centsDeviation,
    required this.salience,
    required this.harmonicRole,
  });

  /// Retorna la desviación en cents formateada con signo explícito (ej. "+3 cents", "-2 cents").
  String get formattedCents {
    final sign = centsDeviation >= 0 ? '+' : '';
    return '$sign${centsDeviation.round()} cents';
  }

  /// Retorna la frecuencia fundamental formateada en Hz con un decimal (ej. "440.0 Hz").
  String get formattedFrequency => '${frequencyHz.toStringAsFixed(1)} Hz';

  /// Nombre completo de la nota con octava (ej. "Do4", "La2").
  String get fullNoteName => '$noteName$octave';

  /// Nombre internacional completo con octava (ej. "C4", "A2").
  String get fullNoteNameInternational => '$noteNameInternational$octave';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectedPolyphonicVoice &&
          runtimeType == other.runtimeType &&
          midiNumber == other.midiNumber;

  @override
  int get hashCode => midiNumber.hashCode;

  @override
  String toString() =>
      'Voice($fullNoteName, $formattedFrequency, ${(salience * 100).toStringAsFixed(0)}%)';
}

/// Resultado consolidado de la descomposición multitonal polifónica en tiempo real.
class PolyphonicMultiToneAnalysisResult {
  final List<DetectedPolyphonicVoice> voices;
  final ChordEntity chord;
  final String voicingName;
  final bool isSilence;

  const PolyphonicMultiToneAnalysisResult({
    required this.voices,
    required this.chord,
    required this.voicingName,
    this.isSilence = false,
  });

  int get polyphonyCount => voices.length;

  static final PolyphonicMultiToneAnalysisResult empty = PolyphonicMultiToneAnalysisResult(
    voices: const [],
    chord: ChordEntity.none,
    voicingName: 'Silencio',
    isSilence: true,
  );

  bool get hasVoices => voices.isNotEmpty;

  /// Retorna la nota más grave del acorde (el bajo).
  DetectedPolyphonicVoice? get bassVoice => voices.isNotEmpty ? voices.first : null;

  /// Retorna la nota más aguda del acorde (la voz superior).
  DetectedPolyphonicVoice? get sopranoVoice => voices.isNotEmpty ? voices.last : null;
}
