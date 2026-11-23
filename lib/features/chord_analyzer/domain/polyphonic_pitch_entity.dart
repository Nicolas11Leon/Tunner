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

  Map<String, dynamic> toJson() {
    return {
      'noteName': noteName,
      'noteNameInternational': noteNameInternational,
      'octave': octave,
      'pitchClassIndex': pitchClassIndex,
      'frequencyHz': frequencyHz,
      'midiNumber': midiNumber,
      'centsDeviation': centsDeviation,
      'salience': salience,
      'harmonicRole': harmonicRole,
      'fullNoteName': fullNoteName,
      'fullNoteNameInternational': fullNoteNameInternational,
    };
  }

  factory DetectedPolyphonicVoice.fromJson(Map<String, dynamic> json) {
    return DetectedPolyphonicVoice(
      noteName: json['noteName'] as String? ?? '',
      noteNameInternational: json['noteNameInternational'] as String? ?? '',
      octave: (json['octave'] as num?)?.toInt() ?? 4,
      pitchClassIndex: (json['pitchClassIndex'] as num?)?.toInt() ?? 0,
      frequencyHz: (json['frequencyHz'] as num?)?.toDouble() ?? 0.0,
      midiNumber: (json['midiNumber'] as num?)?.toInt() ?? 60,
      centsDeviation: (json['centsDeviation'] as num?)?.toDouble() ?? 0.0,
      salience: (json['salience'] as num?)?.toDouble() ?? 0.0,
      harmonicRole: json['harmonicRole'] as String? ?? 'Voz Polifonica',
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'voices': voices.map((v) => v.toJson()).toList(),
      'chord': chord.toJson(),
      'voicingName': voicingName,
      'isSilence': isSilence,
      'polyphonyCount': polyphonyCount,
      'bassVoice': bassVoice?.toJson(),
      'sopranoVoice': sopranoVoice?.toJson(),
    };
  }

  factory PolyphonicMultiToneAnalysisResult.fromJson(Map<String, dynamic> json) {
    final voicesList = (json['voices'] as List<dynamic>?)
            ?.map((e) => DetectedPolyphonicVoice.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <DetectedPolyphonicVoice>[];
    final chordMap = json['chord'] as Map<String, dynamic>?;
    return PolyphonicMultiToneAnalysisResult(
      voices: voicesList,
      chord: chordMap != null ? ChordEntity.fromJson(chordMap) : ChordEntity.none,
      voicingName: json['voicingName'] as String? ?? 'Silencio',
      isSilence: json['isSilence'] as bool? ?? false,
    );
  }
}
