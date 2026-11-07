import 'port_id.dart';
import 'signal_type.dart';

/// Clase base sellada/inmutable para todos los eventos de señal transmitidos en el bus.
sealed class AtomicSignalEvent {
  /// Identificador único del evento.
  final String eventId;

  /// Puerto de origen que originó la señal (o 'broadcast' para señales globales).
  final PortId sourcePort;

  /// Tipo de señal transportada.
  final SignalType signalType;

  /// Marca de tiempo en microsegundos desde el inicio de la sesión.
  final int timestampMicros;

  const AtomicSignalEvent({
    required this.eventId,
    required this.sourcePort,
    required this.signalType,
    required this.timestampMicros,
  });
}

/// Evento atómico de pulso temporal y reloj rítmico (Metrónomo / Secuenciador).
class ClockTickEvent extends AtomicSignalEvent {
  /// Número ordinal del tick dentro del compás actual (ej: 0, 1, 2, 3).
  final int tickIndex;

  /// Número total de pulsos en el compás (ej: 4 para 4/4, 3 para 3/4).
  final int beatsPerBar;

  /// Tempo actual en pulsos por minuto (BPM).
  final double bpm;

  /// Indica si este tick corresponde al primer pulso fuerte del compás (Downbeat).
  final bool isDownbeat;

  /// Duración calculada de este tick en milisegundos.
  final double tickDurationMs;

  const ClockTickEvent({
    required super.eventId,
    required super.sourcePort,
    required super.timestampMicros,
    required this.tickIndex,
    required this.beatsPerBar,
    required this.bpm,
    this.isDownbeat = false,
    required this.tickDurationMs,
  }) : super(signalType: SignalType.temporalClock);
}

/// Evento atómico de búfer de audio PCM (Micrófono / Reproductor / Grabador).
class AudioPcmEvent extends AtomicSignalEvent {
  /// Muestras de audio PCM normalizadas en el rango [-1.0, 1.0].
  final List<double> samples;

  /// Frecuencia de muestreo en Hz (ej: 44100, 48000).
  final int sampleRate;

  /// Nivel de energía RMS calculado del bloque.
  final double rmsLevel;

  const AudioPcmEvent({
    required super.eventId,
    required super.sourcePort,
    required super.timestampMicros,
    required this.samples,
    required this.sampleRate,
    required this.rmsLevel,
  }) : super(signalType: SignalType.audioPcm);
}

/// Evento atómico de afinación y frecuencia fundamental detectada (Afinador MPM/NSDF).
class PitchDetectionEvent extends AtomicSignalEvent {
  /// Frecuencia fundamental $f_0$ en Hz.
  final double frequencyHz;

  /// Nombre de la nota musical identificada (ej: "A4", "C#3").
  final String noteName;

  /// Desviación tonal en cents respecto al tono temperado ($\pm 50.0$ o microtonal).
  final double centsOffset;

  /// Claridad de la periodicidad armónica en el rango [0.0, 1.0].
  final double clarity;

  /// Amplitud de la señal asociada.
  final double amplitude;

  const PitchDetectionEvent({
    required super.eventId,
    required super.sourcePort,
    required super.timestampMicros,
    required this.frequencyHz,
    required this.noteName,
    required this.centsOffset,
    required this.clarity,
    required this.amplitude,
  }) : super(signalType: SignalType.pitchEvents);
}

/// Tipo de comando de transporte global.
enum TransportCommand { play, pause, stop, record, toggleRecord, rewind }

/// Evento atómico de control de transporte (Consola / Botonera de Transporte).
class TransportControlEvent extends AtomicSignalEvent {
  /// Comando de transporte ordenado.
  final TransportCommand command;

  const TransportControlEvent({
    required super.eventId,
    required super.sourcePort,
    required super.timestampMicros,
    required this.command,
  }) : super(signalType: SignalType.transportControl);
}

/// Evento atómico de calibración tonal y temperamento histórico.
class TuningCalibrationEvent extends AtomicSignalEvent {
  /// Frecuencia base de calibración de $A_4$ en Hz (ej: 440.0, 432.0, 415.0).
  final double referenceA4Hz;

  /// Nombre del temperamento (ej: 'equal', 'pythagorean', 'meantone').
  final String temperamentName;

  /// Desviaciones microtonales personalizadas por nota cromática en cents.
  final Map<int, double> chromaticDetunings;

  const TuningCalibrationEvent({
    required super.eventId,
    required super.sourcePort,
    required super.timestampMicros,
    required this.referenceA4Hz,
    required this.temperamentName,
    this.chromaticDetunings = const {},
  }) : super(signalType: SignalType.tuningCalibration);
}

/// Evento atómico de magnitudes espectrales FFT (Espectrograma / Analizador).
class SpectralDataEvent extends AtomicSignalEvent {
  /// Vector de magnitudes normalizadas por bin de frecuencia.
  final List<double> magnitudes;

  /// Frecuencia de muestreo original en Hz.
  final int sampleRate;

  /// Tamaño de ventana FFT utilizado (ej: 1024, 2048, 4096).
  final int fftSize;

  const SpectralDataEvent({
    required super.eventId,
    required super.sourcePort,
    required super.timestampMicros,
    required this.magnitudes,
    required this.sampleRate,
    required this.fftSize,
  }) : super(signalType: SignalType.spectralData);
}
