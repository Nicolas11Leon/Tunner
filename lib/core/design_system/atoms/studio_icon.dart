import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/studio_icon_catalog.dart';

/// Adaptador opcional para renderizar SVG cuando la aplicación integre
/// assets vectoriales en `assets/icons/svg/`.
typedef StudioSvgBuilder = Widget Function(
  BuildContext context,
  String svgAssetPath,
  double size,
  Color? tintColor,
);

/// Átomo de iconografía progresiva de Tunner Studio.
///
/// Orden de resolución sin romper la UI ni lanzar excepciones si faltan assets:
/// 1. SVG vectorial (`assets/icons/svg/<id>.svg`) si [globalSvgBuilder] está registrado.
/// 2. PNG optimizado (`assets/icons/png/<id>.png`) vía [Image.asset] sólo cuando
///    el asset existe en la caché de manifiesto ([hasBundledPng]).
/// 3. Fallback directo al [IconData] canónico mientras el asset no exista,
///    evitando cargas fallidas asíncronas de [Image.asset].
class StudioIcon extends StatelessWidget {
  final StudioIconId id;
  final double size;
  final Color? color;
  final bool tintCustomAsset;
  final IconData? fallbackOverride;

  /// Hook global opcional para conectar `flutter_svg` en el futuro sin editar UI.
  static StudioSvgBuilder? globalSvgBuilder;

  /// Los 38 PNGs actualmente presentes en `assets/icons/png/`.
  static const Set<String> defaultBundledPngAssetPaths = <String>{
    'assets/icons/png/audio_headphones.png',
    'assets/icons/png/audio_mic_off.png',
    'assets/icons/png/audio_mic_on.png',
    'assets/icons/png/audio_volume_on.png',
    'assets/icons/png/file_export_pdf.png',
    'assets/icons/png/file_folder.png',
    'assets/icons/png/file_musicxml_midi.png',
    'assets/icons/png/file_new.png',
    'assets/icons/png/file_open.png',
    'assets/icons/png/file_preset.png',
    'assets/icons/png/file_save.png',
    'assets/icons/png/file_wav_audio.png',
    'assets/icons/png/module_dj_console.png',
    'assets/icons/png/module_drone.png',
    'assets/icons/png/module_metronome.png',
    'assets/icons/png/module_patchbay.png',
    'assets/icons/png/module_rack.png',
    'assets/icons/png/module_recorder.png',
    'assets/icons/png/module_score_sheet.png',
    'assets/icons/png/module_tuner.png',
    'assets/icons/png/tool_terminal.png',
    'assets/icons/png/transport_forward.png',
    'assets/icons/png/transport_loop.png',
    'assets/icons/png/transport_pause.png',
    'assets/icons/png/transport_play.png',
    'assets/icons/png/transport_record.png',
    'assets/icons/png/transport_rewind.png',
    'assets/icons/png/transport_stop.png',
    'assets/icons/png/ui_add_remove.png',
    'assets/icons/png/ui_automations.png',
    'assets/icons/png/ui_close_confirm.png',
    'assets/icons/png/ui_customizations.png',
    'assets/icons/png/ui_lock.png',
    'assets/icons/png/ui_power.png',
    'assets/icons/png/ui_search.png',
    'assets/icons/png/ui_settings.png',
    'assets/icons/png/ui_sidebar_toggle.png',
    'assets/icons/png/ui_workspace_layout.png',
  };

  static Set<String> _availablePngAssets =
      Set<String>.from(defaultBundledPngAssetPaths);

  /// Verifica en O(1) si el PNG para [pngAssetPath] está disponible en el bundle.
  static bool hasBundledPng(String pngAssetPath) =>
      _availablePngAssets.contains(pngAssetPath);

  /// Verifica en O(1) si el [StudioIconId] tiene un PNG disponible en caché.
  static bool hasBundledPngForId(StudioIconId id) =>
      hasBundledPng(StudioIconCatalog.specFor(id).pngAssetPath);

  /// Precarga dinámicamente el `AssetManifest` desde [bundle] (o [rootBundle])
  /// para sincronizar los iconos PNG presentes en tiempo de ejecución.
  static Future<void> preloadManifest([AssetBundle? bundle]) async {
    try {
      final manifest =
          await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
      final pngAssets = manifest
          .listAssets()
          .where(
            (path) =>
                path.startsWith('${StudioIconCatalog.pngBaseDir}/') &&
                path.endsWith('.png'),
          )
          .toSet();
      if (pngAssets.isNotEmpty) {
        _availablePngAssets = pngAssets;
      }
    } catch (_) {
      // Si el bundle de test no expone AssetManifest binario, conservar el registro estático.
    }
  }

