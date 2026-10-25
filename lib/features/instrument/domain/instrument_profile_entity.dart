/// Clave de afinación del instrumento.
enum InstrumentKey {
  concertC(0, 'Do (C) Concierto'),
  bFlat(-2, 'Si♭ (Bb)'),
  eFlat(-9, 'Mi♭ (Eb)'),
  fKey(-7, 'Fa (F)'),
  bassC(-12, 'Do (C) Octava Grave');

  final int semitoneOffset;
  final String displayName;

  const InstrumentKey(this.semitoneOffset, this.displayName);
}

/// Familia acústica del instrumento musical.
enum InstrumentFamily {
  woodwinds('Maderas'),
  brass('Metales'),
  strings('Cuerdas'),
  vocals('Voz'),
  percussion('Percusión / Teclados');

  final String displayName;
  const InstrumentFamily(this.displayName);
}

/// Perfil de instrumento con configuración de transposición y rango acústico.
class InstrumentProfileEntity {
  final String id;
  final String name;
  final InstrumentFamily family;
  final InstrumentKey key;
  final int transpositionSemitones;
  final double minFrequencyHz;
  final double maxFrequencyHz;

  const InstrumentProfileEntity({
    required this.id,
    required this.name,
    required this.family,
    required this.key,
    required this.transpositionSemitones,
    this.minFrequencyHz = 50.0,
    this.maxFrequencyHz = 3500.0,
  });

  /// Perfiles canónicos estándar de orquesta y estudio.
  static const InstrumentProfileEntity flute = InstrumentProfileEntity(
    id: 'flute',
    name: 'Flauta Traversa',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.concertC,
    transpositionSemitones: 0,
    minFrequencyHz: 261.63, // Do4
    maxFrequencyHz: 2093.0,  // Do7
  );

  static const InstrumentProfileEntity bbTrumpet = InstrumentProfileEntity(
    id: 'bb_trumpet',
    name: 'Trompeta en Si♭',
    family: InstrumentFamily.brass,
    key: InstrumentKey.bFlat,
    transpositionSemitones: -2,
    minFrequencyHz: 164.81, // Mi3
    maxFrequencyHz: 987.77,  // Si5
  );

  static const InstrumentProfileEntity bbClarinet = InstrumentProfileEntity(
    id: 'bb_clarinet',
    name: 'Clarinete en Si♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.bFlat,
    transpositionSemitones: -2,
    minFrequencyHz: 146.83, // Re3
    maxFrequencyHz: 1567.98, // Sol6
  );

  static const InstrumentProfileEntity ebAltoSax = InstrumentProfileEntity(
    id: 'eb_alto_sax',
    name: 'Saxofón Alto en Mi♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.eFlat,
    transpositionSemitones: -9,
    minFrequencyHz: 138.59, // Do#3
    maxFrequencyHz: 880.0,   // La5
  );

  static const InstrumentProfileEntity bbTenorSax = InstrumentProfileEntity(
    id: 'bb_tenor_sax',
    name: 'Saxofón Tenor en Si♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.bFlat,
    transpositionSemitones: -14, // Novena mayor abajo (-14 semitonos)
    minFrequencyHz: 103.83, // Sol#2
    maxFrequencyHz: 659.25,  // Mi5
  );

  static const InstrumentProfileEntity fHorn = InstrumentProfileEntity(
    id: 'f_horn',
    name: 'Corno Francés en Fa',
    family: InstrumentFamily.brass,
    key: InstrumentKey.fKey,
    transpositionSemitones: -7,
    minFrequencyHz: 65.41,  // Do2
    maxFrequencyHz: 880.0,  // La5
  );

  static const InstrumentProfileEntity violin = InstrumentProfileEntity(
    id: 'violin',
    name: 'Violín',
    family: InstrumentFamily.strings,
    key: InstrumentKey.concertC,
    transpositionSemitones: 0,
    minFrequencyHz: 196.0,  // Sol3
    maxFrequencyHz: 3136.0, // Sol7
  );

  static const InstrumentProfileEntity guitar = InstrumentProfileEntity(
    id: 'guitar',
    name: 'Guitarra Clásica / Eléctrica',
    family: InstrumentFamily.strings,
    key: InstrumentKey.bassC,
    transpositionSemitones: -12, // Suena una octava abajo de lo escrito
    minFrequencyHz: 82.41,   // Mi2
    maxFrequencyHz: 1174.66, // Re6
  );

  static const InstrumentProfileEntity cello = InstrumentProfileEntity(
    id: 'cello',
    name: 'Violonchelo / Bajo',
    family: InstrumentFamily.strings,
    key: InstrumentKey.bassC,
    transpositionSemitones: -12,
    minFrequencyHz: 30.0,
    maxFrequencyHz: 600.0,
  );

  static const InstrumentProfileEntity voice = InstrumentProfileEntity(
    id: 'voice',
    name: 'Voz / Canto Universal',
    family: InstrumentFamily.vocals,
    key: InstrumentKey.concertC,
    transpositionSemitones: 0,
    minFrequencyHz: 65.0,
    maxFrequencyHz: 1300.0,
  );

  static const List<InstrumentProfileEntity> standardInstruments = [
    flute,
    bbTrumpet,
    bbClarinet,
    ebAltoSax,
    bbTenorSax,
    fHorn,
    violin,
    guitar,
    cello,
    voice,
  ];
}
