import 'dart:typed_data';

/// Puerto de dominio puro para controlar el reproductor de partituras desde el terminal sin acoplar a `features/`.
abstract class ITerminalScorePort {
  bool get isPlaying;
  int get currentMeasureIndex;
  int get currentSubTick;
  double get bpm;
  set bpm(double value);
  bool get hasActiveScore;

  void startActiveScore();
  void pausePlayback();
  void stopPlayback();
}

/// Puerto de dominio puro para leer metadatos y exportar proyectos desde el terminal sin acoplar a `TunerViewModel`.
abstract class ITerminalProjectPort {
  String get activeTitle;
  String get activeComposer;
  int get bpm;

  void updateBpm(int bpm);
  Uint8List exportCurrentProjectToTunner({String? projectTitle});
}

/// Instantánea pura de un ítem de entrenamiento auditivo para el terminal.
class TerminalEarTrainingItemSnapshot {
  final String id;
  final String name;
  final double semitones;
  final double stabilityDays;
  final int repetitions;
  final double retentionPercent;
  final DateTime nextReviewDate;

  const TerminalEarTrainingItemSnapshot({
    required this.id,
    required this.name,
    required this.semitones,
    required this.stabilityDays,
    required this.repetitions,
    required this.retentionPercent,
    required this.nextReviewDate,
  });
}

/// Instantánea pura del resultado de evaluación de entrenamiento auditivo.
class TerminalEarTrainingSubmitSnapshot {
  final TerminalEarTrainingItemSnapshot updatedItem;
  final int qualityGrade;
  final double centsError;
  final double responseTimeSeconds;
  final String cognitiveFeedback;

  const TerminalEarTrainingSubmitSnapshot({
    required this.updatedItem,
    required this.qualityGrade,
    required this.centsError,
    required this.responseTimeSeconds,
    required this.cognitiveFeedback,
  });
}

/// Puerto de dominio puro para el motor Ebbinghaus desde el terminal.
abstract class ITerminalEarTrainingPort {
  List<TerminalEarTrainingItemSnapshot> getAllItems(DateTime now);
  List<TerminalEarTrainingItemSnapshot> getDueItems(DateTime now);
  TerminalEarTrainingItemSnapshot? getItem(String id, DateTime now);
  double overallRetentionAverage(DateTime now);
  TerminalEarTrainingSubmitSnapshot submitAnswer(
    String itemId, {
    required bool isCorrect,
    required double centsError,
    required double responseTimeSeconds,
    required DateTime timestamp,
  });
  void reset();
}

/// Instantánea pura del resultado de estabilidad vocal.
class TerminalVocalEvalSnapshot {
  final String evaluationId;
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

  const TerminalVocalEvalSnapshot({
    required this.evaluationId,
    required this.targetFrequencyHz,
    required this.measuredMeanFrequencyHz,
    required this.centsDeviation,
    required this.jitterPercent,
    required this.shimmerPercent,
    required this.vibratoRateHz,
    required this.vibratoDepthCents,
    required this.overallScore,
    required this.classificationLabel,
    required this.payloadHashSha256,
  });
}

/// Puerto de dominio puro para evaluación vocal y generación de certificados PDF desde el terminal.
abstract class ITerminalVocalPedagogyPort {
  TerminalVocalEvalSnapshot evaluate({
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  });

  Uint8List generateCertificatePdf({
    required String studentName,
    required List<double> frequenciesHz,
    required List<double> amplitudes,
    required double targetFrequencyHz,
  });
}

/// Conversor puro de nombre de nota musical (ej. Do4, C4, Fa#4) a número MIDI [0..127].
int terminalNoteNameToMidi(String noteName) {
  if (noteName.isEmpty || noteName == '--') return -1;
  final clean = noteName.trim();
  final octaveMatch = RegExp(r'[-+]?[0-9]+').firstMatch(clean);
  final octave = octaveMatch != null ? int.tryParse(octaveMatch.group(0)!) ?? 4 : 4;
  final nameWithoutOctave = clean.replaceAll(RegExp(r'[-+]?[0-9]+'), '').trim().toLowerCase();

  const Map<String, int> semitones = {
    'do': 0, 'c': 0,
    'do#': 1, 'reb': 1, 'c#': 1, 'db': 1,
    're': 2, 'd': 2,
    're#': 3, 'mib': 3, 'd#': 3, 'eb': 3,
    'mi': 4, 'e': 4,
    'fa': 5, 'f': 5,
    'fa#': 6, 'solb': 6, 'f#': 6, 'gb': 6,
    'sol': 7, 'g': 7,
    'sol#': 8, 'lab': 8, 'g#': 8, 'ab': 8,
    'la': 9, 'a': 9,
    'la#': 10, 'sib': 10, 'a#': 10, 'bb': 10,
    'si': 11, 'b': 11,
  };

  final semitone = semitones[nameWithoutOctave];
  if (semitone == null) return -1;
  return (((octave + 1) * 12) + semitone).clamp(0, 127);
}
