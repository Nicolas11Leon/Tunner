import 'instrument_profile_entity.dart';
import 'universal_instrument_taxonomy.dart';
import 'timbral_profile.dart';
import 'acoustic_range.dart';
import 'visual_interface_profile.dart';

/// Definición universal completa de un instrumento musical.
/// Integra taxonomía formal Hornbostel-Sachs, mapeo MIDI, acústica,
/// envolvente tímbrica procedural (ADSR) y perfil visual para emulación.
class UniversalInstrumentDefinition {
  /// Identificador universal jerárquico ordenable (ej: 'chordophone.plucked.guitar_classical').
  final String universalId;

  /// Nombre canónico en español (ej: 'Guitarra Clásica').
  final String displayName;

  /// Nombres alternativos o en otros idiomas para optimizar búsquedas globales.
  final List<String> searchKeywords;

  /// Categoría principal Hornbostel-Sachs.
  final HornbostelSachsCategory category;

  /// Subfamilia musical.
  final InstrumentSubfamily subfamily;

  /// Clave de afinación del instrumento (Do, Sib, Mib, etc.).
  final InstrumentKey tuningKey;

  /// Clave principal de notación en el pentagrama.
  final InstrumentClef notationClef;

  /// Desfase de transposición en semitonos respecto a Do de Concierto.
  final int transpositionSemitones;

  /// Rango de frecuencias, límites de tesitura y notas MIDI.
  final AcousticRange acousticRange;

  /// Envolvente ADSR y distribución espectral de armónicos para síntesis/emulación.
  final TimbralProfile timbralProfile;

  /// Perfil estético, interfaz táctil y paleta visual.
  final VisualInterfaceProfile visualProfile;

  /// Número de programa General MIDI (0-127) o nota de percusión GM Canal 10.
  final int generalMidiNumber;

  /// Indica si el instrumento pertenece a percusión de altura indeterminada (Canal 10 MIDI).
  final bool isDrumMapPercussion;

  const UniversalInstrumentDefinition({
    required this.universalId,
    required this.displayName,
    required this.searchKeywords,
    required this.category,
    required this.subfamily,
    required this.tuningKey,
    required this.notationClef,
    required this.transpositionSemitones,
    required this.acousticRange,
    required this.timbralProfile,
    required this.visualProfile,
    required this.generalMidiNumber,
    this.isDrumMapPercussion = false,
  });

  /// Indica si el instrumento es transpositor.
  bool get isTransposing => transpositionSemitones != 0;

  // =========================================================================
  // CATÁLOGO UNIVERSAL CANÓNICO DE INSTRUMENTOS
  // =========================================================================

  // --- 1. AERÓFONOS: MADERAS ---

