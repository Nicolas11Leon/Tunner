/// Nota o evento rítmico individual dentro de una estrofa musical.
class MusicalPhraseNote {
  /// Altura de la nota MIDI (ej: 60 para C4).
  final int midiNote;

  /// Duración en ticks métricos (1 tick = semicorchea, 2 = corchea, 4 = negra, 8 = blanca, 16 = redonda).
  final int durationTicks;

  /// Dinámica de intensidad / velocidad MIDI (0.0 a 1.0).
  final double velocity;

  /// Indica si es un silencio musical.
  final bool isRest;

  /// Texto o sílaba lírica asociada (para estrofas cantadas).
  final String? lyricSyllable;

  const MusicalPhraseNote({
    required this.midiNote,
    required this.durationTicks,
    this.velocity = 0.8,
    this.isRest = false,
    this.lyricSyllable,
  }) : assert(durationTicks > 0);

  static const MusicalPhraseNote restQuarter = MusicalPhraseNote(
    midiNote: 0,
    durationTicks: 4,
    isRest: true,
  );
}

/// Entidad inmutable que representa una frase o estrofa musical completa.
class MusicalPhraseEntity {
  final String id;
  final String title;
  final String description;
  final String genreOrTradition;
  final int defaultBpm;
  final String timeSignature;
  final List<MusicalPhraseNote> notes;

