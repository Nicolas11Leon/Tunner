import 'package:flutter/material.dart';
import 'domain/studio_theme_skin_entity.dart';

/// Immutable, feature-agnostic Design Token specification for the
/// Tunner Studio Workstation and Pro-DAW audio environments.
///
/// Swapping a [StudioDesignTokens] instance updates the entire visual skin
/// independently of any domain logic or ViewModel state.
class StudioDesignTokens {
  final String id;
  final String displayName;
  final Brightness brightness;

  // Matte Surface Hierarchy (Canvas -> Panel -> Elevated -> Input)
  final Color canvasBackground;
  final Color panelBackground;
  final Color panelHeaderBackground;
  final Color elevatedSurface;
  final Color inputSurface;
  final Color hoverSurface;

  // Crisp 1px Hairline Borders
  final Color borderHairline;
  final Color borderSubtle;
  final Color borderFocus;

  // Functional Accents
  final Color accentPrimary;
  final Color accentSecondary;
  final Color accentSuccess;
  final Color accentWarning;
  final Color accentDanger;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnAccent;

  // Precision Geometry
  final double radiusSmall;
  final double radiusMedium;
  final double borderWidth;
  final double toolbarHeight;

  const StudioDesignTokens({
    required this.id,
    required this.displayName,
    required this.brightness,
    required this.canvasBackground,
    required this.panelBackground,
    required this.panelHeaderBackground,
    required this.elevatedSurface,
    required this.inputSurface,
    required this.hoverSurface,
    required this.borderHairline,
    required this.borderSubtle,
    required this.borderFocus,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.accentSuccess,
    required this.accentWarning,
    required this.accentDanger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnAccent,
    this.radiusSmall = 2.0,
    this.radiusMedium = 4.0,
    this.borderWidth = 1.0,
    this.toolbarHeight = 38.0,
  });

  // Convenience aliases for semantic status and border geometry
  Color get statusSuccess => accentSuccess;
  Color get statusWarning => accentWarning;
  Color get statusError => accentDanger;
  double get borderRadiusSmall => radiusSmall;
  double get borderRadiusMedium => radiusMedium;
  double get borderRadiusLarge => radiusMedium * 1.5;

