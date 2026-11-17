import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Enumeración tipada de glifos vectoriales técnicos de estudio.
/// Erradica al 100% el uso de caracteres emoji informales en Tunner.
enum StudioGlyphType {
  // Instrumentos de cuerda y viento
  violin,
  guitar,
  bass,
  flute,
  saxophone,
  trumpet,
  woodwind,
  brass,
  
  // Teclados, percusión y síntesis
  piano,
  drums,
  percussion,
  synthesizer,
  modularRack,
  
  // Audio, voz y análisis
  vocalMic,
  audioWave,
  spectrogram,
  strobeTuner,
  metronome,
  earTraining,
  chordAnalyzer,
  sheetMusic,
  songLibrary,
  
  // Estados, controles y métricas
  activityPulse,
  precisionTarget,
  lock,
  unlock,
  mute,
  solo,
  settings,
  search,
  genericAudioTool,
}

/// Átomo de UI: Glifo vectorial técnico de precisión (StudioIcon).
///
/// Sustituye cualquier representación visual informal por iconografía lineal
/// compacta, de tamaño consistente y vinculada a los tokens de diseño de estudio.
class StudioIcon extends StatelessWidget {
  final StudioGlyphType glyph;
  final double size;
  final Color? color;
  final String? tooltip;

  const StudioIcon({
    super.key,
    required this.glyph,
    this.size = 18.0,
    this.color,
    this.tooltip,
  });

  /// Resuelve el icono vectorial nativo según el glifo técnico.
  IconData _resolveIconData(StudioGlyphType type) {
    switch (type) {
      case StudioGlyphType.violin:
      case StudioGlyphType.guitar:
      case StudioGlyphType.bass:
        return Icons.music_note_rounded;
      case StudioGlyphType.flute:
      case StudioGlyphType.woodwind:
        return Icons.air_rounded;
      case StudioGlyphType.saxophone:
      case StudioGlyphType.trumpet:
      case StudioGlyphType.brass:
        return Icons.campaign_rounded;
      case StudioGlyphType.piano:
        return Icons.piano_rounded;
      case StudioGlyphType.drums:
      case StudioGlyphType.percussion:
        return Icons.radio_button_checked_rounded;
      case StudioGlyphType.synthesizer:
      case StudioGlyphType.modularRack:
        return Icons.tune_rounded;
      case StudioGlyphType.vocalMic:
        return Icons.mic_none_rounded;
      case StudioGlyphType.audioWave:
        return Icons.graphic_eq_rounded;
      case StudioGlyphType.spectrogram:
        return Icons.analytics_outlined;
      case StudioGlyphType.strobeTuner:
        return Icons.straighten_rounded;
      case StudioGlyphType.metronome:
        return Icons.speed_rounded;
      case StudioGlyphType.earTraining:
        return Icons.hearing_rounded;
      case StudioGlyphType.chordAnalyzer:
        return Icons.stacked_bar_chart_rounded;
      case StudioGlyphType.sheetMusic:
        return Icons.menu_book_rounded;
      case StudioGlyphType.songLibrary:
        return Icons.library_music_rounded;
      case StudioGlyphType.activityPulse:
        return Icons.bolt_rounded;
      case StudioGlyphType.precisionTarget:
        return Icons.gps_fixed_rounded;
      case StudioGlyphType.lock:
        return Icons.lock_outline_rounded;
      case StudioGlyphType.unlock:
        return Icons.lock_open_rounded;
      case StudioGlyphType.mute:
        return Icons.volume_off_rounded;
      case StudioGlyphType.solo:
        return Icons.headphones_rounded;
      case StudioGlyphType.settings:
        return Icons.tune_rounded;
      case StudioGlyphType.search:
        return Icons.search_rounded;
      case StudioGlyphType.genericAudioTool:
        return Icons.audiotrack_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final effectiveColor = color ?? tokens.textSecondary;
    final iconData = _resolveIconData(glyph);

    final widget = Icon(
      iconData,
      size: size,
      color: effectiveColor,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: widget,
      );
    }

    return widget;
  }
}
