import 'dart:async';
import 'studio_os_audio_event.dart';

/// Micro-Kernel en proceso y bus de eventos acústicos en tiempo real para Tunner Studio OS.
///
/// Gestiona la recepción y distribución determinista de eventos derivados de Tunner DSL
/// o de la consola interactiva, aplicando las mutaciones a través de manejadores registrados
/// y exponiendo un flujo reactivo inmutable (`eventStream`) para observabilidad.
class StudioOsAudioKernel {
  final StreamController<StudioOsAudioEvent> _eventController =
      StreamController<StudioOsAudioEvent>.broadcast();

  final List<StudioOsAudioEvent> _eventHistory = [];
  final int maxHistoryLength;

  // Manejadores atómicos de hardware y síntesis
  Future<void> Function(double bpm)? onTempoChanged;
  Future<void> Function(String channel)? onChannelDeclared;
  Future<void> Function(String source, String destination)? onConnectionChanged;
  Future<void> Function(String target, String parameter, dynamic value, String? unit)? onParameterChanged;
  Future<void> Function(String pitch, double frequencyHz, int midiNote, String durationFraction, double velocity)? onNoteTriggered;
  Future<void> Function(List<String> pitches, List<double> frequenciesHz, List<int> midiNotes, String durationFraction, double velocity)? onChordTriggered;
  Future<void> Function(String durationFraction)? onRestTriggered;
  Future<void> Function(StudioOsNoteEvent event)? onScheduledNoteTriggered;
  Future<void> Function(StudioOsChordEvent event)? onScheduledChordTriggered;
  Future<void> Function(StudioOsRestEvent event)? onScheduledRestTriggered;
  Future<void> Function(String action)? onTransportChanged;

  StudioOsAudioKernel({
    this.maxHistoryLength = 100,
    this.onTempoChanged,
    this.onChannelDeclared,
    this.onConnectionChanged,
    this.onParameterChanged,
    this.onNoteTriggered,
    this.onChordTriggered,
    this.onRestTriggered,
    this.onScheduledNoteTriggered,
    this.onScheduledChordTriggered,
    this.onScheduledRestTriggered,
    this.onTransportChanged,
  });

  /// Flujo reactivo de eventos acústicos en tiempo real.
  Stream<StudioOsAudioEvent> get eventStream => _eventController.stream;

  /// Historial de eventos despachados en orden cronológico.
  List<StudioOsAudioEvent> get eventHistory => List.unmodifiable(_eventHistory);

  int get _nowMicroseconds => DateTime.now().microsecondsSinceEpoch;

  void _recordEvent(StudioOsAudioEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    _eventHistory.add(event);
    if (_eventHistory.length > maxHistoryLength) {
      _eventHistory.removeAt(0);
    }
  }

  /// Despacha un cambio de tempo en el reloj maestro.
  Future<void> dispatchTempo(double bpm) async {
    final event = StudioOsTempoEvent(
      bpm: bpm,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onTempoChanged != null) {
      await onTempoChanged!(bpm);
    }
  }

  /// Despacha la declaración de un canal virtual de audio.
  Future<void> dispatchDeclareChannel(String channelName) async {
    final event = StudioOsChannelDeclaredEvent(
      channelName: channelName,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onChannelDeclared != null) {
      await onChannelDeclared!(channelName);
    }
  }

  /// Despacha una conexión de enrutamiento en la matriz de parcheo.
  Future<void> dispatchConnect(String source, String destination) async {
    final event = StudioOsConnectionEvent(
      source: source,
      destination: destination,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onConnectionChanged != null) {
      await onConnectionChanged!(source, destination);
    }
  }

  /// Despacha la asignación o modulación de un parámetro de dispositivo.
  Future<void> dispatchSetParameter(
    String target,
    String parameter,
    dynamic value, {
    String? unit,
  }) async {
    final event = StudioOsParameterEvent(
      target: target,
      parameter: parameter,
      value: value,
      unit: unit,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onParameterChanged != null) {
      await onParameterChanged!(target, parameter, value, unit);
    }
  }

  /// Despacha la emisión de una nota tonal individual.
  Future<void> dispatchNote(
    String pitch,
    double frequencyHz,
    int midiNote,
    String durationFraction, {
    double velocity = 0.8,
    int scheduledOffsetMs = 0,
    int durationMs = 0,
  }) async {
    final event = StudioOsNoteEvent(
      pitch: pitch,
      frequencyHz: frequencyHz,
      midiNote: midiNote,
      durationFraction: durationFraction,
      velocity: velocity,
      scheduledOffsetMs: scheduledOffsetMs,
      durationMs: durationMs,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onScheduledNoteTriggered != null) {
      await onScheduledNoteTriggered!(event);
    }
    if (onNoteTriggered != null) {
      await onNoteTriggered!(pitch, frequencyHz, midiNote, durationFraction, velocity);
    }
  }

  /// Despacha la emisión de un acorde polifónico simultáneo.
  Future<void> dispatchChord(
    List<String> pitches,
    List<double> frequenciesHz,
    List<int> midiNotes,
    String durationFraction, {
    double velocity = 0.8,
    int scheduledOffsetMs = 0,
    int durationMs = 0,
  }) async {
    final event = StudioOsChordEvent(
      pitches: pitches,
      frequenciesHz: frequenciesHz,
      midiNotes: midiNotes,
      durationFraction: durationFraction,
      velocity: velocity,
      scheduledOffsetMs: scheduledOffsetMs,
      durationMs: durationMs,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onScheduledChordTriggered != null) {
      await onScheduledChordTriggered!(event);
    }
    if (onChordTriggered != null) {
      await onChordTriggered!(pitches, frequenciesHz, midiNotes, durationFraction, velocity);
    }
  }

  /// Despacha un silencio métrico.
  Future<void> dispatchRest(
    String durationFraction, {
    int scheduledOffsetMs = 0,
    int durationMs = 0,
  }) async {
    final event = StudioOsRestEvent(
      durationFraction: durationFraction,
      scheduledOffsetMs: scheduledOffsetMs,
      durationMs: durationMs,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onScheduledRestTriggered != null) {
      await onScheduledRestTriggered!(event);
    }
    if (onRestTriggered != null) {
      await onRestTriggered!(durationFraction);
    }
  }

  /// Despacha un comando de transporte ('play', 'pause', 'stop').
  Future<void> dispatchTransport(String action) async {
    final event = StudioOsTransportEvent(
      action: action,
      timestampMicroseconds: _nowMicroseconds,
    );
    _recordEvent(event);
    if (onTransportChanged != null) {
      await onTransportChanged!(action);
    }
  }

  /// Limpia el historial acumulado de eventos en memoria.
  void clearHistory() {
    _eventHistory.clear();
  }

  /// Cierra el stream controller para evitar fugas de memoria.
  void dispose() {
    _eventController.close();
  }
}
