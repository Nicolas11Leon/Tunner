import 'package:flutter/material.dart';

/// Temas visuales de alta gama disponibles para Tunner.
enum TunnerThemeMode {
  obsidianStudio,
  vintageParchment,
  neonStage,
  oledPureBlack,
}

/// Paleta completa de diseño estético para todos los elementos visuales de la aplicación.
class TunnerThemePalette {
  final TunnerThemeMode mode;
  final String displayName;
  final Color scaffoldBackground;
  final Color cardBackground;
  final Color staffBackground;
  final Color staffLinesColor;
  final Color musicalSymbolsColor;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color playheadColor;
  final Color correctPitchColor;
  final Color warningPitchColor;
  final Color errorPitchColor;
  final Color textColor;
  final Color textMutedColor;

  const TunnerThemePalette({
    required this.mode,
    required this.displayName,
    required this.scaffoldBackground,
    required this.cardBackground,
    required this.staffBackground,
    required this.staffLinesColor,
    required this.musicalSymbolsColor,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.playheadColor,
    required this.correctPitchColor,
    required this.warningPitchColor,
    required this.errorPitchColor,
    required this.textColor,
    required this.textMutedColor,
  });

  /// 1. Obsidian Studio: Dark mode profesional de estudio acústico con acentos esmeralda y oro
  static const obsidianStudio = TunnerThemePalette(
    mode: TunnerThemeMode.obsidianStudio,
    displayName: "Obsidian Studio",
    scaffoldBackground: Color(0xFF0D0D12),
    cardBackground: Color(0xFF16161F),
    staffBackground: Color(0xFF13131A),
    staffLinesColor: Color(0xFF4A4A5A),
    musicalSymbolsColor: Colors.white,
    primaryAccent: Color(0xFF00E676),
    secondaryAccent: Color(0xFFFFD54F),
    playheadColor: Color(0xFF00E676),
    correctPitchColor: Color(0xFF00E676),
    warningPitchColor: Color(0xFFFFD54F),
    errorPitchColor: Color(0xFFFF5252),
    textColor: Colors.white,
    textMutedColor: Colors.white54,
  );

  /// 2. Vintage Parchment: Estética clásica de conservatorio en papiro/pergamino antiguo
  static const vintageParchment = TunnerThemePalette(
    mode: TunnerThemeMode.vintageParchment,
    displayName: "Vintage Parchment",
    scaffoldBackground: Color(0xFF221C16),
    cardBackground: Color(0xFF2F261E),
    staffBackground: Color(0xFFF4ECD8),
    staffLinesColor: Color(0xFF6B5847),
    musicalSymbolsColor: Color(0xFF2C2218),
    primaryAccent: Color(0xFFD4AF37), // Oro viejo
    secondaryAccent: Color(0xFF8B4513),
    playheadColor: Color(0xFFB8860B),
    correctPitchColor: Color(0xFF2E7D32),
    warningPitchColor: Color(0xFFE65100),
    errorPitchColor: Color(0xFFC62828),
    textColor: Color(0xFFF4ECD8),
    textMutedColor: Color(0xFFBDB39E),
  );

  /// 3. Neon Stage: Alto contraste escénico con tonos cian, violeta y neón eléctrico
  static const neonStage = TunnerThemePalette(
    mode: TunnerThemeMode.neonStage,
    displayName: "Neon Stage",
    scaffoldBackground: Color(0xFF0A051B),
    cardBackground: Color(0xFF140D2B),
    staffBackground: Color(0xFF0E0720),
    staffLinesColor: Color(0xFF5D3EBC),
    musicalSymbolsColor: Color(0xFF00F0FF),
    primaryAccent: Color(0xFF00F0FF),
    secondaryAccent: Color(0xFFFF007F),
    playheadColor: Color(0xFFFF007F),
    correctPitchColor: Color(0xFF00FF9D),
    warningPitchColor: Color(0xFFFFD600),
    errorPitchColor: Color(0xFFFF0055),
    textColor: Color(0xFFE0E0FF),
    textMutedColor: Color(0xFF8B84B5),
  );

  /// 4. OLED Pure Black: Negro absoluto de ultra bajo consumo y máxima pureza visual
  static const oledPureBlack = TunnerThemePalette(
    mode: TunnerThemeMode.oledPureBlack,
    displayName: "OLED Pure Black",
    scaffoldBackground: Colors.black,
    cardBackground: Color(0xFF101010),
    staffBackground: Colors.black,
    staffLinesColor: Color(0xFF333333),
    musicalSymbolsColor: Colors.white,
    primaryAccent: Color(0xFF40C4FF),
    secondaryAccent: Color(0xFFE040FB),
    playheadColor: Color(0xFF40C4FF),
    correctPitchColor: Color(0xFF69F0AE),
    warningPitchColor: Color(0xFFFFD740),
    errorPitchColor: Color(0xFFFF5252),
    textColor: Colors.white,
    textMutedColor: Colors.white38,
  );

  static const List<TunnerThemePalette> allPalettes = [
    obsidianStudio,
    vintageParchment,
    neonStage,
    oledPureBlack,
  ];

  static TunnerThemePalette fromMode(TunnerThemeMode mode) {
    switch (mode) {
      case TunnerThemeMode.obsidianStudio:
        return obsidianStudio;
      case TunnerThemeMode.vintageParchment:
        return vintageParchment;
      case TunnerThemeMode.neonStage:
        return neonStage;
      case TunnerThemeMode.oledPureBlack:
        return oledPureBlack;
    }
  }
}
