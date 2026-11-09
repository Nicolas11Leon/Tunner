import 'dart:math' as math;

/// Intervalos musicales canónicos para el entrenamiento auditivo relativo y absoluto.
///
/// Modela los 13 intervalos cromáticos de la octava (0 a 12 semitonos),
/// incluyendo nombres formales, abreviaturas, semitonos y ratios matemáticos
/// de afinación temperada (12-EDO) y afinación justa (Just Intonation).
enum MusicalInterval {
  /// Unísono Justo (0 semitonos, ratio 1:1, 0 cents).
  unison(
    semitones: 0,
    displayName: 'Unísono Justo',
    shortName: '1J',
    justRatioNumerator: 1,
    justRatioDenominator: 1,
    justCents: 0.0,
  ),

  /// Segunda Menor (1 semitono, ratio diatónico 16:15, ~111.73 cents justos vs 100 temperados).
  minorSecond(
    semitones: 1,
    displayName: 'Segunda Menor',
    shortName: '2m',
    justRatioNumerator: 16,
    justRatioDenominator: 15,
    justCents: 111.73,
  ),

  /// Segunda Mayor (2 semitonos, ratio mayor 9:8, ~203.91 cents justos vs 200 temperados).
  majorSecond(
    semitones: 2,
    displayName: 'Segunda Mayor',
    shortName: '2M',
    justRatioNumerator: 9,
    justRatioDenominator: 8,
    justCents: 203.91,
  ),

  /// Tercera Menor (3 semitonos, ratio 6:5, ~315.64 cents justos vs 300 temperados).
  minorThird(
    semitones: 3,
    displayName: 'Tercera Menor',
    shortName: '3m',
    justRatioNumerator: 6,
    justRatioDenominator: 5,
    justCents: 315.64,
  ),

  /// Tercera Mayor (4 semitonos, ratio 5:4, ~386.31 cents justos vs 400 temperados).
  majorThird(
    semitones: 4,
    displayName: 'Tercera Mayor',
    shortName: '3M',
    justRatioNumerator: 5,
    justRatioDenominator: 4,
    justCents: 386.31,
  ),

  /// Cuarta Justa (5 semitonos, ratio 4:3, ~498.04 cents justos vs 500 temperados).
  perfectFourth(
    semitones: 5,
    displayName: 'Cuarta Justa',
    shortName: '4J',
    justRatioNumerator: 4,
    justRatioDenominator: 3,
    justCents: 498.04,
  ),

  /// Tritono / Cuarta Aumentada / Quinta Disminuida (6 semitonos, ratio 45:32 o √2).
  tritone(
    semitones: 6,
    displayName: 'Tritono (4ª Aum / 5ª Dism)',
    shortName: 'TT',
    justRatioNumerator: 45,
    justRatioDenominator: 32,
    justCents: 590.22,
  ),

  /// Quinta Justa (7 semitonos, ratio 3:2, ~701.96 cents justos vs 700 temperados).
  perfectFifth(
    semitones: 7,
    displayName: 'Quinta Justa',
    shortName: '5J',
    justRatioNumerator: 3,
    justRatioDenominator: 2,
    justCents: 701.96,
  ),

  /// Sexta Menor (8 semitonos, ratio 8:5, ~813.69 cents justos vs 800 temperados).
  minorSixth(
    semitones: 8,
    displayName: 'Sexta Menor',
    shortName: '6m',
    justRatioNumerator: 8,
    justRatioDenominator: 5,
    justCents: 813.69,
  ),

  /// Sexta Mayor (9 semitonos, ratio 5:3, ~884.36 cents justos vs 900 temperados).
  majorSixth(
    semitones: 9,
    displayName: 'Sexta Mayor',
    shortName: '6M',
    justRatioNumerator: 5,
    justRatioDenominator: 3,
    justCents: 884.36,
  ),

