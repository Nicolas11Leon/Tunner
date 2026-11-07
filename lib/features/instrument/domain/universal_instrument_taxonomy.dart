/// Taxonomía universal de clasificación de instrumentos musicales.
/// Basada en el sistema científico Hornbostel-Sachs (HS) y el estándar General MIDI.
library;

/// Categoría principal según el sistema Hornbostel-Sachs (HS).
enum HornbostelSachsCategory {
  /// 1. Idiófonos: El sonido se produce por la vibración del propio cuerpo del instrumento.
  idiophone('idiophone', 'Idiófonos (Láminas, Metales y Auto-resonadores)'),

  /// 2. Membranófonos: El sonido se produce por la vibración de una membrana tensa.
  membranophone('membranophone', 'Membranófonos (Tambores y Parches)'),

  /// 3. Cordófonos: El sonido se produce por la vibración de una o más cuerdas.
  chordophone('chordophone', 'Cordófonos (Cuerdas y Teclados de Cuerda)'),

  /// 4. Aerófonos: El sonido se produce por la vibración de una columna de aire.
  aerophone('aerophone', 'Aerófonos (Vientos Maderas y Metales)'),

  /// 5. Electrófonos: El sonido se produce u oscila por medios electrónicos o digitales.
  electrophone('electrophone', 'Electrófonos (Sintetizadores y DSP)'),

  /// 6. Voz Humana: El instrumento acústico biológico primordial.
  vocal('vocal', 'Voz Humana (Aparato Fonador)');

  final String code;
  final String displayName;

  const HornbostelSachsCategory(this.code, this.displayName);
}

/// Subfamilia musical para clasificación de búsqueda y filtros rápidos.
enum InstrumentSubfamily {
  // Aerófonos
  woodwind('woodwind', 'Vientos Madera'),
  brass('brass', 'Vientos Metal'),
  freeReed('free_reed', 'Lengüeta Libre / Fuelle'),

  // Cordófonos
  pluckedStrings('plucked_strings', 'Cuerdas Pulsadas'),
  bowedStrings('bowed_strings', 'Cuerdas Frotadas'),
  keyboardChordophone('keyboard', 'Teclados de Cuerda / Martillo'),

  // Idiófonos
  pitchedPercussion('pitched_percussion', 'Percusión Melódica / Afinada'),
  unpitchedPercussion('unpitched_percussion', 'Percusión Auxiliar / Metales'),

  // Membranófonos
  acousticDrums('acoustic_drums', 'Batería y Tambores de Concierto'),
  latinPercussion('latin_percussion', 'Percusión Latina / Afrocubana'),
  ethnicDrums('ethnic_drums', 'Tambores Étnicos / Folclóricos'),

  // Electrófonos
  synthesizer('synthesizer', 'Sintetizadores y Leads'),
  bassSynth('bass_synth', 'Bajos Sintéticos y Sub-bajos'),

  // Voz
  humanVoice('human', 'Voz Humana Lírica y Popular');

  final String code;
  final String displayName;

  const InstrumentSubfamily(this.code, this.displayName);
}
