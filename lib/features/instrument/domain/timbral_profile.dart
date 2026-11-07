/// Modelo matemático y acústico de envolvente tímbrica y perfil espectral.
/// Permite emular proceduralmente la firma sonora de cualquier instrumento.
library;

/// Envolvente de amplitud estándar ADSR (Attack, Decay, Sustain, Release).
class AdsrEnvelope {
  /// Tiempo de ataque en milisegundos hasta el pico inicial de amplitud.
  final double attackMs;

  /// Tiempo de caída en milisegundos desde el pico hasta el nivel de sostenimiento.
  final double decayMs;

  /// Nivel relativo de sostenimiento mientras la nota continúa excitada (rango 0.0 a 1.0).
  final double sustainLevel;

  /// Tiempo de liberación / apagado en milisegundos tras cesar la excitación.
  final double releaseMs;

  const AdsrEnvelope({
    required this.attackMs,
    required this.decayMs,
    required this.sustainLevel,
    required this.releaseMs,
  }) : assert(attackMs >= 0.0),
       assert(decayMs >= 0.0),
       assert(sustainLevel >= 0.0 && sustainLevel <= 1.0),
       assert(releaseMs >= 0.0);

  /// Presets canónicos de envolvente por tipo de excitación física.
  static const AdsrEnvelope percussivePitched = AdsrEnvelope(
    attackMs: 2.0,
    decayMs: 350.0,
    sustainLevel: 0.15,
    releaseMs: 300.0,
  );

  static const AdsrEnvelope percussiveUnpitched = AdsrEnvelope(
    attackMs: 0.5,
    decayMs: 120.0,
    sustainLevel: 0.0,
    releaseMs: 80.0,
  );

  static const AdsrEnvelope pluckedString = AdsrEnvelope(
    attackMs: 5.0,
    decayMs: 600.0,
    sustainLevel: 0.25,
    releaseMs: 500.0,
  );

  static const AdsrEnvelope bowedStringLegato = AdsrEnvelope(
    attackMs: 80.0,
    decayMs: 100.0,
    sustainLevel: 0.85,
    releaseMs: 150.0,
  );

  static const AdsrEnvelope woodwind = AdsrEnvelope(
    attackMs: 40.0,
    decayMs: 60.0,
    sustainLevel: 0.80,
    releaseMs: 90.0,
  );

  static const AdsrEnvelope brass = AdsrEnvelope(
    attackMs: 30.0,
    decayMs: 80.0,
    sustainLevel: 0.85,
    releaseMs: 100.0,
  );

  static const AdsrEnvelope pianoAcoustic = AdsrEnvelope(
    attackMs: 3.0,
    decayMs: 800.0,
    sustainLevel: 0.35,
    releaseMs: 600.0,
  );

  static const AdsrEnvelope vocal = AdsrEnvelope(
    attackMs: 60.0,
    decayMs: 80.0,
    sustainLevel: 0.90,
    releaseMs: 120.0,
  );
}

/// Distribución de sobretonos armónicos y textura acústica.
class TimbralProfile {
  /// Envolvente de ganancia temporal.
  final AdsrEnvelope adsr;

  /// Amplitud relativa de los primeros 8 armónicos [H1 (fundamental), H2, H3, ..., H8].
  /// Cada valor está normalizado entre 0.0 y 1.0.
  final List<double> harmonicOvertoneAmplitudes;

  /// Proporción de ruido transiente de ataque (0.0 = senoidal pura, 1.0 = impacto/ruido blanco).
  final double noiseTransientRatio;

  /// Factor de resonancia física del cuerpo / caja acústica (0.0 a 1.0).
  final double resonanceFactor;

  const TimbralProfile({
    required this.adsr,
    required this.harmonicOvertoneAmplitudes,
    this.noiseTransientRatio = 0.05,
    this.resonanceFactor = 0.5,
  });