  /// Séptima Menor (10 semitonos, ratio 9:5 o 16:9, ~1017.60 cents justos vs 1000 temperados).
  minorSeventh(
    semitones: 10,
    displayName: 'Séptima Menor',
    shortName: '7m',
    justRatioNumerator: 9,
    justRatioDenominator: 5,
    justCents: 1017.60,
  ),

  /// Séptima Mayor (11 semitonos, ratio 15:8, ~1088.27 cents justos vs 1100 temperados).
  majorSeventh(
    semitones: 11,
    displayName: 'Séptima Mayor',
    shortName: '7M',
    justRatioNumerator: 15,
    justRatioDenominator: 8,
    justCents: 1088.27,
  ),

  /// Octava Justa (12 semitonos, ratio 2:1, 1200.00 cents).
  perfectOctave(
    semitones: 12,
    displayName: 'Octava Justa',
    shortName: '8J',
    justRatioNumerator: 2,
    justRatioDenominator: 1,
    justCents: 1200.00,
  );

  final int semitones;
  final String displayName;
  final String shortName;
  final int justRatioNumerator;
  final int justRatioDenominator;
  final double justCents;

  const MusicalInterval({
    required this.semitones,
    required this.displayName,
    required this.shortName,
    required this.justRatioNumerator,
    required this.justRatioDenominator,
    required this.justCents,
  });

  /// Ratio de frecuencia en afinación temperada igual (12-EDO):
  ///
  /// $$r = 2^{\frac{n}{12}}$$
  double get equalTemperamentRatio => math.pow(2.0, semitones / 12.0).toDouble();

  /// Ratio exacto en afinación justa (Just Intonation):
  ///
  /// $$r_{\text{just}} = \frac{\text{Numerator}}{\text{Denominator}}$$
  double get justRatio => justRatioNumerator / justRatioDenominator;

  /// Centavos en escala temperada igual:
  ///
  /// $$\text{cents} = n \cdot 100$$
  double get equalTemperamentCents => semitones * 100.0;

  /// Desvío en cents entre la afinación justa y la temperada igual:
  ///
  /// $$\Delta_{\text{cents}} = \text{justCents} - \text{equalTemperamentCents}$$
  double get centDifferenceJustVsEqual => justCents - equalTemperamentCents;

  /// Calcula la frecuencia resultante a partir de una frecuencia base [baseFrequencyHz].
  ///
  /// - Si [ascending] es true, la frecuencia sube; si es false, desciende.
  /// - Si [useJustIntonation] es true, utiliza el ratio armónico puro ($p/q$).
  /// - Si es false, utiliza la escala cromática temperada ($2^{n/12}$).
  double calculateTargetFrequency(
    double baseFrequencyHz, {
    bool ascending = true,
    bool useJustIntonation = false,
  }) {
    if (semitones == 0) return baseFrequencyHz;

    final ratio = useJustIntonation ? justRatio : equalTemperamentRatio;
    return ascending ? (baseFrequencyHz * ratio) : (baseFrequencyHz / ratio);
  }

  /// Retorna el intervalo correspondiente a un número de semitonos dentro de la octava (0 a 12).
  static MusicalInterval fromSemitones(int semitones) {
    final normalized = semitones % 12;
    if (semitones == 12) return MusicalInterval.perfectOctave;
    return MusicalInterval.values.firstWhere(
      (i) => i.semitones == normalized,
      orElse: () => MusicalInterval.unison,
    );
  }

  /// Calcula la desviación en cents entre una frecuencia observada [observedHz]
  /// y una frecuencia esperada [expectedHz]:
  ///
  /// $$\text{cents} = 1200 \cdot \log_2\left(\frac{f_{\text{obs}}}{f_{\text{exp}}}\right)$$
  static double calculateCentsDeviation(double observedHz, double expectedHz) {
    if (observedHz <= 0 || expectedHz <= 0) return 0.0;
    return 1200.0 * (math.log(observedHz / expectedHz) / math.ln2);
  }
}