  static const UniversalInstrumentDefinition fluteConcert = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.flute_concert_c',
    displayName: 'Flauta Traversa de Concierto',
    searchKeywords: ['flauta', 'flute', 'traversa', 'soprano flute', 'c flute'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 261.63, // C4
      maxFrequencyHz: 2093.00, // C7
      minMidiNote: 60,
      maxMidiNote: 96,
    ),
    timbralProfile: TimbralProfile.pureFlute,
    visualProfile: VisualInterfaceProfile.woodwindSilver,
    generalMidiNumber: 73, // Flute
  );

  static const UniversalInstrumentDefinition piccolo = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.piccolo_c',
    displayName: 'Flautín / Piccolo',
    searchKeywords: ['piccolo', 'flautin', 'octave flute'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.highOctaveC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 12,
    acousticRange: AcousticRange(
      minFrequencyHz: 523.25, // C5
      maxFrequencyHz: 4186.01, // C8
      minMidiNote: 72,
      maxMidiNote: 108,
    ),
    timbralProfile: TimbralProfile.pureFlute,
    visualProfile: VisualInterfaceProfile.woodwindSilver,
    generalMidiNumber: 72, // Piccolo
  );

  static const UniversalInstrumentDefinition oboe = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.oboe_c',
    displayName: 'Oboe de Concierto',
    searchKeywords: ['oboe', 'hautbois'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 233.08, // Bb3
      maxFrequencyHz: 1760.00, // A6
      minMidiNote: 58,
      maxMidiNote: 93,
    ),
    timbralProfile: TimbralProfile.clarinet,
    visualProfile: VisualInterfaceProfile.woodwindSilver,
    generalMidiNumber: 68, // Oboe
  );

  static const UniversalInstrumentDefinition englishHorn = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.english_horn_f',
    displayName: 'Corno Inglés en Fa',
    searchKeywords: ['corno ingles', 'english horn', 'cor anglais'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.fKey,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -7,
    acousticRange: AcousticRange(
      minFrequencyHz: 164.81, // E3
      maxFrequencyHz: 1046.50, // C6
      minMidiNote: 52,
      maxMidiNote: 84,
    ),
    timbralProfile: TimbralProfile.clarinet,
    visualProfile: VisualInterfaceProfile.woodwindSilver,
    generalMidiNumber: 69, // English Horn
  );

  static const UniversalInstrumentDefinition clarinetBb = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.clarinet_bb',
    displayName: 'Clarinete Soprano en Si♭',
    searchKeywords: ['clarinete', 'clarinet', 'soprano clarinet', 'bb clarinet'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.bFlat,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -2,
    acousticRange: AcousticRange(
      minFrequencyHz: 146.83, // D3 (sonando)
      maxFrequencyHz: 1567.98, // G6
      minMidiNote: 50,
      maxMidiNote: 91,
    ),
    timbralProfile: TimbralProfile.clarinet,
    visualProfile: VisualInterfaceProfile.woodwindSilver,
    generalMidiNumber: 71, // Clarinet
  );

  static const UniversalInstrumentDefinition bassoon = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.bassoon_c',
    displayName: 'Fagot de Concierto',
    searchKeywords: ['fagot', 'bassoon', 'fagotto'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 58.27, // Bb1
      maxFrequencyHz: 880.00, // A5
      minMidiNote: 34,
      maxMidiNote: 81,
    ),
    timbralProfile: TimbralProfile.clarinet,
    visualProfile: VisualInterfaceProfile.woodwindSilver,
    generalMidiNumber: 70, // Bassoon
  );

  static const UniversalInstrumentDefinition sopranoSax = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.sax_soprano_bb',
    displayName: 'Saxofón Soprano en Si♭',
    searchKeywords: ['saxo soprano', 'soprano sax', 'saxofon'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.bFlat,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -2,
    acousticRange: AcousticRange(
      minFrequencyHz: 207.65, // Ab3
      maxFrequencyHz: 1318.51, // E6
      minMidiNote: 56,
      maxMidiNote: 88,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 64, // Soprano Sax
  );

  static const UniversalInstrumentDefinition altoSax = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.sax_alto_eb',
    displayName: 'Saxofón Alto en Mi♭',
    searchKeywords: ['saxo alto', 'alto sax', 'saxofon'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.eFlat,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -9,
    acousticRange: AcousticRange(
      minFrequencyHz: 138.59, // Db3
      maxFrequencyHz: 880.00, // A5
      minMidiNote: 49,
      maxMidiNote: 81,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 65, // Alto Sax
  );

  static const UniversalInstrumentDefinition tenorSax = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.sax_tenor_bb',
    displayName: 'Saxofón Tenor en Si♭',
    searchKeywords: ['saxo tenor', 'tenor sax'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.bFlat,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -14,
    acousticRange: AcousticRange(
      minFrequencyHz: 103.83, // Ab2
      maxFrequencyHz: 659.25, // E5
      minMidiNote: 44,
      maxMidiNote: 76,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 66, // Tenor Sax
  );

  static const UniversalInstrumentDefinition baritoneSax = UniversalInstrumentDefinition(
    universalId: 'aerophone.woodwind.sax_baritone_eb',
    displayName: 'Saxofón Barítono en Mi♭',
    searchKeywords: ['saxo baritono', 'baritone sax', 'bari sax'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.woodwind,
    tuningKey: InstrumentKey.eFlat,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -21,
    acousticRange: AcousticRange(
      minFrequencyHz: 65.41, // C2
      maxFrequencyHz: 440.00, // A4
      minMidiNote: 36,
      maxMidiNote: 69,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 67, // Baritone Sax
  );

  // --- 2. AERÓFONOS: METALES ---

  static const UniversalInstrumentDefinition trumpetBb = UniversalInstrumentDefinition(
    universalId: 'aerophone.brass.trumpet_bb',
    displayName: 'Trompeta en Si♭',
    searchKeywords: ['trompeta', 'trumpet', 'trompette'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.brass,
    tuningKey: InstrumentKey.bFlat,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -2,
    acousticRange: AcousticRange(
      minFrequencyHz: 164.81, // E3
      maxFrequencyHz: 987.77, // B5
      minMidiNote: 52,
      maxMidiNote: 83,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 56, // Trumpet
  );

  static const UniversalInstrumentDefinition frenchHorn = UniversalInstrumentDefinition(
    universalId: 'aerophone.brass.french_horn_f',
    displayName: 'Corno Francés / Trompa en Fa',
    searchKeywords: ['corno', 'trompa', 'french horn'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.brass,
    tuningKey: InstrumentKey.fKey,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -7,
    acousticRange: AcousticRange(
      minFrequencyHz: 65.41, // C2
      maxFrequencyHz: 880.00, // A5
      minMidiNote: 36,
      maxMidiNote: 81,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 60, // French Horn
  );

  static const UniversalInstrumentDefinition tromboneTenor = UniversalInstrumentDefinition(
    universalId: 'aerophone.brass.trombone_tenor',
    displayName: 'Trombón Tenor de Varas',
    searchKeywords: ['trombon', 'trombone', 'posaune'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.brass,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 82.41, // E2
      maxFrequencyHz: 587.33, // D5
      minMidiNote: 40,
      maxMidiNote: 74,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 57, // Trombone
  );

  static const UniversalInstrumentDefinition tuba = UniversalInstrumentDefinition(
    universalId: 'aerophone.brass.tuba_c',
    displayName: 'Tuba de Concierto',
    searchKeywords: ['tuba', 'bass tuba'],
    category: HornbostelSachsCategory.aerophone,
    subfamily: InstrumentSubfamily.brass,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 43.65, // F1
      maxFrequencyHz: 349.23, // F4
      minMidiNote: 29,
      maxMidiNote: 65,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.brassGolden,
    generalMidiNumber: 58, // Tuba
  );

  // --- 3. CORDÓFONOS: CUERDAS FROTADAS ---

  static const UniversalInstrumentDefinition violin = UniversalInstrumentDefinition(
    universalId: 'chordophone.bowed_strings.violin_acoustic',
    displayName: 'Violín Acústico',
    searchKeywords: ['violin', 'fiddle', 'geige'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.bowedStrings,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 196.00, // G3
      maxFrequencyHz: 3136.00, // G7
      minMidiNote: 55,
      maxMidiNote: 103,
      standardTuningFrequencies: [196.00, 293.66, 440.00, 659.25],
      standardTuningNoteNames: ['G3', 'D4', 'A4', 'E5'],
    ),
    timbralProfile: TimbralProfile.bowedStrings,
    visualProfile: VisualInterfaceProfile.violinClassical,
    generalMidiNumber: 40, // Violin
  );

  static const UniversalInstrumentDefinition viola = UniversalInstrumentDefinition(
    universalId: 'chordophone.bowed_strings.viola_acoustic',
    displayName: 'Viola de Concierto',
    searchKeywords: ['viola', 'alto strings'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.bowedStrings,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 130.81, // C3
      maxFrequencyHz: 1318.51, // E6
      minMidiNote: 48,
      maxMidiNote: 88,
      standardTuningFrequencies: [130.81, 196.00, 293.66, 440.00],
      standardTuningNoteNames: ['C3', 'G3', 'D4', 'A4'],
    ),
    timbralProfile: TimbralProfile.bowedStrings,
    visualProfile: VisualInterfaceProfile.violinClassical,
    generalMidiNumber: 41, // Viola
  );

  static const UniversalInstrumentDefinition cello = UniversalInstrumentDefinition(
    universalId: 'chordophone.bowed_strings.cello_acoustic',
    displayName: 'Violonchelo / Cello',
    searchKeywords: ['cello', 'violonchelo', 'violoncelle'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.bowedStrings,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 65.41, // C2
      maxFrequencyHz: 987.77, // B5
      minMidiNote: 36,
      maxMidiNote: 83,
      standardTuningFrequencies: [65.41, 98.00, 146.83, 220.00],
      standardTuningNoteNames: ['C2', 'G2', 'D3', 'A3'],
    ),
    timbralProfile: TimbralProfile.bowedStrings,
    visualProfile: VisualInterfaceProfile.violinClassical,
    generalMidiNumber: 42, // Cello
  );

  static const UniversalInstrumentDefinition doubleBass = UniversalInstrumentDefinition(
    universalId: 'chordophone.bowed_strings.double_bass_acoustic',
    displayName: 'Contrabajo de Orquesta',
    searchKeywords: ['contrabajo', 'double bass', 'upright bass'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.bowedStrings,
    tuningKey: InstrumentKey.bassC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: -12,
    acousticRange: AcousticRange(
      minFrequencyHz: 30.87, // B0 (con extensión C) o 41.20 E1
      maxFrequencyHz: 392.00, // G4
      minMidiNote: 23,
      maxMidiNote: 67,
      standardTuningFrequencies: [41.20, 55.00, 73.42, 98.00],
      standardTuningNoteNames: ['E1', 'A1', 'D2', 'G2'],
    ),
    timbralProfile: TimbralProfile.bowedStrings,
    visualProfile: VisualInterfaceProfile.violinClassical,
    generalMidiNumber: 43, // Contrabass
  );

  // --- 4. CORDÓFONOS: CUERDAS PULSADAS ---

  static const UniversalInstrumentDefinition classicalGuitar = UniversalInstrumentDefinition(
    universalId: 'chordophone.plucked_strings.guitar_classical',
    displayName: 'Guitarra Clásica / Española (Nylon)',
    searchKeywords: ['guitarra clasica', 'guitarra espanola', 'classical guitar', 'nylon guitar'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.pluckedStrings,
    tuningKey: InstrumentKey.bassC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -12,
    acousticRange: AcousticRange(
      minFrequencyHz: 82.41, // E2
      maxFrequencyHz: 1174.66, // D6
      minMidiNote: 40,
      maxMidiNote: 86,
      standardTuningFrequencies: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63],
      standardTuningNoteNames: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    ),
    timbralProfile: TimbralProfile.acousticGuitar,
    visualProfile: VisualInterfaceProfile.guitarWarm,
    generalMidiNumber: 24, // Acoustic Guitar (nylon)
  );

  static const UniversalInstrumentDefinition electricGuitar = UniversalInstrumentDefinition(
    universalId: 'chordophone.plucked_strings.guitar_electric',
    displayName: 'Guitarra Eléctrica (Clean / Studio)',
    searchKeywords: ['guitarra electrica', 'electric guitar', 'strat', 'les paul'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.pluckedStrings,
    tuningKey: InstrumentKey.bassC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: -12,
    acousticRange: AcousticRange(
      minFrequencyHz: 82.41, // E2
      maxFrequencyHz: 1318.51, // E6
      minMidiNote: 40,
      maxMidiNote: 88,
      standardTuningFrequencies: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63],
      standardTuningNoteNames: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
    ),
    timbralProfile: TimbralProfile.acousticGuitar,
    visualProfile: VisualInterfaceProfile.guitarWarm,
    generalMidiNumber: 27, // Electric Guitar (clean)
  );

  static const UniversalInstrumentDefinition electricBass = UniversalInstrumentDefinition(
    universalId: 'chordophone.plucked_strings.bass_electric_4str',
    displayName: 'Bajo Eléctrico Estándar (4 Cuerdas)',
    searchKeywords: ['bajo electrico', 'electric bass', 'bass guitar'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.pluckedStrings,
    tuningKey: InstrumentKey.bassC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: -12,
    acousticRange: AcousticRange(
      minFrequencyHz: 41.20, // E1
      maxFrequencyHz: 392.00, // G4
      minMidiNote: 28,
      maxMidiNote: 67,
      standardTuningFrequencies: [41.20, 55.00, 73.42, 98.00],
      standardTuningNoteNames: ['E1', 'A1', 'D2', 'G2'],
    ),
    timbralProfile: TimbralProfile.acousticGuitar,
    visualProfile: VisualInterfaceProfile.electricBass,
    generalMidiNumber: 33, // Electric Bass (finger)
  );

  static const UniversalInstrumentDefinition ukulele = UniversalInstrumentDefinition(
    universalId: 'chordophone.plucked_strings.ukulele_soprano',
    displayName: 'Ukelele Soprano (G-C-E-A)',
    searchKeywords: ['ukelele', 'ukulele', 'uke'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.pluckedStrings,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 261.63, // C4
      maxFrequencyHz: 1046.50, // C6
      minMidiNote: 60,
      maxMidiNote: 84,
      standardTuningFrequencies: [392.00, 261.63, 329.63, 440.00],
      standardTuningNoteNames: ['G4', 'C4', 'E4', 'A4'],
    ),
    timbralProfile: TimbralProfile.acousticGuitar,
    visualProfile: VisualInterfaceProfile.guitarWarm,
    generalMidiNumber: 24,
  );

  // --- 5. CORDÓFONOS: TECLADOS ---

  static const UniversalInstrumentDefinition grandPiano = UniversalInstrumentDefinition(
    universalId: 'chordophone.keyboard.piano_grand_acoustic',
    displayName: 'Piano de Cola de Concierto',
    searchKeywords: ['piano', 'grand piano', 'piano de cola', 'klavier'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.keyboardChordophone,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 27.50, // A0
      maxFrequencyHz: 4186.01, // C8
      minMidiNote: 21,
      maxMidiNote: 108,
    ),
    timbralProfile: TimbralProfile.grandPiano,
    visualProfile: VisualInterfaceProfile.grandPianoIvory,
    generalMidiNumber: 0, // Acoustic Grand Piano
  );

  static const UniversalInstrumentDefinition harpsichord = UniversalInstrumentDefinition(
    universalId: 'chordophone.keyboard.harpsichord_baroque',
    displayName: 'Clavecín / Clavicémbalo Barroco',
    searchKeywords: ['clavecin', 'harpsichord', 'cembalo'],
    category: HornbostelSachsCategory.chordophone,
    subfamily: InstrumentSubfamily.keyboardChordophone,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 65.41, // C2
      maxFrequencyHz: 1567.98, // G6
      minMidiNote: 36,
      maxMidiNote: 91,
    ),
    timbralProfile: TimbralProfile.grandPiano,
    visualProfile: VisualInterfaceProfile.grandPianoIvory,
    generalMidiNumber: 6, // Harpsichord
  );

  // --- 6. IDIÓFONOS: PERCUSIÓN AFINADA ---

  static const UniversalInstrumentDefinition concertMarimba = UniversalInstrumentDefinition(
    universalId: 'idiophone.pitched_percussion.marimba_concert',
    displayName: 'Marimba de Concierto (5 Octavas)',
    searchKeywords: ['marimba', 'marimba de concierto'],
    category: HornbostelSachsCategory.idiophone,
    subfamily: InstrumentSubfamily.pitchedPercussion,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 65.41, // C2
      maxFrequencyHz: 2093.00, // C7
      minMidiNote: 36,
      maxMidiNote: 96,
    ),
    timbralProfile: TimbralProfile.concertMarimba,
    visualProfile: VisualInterfaceProfile.marimbaConcert,
    generalMidiNumber: 12, // Marimba
  );

  static const UniversalInstrumentDefinition vibraphone = UniversalInstrumentDefinition(
    universalId: 'idiophone.pitched_percussion.vibraphone_jazz',
    displayName: 'Vibráfono de Concierto con Motor',
    searchKeywords: ['vibrafono', 'vibraphone', 'vibes'],
    category: HornbostelSachsCategory.idiophone,
    subfamily: InstrumentSubfamily.pitchedPercussion,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 174.61, // F3
      maxFrequencyHz: 1396.91, // F6
      minMidiNote: 53,
      maxMidiNote: 89,
    ),
    timbralProfile: TimbralProfile.concertMarimba,
    visualProfile: VisualInterfaceProfile.marimbaConcert,
    generalMidiNumber: 11, // Vibraphone
  );

  static const UniversalInstrumentDefinition glockenspiel = UniversalInstrumentDefinition(
    universalId: 'idiophone.pitched_percussion.glockenspiel_orchestral',
    displayName: 'Glockenspiel / Campanas de Metal',
    searchKeywords: ['glockenspiel', 'campanas', 'orchestral bells'],
    category: HornbostelSachsCategory.idiophone,
    subfamily: InstrumentSubfamily.pitchedPercussion,
    tuningKey: InstrumentKey.highOctaveC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 24, // Suena 2 octavas arriba de lo escrito
    acousticRange: AcousticRange(
      minFrequencyHz: 783.99, // G5 (suena G7)
      maxFrequencyHz: 4186.01, // C8
      minMidiNote: 79,
      maxMidiNote: 108,
    ),
    timbralProfile: TimbralProfile.concertMarimba,
    visualProfile: VisualInterfaceProfile.marimbaConcert,
    generalMidiNumber: 9, // Glockenspiel
  );

  // --- 7. MEMBRANÓFONOS Y BATERÍA ACÚSTICA ---

  static const UniversalInstrumentDefinition acousticDrumKit = UniversalInstrumentDefinition(
    universalId: 'membranophone.acoustic_drums.standard_kit',
    displayName: 'Batería Acústica Completa (Standard Kit)',
    searchKeywords: ['bateria', 'drum kit', 'drums', 'bateria acustica'],
    category: HornbostelSachsCategory.membranophone,
    subfamily: InstrumentSubfamily.acousticDrums,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 35.0,
      maxFrequencyHz: 10000.0,
      minMidiNote: 35, // Bass Drum 2
      maxMidiNote: 81, // Open Triangle
    ),
    timbralProfile: TimbralProfile.snareDrum,
    visualProfile: VisualInterfaceProfile.acousticDrums,
    generalMidiNumber: 0, // Standard Drum Kit Preset
    isDrumMapPercussion: true,
  );

  static const UniversalInstrumentDefinition snareDrumConcert = UniversalInstrumentDefinition(
    universalId: 'membranophone.acoustic_drums.snare_drum',
    displayName: 'Caja / Redoblante de Concierto',
    searchKeywords: ['caja', 'redoblante', 'snare drum', 'tarola'],
    category: HornbostelSachsCategory.membranophone,
    subfamily: InstrumentSubfamily.acousticDrums,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 150.0,
      maxFrequencyHz: 8000.0,
      minMidiNote: 38, // Acoustic Snare GM
      maxMidiNote: 40, // Electric Snare GM
    ),
    timbralProfile: TimbralProfile.snareDrum,
    visualProfile: VisualInterfaceProfile.acousticDrums,
    generalMidiNumber: 38,
    isDrumMapPercussion: true,
  );

  static const UniversalInstrumentDefinition orchestralTimpani = UniversalInstrumentDefinition(
    universalId: 'membranophone.acoustic_drums.timpani_orchestral',
    displayName: 'Timbales Sinfónicos Afinables',
    searchKeywords: ['timbales', 'timpani', 'kettledrums'],
    category: HornbostelSachsCategory.membranophone,
    subfamily: InstrumentSubfamily.acousticDrums,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 73.42, // D2
      maxFrequencyHz: 220.00, // A3
      minMidiNote: 38,
      maxMidiNote: 57,
    ),
    timbralProfile: TimbralProfile.concertMarimba,
    visualProfile: VisualInterfaceProfile.acousticDrums,
    generalMidiNumber: 47, // Timpani GM
  );

  static const UniversalInstrumentDefinition congasAfroCuban = UniversalInstrumentDefinition(
    universalId: 'membranophone.latin_percussion.congas_set',
    displayName: 'Congas Afrocubanas (Quinto, Secundo, Tumba)',
    searchKeywords: ['congas', 'tumbadoras', 'quinto', 'latin percussion'],
    category: HornbostelSachsCategory.membranophone,
    subfamily: InstrumentSubfamily.latinPercussion,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 100.0,
      maxFrequencyHz: 3500.0,
      minMidiNote: 62, // Mute Hi Conga GM
      maxMidiNote: 64, // Low Conga GM
    ),
    timbralProfile: TimbralProfile.snareDrum,
    visualProfile: VisualInterfaceProfile.acousticDrums,
    generalMidiNumber: 62,
    isDrumMapPercussion: true,
  );

  // --- 8. VOZ HUMANA ---

  static const UniversalInstrumentDefinition voiceSoprano = UniversalInstrumentDefinition(
    universalId: 'vocal.human.voice_soprano',
    displayName: 'Voz Humana: Soprano',
    searchKeywords: ['voz soprano', 'soprano', 'canto'],
    category: HornbostelSachsCategory.vocal,
    subfamily: InstrumentSubfamily.humanVoice,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 261.63, // C4
      maxFrequencyHz: 1046.50, // C6
      minMidiNote: 60,
      maxMidiNote: 84,
    ),
    timbralProfile: TimbralProfile.humanVocal,
    visualProfile: VisualInterfaceProfile.vocalStudio,
    generalMidiNumber: 54, // Synth Voice
  );

  static const UniversalInstrumentDefinition voiceTenor = UniversalInstrumentDefinition(
    universalId: 'vocal.human.voice_tenor',
    displayName: 'Voz Humana: Tenor',
    searchKeywords: ['voz tenor', 'tenor', 'canto tenor'],
    category: HornbostelSachsCategory.vocal,
    subfamily: InstrumentSubfamily.humanVoice,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 130.81, // C3
      maxFrequencyHz: 523.25, // C5
      minMidiNote: 48,
      maxMidiNote: 72,
    ),
    timbralProfile: TimbralProfile.humanVocal,
    visualProfile: VisualInterfaceProfile.vocalStudio,
    generalMidiNumber: 54,
  );

  static const UniversalInstrumentDefinition voiceBass = UniversalInstrumentDefinition(
    universalId: 'vocal.human.voice_bass',
    displayName: 'Voz Humana: Bajo / Barítono',
    searchKeywords: ['voz bajo', 'baritono', 'bass vocal', 'canto'],
    category: HornbostelSachsCategory.vocal,
    subfamily: InstrumentSubfamily.humanVoice,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.bass,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 65.41, // C2
      maxFrequencyHz: 329.63, // E4
      minMidiNote: 36,
      maxMidiNote: 64,
    ),
    timbralProfile: TimbralProfile.humanVocal,
    visualProfile: VisualInterfaceProfile.vocalStudio,
    generalMidiNumber: 54,
  );

  // --- 9. ELECTRÓFONOS: SINTETIZADORES ---

  static const UniversalInstrumentDefinition synthLeadSaw = UniversalInstrumentDefinition(
    universalId: 'electrophone.synthesizer.lead_sawtooth',
    displayName: 'Sintetizador Analógico: Lead Sawtooth',
    searchKeywords: ['sintetizador', 'synth lead', 'sawtooth', 'lead'],
    category: HornbostelSachsCategory.electrophone,
    subfamily: InstrumentSubfamily.synthesizer,
    tuningKey: InstrumentKey.concertC,
    notationClef: InstrumentClef.treble,
    transpositionSemitones: 0,
    acousticRange: AcousticRange(
      minFrequencyHz: 40.0,
      maxFrequencyHz: 4000.0,
      minMidiNote: 28,
      maxMidiNote: 96,
    ),
    timbralProfile: TimbralProfile.brassBright,
    visualProfile: VisualInterfaceProfile.synthModern,
    generalMidiNumber: 81, // Lead 2 (sawtooth)
  );

  // =========================================================================
  // LISTA MAESTRA Y MÉTODOS DE BÚSQUEDA Y FILTRADO TAXONÓMICO
  // =========================================================================

  /// Lista exhaustiva de todos los instrumentos universales registrados.
  static const List<UniversalInstrumentDefinition> masterCatalog = [
    // Maderas
    fluteConcert,
    piccolo,
    oboe,
    englishHorn,
    clarinetBb,
    bassoon,
    sopranoSax,
    altoSax,
    tenorSax,
    baritoneSax,

    // Metales
    trumpetBb,
    frenchHorn,
    tromboneTenor,
    tuba,

    // Cuerdas Frotadas
    violin,
    viola,
    cello,
    doubleBass,

    // Cuerdas Pulsadas
    classicalGuitar,
    electricGuitar,
    electricBass,
    ukulele,

    // Teclados
    grandPiano,
    harpsichord,

    // Percusión Afinada
    concertMarimba,
    vibraphone,
    glockenspiel,

    // Batería & Tambores
    acousticDrumKit,
    snareDrumConcert,
    orchestralTimpani,
    congasAfroCuban,

    // Voces
    voiceSoprano,
    voiceTenor,
    voiceBass,

    // Electrónicos
    synthLeadSaw,
  ];

  /// Busca un instrumento por su identificador universal exacto.
  static UniversalInstrumentDefinition? findById(String id) {
    for (final inst in masterCatalog) {
      if (inst.universalId == id) return inst;
    }
    return null;
  }

  /// Busca instrumentos que coincidan con un texto de consulta (nombre, ID o palabras clave).
  static List<UniversalInstrumentDefinition> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return masterCatalog;

    return masterCatalog.where((inst) {
      if (inst.universalId.toLowerCase().contains(clean)) return true;
      if (inst.displayName.toLowerCase().contains(clean)) return true;
      for (final kw in inst.searchKeywords) {
        if (kw.toLowerCase().contains(clean)) return true;
      }
      return false;
    }).toList();
  }

  /// Filtra instrumentos por su categoría Hornbostel-Sachs.
  static List<UniversalInstrumentDefinition> filterByCategory(HornbostelSachsCategory cat) {
    return masterCatalog.where((i) => i.category == cat).toList();
  }

  /// Filtra instrumentos por su subfamilia.
  static List<UniversalInstrumentDefinition> filterBySubfamily(InstrumentSubfamily sub) {
    return masterCatalog.where((i) => i.subfamily == sub).toList();
  }
}