  const MusicalPhraseEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.genreOrTradition,
    this.defaultBpm = 110,
    this.timeSignature = '4/4',
    required this.notes,
  });

  /// Duración total de la estrofa en ticks métricos.
  int get totalTicks => notes.fold(0, (sum, n) => sum + n.durationTicks);

  // =========================================================================
  // CATÁLOGO CANÓNICO DE ESTROFAS MUSICALES
  // =========================================================================

  /// 1. Arpegio Mayor de Concierto (Do Mayor: C4 - E4 - G4 - C5 - G4 - E4 - C4)
  static const MusicalPhraseEntity majorConcertArpeggio = MusicalPhraseEntity(
    id: 'major_arpeggio',
    title: 'Arpegio Mayor de Concierto',
    description: 'Arpegio ascendente y descendente en Do Mayor para probar resonancia de tríadas.',
    genreOrTradition: 'Clásico Universal',
    defaultBpm: 120,
    notes: [
      MusicalPhraseNote(midiNote: 60, durationTicks: 4), // C4 (Negra)
      MusicalPhraseNote(midiNote: 64, durationTicks: 4), // E4
      MusicalPhraseNote(midiNote: 67, durationTicks: 4), // G4
      MusicalPhraseNote(midiNote: 72, durationTicks: 8), // C5 (Blanca)
      MusicalPhraseNote(midiNote: 67, durationTicks: 4), // G4
      MusicalPhraseNote(midiNote: 64, durationTicks: 4), // E4
      MusicalPhraseNote(midiNote: 60, durationTicks: 8), // C4 (Blanca final)
    ],
  );

  /// 2. Preludio Clásico (Motivo inspirado en J.S. Bach BWV 846)
  static const MusicalPhraseEntity bachPreludeMotif = MusicalPhraseEntity(
    id: 'bach_prelude',
    title: 'Preludio Clásico en Do (Bach)',
    description: 'Diseño continuo de arpegios en semicorcheas para evaluar legato y balance tímbrico.',
    genreOrTradition: 'Barroco',
    defaultBpm: 100,
    notes: [
      MusicalPhraseNote(midiNote: 60, durationTicks: 2), // C4
      MusicalPhraseNote(midiNote: 64, durationTicks: 2), // E4
      MusicalPhraseNote(midiNote: 67, durationTicks: 2), // G4
      MusicalPhraseNote(midiNote: 72, durationTicks: 2), // C5
      MusicalPhraseNote(midiNote: 76, durationTicks: 2), // E5
      MusicalPhraseNote(midiNote: 67, durationTicks: 2), // G4
      MusicalPhraseNote(midiNote: 72, durationTicks: 2), // C5
      MusicalPhraseNote(midiNote: 76, durationTicks: 2), // E5
      MusicalPhraseNote(midiNote: 60, durationTicks: 2), // C4
      MusicalPhraseNote(midiNote: 64, durationTicks: 2), // E4
      MusicalPhraseNote(midiNote: 67, durationTicks: 2), // G4
      MusicalPhraseNote(midiNote: 72, durationTicks: 2), // C5
      MusicalPhraseNote(midiNote: 76, durationTicks: 2), // E5
      MusicalPhraseNote(midiNote: 67, durationTicks: 2), // G4
      MusicalPhraseNote(midiNote: 72, durationTicks: 2), // C5
      MusicalPhraseNote(midiNote: 76, durationTicks: 2), // E5
    ],
  );

  /// 3. Melodía Pentatónica Andina (Vientos y Cuerdas)
  static const MusicalPhraseEntity andeanPentatonic = MusicalPhraseEntity(
    id: 'andean_pentatonic',
    title: 'Melodía Pentatónica Andina',
    description: 'Frase tradicional en escala menor pentatónica (La - Do - Re - Mi - Sol).',
    genreOrTradition: 'Folclor Andino / Vientos',
    defaultBpm: 95,
    notes: [
      MusicalPhraseNote(midiNote: 69, durationTicks: 4), // A4
      MusicalPhraseNote(midiNote: 72, durationTicks: 4), // C5
      MusicalPhraseNote(midiNote: 74, durationTicks: 6), // D5
      MusicalPhraseNote(midiNote: 76, durationTicks: 2), // E5
      MusicalPhraseNote(midiNote: 74, durationTicks: 4), // D5
      MusicalPhraseNote(midiNote: 72, durationTicks: 4), // C5
      MusicalPhraseNote(midiNote: 69, durationTicks: 8), // A4
    ],
  );

  /// 4. Groove & Línea de Bajo Funk (Slap / Finger)
  static const MusicalPhraseEntity funkBassline = MusicalPhraseEntity(
    id: 'funk_bassline',
    title: 'Groove & Línea de Bajo Funk',
    description: 'Secuencia sincopada en Mi grave con ataque percutido y octavas dinámicas.',
    genreOrTradition: 'Funk / Jazz Moderno',
    defaultBpm: 105,
    notes: [
      MusicalPhraseNote(midiNote: 40, durationTicks: 2), // E2
      MusicalPhraseNote(midiNote: 40, durationTicks: 2, isRest: true),
      MusicalPhraseNote(midiNote: 52, durationTicks: 2), // E3 (Octava)
      MusicalPhraseNote(midiNote: 40, durationTicks: 2), // E2
      MusicalPhraseNote(midiNote: 43, durationTicks: 2), // G2
      MusicalPhraseNote(midiNote: 45, durationTicks: 4), // A2
      MusicalPhraseNote(midiNote: 46, durationTicks: 2), // Bb2 (Nota de paso blue)
      MusicalPhraseNote(midiNote: 47, durationTicks: 4), // B2
      MusicalPhraseNote(midiNote: 40, durationTicks: 8), // E2
    ],
  );

  /// 5. Estrofa Maqam Bayati (Microtonal Oriental con cuartos de tono)
  static const MusicalPhraseEntity maqamBayatiStanza = MusicalPhraseEntity(
    id: 'maqam_bayati_stanza',
    title: 'Estrofa Maqam Bayati (Microtonal)',
    description: 'Frase melódica tradicional árabe donde el Mi tiene un cuarto de tono (-50 cents).',
    genreOrTradition: 'Música Oriental Maqam',
    defaultBpm: 80,
    notes: [
      MusicalPhraseNote(midiNote: 62, durationTicks: 4), // D4
      MusicalPhraseNote(midiNote: 64, durationTicks: 4), // E4 (Con micro-offset -50¢)
      MusicalPhraseNote(midiNote: 65, durationTicks: 4), // F4
      MusicalPhraseNote(midiNote: 67, durationTicks: 6), // G4
      MusicalPhraseNote(midiNote: 65, durationTicks: 2), // F4
      MusicalPhraseNote(midiNote: 64, durationTicks: 4), // E4 (-50¢)
      MusicalPhraseNote(midiNote: 62, durationTicks: 8), // D4 final
    ],
  );

  /// Catálogo completo de estrofas disponibles.
  static const List<MusicalPhraseEntity> canonicalPhrases = [
    majorConcertArpeggio,
    bachPreludeMotif,
    andeanPentatonic,
    funkBassline,
    maqamBayatiStanza,
  ];
}
