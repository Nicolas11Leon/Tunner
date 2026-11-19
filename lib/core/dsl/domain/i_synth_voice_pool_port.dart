/// Formas de onda estándar direccionables desde Tunner DSL.
enum DslSynthWaveform {
  sine,
  sawtooth,
  pulse,
  triangle,
}

/// Puerto abstracto de dominio para controlar un sintetizador polifónico desde el kernel DSL
/// sin acoplar `core/` a `features/audio_synthesizer/`.
abstract class ISynthVoicePoolPort {
  void setDslWaveform(DslSynthWaveform value);
  set attackSeconds(double value);
  set decaySeconds(double value);
  set sustainLevel(double value);
  set releaseSeconds(double value);

  void noteOn(int midiNote, double velocity, {double? frequency});
  void noteOff(int midiNote);
  void panic();
}
