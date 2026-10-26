import 'package:flutter/material.dart';

/// Modos de tema predefinidos para Tunner (mantiene retrocompatibilidad canónica).
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

/// Paleta completa de diseño estético para todos los elementos visuales de Tunner.
/// Modelo abierto y extensible que soporta presets de fábrica y paletas creadas/editadas por el usuario.
class TunnerThemePalette {
  final String id;
  final TunnerThemeMode mode;
  final String displayName;
  final bool isCustom;
  final Brightness brightness;

  // Colores de Fondo y Estructura
  final Color scaffoldBackground;
  final Color cardBackground;

  // Colores del Lienzo Musical (Pentagrama)
  final Color staffBackground;
  final Color staffLinesColor;
  final Color musicalSymbolsColor;

  // Acentos de Acción e Identidad
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color playheadColor;

  // Feedback Acústico de Afinación
  final Color correctPitchColor;
  final Color warningPitchColor;
  final Color errorPitchColor;

  // Tipografía y Textos
  final Color textColor;
  final Color textMutedColor;

  const TunnerThemePalette({
    required this.id,
    required this.mode,
    required this.displayName,
    this.isCustom = false,
    this.brightness = Brightness.dark,
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

  // --- Tokens Semánticos Derivados para Consistencia de Contraste ---
  Color get surfaceBorderColor => staffLinesColor.withValues(alpha: 0.35);
  Color get surfaceHighlightColor => primaryAccent.withValues(alpha: 0.15);
  Color get onPrimaryColor => brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  Color get dividerColor => brightness == Brightness.dark ? const Color(0x26FFFFFF) : const Color(0x1F000000);
  Color get subtleTextColor => brightness == Brightness.dark ? const Color(0x99FFFFFF) : const Color(0x99000000);
  Color get cardBorderColor => staffLinesColor.withValues(alpha: 0.25);

  // --- 1. Obsidian Studio: Dark mode profesional de estudio acústico ---
  static const obsidianStudio = TunnerThemePalette(
    id: "obsidian_studio",
    mode: TunnerThemeMode.obsidianStudio,
    displayName: "Obsidian Studio",
    isCustom: false,
    brightness: Brightness.dark,
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

  // --- 2. OLED Pure Black: Negro absoluto para pantallas AMOLED y máximo ahorro ---
  static const oledPureBlack = TunnerThemePalette(
    id: "oled_pure_black",
    mode: TunnerThemeMode.oledPureBlack,
    displayName: "OLED Pure Black",
    isCustom: false,
    brightness: Brightness.dark,
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

  // --- 3. Royal Symphony: Azul marino de concierto, zafiro brillante y oro regio ---
  static const royalSymphony = TunnerThemePalette(
    id: "royal_symphony",
    mode: TunnerThemeMode.royalSymphony,
    displayName: "Royal Symphony",
    isCustom: false,
    brightness: Brightness.dark,
    scaffoldBackground: Color(0xFF080D1A),
    cardBackground: Color(0xFF101930),
    staffBackground: Color(0xFF0B1224),
    staffLinesColor: Color(0xFF283B66),
    musicalSymbolsColor: Color(0xFFE2E8F0),
    primaryAccent: Color(0xFF38BDF8),
    secondaryAccent: Color(0xFFFBBF24),
    playheadColor: Color(0xFF38BDF8),
    correctPitchColor: Color(0xFF34D399),
    warningPitchColor: Color(0xFFFBBF24),
    errorPitchColor: Color(0xFFF87171),
    textColor: Color(0xFFF1F5F9),
    textMutedColor: Color(0xFF94A3B8),
  );

  // --- 4. Acoustic Wood: Calidez artesanal en nogal, cedro ámbar y abeto ---
  static const acousticWood = TunnerThemePalette(
    id: "acoustic_wood",
    mode: TunnerThemeMode.acousticWood,
    displayName: "Acoustic Wood",
    isCustom: false,
    brightness: Brightness.dark,
    scaffoldBackground: Color(0xFF181310),
    cardBackground: Color(0xFF241C18),
    staffBackground: Color(0xFF1E1713),
    staffLinesColor: Color(0xFF5E483D),
    musicalSymbolsColor: Color(0xFFFCEFD9),
    primaryAccent: Color(0xFFF59E0B),
    secondaryAccent: Color(0xFFD97706),
    playheadColor: Color(0xFFF59E0B),
    correctPitchColor: Color(0xFF10B981),
    warningPitchColor: Color(0xFFF59E0B),
    errorPitchColor: Color(0xFFEF4444),
    textColor: Color(0xFFFDF6EE),
    textMutedColor: Color(0xFFA69285),
  );

  // --- 5. Cyberpunk Synthwave / Neon Stage: Alto contraste escénico ---
  static const neonStage = TunnerThemePalette(
    id: "neon_stage",
    mode: TunnerThemeMode.neonStage,
    displayName: "Neon Synthwave",
    isCustom: false,
    brightness: Brightness.dark,
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

  // --- 6. Vintage Parchment: Estética clásica de conservatorio en pergamino antiguo ---
  static const vintageParchment = TunnerThemePalette(
    id: "vintage_parchment",
    mode: TunnerThemeMode.vintageParchment,
    displayName: "Vintage Parchment",
    isCustom: false,
    brightness: Brightness.dark,
    scaffoldBackground: Color(0xFF221C16),
    cardBackground: Color(0xFF2F261E),
    staffBackground: Color(0xFFF4ECD8),
    staffLinesColor: Color(0xFF6B5847),
    musicalSymbolsColor: Color(0xFF2C2218),
    primaryAccent: Color(0xFFD4AF37),
    secondaryAccent: Color(0xFF8B4513),
    playheadColor: Color(0xFFB8860B),
    correctPitchColor: Color(0xFF2E7D32),
    warningPitchColor: Color(0xFFE65100),
    errorPitchColor: Color(0xFFC62828),
    textColor: Color(0xFFF4ECD8),
    textMutedColor: Color(0xFFBDB39E),
  );

  // --- 7. Nordic Frost: Modo claro escandinavo para exteriores y luz solar intensa ---
  static const nordicFrost = TunnerThemePalette(
    id: "nordic_frost",
    mode: TunnerThemeMode.nordicFrost,
    displayName: "Nordic Frost (Light)",
    isCustom: false,
    brightness: Brightness.light,
    scaffoldBackground: Color(0xFFF8FAFC),
    cardBackground: Color(0xFFFFFFFF),
    staffBackground: Color(0xFFF1F5F9),
    staffLinesColor: Color(0xFF94A3B8),
    musicalSymbolsColor: Color(0xFF0F172A),
    primaryAccent: Color(0xFF2563EB),
    secondaryAccent: Color(0xFFD97706),
    playheadColor: Color(0xFF2563EB),
    correctPitchColor: Color(0xFF059669),
    warningPitchColor: Color(0xFFD97706),
    errorPitchColor: Color(0xFFDC2626),
    textColor: Color(0xFF0F172A),
    textMutedColor: Color(0xFF64748B),
  );

  /// Lista maestra de todas las estéticas de fábrica curadas.
  static const List<TunnerThemePalette> allPresets = [
    obsidianStudio,
    oledPureBlack,
    royalSymphony,
    acousticWood,
    neonStage,
    vintageParchment,
    nordicFrost,
  ];

  /// Colección retrocompatible
  static const List<TunnerThemePalette> allPalettes = allPresets;

  /// Obtiene la paleta predefinida a partir del modo enum (retrocompatibilidad).
  static TunnerThemePalette fromMode(TunnerThemeMode mode) {
    switch (mode) {
      case TunnerThemeMode.obsidianStudio:
        return obsidianStudio;
      case TunnerThemeMode.oledPureBlack:
        return oledPureBlack;
      case TunnerThemeMode.royalSymphony:
        return royalSymphony;
      case TunnerThemeMode.acousticWood:
        return acousticWood;
      case TunnerThemeMode.neonStage:
        return neonStage;
      case TunnerThemeMode.vintageParchment:
        return vintageParchment;
      case TunnerThemeMode.nordicFrost:
        return nordicFrost;
      case TunnerThemeMode.custom:
        return obsidianStudio;
    }
  }

  /// Crea una nueva paleta personalizada basada en una plantilla base y acentos armónicos.
  static TunnerThemePalette createCustom({
    required String name,
    required String baseStyle, // "dark", "oled", "wood", "light"
    required Color primaryAccent,
    Color? secondaryAccent,
  }) {
    final secAccent = secondaryAccent ?? const Color(0xFFFFD54F);
    final id = "custom_${DateTime.now().millisecondsSinceEpoch}";

    switch (baseStyle.toLowerCase()) {
      case "oled":
        return TunnerThemePalette(
          id: id,
          mode: TunnerThemeMode.custom,
          displayName: name,
          isCustom: true,
          brightness: Brightness.dark,
          scaffoldBackground: Colors.black,
          cardBackground: const Color(0xFF121212),
          staffBackground: Colors.black,
          staffLinesColor: const Color(0xFF383838),
          musicalSymbolsColor: Colors.white,
          primaryAccent: primaryAccent,
          secondaryAccent: secAccent,
          playheadColor: primaryAccent,
          correctPitchColor: const Color(0xFF00FF88),
          warningPitchColor: const Color(0xFFFFD54F),
          errorPitchColor: const Color(0xFFFF5252),
          textColor: Colors.white,
          textMutedColor: Colors.white54,
        );
      case "wood":
        return TunnerThemePalette(
          id: id,
          mode: TunnerThemeMode.custom,
          displayName: name,
          isCustom: true,
          brightness: Brightness.dark,
          scaffoldBackground: const Color(0xFF1B1410),
          cardBackground: const Color(0xFF261D17),
          staffBackground: const Color(0xFF201712),
          staffLinesColor: const Color(0xFF5B4538),
          musicalSymbolsColor: const Color(0xFFFDEFD9),
          primaryAccent: primaryAccent,
          secondaryAccent: secAccent,
          playheadColor: primaryAccent,
          correctPitchColor: const Color(0xFF10B981),
          warningPitchColor: const Color(0xFFF59E0B),
          errorPitchColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFFDF6EE),
          textMutedColor: const Color(0xFFA69285),
        );
      case "light":
        return TunnerThemePalette(
          id: id,
          mode: TunnerThemeMode.custom,
          displayName: name,
          isCustom: true,
          brightness: Brightness.light,
          scaffoldBackground: const Color(0xFFF8FAFC),
          cardBackground: const Color(0xFFFFFFFF),
          staffBackground: const Color(0xFFF1F5F9),
          staffLinesColor: const Color(0xFF94A3B8),
          musicalSymbolsColor: const Color(0xFF0F172A),
          primaryAccent: primaryAccent,
          secondaryAccent: secAccent,
          playheadColor: primaryAccent,
          correctPitchColor: const Color(0xFF059669),
          warningPitchColor: const Color(0xFFD97706),
          errorPitchColor: const Color(0xFFDC2626),
          textColor: const Color(0xFF0F172A),
          textMutedColor: const Color(0xFF64748B),
        );
      case "dark":
      default:
        return TunnerThemePalette(
          id: id,
          mode: TunnerThemeMode.custom,
          displayName: name,
          isCustom: true,
          brightness: Brightness.dark,
          scaffoldBackground: const Color(0xFF0D0D14),
          cardBackground: const Color(0xFF171722),
          staffBackground: const Color(0xFF12121A),
          staffLinesColor: const Color(0xFF48485C),
          musicalSymbolsColor: Colors.white,
          primaryAccent: primaryAccent,
          secondaryAccent: secAccent,
          playheadColor: primaryAccent,
          correctPitchColor: const Color(0xFF00E676),
          warningPitchColor: const Color(0xFFFFD54F),
          errorPitchColor: const Color(0xFFFF5252),
          textColor: Colors.white,
          textMutedColor: Colors.white54,
        );
    }
  }

  /// Clona la paleta actual permitiendo modificar campos específicos.
  TunnerThemePalette copyWith({
    String? id,
    TunnerThemeMode? mode,
    String? displayName,
    bool? isCustom,
    Brightness? brightness,
    Color? scaffoldBackground,
    Color? cardBackground,
    Color? staffBackground,
    Color? staffLinesColor,
    Color? musicalSymbolsColor,
    Color? primaryAccent,
    Color? secondaryAccent,
    Color? playheadColor,
    Color? correctPitchColor,
    Color? warningPitchColor,
    Color? errorPitchColor,
    Color? textColor,
    Color? textMutedColor,
  }) {
    return TunnerThemePalette(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      displayName: displayName ?? this.displayName,
      isCustom: isCustom ?? this.isCustom,
      brightness: brightness ?? this.brightness,
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      staffBackground: staffBackground ?? this.staffBackground,
      staffLinesColor: staffLinesColor ?? this.staffLinesColor,
      musicalSymbolsColor: musicalSymbolsColor ?? this.musicalSymbolsColor,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      playheadColor: playheadColor ?? this.playheadColor,
      correctPitchColor: correctPitchColor ?? this.correctPitchColor,
      warningPitchColor: warningPitchColor ?? this.warningPitchColor,
      errorPitchColor: errorPitchColor ?? this.errorPitchColor,
      textColor: textColor ?? this.textColor,
      textMutedColor: textMutedColor ?? this.textMutedColor,
    );
  }

  /// Serialización JSON para exportar el tema o compartirlo entre usuarios.
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "displayName": displayName,
      "isCustom": isCustom,
      "brightness": brightness == Brightness.light ? "light" : "dark",
      "scaffoldBackground": scaffoldBackground.toARGB32(),
      "cardBackground": cardBackground.toARGB32(),
      "staffBackground": staffBackground.toARGB32(),
      "staffLinesColor": staffLinesColor.toARGB32(),
      "musicalSymbolsColor": musicalSymbolsColor.toARGB32(),
      "primaryAccent": primaryAccent.toARGB32(),
      "secondaryAccent": secondaryAccent.toARGB32(),
      "playheadColor": playheadColor.toARGB32(),
      "correctPitchColor": correctPitchColor.toARGB32(),
      "warningPitchColor": warningPitchColor.toARGB32(),
      "errorPitchColor": errorPitchColor.toARGB32(),
      "textColor": textColor.toARGB32(),
      "textMutedColor": textMutedColor.toARGB32(),
    };
  }

  /// Deserialización desde JSON para importar un tema personalizado.
  factory TunnerThemePalette.fromJson(Map<String, dynamic> json) {
    Color parseColor(dynamic val, Color fallback) {
      if (val is int) return Color(val);
      if (val is String) {
        final clean = val.replaceFirst('#', '');
        final intVal = int.tryParse(clean.length <= 6 ? 'FF$clean' : clean, radix: 16);
        if (intVal != null) return Color(intVal);
      }
      return fallback;
    }

    final isLight = json["brightness"] == "light";

    return TunnerThemePalette(
      id: json["id"] as String? ?? "custom_${DateTime.now().millisecondsSinceEpoch}",
      mode: TunnerThemeMode.custom,
      displayName: json["displayName"] as String? ?? "Tema Personalizado",
      isCustom: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackground: parseColor(json["scaffoldBackground"], const Color(0xFF0D0D12)),
      cardBackground: parseColor(json["cardBackground"], const Color(0xFF16161F)),
      staffBackground: parseColor(json["staffBackground"], const Color(0xFF13131A)),
      staffLinesColor: parseColor(json["staffLinesColor"], const Color(0xFF4A4A5A)),
      musicalSymbolsColor: parseColor(json["musicalSymbolsColor"], Colors.white),
      primaryAccent: parseColor(json["primaryAccent"], const Color(0xFF00E676)),
      secondaryAccent: parseColor(json["secondaryAccent"], const Color(0xFFFFD54F)),
      playheadColor: parseColor(json["playheadColor"], const Color(0xFF00E676)),
      correctPitchColor: parseColor(json["correctPitchColor"], const Color(0xFF00E676)),
      warningPitchColor: parseColor(json["warningPitchColor"], const Color(0xFFFFD54F)),
      errorPitchColor: parseColor(json["errorPitchColor"], const Color(0xFFFF5252)),
      textColor: parseColor(json["textColor"], Colors.white),
      textMutedColor: parseColor(json["textMutedColor"], Colors.white54),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TunnerThemePalette &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
