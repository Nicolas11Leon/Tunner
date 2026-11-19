/// Tipo de renderizador de interfaz táctil para la emulación interactiva del instrumento.
enum VisualRendererType {
  /// Diapasón con trastes, cuerdas y marcadores de posición (Guitarras, Bajos, Ukeleles, Banjo).
  fretboard('fretboard', 'Mástil con Trastes'),

  /// Diapasón continuo liso sin trastes con guía milimétrica (Violín, Viola, Cello, Contrabajo).
  fingerboard('fingerboard', 'Diapasón Continuo Fretless'),

  /// Teclado clásico de teclas blancas y negras con respuesta táctil (Piano, Clavecín, Órgano).
  keybed('keybed', 'Teclado de Concierto'),

  /// Láminas melódicas percutidas (Marimba, Xilófono, Vibráfono, Glockenspiel).
  malletBars('mallet_bars', 'Láminas Percutidas'),

  /// Cuadrícula o disposición de parches de tambor y platillos (Batería, Timbales, Congas).
  drumPads('drum_pads', 'Pads Táctiles de Percusión'),

  /// Representación de columnas de aire, llaves y pistones (Flauta, Clarinete, Trompeta, Saxo).
  valvesPads('valves_pads', 'Llaves / Pistones de Viento'),

  /// Curva continua de entonación y espectro de formantes (Voz humana).
  vocalFormants('vocal_formants', 'Curva Melódica y Formantes Vocales');

  final String code;
  final String displayName;

  const VisualRendererType(this.code, this.displayName);
}

/// Perfil de diseño, color y componentes gráficos para adaptar la interfaz al instrumento.
class VisualInterfaceProfile {
  /// Tipo de visualizador táctil.
  final VisualRendererType rendererType;

  /// Familia visual de texturas y materiales (wood, brass, darkCarbon, ivory, neonSynth, luthier).
  final String visualMaterialTheme;

  /// Color primario de acento distintivo del instrumento.
  final int primaryAccentHex;

  /// Color secundario / de contraste.
  final int secondaryAccentHex;

  /// Color de fondo o textura de superficie del módulo.
  final int surfaceHex;

  /// Glifo musical técnico representativo del instrumento (código técnico o clave musical SMuFL).
  final String smuflGlyph;

  /// Etiquetas de cuerdas, parches o teclas que se muestran en el visualizador.
  final List<String> tactileLabels;

  const VisualInterfaceProfile({
    required this.rendererType,
    required this.visualMaterialTheme,
    required this.primaryAccentHex,
    required this.secondaryAccentHex,
    required this.surfaceHex,
    required this.smuflGlyph,
    this.tactileLabels = const [],
  });