  /// Default v1.0: True OLED Monochrome Pro-DAW (Black + Silver/White, telemetry-only color).
  static const StudioDesignTokens studioOledMonochrome = StudioDesignTokens(
    id: 'studio_oled_monochrome',
    displayName: 'OLED Monochrome',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF000000),
    panelBackground: Color(0xFF0B0C0F),
    panelHeaderBackground: Color(0xFF111318),
    elevatedSurface: Color(0xFF171A21),
    inputSurface: Color(0xFF07080A),
    hoverSurface: Color(0xFF1E222B),
    borderHairline: Color(0xFF232730),
    borderSubtle: Color(0xFF171A20),
    borderFocus: Color(0xFFE5E9F0),
    accentPrimary: Color(0xFFE5E9F0),
    accentSecondary: Color(0xFFAEB6C2),
    accentSuccess: Color(0xFF22C55E),
    accentWarning: Color(0xFFF59E0B),
    accentDanger: Color(0xFFEF4444),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF636B78),
    textOnAccent: Color(0xFF07080A),
  );

  /// Tunner Studio Dark.
  static const StudioDesignTokens studioDark = StudioDesignTokens(
    id: 'studio_dark',
    displayName: 'Studio Dark',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF1E1E1E),
    panelBackground: Color(0xFF252526),
    panelHeaderBackground: Color(0xFF2D2D30),
    elevatedSurface: Color(0xFF323236),
    inputSurface: Color(0xFF1A1A1C),
    hoverSurface: Color(0xFF3A3A3E),
    borderHairline: Color(0xFF3E3E42),
    borderSubtle: Color(0xFF2F2F33),
    borderFocus: Color(0xFF2680EB),
    accentPrimary: Color(0xFF1473E6),
    accentSecondary: Color(0xFF378EF0),
    accentSuccess: Color(0xFF2D9D78),
    accentWarning: Color(0xFFE68619),
    accentDanger: Color(0xFFE34850),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xFFB3B3B3),
    textMuted: Color(0xFF808080),
    textOnAccent: Color(0xFFFFFFFF),
  );

  /// Ultra-deep studio mastering slate (Studio Obsidian).
  static const StudioDesignTokens studioObsidian = StudioDesignTokens(
    id: 'studio_obsidian',
    displayName: 'Studio Obsidian',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF141414),
    panelBackground: Color(0xFF1B1B1D),
    panelHeaderBackground: Color(0xFF222225),
    elevatedSurface: Color(0xFF2A2A2E),
    inputSurface: Color(0xFF111112),
    hoverSurface: Color(0xFF323236),
    borderHairline: Color(0xFF333338),
    borderSubtle: Color(0xFF242428),
    borderFocus: Color(0xFF378EF0),
    accentPrimary: Color(0xFF2680EB),
    accentSecondary: Color(0xFF4B9CF5),
    accentSuccess: Color(0xFF33AB84),
    accentWarning: Color(0xFFF29423),
    accentDanger: Color(0xFFEC5B62),
    textPrimary: Color(0xFFEBEBEB),
    textSecondary: Color(0xFFA8A8A8),
    textMuted: Color(0xFF707070),
    textOnAccent: Color(0xFFFFFFFF),
  );

  /// Clean daylight studio theme (Studio Light).
  static const StudioDesignTokens studioLight = StudioDesignTokens(
    id: 'studio_light',
    displayName: 'Studio Light',
    brightness: Brightness.light,
    canvasBackground: Color(0xFFF5F5F5),
    panelBackground: Color(0xFFFFFFFF),
    panelHeaderBackground: Color(0xFFEAEAEA),
    elevatedSurface: Color(0xFFE1E1E1),
    inputSurface: Color(0xFFFFFFFF),
    hoverSurface: Color(0xFFDADADA),
    borderHairline: Color(0xFFC8C8C8),
    borderSubtle: Color(0xFFE0E0E0),
    borderFocus: Color(0xFF1473E6),
    accentPrimary: Color(0xFF1473E6),
    accentSecondary: Color(0xFF0D66D0),
    accentSuccess: Color(0xFF12805C),
    accentWarning: Color(0xFFCB6F10),
    accentDanger: Color(0xFFC9252D),
    textPrimary: Color(0xFF222222),
    textSecondary: Color(0xFF4B4B4B),
    textMuted: Color(0xFF6E6E6E),
    textOnAccent: Color(0xFFFFFFFF),
  );

  /// 1. Obsidian Pro DAW (Matte Black de precisión con acentos de láser cian).
  static const StudioDesignTokens obsidianPro = StudioDesignTokens(
    id: 'skin_obsidian_pro',
    displayName: 'Obsidian Pro DAW',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF0D0E12),
    panelBackground: Color(0xFF13151C),
    panelHeaderBackground: Color(0xFF1A1D27),
    elevatedSurface: Color(0xFF222633),
    inputSurface: Color(0xFF090A0D),
    hoverSurface: Color(0xFF2A2E3D),
    borderHairline: Color(0xFF262A38),
    borderSubtle: Color(0xFF1B1E28),
    borderFocus: Color(0xFF00E5FF),
    accentPrimary: Color(0xFF00E5FF),
    accentSecondary: Color(0xFF00B0FF),
    accentSuccess: Color(0xFF00E676),
    accentWarning: Color(0xFFFFD600),
    accentDanger: Color(0xFFFF1744),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF475569),
    textOnAccent: Color(0xFF000000),
    radiusSmall: 3.0,
    radiusMedium: 6.0,
  );

  /// 2. Neve 88RS Vintage Console (Pizarra cálida, metal cepillado y ámbar analógico).
  static const StudioDesignTokens neve88rs = StudioDesignTokens(
    id: 'skin_neve_88rs',
    displayName: 'Neve 88RS Vintage',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF161718),
    panelBackground: Color(0xFF202224),
    panelHeaderBackground: Color(0xFF292C2E),
    elevatedSurface: Color(0xFF35393C),
    inputSurface: Color(0xFF101112),
    hoverSurface: Color(0xFF404548),
    borderHairline: Color(0xFF3D4246),
    borderSubtle: Color(0xFF2C3033),
    borderFocus: Color(0xFFFFAB00),
    accentPrimary: Color(0xFFFFAB00),
    accentSecondary: Color(0xFFFF8F00),
    accentSuccess: Color(0xFF2E7D32),
    accentWarning: Color(0xFFF57F17),
    accentDanger: Color(0xFFC62828),
    textPrimary: Color(0xFFECEFF1),
    textSecondary: Color(0xFFB0BEC5),
    textMuted: Color(0xFF78909C),
    textOnAccent: Color(0xFF000000),
    radiusSmall: 4.0,
    radiusMedium: 8.0,
  );

  /// 3. Tokyo Cyberpunk Synthwave (Violeta medianoche, fucsia y neón resplandeciente).
  static const StudioDesignTokens cyberpunkSynth = StudioDesignTokens(
    id: 'skin_cyberpunk_synth',
    displayName: 'Tokyo Cyberpunk',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF0F0B18),
    panelBackground: Color(0xFF181226),
    panelHeaderBackground: Color(0xFF221A36),
    elevatedSurface: Color(0xFF2F244A),
    inputSurface: Color(0xFF0A0711),
    hoverSurface: Color(0xFF3D2F5F),
    borderHairline: Color(0xFF3C2E5E),
    borderSubtle: Color(0xFF261D3B),
    borderFocus: Color(0xFFFF007F),
    accentPrimary: Color(0xFFD946EF),
    accentSecondary: Color(0xFF06B6D4),
    accentSuccess: Color(0xFF10B981),
    accentWarning: Color(0xFFF59E0B),
    accentDanger: Color(0xFFEF4444),
    textPrimary: Color(0xFFFAF5FF),
    textSecondary: Color(0xFFC084FC),
    textMuted: Color(0xFF6B5885),
    textOnAccent: Color(0xFFFFFFFF),
    radiusSmall: 4.0,
    radiusMedium: 8.0,
  );

  /// 4. Nord Electro Crimson (Grafito industrial con toques rojo satinado de alta gama).
  static const StudioDesignTokens nordCrimson = StudioDesignTokens(
    id: 'skin_nord_crimson',
    displayName: 'Nord Electro Crimson',
    brightness: Brightness.dark,
    canvasBackground: Color(0xFF18191B),
    panelBackground: Color(0xFF212226),
    panelHeaderBackground: Color(0xFF2A2C30),
    elevatedSurface: Color(0xFF36393E),
    inputSurface: Color(0xFF121315),
    hoverSurface: Color(0xFF42454B),
    borderHairline: Color(0xFF3A3E45),
    borderSubtle: Color(0xFF282B30),
    borderFocus: Color(0xFFE53935),
    accentPrimary: Color(0xFFE53935),
    accentSecondary: Color(0xFFFF5252),
    accentSuccess: Color(0xFF43A047),
    accentWarning: Color(0xFFFB8C00),
    accentDanger: Color(0xFFD32F2F),
    textPrimary: Color(0xFFF1F2F4),
    textSecondary: Color(0xFFA6ABB4),
    textMuted: Color(0xFF6D737E),
    textOnAccent: Color(0xFFFFFFFF),
    radiusSmall: 2.0,
    radiusMedium: 5.0,
  );

  /// 5. Conservatory Ivory Paper (Papel marfil cálido y tinta sepia para partituras y luz diurna).
  static const StudioDesignTokens conservatoryIvory = StudioDesignTokens(
    id: 'skin_conservatory_ivory',
    displayName: 'Conservatory Ivory',
    brightness: Brightness.light,
    canvasBackground: Color(0xFFF4F0E6),
    panelBackground: Color(0xFFFAF7F0),
    panelHeaderBackground: Color(0xFFEAE3D2),
    elevatedSurface: Color(0xFFE2D9C4),
    inputSurface: Color(0xFFFFFFFF),
    hoverSurface: Color(0xFFD8CEB6),
    borderHairline: Color(0xFFCDC0A5),
    borderSubtle: Color(0xFFDFD4BD),
    borderFocus: Color(0xFF8D6E63),
    accentPrimary: Color(0xFF6D4C41),
    accentSecondary: Color(0xFF8D6E63),
    accentSuccess: Color(0xFF388E3C),
    accentWarning: Color(0xFFF57C00),
    accentDanger: Color(0xFFD32F2F),
    textPrimary: Color(0xFF2D241E),
    textSecondary: Color(0xFF5D4A3E),
    textMuted: Color(0xFF8D7B70),
    textOnAccent: Color(0xFFFFFFFF),
    radiusSmall: 3.0,
    radiusMedium: 6.0,
  );

  static const List<StudioDesignTokens> presets = <StudioDesignTokens>[
    studioOledMonochrome,
    obsidianPro,
    neve88rs,
    cyberpunkSynth,
    nordCrimson,
    conservatoryIvory,
    studioDark,
    studioObsidian,
    studioLight,
  ];
}

