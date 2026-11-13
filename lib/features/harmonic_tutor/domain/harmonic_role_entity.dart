/// Pure Dart representation of harmonic roles and interval ratios in Just Intonation (JI).
///
/// Contains irreducible whole-number rational ratios (p/q), canonical deviations
/// relative to twelve-tone equal temperament (12-TET), and overtone order numbers
/// for acoustic beat calculation.
enum HarmonicRole {
  root(
    semitones: 0,
    numerator: 1,
    denominator: 1,
    justCents: 0.0,
    tetOffsetCents: 0.0,
    labelEs: 'Fundamental',
    symbol: '1',
    description: 'Unísono u octava pura sin batimiento.',
  ),
  minorSecond(
    semitones: 1,
    numerator: 16,
    denominator: 15,
    justCents: 111.73,
    tetOffsetCents: 11.73,
    labelEs: 'Segunda Menor',
    symbol: 'm2',
    description: 'Semitono diatónico justo (16/15). Tocar +12 c más alto que 12-TET.',
  ),
  majorSecond(
    semitones: 2,
    numerator: 9,
    denominator: 8,
    justCents: 203.91,
    tetOffsetCents: 3.91,
    labelEs: 'Segunda Mayor',
    symbol: 'M2',
    description: 'Tono mayor justo (9/8). Tocar +4 c más alto que 12-TET.',
  ),
  minorThird(
    semitones: 3,
    numerator: 6,
    denominator: 5,
    justCents: 315.64,
    tetOffsetCents: 15.64,
    labelEs: 'Tercera Menor',
    symbol: 'm3',
    description: 'Tercera menor pura (6/5). Tocar +16 c más alto que 12-TET para eliminar aspereza.',
  ),
  majorThird(
    semitones: 4,
    numerator: 5,
    denominator: 4,
    justCents: 386.31,
    tetOffsetCents: -13.69,
    labelEs: 'Tercera Mayor',
    symbol: 'M3',
    description: 'Tercera mayor pura (5/4). Tocar -14 c más bajo que 12-TET para anular el batimiento.',
  ),
  perfectFourth(
    semitones: 5,
    numerator: 4,
    denominator: 3,
    justCents: 498.04,
    tetOffsetCents: -1.96,
    labelEs: 'Cuarta Justa',
    symbol: '4',
    description: 'Cuarta justa natural (4/3). Tocar -2 c ligeramente más bajo que 12-TET.',
  ),
  tritone(
    semitones: 6,
    numerator: 7,
    denominator: 5,
    justCents: 582.51,
    tetOffsetCents: -17.49,
    labelEs: 'Tritono Sub-séptimo',
    symbol: 'd5',
    description: 'Tritono de límite 7 (7/5). Tocar -17 c más bajo que 12-TET.',
  ),
  perfectFifth(
    semitones: 7,
    numerator: 3,
    denominator: 2,
    justCents: 701.96,
    tetOffsetCents: 1.96,
    labelEs: 'Quinta Justa',
    symbol: '5',
    description: 'Quinta justa pura (3/2). Tocar +2 c sutilmente más alto que 12-TET.',
  ),
  minorSixth(
    semitones: 8,
    numerator: 8,
    denominator: 5,
    justCents: 813.69,
    tetOffsetCents: 13.69,
    labelEs: 'Sexta Menor',
    symbol: 'm6',
    description: 'Sexta menor pura (8/5). Tocar +14 c más alto que 12-TET.',
  ),
  majorSixth(
    semitones: 9,
    numerator: 5,
    denominator: 3,
    justCents: 884.36,
    tetOffsetCents: -15.64,
    labelEs: 'Sexta Mayor',
    symbol: 'M6',
    description: 'Sexta mayor pura (5/3). Tocar -16 c más bajo que 12-TET.',
  ),
  harmonicSeventh(
    semitones: 10,
    numerator: 7,
    denominator: 4,
    justCents: 968.83,
    tetOffsetCents: -31.17,
    labelEs: 'Séptima Armónica (Dominante)',
    symbol: '7',
    description: 'Séptima armónica de límite 7 (7/4). Tocar -31 c notablemente más bajo para acorde dominante puro.',
  ),
  majorSeventh(
    semitones: 11,
    numerator: 15,
    denominator: 8,
    justCents: 1088.27,
    tetOffsetCents: -11.73,
    labelEs: 'Séptima Mayor',
    symbol: 'M7',
    description: 'Séptima mayor clásica (15/8). Tocar -12 c más bajo que 12-TET.',
  );

  final int semitones;
  final int numerator;
  final int denominator;
  final double justCents;
  final double tetOffsetCents;
  final String labelEs;
  final String symbol;
  final String description;

  const HarmonicRole({
    required this.semitones,
    required this.numerator,
    required this.denominator,
    required this.justCents,
    required this.tetOffsetCents,
    required this.labelEs,
    required this.symbol,
    required this.description,
  });

  /// Ratio as a decimal fraction.
  double get ratio => numerator / denominator;

  /// Locates the corresponding HarmonicRole by modular semitone interval [0..11].
  static HarmonicRole fromSemitones(int semitones) {
    final mod = ((semitones % 12) + 12) % 12;
    return HarmonicRole.values.firstWhere(
      (r) => r.semitones == mod,
      orElse: () => HarmonicRole.root,
    );
  }
}

/// Harmonic chord qualities supported by the Tutor.
enum HarmonicChordType {
  majorTriad(
    label: 'Tríada Mayor (1 - 3 - 5)',
    roles: [HarmonicRole.root, HarmonicRole.majorThird, HarmonicRole.perfectFifth],
  ),
  minorTriad(
    label: 'Tríada Menor (1 - b3 - 5)',
    roles: [HarmonicRole.root, HarmonicRole.minorThird, HarmonicRole.perfectFifth],
  ),
  dominantSeventh(
    label: 'Séptima Dominante (1 - 3 - 5 - b7)',
    roles: [HarmonicRole.root, HarmonicRole.majorThird, HarmonicRole.perfectFifth, HarmonicRole.harmonicSeventh],
  ),
  suspendedFourth(
    label: 'Cuarta Suspendida (1 - 4 - 5)',
    roles: [HarmonicRole.root, HarmonicRole.perfectFourth, HarmonicRole.perfectFifth],
  ),
  powerChord(
    label: 'Quinta Pura / Power Chord (1 - 5)',
    roles: [HarmonicRole.root, HarmonicRole.perfectFifth],
  ),
  majorSeventh(
    label: 'Séptima Mayor (1 - 3 - 5 - 7)',
    roles: [HarmonicRole.root, HarmonicRole.majorThird, HarmonicRole.perfectFifth, HarmonicRole.majorSeventh],
  );

  final String label;
  final List<HarmonicRole> roles;
  const HarmonicChordType({required this.label, required this.roles});
}
