import 'dart:typed_data';
import 'harmonic_role_entity.dart';

/// Contrato de dominio puro para sintetizadores procedurales de referencia armónica
/// en Afinación Justa (Just Intonation).
abstract class IHarmonicReferenceSynth {
  int get sampleRate;

  /// Sintetiza un buffer mono normalizado con el acorde o dron armónico de referencia.
  Float32List generateChordBuffer({
    required double rootFrequency,
    required List<HarmonicRole> roles,
    int durationMs = 1000,
    double volume = 0.5,
  });
}
