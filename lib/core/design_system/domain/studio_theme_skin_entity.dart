import 'package:meta/meta.dart';

/// Entidad inmutable y serializable que representa un paquete de estética / skin de estudio (.tntheme).
/// Permite descargar, importar y exportar estéticas visuales completas sin tocar código.
@immutable
class StudioThemeSkinEntity {
  final String id;
  final String name;
  final String description;
  final String author;
  final bool isDark;

  // Superficies jerárquicas (hexadecimal ARGB: ej. 0xFF1E1E1E)
  final int canvasBackgroundHex;
  final int panelBackgroundHex;
  final int panelHeaderBackgroundHex;
  final int elevatedSurfaceHex;
  final int inputSurfaceHex;
  final int hoverSurfaceHex;

  // Bordes y líneas de división finas (1px)
  final int borderHairlineHex;
  final int borderSubtleHex;
  final int borderFocusHex;

  // Acentos funcionales de estudio
  final int accentPrimaryHex;
  final int accentSecondaryHex;
  final int accentSuccessHex;
  final int accentWarningHex;
  final int accentDangerHex;

  // Tipografía
  final int textPrimaryHex;
  final int textSecondaryHex;
  final int textMutedHex;
  final int textOnAccentHex;

  // Geometría y ergonomía
  final double radiusSmall;
  final double radiusMedium;
  final double borderWidth;

  const StudioThemeSkinEntity({
    required this.id,
    required this.name,
    required this.description,
    this.author = 'Tunner Acoustics',
    this.isDark = true,
    required this.canvasBackgroundHex,
    required this.panelBackgroundHex,
    required this.panelHeaderBackgroundHex,
    required this.elevatedSurfaceHex,
    required this.inputSurfaceHex,
    required this.hoverSurfaceHex,
    required this.borderHairlineHex,
    required this.borderSubtleHex,
    required this.borderFocusHex,
    required this.accentPrimaryHex,
    required this.accentSecondaryHex,
    required this.accentSuccessHex,
    required this.accentWarningHex,
    required this.accentDangerHex,
    required this.textPrimaryHex,
    required this.textSecondaryHex,
    required this.textMutedHex,
    required this.textOnAccentHex,
    this.radiusSmall = 3.0,
    this.radiusMedium = 6.0,
    this.borderWidth = 1.0,
  });

  /// Serialización JSON para exportar a archivo .tntheme.
  Map<String, dynamic> toJson() {
    return {
      'format': 'tunner_theme_package',
      'version': 1,
      'id': id,
      'name': name,
      'description': description,
      'author': author,
      'isDark': isDark,
      'surfaces': {
        'canvas': canvasBackgroundHex,
        'panel': panelBackgroundHex,
        'panelHeader': panelHeaderBackgroundHex,
        'elevated': elevatedSurfaceHex,
        'input': inputSurfaceHex,
        'hover': hoverSurfaceHex,
      },
      'borders': {
        'hairline': borderHairlineHex,
        'subtle': borderSubtleHex,
        'focus': borderFocusHex,
        'width': borderWidth,
      },
      'accents': {
        'primary': accentPrimaryHex,
        'secondary': accentSecondaryHex,
        'success': accentSuccessHex,
        'warning': accentWarningHex,
        'danger': accentDangerHex,
      },
      'typography': {
        'textPrimary': textPrimaryHex,
        'textSecondary': textSecondaryHex,
        'textMuted': textMutedHex,
        'textOnAccent': textOnAccentHex,
      },
      'geometry': {
        'radiusSmall': radiusSmall,
        'radiusMedium': radiusMedium,
      },
    };
  }

