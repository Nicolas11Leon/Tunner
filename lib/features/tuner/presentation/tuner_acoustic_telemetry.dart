/// Instantánea inmutable de telemetría acústica de alta frecuencia (30-60 Hz).
/// Permite reconstrucciones atómicas vía [ValueListenableBuilder] sin redibujar árboles completos.
class TunerAcousticTelemetry {
  final double frequency;
  final double cents;
  final String noteName;
  final double micRmsLevel;
  final bool isRecording;

  const TunerAcousticTelemetry({
    this.frequency = 0.0,
    this.cents = 0.0,
    this.noteName = '--',
    this.micRmsLevel = 0.0,
    this.isRecording = false,
  });

  TunerAcousticTelemetry copyWith({
    double? frequency,
    double? cents,
    String? noteName,
    double? micRmsLevel,
    bool? isRecording,
  }) {
    return TunerAcousticTelemetry(
      frequency: frequency ?? this.frequency,
      cents: cents ?? this.cents,
      noteName: noteName ?? this.noteName,
      micRmsLevel: micRmsLevel ?? this.micRmsLevel,
      isRecording: isRecording ?? this.isRecording,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TunerAcousticTelemetry &&
        other.frequency == frequency &&
        other.cents == cents &&
        other.noteName == noteName &&
        other.micRmsLevel == micRmsLevel &&
        other.isRecording == isRecording;
  }

  @override
  int get hashCode => Object.hash(
        frequency,
        cents,
        noteName,
        micRmsLevel,
        isRecording,
      );
}