  /// Perfil puro para vientos suaves (flauta). Predominio casi total de fundamental.
  static const TimbralProfile pureFlute = TimbralProfile(
    adsr: AdsrEnvelope.woodwind,
    harmonicOvertoneAmplitudes: [1.0, 0.15, 0.05, 0.02, 0.01, 0.0, 0.0, 0.0],
    noiseTransientRatio: 0.08,
    resonanceFactor: 0.3,
  );

  /// Perfil para lengüeta cilíndrica (clarinete). Armónicos impares destacados (H1, H3, H5).
  static const TimbralProfile clarinet = TimbralProfile(
    adsr: AdsrEnvelope.woodwind,
    harmonicOvertoneAmplitudes: [1.0, 0.08, 0.65, 0.04, 0.35, 0.03, 0.18, 0.02],
    noiseTransientRatio: 0.04,
    resonanceFactor: 0.6,
  );

  /// Perfil brillante para metales (trompeta / saxo). Riqueza armónica progresiva.
  static const TimbralProfile brassBright = TimbralProfile(
    adsr: AdsrEnvelope.brass,
    harmonicOvertoneAmplitudes: [1.0, 0.85, 0.70, 0.55, 0.40, 0.28, 0.18, 0.10],
    noiseTransientRatio: 0.06,
    resonanceFactor: 0.8,
  );

  /// Perfil de cuerda pulsada (guitarra acústica). Ricos armónicos con decaimiento natural.
  static const TimbralProfile acousticGuitar = TimbralProfile(
    adsr: AdsrEnvelope.pluckedString,
    harmonicOvertoneAmplitudes: [1.0, 0.60, 0.45, 0.30, 0.20, 0.12, 0.08, 0.04],
    noiseTransientRatio: 0.12,
    resonanceFactor: 0.85,
  );

  /// Perfil de piano de cola acústico. Cuerda percutida con resonancia de caja armónica.
  static const TimbralProfile grandPiano = TimbralProfile(
    adsr: AdsrEnvelope.pianoAcoustic,
    harmonicOvertoneAmplitudes: [1.0, 0.50, 0.35, 0.22, 0.15, 0.09, 0.05, 0.03],
    noiseTransientRatio: 0.07,
    resonanceFactor: 0.90,
  );

  /// Perfil de cuerda frotada con arco (violín / cello). Armónicos continuos y resonantes.
  static const TimbralProfile bowedStrings = TimbralProfile(
    adsr: AdsrEnvelope.bowedStringLegato,
    harmonicOvertoneAmplitudes: [1.0, 0.70, 0.50, 0.38, 0.25, 0.18, 0.12, 0.08],
    noiseTransientRatio: 0.03,
    resonanceFactor: 0.88,
  );

  /// Perfil de percusión melódica (marimba de concierto).
  static const TimbralProfile concertMarimba = TimbralProfile(
    adsr: AdsrEnvelope.percussivePitched,
    harmonicOvertoneAmplitudes: [1.0, 0.10, 0.04, 0.70, 0.02, 0.01, 0.0, 0.0],
    noiseTransientRatio: 0.15,
    resonanceFactor: 0.75,
  );

  /// Perfil de percusión indeterminada (caja / redoblante).
  static const TimbralProfile snareDrum = TimbralProfile(
    adsr: AdsrEnvelope.percussiveUnpitched,
    harmonicOvertoneAmplitudes: [0.4, 0.6, 0.8, 0.7, 0.9, 0.8, 0.7, 0.6],
    noiseTransientRatio: 0.85,
    resonanceFactor: 0.4,
  );

  /// Perfil vocal humano.
  static const TimbralProfile humanVocal = TimbralProfile(
    adsr: AdsrEnvelope.vocal,
    harmonicOvertoneAmplitudes: [1.0, 0.55, 0.45, 0.35, 0.25, 0.15, 0.10, 0.05],
    noiseTransientRatio: 0.02,
    resonanceFactor: 0.70,
  );
}
