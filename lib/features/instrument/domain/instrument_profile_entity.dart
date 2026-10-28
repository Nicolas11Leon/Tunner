/// Clave de notación del pentagrama para el instrumento.
enum InstrumentClef {
  treble('Clave de Sol', '𝄞'),
  bass('Clave de Fa', '𝄢');

  final String displayName;
  final String symbol;

  const InstrumentClef(this.displayName, this.symbol);
}

/// Clave de afinación del instrumento.
enum InstrumentKey {
  concertC(0, 'Do (C) Concierto'),
  bFlat(-2, 'Si♭ (Bb)'),
  eFlat(-9, 'Mi♭ (Eb)'),
  fKey(-7, 'Fa (F)'),
  gKey(-5, 'Sol (G)'),
  aKey(-3, 'La (A)'),
  bassC(-12, 'Do (C) Octava Grave'),
  highOctaveC(12, 'Do (C) Octava Aguda');

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

/// Perfil de instrumento con configuración de transposición, clave y rango acústico.
class InstrumentProfileEntity {
  final String id;
  final String name;
  final InstrumentFamily family;
  final InstrumentKey key;
  final InstrumentClef clef;
  final int transpositionSemitones;
  final double minFrequencyHz;
  final double maxFrequencyHz;

  const InstrumentProfileEntity({
    required this.id,
    required this.name,
    required this.family,
    required this.key,
    this.clef = InstrumentClef.treble,
    required this.transpositionSemitones,
    this.minFrequencyHz = 50.0,
    this.maxFrequencyHz = 3500.0,
  });

  /// Indica si el instrumento requiere transposición respecto al tono de concierto.
  bool get isTransposing => transpositionSemitones != 0;

  /// Perfiles canónicos estándar de orquesta y estudio.
  static const InstrumentProfileEntity flute = InstrumentProfileEntity(
    id: 'flute',
    name: 'Flauta Traversa',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.treble,
    transpositionSemitones: 0,
    minFrequencyHz: 261.63, // Do4
    maxFrequencyHz: 2093.0,  // Do7
  );

  static const InstrumentProfileEntity piccolo = InstrumentProfileEntity(
    id: 'piccolo',
    name: 'Flautín / Piccolo',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.highOctaveC,
    clef: InstrumentClef.treble,
    transpositionSemitones: 12, // Suena 1 octava más aguda de lo escrito
    minFrequencyHz: 523.25, // Do5
    maxFrequencyHz: 4186.0,  // Do8
  );

  static const InstrumentProfileEntity altoFlute = InstrumentProfileEntity(
    id: 'alto_flute',
    name: 'Flauta Alto en Sol',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.gKey,
    clef: InstrumentClef.treble,
    transpositionSemitones: -5, // Cuarta justa abajo (-5 semitonos)
    minFrequencyHz: 196.0,  // Sol3
    maxFrequencyHz: 1568.0, // Sol6
  );

  static const InstrumentProfileEntity oboe = InstrumentProfileEntity(
    id: 'oboe',
    name: 'Oboe',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.treble,
    transpositionSemitones: 0,
    minFrequencyHz: 233.08, // Sib3
    maxFrequencyHz: 1760.0, // La6
  );

  static const InstrumentProfileEntity englishHorn = InstrumentProfileEntity(
    id: 'english_horn',
    name: 'Corno Inglés en Fa',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.fKey,
    clef: InstrumentClef.treble,
    transpositionSemitones: -7, // Quinta justa abajo
    minFrequencyHz: 164.81, // Mi3
    maxFrequencyHz: 1046.5, // Do6
  );

  static const InstrumentProfileEntity bbTrumpet = InstrumentProfileEntity(
    id: 'bb_trumpet',
    name: 'Trompeta en Si♭',
    family: InstrumentFamily.brass,
    key: InstrumentKey.bFlat,
    clef: InstrumentClef.treble,
    transpositionSemitones: -2,
    minFrequencyHz: 164.81, // Mi3
    maxFrequencyHz: 987.77,  // Si5
  );

  static const InstrumentProfileEntity bbClarinet = InstrumentProfileEntity(
    id: 'bb_clarinet',
    name: 'Clarinete en Si♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.bFlat,
    clef: InstrumentClef.treble,
    transpositionSemitones: -2,
    minFrequencyHz: 146.83, // Re3
    maxFrequencyHz: 1567.98, // Sol6
  );

  static const InstrumentProfileEntity aClarinet = InstrumentProfileEntity(
    id: 'a_clarinet',
    name: 'Clarinete en La',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.aKey,
    clef: InstrumentClef.treble,
    transpositionSemitones: -3, // Tercera menor abajo
    minFrequencyHz: 138.59, // Do#3
    maxFrequencyHz: 1480.0, // Fa#6
  );

  static const InstrumentProfileEntity bassoon = InstrumentProfileEntity(
    id: 'bassoon',
    name: 'Fagot',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.bass,
    transpositionSemitones: 0,
    minFrequencyHz: 58.27, // Sib1
    maxFrequencyHz: 880.0, // La5
  );