/// Extensión de presentación para convertir una entidad pura [StudioThemeSkinEntity]
/// en tokens de renderizado Flutter [StudioDesignTokens].
extension StudioThemeSkinTokensMapper on StudioThemeSkinEntity {
  StudioDesignTokens toDesignTokens() {
    return StudioDesignTokens(
      id: id,
      displayName: name,
      brightness: isDark ? Brightness.dark : Brightness.light,
      canvasBackground: Color(canvasBackgroundHex),
      panelBackground: Color(panelBackgroundHex),
      panelHeaderBackground: Color(panelHeaderBackgroundHex),
      elevatedSurface: Color(elevatedSurfaceHex),
      inputSurface: Color(inputSurfaceHex),
      hoverSurface: Color(hoverSurfaceHex),
      borderHairline: Color(borderHairlineHex),
      borderSubtle: Color(borderSubtleHex),
      borderFocus: Color(borderFocusHex),
      accentPrimary: Color(accentPrimaryHex),
      accentSecondary: Color(accentSecondaryHex),
      accentSuccess: Color(accentSuccessHex),
      accentWarning: Color(accentWarningHex),
      accentDanger: Color(accentDangerHex),
      textPrimary: Color(textPrimaryHex),
      textSecondary: Color(textSecondaryHex),
      textMuted: Color(textMutedHex),
      textOnAccent: Color(textOnAccentHex),
      radiusSmall: radiusSmall,
      radiusMedium: radiusMedium,
      borderWidth: borderWidth,
    );
  }
}