  /// Registra rutas PNG adicionales en la caché (útil para tests o carga dinámica).
  static void registerAvailablePngAssets(Iterable<String> assetPaths) {
    _availablePngAssets = <String>{
      ..._availablePngAssets,
      ...assetPaths,
    };
  }

  /// Restaura la caché de assets PNG al conjunto canónico por defecto.
  static void resetManifestCache() {
    _availablePngAssets = Set<String>.from(defaultBundledPngAssetPaths);
  }

  const StudioIcon(
    this.id, {
    super.key,
    this.size = 18.0,
    this.color,
    this.tintCustomAsset = false,
    this.fallbackOverride,
  });

  static IconData fallbackIconFor(StudioIconId id) {
    switch (id) {
      case StudioIconId.moduleTuner:
        return Icons.tune;
      case StudioIconId.moduleDrone:
        return Icons.waves;
      case StudioIconId.moduleMetronome:
        return Icons.av_timer;
      case StudioIconId.moduleRack:
        return Icons.view_column;
      case StudioIconId.modulePatchbay:
        return Icons.cable;
      case StudioIconId.moduleDjConsole:
        return Icons.album;
      case StudioIconId.moduleScoreSheet:
        return Icons.menu_book_outlined;
      case StudioIconId.moduleScoreEditor:
        return Icons.edit_note;
      case StudioIconId.modulePianoRoll:
        return Icons.piano;
      case StudioIconId.moduleSpectrogram:
        return Icons.graphic_eq;
      case StudioIconId.moduleChordAnalyzer:
        return Icons.hub_outlined;
      case StudioIconId.moduleRecorder:
        return Icons.mic;
      case StudioIconId.moduleAutotune:
        return Icons.auto_fix_high;
      case StudioIconId.modulePedagogy:
        return Icons.school_outlined;
      case StudioIconId.transportPlay:
        return Icons.play_arrow;
      case StudioIconId.transportPause:
        return Icons.pause;
      case StudioIconId.transportStop:
        return Icons.stop;
      case StudioIconId.transportRecord:
        return Icons.fiber_manual_record;
      case StudioIconId.transportRewind:
        return Icons.fast_rewind;
      case StudioIconId.transportForward:
        return Icons.fast_forward;
      case StudioIconId.transportLoop:
        return Icons.repeat;
      case StudioIconId.audioMicOn:
        return Icons.mic;
      case StudioIconId.audioMicOff:
        return Icons.mic_off;
      case StudioIconId.audioVolumeOn:
        return Icons.volume_up;
      case StudioIconId.audioHeadphones:
        return Icons.headphones;
      case StudioIconId.fileFolder:
        return Icons.folder_outlined;
      case StudioIconId.fileNew:
        return Icons.note_add_outlined;
      case StudioIconId.fileOpen:
        return Icons.file_open_outlined;
      case StudioIconId.fileSave:
        return Icons.save_outlined;
      case StudioIconId.fileExportPdf:
        return Icons.picture_as_pdf_outlined;
      case StudioIconId.fileMusicXmlMidi:
        return Icons.music_note_outlined;
      case StudioIconId.fileWavAudio:
        return Icons.audio_file_outlined;
      case StudioIconId.filePreset:
        return Icons.tune_outlined;
      case StudioIconId.toolTerminal:
        return Icons.terminal;
      case StudioIconId.uiSearch:
        return Icons.search;
      case StudioIconId.uiSettings:
        return Icons.settings_outlined;
      case StudioIconId.uiAutomations:
        return Icons.bolt;
      case StudioIconId.uiCustomizations:
        return Icons.palette_outlined;
      case StudioIconId.uiWorkspaceLayout:
        return Icons.dashboard_customize_outlined;
      case StudioIconId.uiSidebarToggle:
        return Icons.view_sidebar_outlined;
      case StudioIconId.uiLock:
        return Icons.lock_outline;
      case StudioIconId.uiPower:
        return Icons.power_settings_new;
      case StudioIconId.uiAddRemove:
        return Icons.add;
      case StudioIconId.uiCloseConfirm:
        return Icons.close;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = StudioIconCatalog.specFor(id);
    final effectiveColor = color ?? IconTheme.of(context).color;
    final fallback = Icon(
      fallbackOverride ?? fallbackIconFor(id),
      size: size,
      color: effectiveColor,
    );

    if (globalSvgBuilder != null) {
      return SizedBox(
        width: size,
        height: size,
        child: globalSvgBuilder!(
          context,
          spec.svgAssetPath,
          size,
          tintCustomAsset ? effectiveColor : null,
        ),
      );
    }

    if (!hasBundledPng(spec.pngAssetPath)) {
      return SizedBox(
        width: size,
        height: size,
        child: fallback,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        spec.pngAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        color: tintCustomAsset ? effectiveColor : null,
        colorBlendMode: tintCustomAsset ? BlendMode.srcIn : null,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