  static const InstrumentProfileEntity sopranoSax = InstrumentProfileEntity(
    id: 'soprano_sax',
    name: 'Saxofón Soprano en Si♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.bFlat,
    clef: InstrumentClef.treble,
    transpositionSemitones: -2,
    minFrequencyHz: 207.65, // Lab3
    maxFrequencyHz: 1318.5, // Mi6
  );

  static const InstrumentProfileEntity ebAltoSax = InstrumentProfileEntity(
    id: 'eb_alto_sax',
    name: 'Saxofón Alto en Mi♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.eFlat,
    clef: InstrumentClef.treble,
    transpositionSemitones: -9,
    minFrequencyHz: 138.59, // Do#3
    maxFrequencyHz: 880.0,   // La5
  );

  static const InstrumentProfileEntity bbTenorSax = InstrumentProfileEntity(
    id: 'bb_tenor_sax',
    name: 'Saxofón Tenor en Si♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.bFlat,
    clef: InstrumentClef.treble,
    transpositionSemitones: -14, // Novena mayor abajo (-14 semitonos)
    minFrequencyHz: 103.83, // Sol#2
    maxFrequencyHz: 659.25,  // Mi5
  );

  static const InstrumentProfileEntity ebBaritoneSax = InstrumentProfileEntity(
    id: 'eb_baritone_sax',
    name: 'Saxofón Barítono en Mi♭',
    family: InstrumentFamily.woodwinds,
    key: InstrumentKey.eFlat,
    clef: InstrumentClef.treble,
    transpositionSemitones: -21, // Octava + sexta mayor abajo (-21 semitonos)
    minFrequencyHz: 65.41,  // Do2
    maxFrequencyHz: 440.0,  // La4
  );

  static const InstrumentProfileEntity fHorn = InstrumentProfileEntity(
    id: 'f_horn',
    name: 'Corno Francés en Fa',
    family: InstrumentFamily.brass,
    key: InstrumentKey.fKey,
    clef: InstrumentClef.treble,
    transpositionSemitones: -7,
    minFrequencyHz: 65.41,  // Do2
    maxFrequencyHz: 880.0,  // La5
  );

  static const InstrumentProfileEntity trombone = InstrumentProfileEntity(
    id: 'trombone',
    name: 'Trombón',
    family: InstrumentFamily.brass,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.bass,
    transpositionSemitones: 0,
    minFrequencyHz: 82.41,  // Mi2
    maxFrequencyHz: 587.33, // Re5
  );

  static const InstrumentProfileEntity tuba = InstrumentProfileEntity(
    id: 'tuba',
    name: 'Tuba',
    family: InstrumentFamily.brass,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.bass,
    transpositionSemitones: 0,
    minFrequencyHz: 43.65,  // Fa1
    maxFrequencyHz: 349.23, // Fa4
  );

  static const InstrumentProfileEntity violin = InstrumentProfileEntity(
    id: 'violin',
    name: 'Violín',
    family: InstrumentFamily.strings,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.treble,
    transpositionSemitones: 0,
    minFrequencyHz: 196.0,  // Sol3
    maxFrequencyHz: 3136.0, // Sol7
  );

  static const InstrumentProfileEntity guitar = InstrumentProfileEntity(
    id: 'guitar',
    name: 'Guitarra Clásica / Eléctrica',
    family: InstrumentFamily.strings,
    key: InstrumentKey.bassC,
    clef: InstrumentClef.treble,
    transpositionSemitones: -12, // Suena una octava abajo de lo escrito
    minFrequencyHz: 82.41,   // Mi2
    maxFrequencyHz: 1174.66, // Re6
  );

  static const InstrumentProfileEntity cello = InstrumentProfileEntity(
    id: 'cello',
    name: 'Violonchelo',
    family: InstrumentFamily.strings,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.bass,
    transpositionSemitones: 0,
    minFrequencyHz: 65.41,  // Do2
    maxFrequencyHz: 987.77, // Si5
  );

  static const InstrumentProfileEntity doubleBass = InstrumentProfileEntity(
    id: 'double_bass',
    name: 'Contrabajo',
    family: InstrumentFamily.strings,
    key: InstrumentKey.bassC,
    clef: InstrumentClef.bass,
    transpositionSemitones: -12, // Suena una octava abajo de lo escrito
    minFrequencyHz: 30.87,  // Si0
    maxFrequencyHz: 392.0,  // Sol4
  );

  static const InstrumentProfileEntity voice = InstrumentProfileEntity(
    id: 'voice',
    name: 'Voz / Canto Universal',
    family: InstrumentFamily.vocals,
    key: InstrumentKey.concertC,
    clef: InstrumentClef.treble,
    transpositionSemitones: 0,
    minFrequencyHz: 65.0,
    maxFrequencyHz: 1300.0,
  );

  static const List<InstrumentProfileEntity> standardInstruments = [
    flute,
    piccolo,
    altoFlute,
    oboe,
    englishHorn,
    bbClarinet,
    aClarinet,
    bassoon,
    sopranoSax,
    ebAltoSax,
    bbTenorSax,
    ebBaritoneSax,
    bbTrumpet,
    fHorn,
    trombone,
    tuba,
    violin,
    guitar,
    cello,
    doubleBass,
    voice,
  ];
}
