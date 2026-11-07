import 'package:flutter/material.dart';

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
  final Color primaryAccentColor;

  /// Color secundario / de contraste.
  final Color secondaryAccentColor;

  /// Color de fondo o textura de superficie del módulo.
  final Color surfaceColor;

  /// Glifo musical SMuFL representativo del instrumento (o código unicode musical).
  final String smuflGlyph;

  /// Etiquetas de cuerdas, parches o teclas que se muestran en el visualizador.
  final List<String> tactileLabels;

  const VisualInterfaceProfile({
    required this.rendererType,
    required this.visualMaterialTheme,
    required this.primaryAccentColor,
    required this.secondaryAccentColor,
    required this.surfaceColor,
    required this.smuflGlyph,
    this.tactileLabels = const [],
  });

  /// Preset visual para Guitarras (maderas cálidas, ámbar y trastes niquelados).
  static const VisualInterfaceProfile guitarWarm = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'wood_rosewood',
    primaryAccentColor: Color(0xFFF59E0B), // Ámbar dorado
    secondaryAccentColor: Color(0xFFD97706),
    surfaceColor: Color(0xFF1E140F), // Madera oscura
    smuflGlyph: '🎸',
    tactileLabels: ['E2', 'A2', 'D3', 'G3', 'B3', 'E4'],
  );

  /// Preset visual para Bajo Eléctrico (azul profundo y cuerdas de acero).
  static const VisualInterfaceProfile electricBass = VisualInterfaceProfile(
    rendererType: VisualRendererType.fretboard,
    visualMaterialTheme: 'dark_carbon',
    primaryAccentColor: Color(0xFF38BDF8), // Azul eléctrico
    secondaryAccentColor: Color(0xFF0284C7),
    surfaceColor: Color(0xFF0F172A), // Slate profundo
    smuflGlyph: '🎸',
    tactileLabels: ['E1', 'A1', 'D2', 'G2'],
  );

  /// Preset visual para Cuerdas Frotadas (Violín / Cello: luthería clásica y caoba).
  static const VisualInterfaceProfile violinClassical = VisualInterfaceProfile(
    rendererType: VisualRendererType.fingerboard,
    visualMaterialTheme: 'luthier_varnish',
    primaryAccentColor: Color(0xFFE11D48), // Carmín de luthier
    secondaryAccentColor: Color(0xFFBE123C),
    surfaceColor: Color(0xFF1C1014),
    smuflGlyph: '🎻',
    tactileLabels: ['G3', 'D4', 'A4', 'E5'],
  );

  /// Preset visual para Vientos Metal (Trompeta / Corno: latón dorado y brillo).
  static const VisualInterfaceProfile brassGolden = VisualInterfaceProfile(
    rendererType: VisualRendererType.valvesPads,
    visualMaterialTheme: 'brass_gold',
    primaryAccentColor: Color(0xFFFBBF24), // Oro metálico
    secondaryAccentColor: Color(0xFFD97706),
    surfaceColor: Color(0xFF1A1608),
    smuflGlyph: '🎺',
    tactileLabels: ['Pistón 1', 'Pistón 2', 'Pistón 3'],
  );

  /// Preset visual para Vientos Madera (Flauta / Clarinete: ébano y plata).
  static const VisualInterfaceProfile woodwindSilver = VisualInterfaceProfile(
    rendererType: VisualRendererType.valvesPads,
    visualMaterialTheme: 'silver_ebony',
    primaryAccentColor: Color(0xFF34D399), // Esmeralda / plata
    secondaryAccentColor: Color(0xFF059669),
    surfaceColor: Color(0xFF0B1713),
    smuflGlyph: '🎷',
    tactileLabels: ['Llave C', 'Llave D', 'Llave E', 'Llave F', 'Llave G', 'Llave A', 'Llave B'],
  );

  /// Preset visual para Piano de Cola (marfil, ébano y elegancia de conservatorio).
  static const VisualInterfaceProfile grandPianoIvory = VisualInterfaceProfile(
    rendererType: VisualRendererType.keybed,
    visualMaterialTheme: 'ivory_ebony',
    primaryAccentColor: Color(0xFFA78BFA), // Púrpura conservatorio
    secondaryAccentColor: Color(0xFF7C3AED),
    surfaceColor: Color(0xFF140F21),
    smuflGlyph: '🎹',
    tactileLabels: ['88 Teclas (A0 - C8)'],
  );

  /// Preset visual para Percusión Melódica (Marimba / Vibráfono: palisandro y tubos de resonancia).
  static const VisualInterfaceProfile marimbaConcert = VisualInterfaceProfile(
    rendererType: VisualRendererType.malletBars,
    visualMaterialTheme: 'rosewood_bars',
    primaryAccentColor: Color(0xFFFB923C), // Naranja madera
    secondaryAccentColor: Color(0xFFEA580C),
    surfaceColor: Color(0xFF1C130D),
    smuflGlyph: '🪵',
    tactileLabels: ['Láminas Cromáticas (C2 - C7)'],
  );

  /// Preset visual para Batería Acústica y Percusión (parches de tambor y platillos).
  static const VisualInterfaceProfile acousticDrums = VisualInterfaceProfile(
    rendererType: VisualRendererType.drumPads,
    visualMaterialTheme: 'percussion_chrome',
    primaryAccentColor: Color(0xFF10B981), // Verde cromo
    secondaryAccentColor: Color(0xFF059669),
    surfaceColor: Color(0xFF0B1A14),
    smuflGlyph: '🥁',
    tactileLabels: ['Bombo', 'Caja', 'Hi-Hat', 'Tom 1', 'Tom 2', 'Tom Piso', 'Crash', 'Ride'],
  );

  /// Preset visual para Voz Humana (cian vocal, espectro de formantes y curva tonal).
  static const VisualInterfaceProfile vocalStudio = VisualInterfaceProfile(
    rendererType: VisualRendererType.vocalFormants,
    visualMaterialTheme: 'vocal_booth',
    primaryAccentColor: Color(0xFF06B6D4), // Cian de estudio
    secondaryAccentColor: Color(0xFF0891B2),
    surfaceColor: Color(0xFF09171C),
    smuflGlyph: '🎤',
    tactileLabels: ['Formante F1', 'Formante F2', 'Vibrato Rate', 'Autotune Speed'],
  );

  /// Preset visual para Sintetizadores y Teclados Electrónicos.
  static const VisualInterfaceProfile synthModern = VisualInterfaceProfile(
    rendererType: VisualRendererType.keybed,
    visualMaterialTheme: 'neon_synth',
    primaryAccentColor: Color(0xFFEC4899), // Magenta Neón
    secondaryAccentColor: Color(0xFFDB2777),
    surfaceColor: Color(0xFF1B0C18),
    smuflGlyph: '🎛️',
    tactileLabels: ['Osc 1 (Saw)', 'Cutoff', 'Resonance', 'Glide'],
  );
}
