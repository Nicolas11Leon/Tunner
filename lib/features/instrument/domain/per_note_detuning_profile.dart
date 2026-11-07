import 'dart:math' as math;

/// Perfil de micro-afinación y desafinaciones deliberadas por tecla cromática o cuerda.
class PerNoteDetuningProfile {
  final String id;
  final String name;
  final String description;

  /// Desfase microtonal en cents ($\pm 100.0\text{ cents}$) indexado por nota MIDI (0 a 127).
  final Map<int, double> centsOffsetsByMidiNote;

  /// Desfase microtonal en cents ($\pm 100.0\text{ cents}$) indexado por índice de cuerda (0 a N-1).
  final Map<int, double> centsOffsetsByStringIndex;

  const PerNoteDetuningProfile({
    required this.id,
    required this.name,
    required this.description,
    this.centsOffsetsByMidiNote = const {},
    this.centsOffsetsByStringIndex = const {},
  });

  /// Obtiene la desviación en cents para una nota MIDI dada.
  double getCentsOffsetForNote(int midiNote) {
    return centsOffsetsByMidiNote[midiNote] ?? 0.0;
  }

  /// Obtiene la desviación en cents para una cuerda dada por su índice.
  double getCentsOffsetForString(int stringIndex) {
    return centsOffsetsByStringIndex[stringIndex] ?? 0.0;
  }

  /// Calcula la frecuencia acústica física resultante aplicando el offset en cents:
  /// $$f = f_0 \cdot 2^{\frac{\Delta c}{1200}}$$
  double calculateDetunedFrequency(double baseFreqHz, {int? midiNote, int? stringIndex}) {
    double totalOffsetCents = 0.0;
    if (midiNote != null) {
      totalOffsetCents += getCentsOffsetForNote(midiNote);
    }
    if (stringIndex != null) {
      totalOffsetCents += getCentsOffsetForString(stringIndex);
    }

    if (totalOffsetCents.abs() < 0.0001) {
      return baseFreqHz;
    }

    return baseFreqHz * math.pow(2.0, totalOffsetCents / 1200.0);
  }

  /// Retorna una copia con una nota MIDI actualizada con un offset en cents.
  PerNoteDetuningProfile withNoteOffset(int midiNote, double cents) {
    final updated = Map<int, double>.from(centsOffsetsByMidiNote);
    if (cents.abs() < 0.001) {
      updated.remove(midiNote);
    } else {
      updated[midiNote] = cents.clamp(-1200.0, 1200.0);
    }
    return PerNoteDetuningProfile(
      id: id,
      name: name,
      description: description,
      centsOffsetsByMidiNote: updated,
      centsOffsetsByStringIndex: centsOffsetsByStringIndex,
    );
  }

  /// Retorna una copia con una cuerda actualizada con un offset en cents.
  PerNoteDetuningProfile withStringOffset(int stringIndex, double cents) {
    final updated = Map<int, double>.from(centsOffsetsByStringIndex);
    if (cents.abs() < 0.001) {
      updated.remove(stringIndex);
    } else {
      updated[stringIndex] = cents.clamp(-1200.0, 1200.0);
    }
    return PerNoteDetuningProfile(
      id: id,
      name: name,
      description: description,
      centsOffsetsByMidiNote: centsOffsetsByMidiNote,
      centsOffsetsByStringIndex: updated,
    );
  }

  // =========================================================================
  // PRESETS CANÓNICOS DE DESAFINACIÓN Y AFINACIONES ESPECIALES
  // =========================================================================

  /// Preset estándar: Afinación pura sin desafinaciones adicionales (0.0 cents).
  static const PerNoteDetuningProfile standard = PerNoteDetuningProfile(
    id: 'standard_pure',
    name: 'Afinación Pura Estándar',
    description: 'Sin desafinaciones artificiales (0.0 cents en todas las cuerdas y teclas).',
    centsOffsetsByMidiNote: {},
    centsOffsetsByStringIndex: {},
  );

  /// Preset Honky-Tonk: Desafinación sutil alternada emulando piano de taberna con batimento.
  static final PerNoteDetuningProfile honkyTonk = PerNoteDetuningProfile(
    id: 'honky_tonk',
    name: 'Piano Honky-Tonk / Ragtime',
    description: 'Desafinación alternada de ±8 cents para emular unísonos batientes de taberna.',
    centsOffsetsByMidiNote: {
      for (int n = 21; n <= 108; n++) n: (n % 2 == 0 ? 7.5 : -8.0),
    },
    centsOffsetsByStringIndex: {},
  );

  /// Preset Curva de Railsback (Stretch Tuning): Afinación estirada clásica de pianos de concierto.
  static final PerNoteDetuningProfile railsbackStretch = PerNoteDetuningProfile(
    id: 'railsback_stretch',
    name: 'Curva de Railsback (Stretch Tuning)',
    description: 'Graves estirados hacia abajo (-12 cents) y agudos hacia arriba (+20 cents) por inharmonicidad.',
    centsOffsetsByMidiNote: {
      for (int n = 21; n <= 108; n++)
        n: (n < 60)
            ? -12.0 * ((60 - n) / 39.0) // Graves hasta -12 cents en A0
            : 20.0 * ((n - 60) / 48.0), // Agudos hasta +20 cents en C8
    },
    centsOffsetsByStringIndex: {},
  );

  /// Preset Shimmer / 12 Cuerdas: Batimento de cuerdas pareadas de guitarra acústica.
  static const PerNoteDetuningProfile twelveStrings = PerNoteDetuningProfile(
    id: 'twelve_strings',
    name: 'Guitarra 12 Cuerdas (Chorus Shimmer)',
    description: 'Desfase microtonal de ±5 cents simulando las cuerdas dobles de una 12 cuerdas.',
    centsOffsetsByMidiNote: {},
    centsOffsetsByStringIndex: {
      0: 4.5,
      1: -5.0,
      2: 6.0,
      3: -4.0,
      4: 5.5,
      5: -6.0,
    },
  );

  /// Preset Microtonal Maqam Árabe (Bayati / Rast): Cuartos de tono en notas Mi y Si (-50 cents).
  static final PerNoteDetuningProfile quarterToneMaqam = PerNoteDetuningProfile(
    id: 'quarter_tone_maqam',
    name: 'Maqam Oriental (Cuartos de Tono -50¢)',
    description: 'Notas Mi (E) y Si (B) bajadas exactamente 50 cents (medio semitono microtonal).',
    centsOffsetsByMidiNote: {
      for (int n = 0; n <= 127; n++)
        if (n % 12 == 4 || n % 12 == 11) // Mi (4) y Si (11)
          n: -50.0,
    },
    centsOffsetsByStringIndex: {},
  );

  /// Lista de todos los presets canónicos.
  static final List<PerNoteDetuningProfile> presets = [
    standard,
    honkyTonk,
    railsbackStretch,
    twelveStrings,
    quarterToneMaqam,
  ];
}