  /// Preset visual para Guitarras (maderas cálidas, ámbar y trastes niquelados).
  static const VisualInterfaceProfile guitarWarm = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'wood_rosewood',
    primaryAccentHex: 0xFFF59E0B, // Ámbar dorado
    secondaryAccentHex: 0xFFD97706,
    surfaceHex: 0xFF1E140F, // Madera oscura
    smuflGlyph: 'STR',
    tactileLabels: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
  );

  /// Preset visual para Bajo Eléctrico (azul profundo y cuerdas de acero).
  static const VisualInterfaceProfile electricBass = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'dark_carbon',
    primaryAccentHex: 0xFF38BDF8, // Azul eléctrico
    secondaryAccentHex: 0xFF0284C7,
    surfaceHex: 0xFF0F172A, // Slate profundo
    smuflGlyph: 'BSS',
    tactileLabels: ['E1', 'A1', 'D2', 'G2'],
  );

  /// Preset visual para Cuerdas Frotadas (Violín / Cello: luthería clásica y caoba).
  static const VisualInterfaceProfile violinClassical = VisualInterfaceProfile(
    rendererType: VisualRendererType.fingerboard,
    visualMaterialTheme: 'luthier_varnish',
    primaryAccentHex: 0xFFE11D48, // Carmín de luthier
    secondaryAccentHex: 0xFFBE123C,
    surfaceHex: 0xFF1C1014,
    smuflGlyph: 'VLN',
    tactileLabels: ['G3', 'D4', 'A4', 'E5'],
  );

  /// Preset visual para Vientos Metal (Trompeta / Corno: latón dorado y brillo).
  static const VisualInterfaceProfile brassGolden = VisualInterfaceProfile(
    rendererType: VisualRendererType.valvesPads,
    visualMaterialTheme: 'brass_gold',
    primaryAccentHex: 0xFFFBBF24, // Oro metálico
    secondaryAccentHex: 0xFFD97706,
    surfaceHex: 0xFF1A1608,
    smuflGlyph: 'BRS',
    tactileLabels: ['Pistón 1', 'Pistón 2', 'Pistón 3'],
  );

  /// Preset visual para Vientos Madera (Flauta / Clarinete: ébano y plata).
  static const VisualInterfaceProfile woodwindSilver = VisualInterfaceProfile(
    rendererType: VisualRendererType.valvesPads,
    visualMaterialTheme: 'silver_ebony',
    primaryAccentHex: 0xFF34D399, // Esmeralda / plata
    secondaryAccentHex: 0xFF059669,
    surfaceHex: 0xFF0B1713,
    smuflGlyph: 'WND',
    tactileLabels: ['Llave C', 'Llave D', 'Llave E', 'Llave F', 'Llave G', 'Llave A', 'Llave B'],
  );

  /// Preset visual para Piano de Cola (marfil, ébano y elegancia de conservatorio).
  static const VisualInterfaceProfile grandPianoIvory = VisualInterfaceProfile(
    rendererType: VisualRendererType.keybed,
    visualMaterialTheme: 'ivory_ebony',
    primaryAccentHex: 0xFFA78BFA, // Púrpura conservatorio
    secondaryAccentHex: 0xFF7C3AED,
    surfaceHex: 0xFF140F21,
    smuflGlyph: 'PNO',
    tactileLabels: ['88 Teclas (A0 - C8)'],
  );

  /// Preset visual para Percusión Melódica (Marimba / Vibráfono: palisandro y tubos de resonancia).
  static const VisualInterfaceProfile marimbaConcert = VisualInterfaceProfile(
    rendererType: VisualRendererType.malletBars,
    visualMaterialTheme: 'rosewood_bars',
    primaryAccentHex: 0xFFFB923C, // Naranja madera
    secondaryAccentHex: 0xFFEA580C,
    surfaceHex: 0xFF1C130D,
    smuflGlyph: 'MLT',
    tactileLabels: ['Láminas Cromáticas (C2 - C7)'],
  );

  /// Preset visual para Batería Acústica y Percusión (parches de tambor y platillos).
  static const VisualInterfaceProfile acousticDrums = VisualInterfaceProfile(
    rendererType: VisualRendererType.drumPads,
    visualMaterialTheme: 'percussion_chrome',
    primaryAccentHex: 0xFF10B981, // Verde cromo
    secondaryAccentHex: 0xFF059669,
    surfaceHex: 0xFF0B1A14,
    smuflGlyph: 'DRM',
    tactileLabels: ['Bombo', 'Caja', 'Hi-Hat', 'Tom 1', 'Tom 2', 'Tom Piso', 'Crash', 'Ride'],
  );

  /// Preset visual para Voz Humana (cian vocal, espectro de formantes y curva tonal).
  static const VisualInterfaceProfile vocalStudio = VisualInterfaceProfile(
    rendererType: VisualRendererType.vocalFormants,
    visualMaterialTheme: 'vocal_booth',
    primaryAccentHex: 0xFF06B6D4, // Cian de estudio
    secondaryAccentHex: 0xFF0891B2,
    surfaceHex: 0xFF09171C,
    smuflGlyph: 'VOX',
    tactileLabels: ['Formante F1', 'Formante F2', 'Vibrato Rate', 'Autotune Speed'],
  );

  /// Preset visual para Sintetizadores y Teclados Electrónicos.
  static const VisualInterfaceProfile synthModern = VisualInterfaceProfile(
    rendererType: VisualRendererType.keybed,
    visualMaterialTheme: 'neon_synth',
    primaryAccentHex: 0xFFEC4899, // Magenta Neón
    secondaryAccentHex: 0xFFDB2777,
    surfaceHex: 0xFF1B0C18,
    smuflGlyph: 'SYN',
    tactileLabels: ['Osc 1 (Saw)', 'Cutoff', 'Resonance', 'Glide'],
  );

  /// Preset visual para Kora de África Occidental.
  static const VisualInterfaceProfile koraEthnic = VisualInterfaceProfile(
    rendererType: VisualRendererType.fingerboard,
    visualMaterialTheme: 'calabash_wood',
    primaryAccentHex: 0xFFEAB308, // Oro africano
    secondaryAccentHex: 0xFFCA8A04,
    surfaceHex: 0xFF26180E,
    smuflGlyph: 'KRA',
    tactileLabels: ['F2', 'C3', 'D3', 'E3', 'F3', 'G3', 'A3', 'Bb3', 'C4', 'D4', 'E4'],
  );

  /// Preset visual para Sitar de la India.
  static const VisualInterfaceProfile sitarEthnic = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'teak_brass',
    primaryAccentHex: 0xFFF97316, // Azafrán védico
    secondaryAccentHex: 0xFFC2410C,
    surfaceHex: 0xFF1F120A,
    smuflGlyph: 'SIT',
    tactileLabels: ['C2', 'G2', 'C3', 'F3', 'G3', 'C4', 'C5'],
  );

  /// Preset visual para Shakuhachi japonés.
  static const VisualInterfaceProfile shakuhachiEthnic = VisualInterfaceProfile(
    rendererType: VisualRendererType.valvesPads,
    visualMaterialTheme: 'bamboo_natural',
    primaryAccentHex: 0xFF84CC16, // Verde bambú
    secondaryAccentHex: 0xFF65A30D,
    surfaceHex: 0xFF1A1F12,
    smuflGlyph: 'SHK',
    tactileLabels: ['D4', 'F4', 'G4', 'A4', 'C5'],
  );

  /// Preset visual para Charango andino.
  static const VisualInterfaceProfile charangoEthnic = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'andean_jacaranda',
    primaryAccentHex: 0xFF06B6D4, // Turquesa andino
    secondaryAccentHex: 0xFF0891B2,
    surfaceHex: 0xFF131D24,
    smuflGlyph: 'CHG',
    tactileLabels: ['E5', 'A4', 'E5', 'C5', 'G4'],
  );

  /// Preset visual para Cuatro tradicional venezolano.
  static const VisualInterfaceProfile cuatroVenezuelan = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'cedar_llanero',
    primaryAccentHex: 0xFFE11D48, // Rojo llanero
    secondaryAccentHex: 0xFFBE123C,
    surfaceHex: 0xFF241216,
    smuflGlyph: 'CTR',
    tactileLabels: ['B3', 'F#4', 'D4', 'A3'],
  );
}
