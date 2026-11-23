/// Identificadores canónicos de iconografía para Tunner Studio.
///
/// Consolida los 308 usos dispersos de Material Icons en 44 símbolos
/// semánticos de estudio para permitir reemplazo progresivo por
/// PNGs optimizados y SVGs vectoriales con identidad propia.
enum StudioIconId {
  // A. Módulos del Estudio (14)
  moduleTuner('module_tuner'),
  moduleDrone('module_drone'),
  moduleMetronome('module_metronome'),
  moduleRack('module_rack'),
  modulePatchbay('module_patchbay'),
  moduleDjConsole('module_dj_console'),
  moduleScoreSheet('module_score_sheet'),
  moduleScoreEditor('module_score_editor'),
  modulePianoRoll('module_piano_roll'),
  moduleSpectrogram('module_spectrogram'),
  moduleChordAnalyzer('module_chord_analyzer'),
  moduleRecorder('module_recorder'),
  moduleAutotune('module_autotune'),
  modulePedagogy('module_pedagogy'),

  // B. Transporte, Audio y Hardware DSP (11)
  transportPlay('transport_play'),
  transportPause('transport_pause'),
  transportStop('transport_stop'),
  transportRecord('transport_record'),
  transportRewind('transport_rewind'),
  transportForward('transport_forward'),
  transportLoop('transport_loop'),
  audioMicOn('audio_mic_on'),
  audioMicOff('audio_mic_off'),
  audioVolumeOn('audio_volume_on'),
  audioHeadphones('audio_headphones'),

  // C. Archivos, Formatos y Terminal (9)
  fileFolder('file_folder'),
  fileNew('file_new'),
  fileOpen('file_open'),
  fileSave('file_save'),
  fileExportPdf('file_export_pdf'),
  fileMusicXmlMidi('file_musicxml_midi'),
  fileWavAudio('file_wav_audio'),
  filePreset('file_preset'),
  toolTerminal('tool_terminal'),

  // D. Shell, Ventanas y Controles UI (10)
  uiSearch('ui_search'),
  uiSettings('ui_settings'),
  uiAutomations('ui_automations'),
  uiCustomizations('ui_customizations'),
  uiWorkspaceLayout('ui_workspace_layout'),
  uiSidebarToggle('ui_sidebar_toggle'),
  uiLock('ui_lock'),
  uiPower('ui_power'),
  uiAddRemove('ui_add_remove'),
  uiCloseConfirm('ui_close_confirm');

  const StudioIconId(this.assetKey);

  /// Nombre base canónico del archivo (`<assetKey>.png` / `<assetKey>.svg`).
  final String assetKey;
}

/// Especificación pura de resolución de rutas de assets para [StudioIconId].
class StudioIconAssetSpec {
  final StudioIconId id;
  final String pngAssetPath;
  final String svgAssetPath;

  const StudioIconAssetSpec({
    required this.id,
    required this.pngAssetPath,
    required this.svgAssetPath,
  });
}

/// Catálogo puro en Dart que resuelve las rutas canónicas PNG y SVG.
class StudioIconCatalog {
  StudioIconCatalog._();

  static const String pngBaseDir = 'assets/icons/png';
  static const String svgBaseDir = 'assets/icons/svg';

  static StudioIconAssetSpec specFor(StudioIconId id) {
    return StudioIconAssetSpec(
      id: id,
      pngAssetPath: '$pngBaseDir/${id.assetKey}.png',
      svgAssetPath: '$svgBaseDir/${id.assetKey}.svg',
    );
  }

  static List<StudioIconAssetSpec> get allSpecs =>
      StudioIconId.values.map(specFor).toList(growable: false);
}