  /// Deserialización desde archivo JSON .tntheme.
  factory StudioThemeSkinEntity.fromJson(Map<String, dynamic> json) {
    final surfaces = json['surfaces'] as Map<String, dynamic>? ?? {};
    final borders = json['borders'] as Map<String, dynamic>? ?? {};
    final accents = json['accents'] as Map<String, dynamic>? ?? {};
    final typo = json['typography'] as Map<String, dynamic>? ?? {};
    final geom = json['geometry'] as Map<String, dynamic>? ?? {};

    return StudioThemeSkinEntity(
      id: json['id'] as String? ?? 'custom_theme',
      name: json['name'] as String? ?? 'Tema Personalizado',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? 'Usuario Tunner',
      isDark: json['isDark'] as bool? ?? true,
      canvasBackgroundHex: surfaces['canvas'] as int? ?? 0xFF141720,
      panelBackgroundHex: surfaces['panel'] as int? ?? 0xFF181C28,
      panelHeaderBackgroundHex: surfaces['panelHeader'] as int? ?? 0xFF1F2434,
      elevatedSurfaceHex: surfaces['elevated'] as int? ?? 0xFF262C40,
      inputSurfaceHex: surfaces['input'] as int? ?? 0xFF10131B,
      hoverSurfaceHex: surfaces['hover'] as int? ?? 0xFF2D344B,
      borderHairlineHex: borders['hairline'] as int? ?? 0xFF2A324A,
      borderSubtleHex: borders['subtle'] as int? ?? 0xFF1E2538,
      borderFocusHex: borders['focus'] as int? ?? 0xFF00E5FF,
      accentPrimaryHex: accents['primary'] as int? ?? 0xFF00E5FF,
      accentSecondaryHex: accents['secondary'] as int? ?? 0xFF3D5AFE,
      accentSuccessHex: accents['success'] as int? ?? 0xFF10B981,
      accentWarningHex: accents['warning'] as int? ?? 0xFFFFAB00,
      accentDangerHex: accents['danger'] as int? ?? 0xFFFF5252,
      textPrimaryHex: typo['textPrimary'] as int? ?? 0xFFF0F4F8,
      textSecondaryHex: typo['textSecondary'] as int? ?? 0xFF94A3B8,
      textMutedHex: typo['textMuted'] as int? ?? 0xFF64748B,
      textOnAccentHex: typo['textOnAccent'] as int? ?? 0xFF000000,
      radiusSmall: (geom['radiusSmall'] as num?)?.toDouble() ?? 3.0,
      radiusMedium: (geom['radiusMedium'] as num?)?.toDouble() ?? 6.0,
      borderWidth: (borders['width'] as num?)?.toDouble() ?? 1.0,
    );
  }

  // =========================================================================
  // 5 ESTÉTICAS CANÓNICAS DE ESTUDIO DE ALTA GAMA ("SOFTWARE CARO DE LICENCIA")
  // =========================================================================

  /// 0. OLED Monochrome Pro-DAW (Default v1.0: True Black + Silver/White).
  static const StudioThemeSkinEntity studioOledMonochrome = StudioThemeSkinEntity(
    id: 'studio_oled_monochrome',
    name: 'OLED Monochrome',
    description: 'Estética Pro-DAW en Negro OLED puro con acentos monocromáticos plata.',
    author: 'Tunner Acoustic Labs',
    isDark: true,
    canvasBackgroundHex: 0xFF000000,
    panelBackgroundHex: 0xFF0B0C0F,
    panelHeaderBackgroundHex: 0xFF111318,
    elevatedSurfaceHex: 0xFF171A21,
    inputSurfaceHex: 0xFF07080A,
    hoverSurfaceHex: 0xFF1E222B,
    borderHairlineHex: 0xFF232730,
    borderSubtleHex: 0xFF171A20,
    borderFocusHex: 0xFFE5E9F0,
    accentPrimaryHex: 0xFFE5E9F0,
    accentSecondaryHex: 0xFFAEB6C2,
    accentSuccessHex: 0xFF22C55E,
    accentWarningHex: 0xFFF59E0B,
    accentDangerHex: 0xFFEF4444,
    textPrimaryHex: 0xFFF5F7FA,
    textSecondaryHex: 0xFF9CA3AF,
    textMutedHex: 0xFF636B78,
    textOnAccentHex: 0xFF07080A,
    radiusSmall: 2.0,
    radiusMedium: 4.0,
    borderWidth: 1.0,
  );

  /// 1. Obsidian Pro DAW (Matte Black de precisión con acentos de láser cian).
  static const StudioThemeSkinEntity obsidianPro = StudioThemeSkinEntity(
    id: 'skin_obsidian_pro',
    name: 'Obsidian Pro DAW',
    description: 'Estética de grado mastering en negro mate profundo con acentos cian láser.',
    author: 'Tunner Acoustic Labs',
    isDark: true,
    canvasBackgroundHex: 0xFF0D0E12,
    panelBackgroundHex: 0xFF13151C,
    panelHeaderBackgroundHex: 0xFF1A1D27,
    elevatedSurfaceHex: 0xFF222633,
    inputSurfaceHex: 0xFF090A0D,
    hoverSurfaceHex: 0xFF2A2E3D,
    borderHairlineHex: 0xFF262A38,
    borderSubtleHex: 0xFF1B1E28,
    borderFocusHex: 0xFF00E5FF,
    accentPrimaryHex: 0xFF00E5FF,
    accentSecondaryHex: 0xFF00B0FF,
    accentSuccessHex: 0xFF00E676,
    accentWarningHex: 0xFFFFD600,
    accentDangerHex: 0xFFFF1744,
    textPrimaryHex: 0xFFF8FAFC,
    textSecondaryHex: 0xFF94A3B8,
    textMutedHex: 0xFF475569,
    textOnAccentHex: 0xFF000000,
    radiusSmall: 3.0,
    radiusMedium: 6.0,
  );

