/// Clase base inmutable para todos los eventos emitidos por el bus del micro-kernel Tunner Studio OS.
abstract class StudioOsAudioEvent {
  /// Marca temporal en microsegundos cuando se generó el evento.
  final int timestampMicroseconds;

  const StudioOsAudioEvent({
    required this.timestampMicroseconds,
  });

  /// Tipo de evento para propósitos de telemetría y registro legible.
  String get eventType;
}

/// Evento de cambio de tempo en el reloj maestro de transporte.
class StudioOsTempoEvent extends StudioOsAudioEvent {
  final double bpm;

  const StudioOsTempoEvent({
    required this.bpm,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'TEMPO';

  @override
  String toString() => 'StudioOsTempoEvent(bpm: $bpm)';
}

/// Evento de declaración y registro de canal virtual de estudio.
class StudioOsChannelDeclaredEvent extends StudioOsAudioEvent {
  final String channelName;

  const StudioOsChannelDeclaredEvent({
    required this.channelName,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'CHANNEL_DECLARED';

  @override
  String toString() => 'StudioOsChannelDeclaredEvent(channel: $channelName)';
}

/// Evento de enrutamiento o parcheo de audio entre nodos.
class StudioOsConnectionEvent extends StudioOsAudioEvent {
  final String source;
  final String destination;

  const StudioOsConnectionEvent({
    required this.source,
    required this.destination,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'CONNECTION';

  @override
  String toString() => 'StudioOsConnectionEvent($source -> $destination)';
}

/// Evento de modificación de parámetro en dispositivos de estudio.
class StudioOsParameterEvent extends StudioOsAudioEvent {
  final String target;
  final String parameter;
  final dynamic value;
  final String? unit;

  const StudioOsParameterEvent({
    required this.target,
    required this.parameter,
    required this.value,
    this.unit,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'PARAMETER_SET';

  @override
  String toString() =>
      'StudioOsParameterEvent($target.$parameter = $value${unit != null ? " $unit" : ""})';
}

/// Evento de disparo de nota musical individual.
class StudioOsNoteEvent extends StudioOsAudioEvent {
  final String pitch;
  final double frequencyHz;
  final int midiNote;
  final String durationFraction;
  final double velocity;
  final int scheduledOffsetMs;
  final int durationMs;

  const StudioOsNoteEvent({
    required this.pitch,
    required this.frequencyHz,
    required this.midiNote,
    required this.durationFraction,
    this.velocity = 0.8,
    this.scheduledOffsetMs = 0,
    this.durationMs = 0,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'NOTE_ON';

  @override
  String toString() =>
      'StudioOsNoteEvent($pitch, freq: ${frequencyHz.toStringAsFixed(2)} Hz, midi: $midiNote, dur: $durationFraction, offsetMs: $scheduledOffsetMs, durationMs: $durationMs, vel: $velocity)';
}

/// Evento de disparo de acorde polifónico simultáneo.
class StudioOsChordEvent extends StudioOsAudioEvent {
  final List<String> pitches;
  final List<double> frequenciesHz;
  final List<int> midiNotes;
  final String durationFraction;
  final double velocity;
  final int scheduledOffsetMs;
  final int durationMs;

  const StudioOsChordEvent({
    required this.pitches,
    required this.frequenciesHz,
    required this.midiNotes,
    required this.durationFraction,
    this.velocity = 0.8,
    this.scheduledOffsetMs = 0,
    this.durationMs = 0,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'CHORD_ON';

  @override
  String toString() =>
      'StudioOsChordEvent([${pitches.join(", ")}], dur: $durationFraction, offsetMs: $scheduledOffsetMs, durationMs: $durationMs, vel: $velocity)';
}

/// Evento de silencio métrico.
class StudioOsRestEvent extends StudioOsAudioEvent {
  final String durationFraction;
  final int scheduledOffsetMs;
  final int durationMs;

  const StudioOsRestEvent({
    required this.durationFraction,
    this.scheduledOffsetMs = 0,
    this.durationMs = 0,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'REST';

  @override
  String toString() =>
      'StudioOsRestEvent(dur: $durationFraction, offsetMs: $scheduledOffsetMs, durationMs: $durationMs)';
}

/// Evento de transporte ('play', 'pause', 'stop').
class StudioOsTransportEvent extends StudioOsAudioEvent {
  final String action;

  const StudioOsTransportEvent({
    required this.action,
    required super.timestampMicroseconds,
  });

  @override
  String get eventType => 'TRANSPORT';

  @override
  String toString() => 'StudioOsTransportEvent(action: $action)';
}
