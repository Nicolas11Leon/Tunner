import 'package:flutter/material.dart';

/// Immutable, feature-agnostic Design Token specification inspired by
/// Adobe Creative Cloud (Photoshop / Audition / Premiere Pro) and Pro-DAW
/// desktop workstations.
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

  // Functional Accents (Adobe Spectrum inspired)
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

  /// Default: Adobe Spectrum Dark (Photoshop / Audition / Premiere CC).
  static const StudioDesignTokens adobeSpectrumDark = StudioDesignTokens(
    id: 'adobe_spectrum_dark',
    displayName: 'Adobe Dark',
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

  /// Ultra-deep studio mastering slate (Audition Darkest).
  static const StudioDesignTokens adobeSpectrumDarkest = StudioDesignTokens(
    id: 'adobe_spectrum_darkest',
    displayName: 'Adobe Darkest',
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

  /// Clean daylight studio theme (Photoshop / Spectrum Light).
  static const StudioDesignTokens adobeSpectrumLight = StudioDesignTokens(
    id: 'adobe_spectrum_light',
    displayName: 'Adobe Light',
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

  static const List<StudioDesignTokens> presets = <StudioDesignTokens>[
    adobeSpectrumDark,
    adobeSpectrumDarkest,
    adobeSpectrumLight,
  ];
}