  /// 2. Neve 88RS Vintage Console (Consola analógica británica en pizarra cálida y ámbar cálido).
  static const StudioThemeSkinEntity neve88rs = StudioThemeSkinEntity(
    id: 'skin_neve_88rs',
    name: 'Neve 88RS Vintage Console',
    description: 'Calidez analógica inspirada en las legendarias consolas de estudio británicas.',
    author: 'British Console Classics',
    isDark: true,
    canvasBackgroundHex: 0xFF161718,
    panelBackgroundHex: 0xFF202224,
    panelHeaderBackgroundHex: 0xFF292C2E,
    elevatedSurfaceHex: 0xFF35393C,
    inputSurfaceHex: 0xFF101112,
    hoverSurfaceHex: 0xFF404548,
    borderHairlineHex: 0xFF3D4246,
    borderSubtleHex: 0xFF2C3033,
    borderFocusHex: 0xFFFFAB00,
    accentPrimaryHex: 0xFFFFAB00, // Ámbar cálido analógico
    accentSecondaryHex: 0xFFFF8F00,
    accentSuccessHex: 0xFF2E7D32,
    accentWarningHex: 0xFFF57F17,
    accentDangerHex: 0xFFC62828,
    textPrimaryHex: 0xFFECEFF1,
    textSecondaryHex: 0xFFB0BEC5,
    textMutedHex: 0xFF78909C,
    textOnAccentHex: 0xFF000000,
    radiusSmall: 4.0,
    radiusMedium: 8.0,
  );

  /// 3. Tokyo Cyberpunk Synthwave (Violeta medianoche, fucsia y neón resplandeciente).
  static const StudioThemeSkinEntity cyberpunkSynth = StudioThemeSkinEntity(
    id: 'skin_cyberpunk_synth',
    name: 'Tokyo Cyberpunk Synthwave',
    description: 'Club nocturno y producción electrónica con brillo neón violeta y cian.',
    author: 'Synthwave Soundworks',
    isDark: true,
    canvasBackgroundHex: 0xFF0F0B18,
    panelBackgroundHex: 0xFF181226,
    panelHeaderBackgroundHex: 0xFF221A36,
    elevatedSurfaceHex: 0xFF2F244A,
    inputSurfaceHex: 0xFF0A0711,
    hoverSurfaceHex: 0xFF3D2F5F,
    borderHairlineHex: 0xFF3C2E5E,
    borderSubtleHex: 0xFF261D3B,
    borderFocusHex: 0xFFFF007F,
    accentPrimaryHex: 0xFFD946EF, // Fucsia neón
    accentSecondaryHex: 0xFF06B6D4, // Cian eléctrico
    accentSuccessHex: 0xFF10B981,
    accentWarningHex: 0xFFF59E0B,
    accentDangerHex: 0xFFEF4444,
    textPrimaryHex: 0xFFFAF5FF,
    textSecondaryHex: 0xFFC084FC,
    textMutedHex: 0xFF6B5885,
    textOnAccentHex: 0xFFFFFFFF,
    radiusSmall: 4.0,
    radiusMedium: 8.0,
  );

  /// 4. Nord Electro Crimson (Grafito industrial con toques rojo satinado de alta gama).
  static const StudioThemeSkinEntity nordCrimson = StudioThemeSkinEntity(
    id: 'skin_nord_crimson',
    name: 'Nord Electro Crimson',
    description: 'Minimalismo nórdico industrial en gris mate con detalles en rojo carmesí.',
    author: 'Nordic Hardware Aesthetics',
    isDark: true,
    canvasBackgroundHex: 0xFF18191B,
    panelBackgroundHex: 0xFF212226,
    panelHeaderBackgroundHex: 0xFF2A2C30,
    elevatedSurfaceHex: 0xFF36393E,
    inputSurfaceHex: 0xFF121315,
    hoverSurfaceHex: 0xFF42454B,
    borderHairlineHex: 0xFF3A3E45,
    borderSubtleHex: 0xFF282B30,
    borderFocusHex: 0xFFE53935,
    accentPrimaryHex: 0xFFE53935, // Rojo Nord
    accentSecondaryHex: 0xFFFF5252,
    accentSuccessHex: 0xFF43A047,
    accentWarningHex: 0xFFFB8C00,
    accentDangerHex: 0xFFD32F2F,
    textPrimaryHex: 0xFFF1F2F4,
    textSecondaryHex: 0xFFA6ABB4,
    textMutedHex: 0xFF6D737E,
    textOnAccentHex: 0xFFFFFFFF,
    radiusSmall: 2.0,
    radiusMedium: 5.0,
  );

