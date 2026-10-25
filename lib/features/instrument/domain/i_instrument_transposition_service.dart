import 'instrument_profile_entity.dart';

/// Contrato abstracto para el servicio de transposición armónica por instrumento.
abstract class IInstrumentTranspositionService {
  /// Obtiene la nota física sonora (Concert Pitch) correspondiente a una nota escrita en la partitura.
  String getSoundingNote(String writtenNote, InstrumentProfileEntity instrument);

  /// Obtiene la frecuencia física teórica exacta (Hz) que debe captar el micrófono.
  double getSoundingFrequency(String writtenNote, InstrumentProfileEntity instrument, {double a4Ref = 440.0});

  /// Transpone una nota detectada acústicamente de vuelta a la notación escrita para el instrumento.
  String getWrittenNote(String soundingNote, InstrumentProfileEntity instrument);
}
