/// Tipo de señal transportada a través del bus de datos y puertos de los módulos.
library;

/// Clasificación tipada de señales entre módulos interactivos.
enum SignalType {
  /// Flujo continuo de muestras de audio PCM (`List<double>` normalizado en [-1.0, 1.0]).
  audioPcm('audio_pcm', 'Audio PCM (Onda de Sonido)'),

  /// Eventos discretos de afinación y frecuencia (Hz, nota, desviación en cents, amplitud).
  pitchEvents('pitch_events', 'Eventos de Afinación / Pitch'),

  /// Eventos estructurados de partitura (notas musicales, duraciones, silencios SMuFL).
  musicalNotes('musical_notes', 'Flujo de Notas Musicales / Partitura'),

  /// Pulsos de sincronización temporal y sub-ticks de metrónomo.
  temporalClock('temporal_clock', 'Reloj Maestro / Sincronía Temporal'),

  /// Comandos de control de transporte (Play, Pause, Stop, Record).
  transportControl('transport_control', 'Control de Transporte Global'),

  /// Parámetros de afinación maestra ($A_4$, temperamentos históricos y microdesafinación).
  tuningCalibration('tuning_calibration', 'Calibración de Afinación y Temperamento'),

  /// Distribución de magnitudes espectrales FFT para análisis acústico simultáneo.
  spectralData('spectral_data', 'Espectro de Magnitudes FFT');

  final String code;
  final String displayName;

  const SignalType(this.code, this.displayName);
}
