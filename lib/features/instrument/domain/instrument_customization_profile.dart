import 'dart:math' as math;
import 'universal_instrument_definition.dart';
import 'per_note_detuning_profile.dart';
import '../../tuner/domain/temperament_engine.dart';

/// Agregado de personalización física, tímbrica y microtonal para cualquier instrumento.
class InstrumentCustomizationProfile {
  /// Instrumento universal base.
  final UniversalInstrumentDefinition instrument;

  /// Frecuencia de concierto A4 de referencia en Hertz (415 a 466 Hz).
  final double referencePitchA4;

  /// Sistema de temperamento musical activo.
  final MusicalTemperament temperament;

  /// Perfil de desafinaciones microtonales individuales por tecla o cuerda.
  final PerNoteDetuningProfile detuningProfile;

  /// Multiplicador de tiempo de ataque de la envolvente ADSR (0.2 a 3.0).
  final double attackMultiplier;

  /// Multiplicador del nivel de sostenimiento ADSR (0.2 a 2.0).
  final double sustainMultiplier;

  /// Factor de brillo armónico para los sobretonos H2 a H8 (0.2 a 2.0).
  final double harmonicBrightness;

  /// Factor de resonancia física del cuerpo acústico (0.0 a 1.0).
  final double resonanceFactor;

  const InstrumentCustomizationProfile({
    required this.instrument,
    this.referencePitchA4 = 440.0,
    this.temperament = const MusicalTemperament(
      id: 'equal',
      name: 'Temperamento Igual (12-EDO)',
      historicalEra: 'Contemporáneo',
      description: '12 semitonos iguales.',
      centsOffsets: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    this.detuningProfile = PerNoteDetuningProfile.standard,
    this.attackMultiplier = 1.0,
    this.sustainMultiplier = 1.0,
    this.harmonicBrightness = 1.0,
    this.resonanceFactor = 0.5,
  }) : assert(referencePitchA4 >= 415.0 && referencePitchA4 <= 466.0),
       assert(attackMultiplier >= 0.1 && attackMultiplier <= 5.0);

  /// Crea un perfil por defecto basado en un instrumento universal.
  factory InstrumentCustomizationProfile.defaultFor(UniversalInstrumentDefinition instrument) {
    return InstrumentCustomizationProfile(
      instrument: instrument,
      referencePitchA4: 440.0,
      detuningProfile: PerNoteDetuningProfile.standard,
    );
  }

  /// Calcula la frecuencia acústica física exacta en Hertz de una nota considerando:
  /// 1. Tono de concierto A4
  /// 2. Semitonos de transposición del instrumento
  /// 3. Desviación en cents del temperamento musical
  /// 4. Desafinación microtonal individual por tecla o cuerda
  double calculateFrequencyForMidiNote(int midiNote, {int? stringIndex}) {
    // 1. Tono de concierto en temperamento igual (La4 = MIDI 69)
    final transposedNote = midiNote + instrument.transpositionSemitones;
    final baseFreq12Edo = referencePitchA4 * math.pow(2.0, (transposedNote - 69) / 12.0);

    // 2. Desviación del temperamento musical (Do = 0, La = 9, etc.)
    final chromaticClass = transposedNote % 12;
    final temperamentOffsetCents = (temperament.centsOffsets.length > chromaticClass)
        ? temperament.centsOffsets[chromaticClass]
        : 0.0;

    // 3. Desviación por micro-afinación personalizada de tecla o cuerda
    final customDetuneCents = detuningProfile.getCentsOffsetForNote(midiNote) +
        (stringIndex != null ? detuningProfile.getCentsOffsetForString(stringIndex) : 0.0);

    final totalCents = temperamentOffsetCents + customDetuneCents;

    if (totalCents.abs() < 0.0001) {
      return baseFreq12Edo;
    }

    return baseFreq12Edo * math.pow(2.0, totalCents / 1200.0);
  }

  InstrumentCustomizationProfile copyWith({
    UniversalInstrumentDefinition? instrument,
    double? referencePitchA4,
    MusicalTemperament? temperament,
    PerNoteDetuningProfile? detuningProfile,
    double? attackMultiplier,
    double? sustainMultiplier,
    double? harmonicBrightness,
    double? resonanceFactor,
  }) {
    return InstrumentCustomizationProfile(
      instrument: instrument ?? this.instrument,
      referencePitchA4: referencePitchA4 ?? this.referencePitchA4,
      temperament: temperament ?? this.temperament,
      detuningProfile: detuningProfile ?? this.detuningProfile,
      attackMultiplier: attackMultiplier ?? this.attackMultiplier,
      sustainMultiplier: sustainMultiplier ?? this.sustainMultiplier,
      harmonicBrightness: harmonicBrightness ?? this.harmonicBrightness,
      resonanceFactor: resonanceFactor ?? this.resonanceFactor,
    );
  }
}
