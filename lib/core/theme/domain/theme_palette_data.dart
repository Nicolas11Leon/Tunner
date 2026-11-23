/// Modos de tema predefinidos para Tunner (mantiene retrocompatibilidad canonica).
enum TunnerThemeMode {
  obsidianStudio,
  vintageParchment,
  neonStage,
  oledPureBlack,
  royalSymphony,
  acousticWood,
  nordicFrost,
  custom,
}

/// Representacion Pure Dart e inmutable de una paleta de tema de Tunner.
///
/// Almacena colores como enteros ARGB32 (`0xAARRGGBB`) y polaridad luminosa
/// (`isDark`) sin depender de `package:flutter/` ni `dart:ui`, permitiendo
/// serializacion y persistencia en entornos headless / CLI.
class ThemePaletteData {
  final String id;
  final TunnerThemeMode mode;
  final String displayName;
  final bool isCustom;
  final bool isDark;

  final int scaffoldBackgroundArgb;
  final int cardBackgroundArgb;
  final int staffBackgroundArgb;
  final int staffLinesColorArgb;
  final int musicalSymbolsColorArgb;
  final int primaryAccentArgb;
  final int secondaryAccentArgb;
  final int playheadColorArgb;
  final int correctPitchColorArgb;
  final int warningPitchColorArgb;
  final int errorPitchColorArgb;
  final int textColorArgb;
  final int textMutedColorArgb;

  const ThemePaletteData({
    required this.id,
    this.mode = TunnerThemeMode.custom,
    required this.displayName,
    this.isCustom = true,
    this.isDark = true,
    required this.scaffoldBackgroundArgb,
    required this.cardBackgroundArgb,
    required this.staffBackgroundArgb,
    required this.staffLinesColorArgb,
    required this.musicalSymbolsColorArgb,
    required this.primaryAccentArgb,
    required this.secondaryAccentArgb,
    required this.playheadColorArgb,
    required this.correctPitchColorArgb,
    required this.warningPitchColorArgb,
    required this.errorPitchColorArgb,
    required this.textColorArgb,
    required this.textMutedColorArgb,
  });

  /// Serializacion JSON canonica compatible con `TunnerThemePalette`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'isCustom': isCustom,
      'brightness': isDark ? 'dark' : 'light',
      'scaffoldBackground': scaffoldBackgroundArgb,
      'cardBackground': cardBackgroundArgb,
      'staffBackground': staffBackgroundArgb,
      'staffLinesColor': staffLinesColorArgb,
      'musicalSymbolsColor': musicalSymbolsColorArgb,
      'primaryAccent': primaryAccentArgb,
      'secondaryAccent': secondaryAccentArgb,
      'playheadColor': playheadColorArgb,
      'correctPitchColor': correctPitchColorArgb,
      'warningPitchColor': warningPitchColorArgb,
      'errorPitchColor': errorPitchColorArgb,
      'textColor': textColorArgb,
      'textMutedColor': textMutedColorArgb,
    };
  }

  /// Deserializacion JSON tolerante a enteros ARGB32 y cadenas hexadecimales.
  factory ThemePaletteData.fromJson(Map<String, dynamic> json) {
    int parseArgb(dynamic val, int fallback) {
      if (val is int) return val;
      if (val is String) {
        final clean = val.replaceFirst('#', '');
        final intVal = int.tryParse(clean.length <= 6 ? 'FF$clean' : clean, radix: 16);
        if (intVal != null) return intVal;
      }
      return fallback;
    }

    final isLight = json['brightness'] == 'light';

    return ThemePaletteData(
      id: json['id'] as String? ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      mode: TunnerThemeMode.custom,
      displayName: json['displayName'] as String? ?? 'Tema Personalizado',
      isCustom: json['isCustom'] as bool? ?? true,
      isDark: !isLight,
      scaffoldBackgroundArgb: parseArgb(json['scaffoldBackground'], 0xFF0D0D12),
      cardBackgroundArgb: parseArgb(json['cardBackground'], 0xFF16161F),
      staffBackgroundArgb: parseArgb(json['staffBackground'], 0xFF13131A),
      staffLinesColorArgb: parseArgb(json['staffLinesColor'], 0xFF4A4A5A),
      musicalSymbolsColorArgb: parseArgb(json['musicalSymbolsColor'], 0xFFFFFFFF),
      primaryAccentArgb: parseArgb(json['primaryAccent'], 0xFF00E676),
      secondaryAccentArgb: parseArgb(json['secondaryAccent'], 0xFFFFD54F),
      playheadColorArgb: parseArgb(json['playheadColor'], 0xFF00E676),
      correctPitchColorArgb: parseArgb(json['correctPitchColor'], 0xFF00E676),
      warningPitchColorArgb: parseArgb(json['warningPitchColor'], 0xFFFFD54F),
      errorPitchColorArgb: parseArgb(json['errorPitchColor'], 0xFFFF5252),
      textColorArgb: parseArgb(json['textColor'], 0xFFFFFFFF),
      textMutedColorArgb: parseArgb(json['textMutedColor'], 0x8AFFFFFF),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemePaletteData && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