  /// 5. Conservatory Ivory Paper (Papel marfil cálido y tinta sepia para partituras y luz diurna).
  static const StudioThemeSkinEntity conservatoryIvory = StudioThemeSkinEntity(
    id: 'skin_conservatory_ivory',
    name: 'Conservatory Ivory Paper',
    description: 'Lectura diurna de partituras inspirada en papel pergamino y tinta sepia.',
    author: 'Royal Conservatory Edition',
    isDark: false,
    canvasBackgroundHex: 0xFFF4F0E6,
    panelBackgroundHex: 0xFFFAF7F0,
    panelHeaderBackgroundHex: 0xFFEAE3D2,
    elevatedSurfaceHex: 0xFFE2D9C4,
    inputSurfaceHex: 0xFFFFFFFF,
    hoverSurfaceHex: 0xFFD8CEB6,
    borderHairlineHex: 0xFFCDC0A5,
    borderSubtleHex: 0xFFDFD4BD,
    borderFocusHex: 0xFF8D6E63,
    accentPrimaryHex: 0xFF6D4C41, // Sepia bronce
    accentSecondaryHex: 0xFF8D6E63,
    accentSuccessHex: 0xFF388E3C,
    accentWarningHex: 0xFFF57C00,
    accentDangerHex: 0xFFD32F2F,
    textPrimaryHex: 0xFF2D241E,
    textSecondaryHex: 0xFF5D4A3E,
    textMutedHex: 0xFF8D7B70,
    textOnAccentHex: 0xFFFFFFFF,
    radiusSmall: 3.0,
    radiusMedium: 6.0,
  );

  static const List<StudioThemeSkinEntity> defaultCatalog = [
    studioOledMonochrome,
    obsidianPro,
    neve88rs,
    cyberpunkSynth,
    nordCrimson,
    conservatoryIvory,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudioThemeSkinEntity &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.author == author &&
        other.isDark == isDark &&
        other.canvasBackgroundHex == canvasBackgroundHex &&
        other.panelBackgroundHex == panelBackgroundHex &&
        other.panelHeaderBackgroundHex == panelHeaderBackgroundHex &&
        other.elevatedSurfaceHex == elevatedSurfaceHex &&
        other.inputSurfaceHex == inputSurfaceHex &&
        other.hoverSurfaceHex == hoverSurfaceHex &&
        other.borderHairlineHex == borderHairlineHex &&
        other.borderSubtleHex == borderSubtleHex &&
        other.borderFocusHex == borderFocusHex &&
        other.accentPrimaryHex == accentPrimaryHex &&
        other.accentSecondaryHex == accentSecondaryHex &&
        other.accentSuccessHex == accentSuccessHex &&
        other.accentWarningHex == accentWarningHex &&
        other.accentDangerHex == accentDangerHex &&
        other.textPrimaryHex == textPrimaryHex &&
        other.textSecondaryHex == textSecondaryHex &&
        other.textMutedHex == textMutedHex &&
        other.textOnAccentHex == textOnAccentHex &&
        other.radiusSmall == radiusSmall &&
        other.radiusMedium == radiusMedium &&
        other.borderWidth == borderWidth;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        description,
        author,
        isDark,
        canvasBackgroundHex,
        panelBackgroundHex,
        panelHeaderBackgroundHex,
        elevatedSurfaceHex,
        inputSurfaceHex,
        hoverSurfaceHex,
        borderHairlineHex,
        borderSubtleHex,
        borderFocusHex,
        accentPrimaryHex,
        accentSecondaryHex,
        accentSuccessHex,
        accentWarningHex,
        accentDangerHex,
        textPrimaryHex,
        textSecondaryHex,
        textMutedHex,
        textOnAccentHex,
        radiusSmall,
        radiusMedium,
        borderWidth,
      ]);
}
