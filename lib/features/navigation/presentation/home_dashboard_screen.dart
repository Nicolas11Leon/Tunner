import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/atoms/studio_icon.dart';
import '../../../core/design_system/domain/studio_icon_catalog.dart';
import '../../../core/design_system/studio_design_tokens.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../instrument/presentation/instrument_selector_modal.dart';
import '../../media_vault/presentation/media_vault_viewmodel.dart';
import '../../modular_rack/presentation/modular_rack_viewmodel.dart';
import '../../pedagogy_report/presentation/pedagogical_report_modal.dart';
import '../../tuner/presentation/concert_pitch_selector_modal.dart';
import '../../tuner/presentation/microphone_calibration_modal.dart';
import '../../tuner/presentation/temperament_selector_modal.dart';
import '../../tuner_viewmodel.dart';
import 'keyboard_shortcuts_modal.dart';
import 'pro_command_palette_modal.dart';
import 'studio_command_catalog_builder.dart';
import 'tool_search_modal.dart';

/// Hub Técnico y Lanzador Pro-DAW de Tunner Studio (UC-174).
///
/// Reemplaza las tarjetas web genéricas por paneles técnicos de alta densidad
/// con costuras de 1px, tipografía tabular monoespaciada e iconografía
/// progresiva [StudioIcon] (PNG -> SVG -> Fallback).
class HomeDashboardScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;
  final VoidCallback? onOpenTerminal;
  final void Function(String deckId, String songKey)? onLoadDjTemplate;
  final VoidCallback? onOpenUniversalCommandPalette;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToTab,
    this.onOpenTerminal,
    this.onLoadDjTemplate,
    this.onOpenUniversalCommandPalette,
  });

  void _openDefaultUniversalCommandPalette(
    BuildContext context,
    TunerViewModel viewModel,
  ) {
    if (onOpenUniversalCommandPalette != null) {
      onOpenUniversalCommandPalette!();
      return;
    }
    final rackVm = ModularRackViewModel();
    final vaultVm = MediaVaultViewModel();
    final commands = StudioCommandCatalogBuilder.build(
      context: context,
      viewModel: viewModel,
      modularRackViewModel: rackVm,
      mediaVaultViewModel: vaultVm,
      onNavigateToTab: onNavigateToTab,
      onOpenInstrumentSelector: () =>
          InstrumentSelectorModal.show(context, viewModel),
      onToggleSidebar: () {},
      onToggleDualSplit: () {},
      onToggleTerminal: onOpenTerminal ?? () {},
      onOpenShortcutsGuide: () => KeyboardShortcutsCheatSheetModal.show(
        context: context,
        palette: viewModel.currentPalette,
      ),
      onOpenMasterConsole: () {},
    );
    ProCommandPaletteModal.show(
      context: context,
      palette: viewModel.currentPalette,
      commands: commands,
    ).whenComplete(() {
      rackVm.dispose();
      vaultVm.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);
    final instrument = viewModel.activeInstrument;

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 720;
            final isWideGrid = constraints.maxWidth >= 960;

            final modules = <_ProModuleSpec>[
              _ProModuleSpec(
                key: const Key('card_action_tuner'),
                title: 'Afinador de Precisión',
                spec: 'Aguja centesimal · Estroboscopio · MPM/FFI',
                tag: 'A4=${viewModel.referencePitch.toInt()}HZ',
                iconId: StudioIconId.moduleTuner,
                onTap: () => onNavigateToTab(1),
              ),
              _ProModuleSpec(
                key: const Key('card_action_lessons'),
                title: 'Conservatorio & Práctica',
                spec: 'Rutinas guiadas · Ebbinghaus · ${instrument.name}',
                tag: '${viewModel.availableGuidedLessons.length} RUTINAS',
                iconId: StudioIconId.modulePedagogy,
                onTap: () => onNavigateToTab(2),
              ),
              _ProModuleSpec(
                key: const Key('card_action_recorder'),
                title: 'Rack Modular & SignalBus',
                spec: 'Cadena DSP en vivo · Patchbay · Grabadora',
                tag: 'MODULAR DSP',
                iconId: StudioIconId.moduleRack,
                onTap: () => onNavigateToTab(3),
              ),
              _ProModuleSpec(
                key: const Key('card_action_library'),
                title: 'Partituras & Editor SMuFL',
                spec: 'Repertorio · Stems · MusicXML / MIDI / ABC',
                tag: 'SMUFL PRO',
                iconId: StudioIconId.moduleScoreSheet,
                onTap: () => onNavigateToTab(4),
              ),
              _ProModuleSpec(
                key: const Key('card_action_dj'),
                title: 'Consola DJ Workstation',
                spec: '2 Decks · Jog Wheels · 4-Stems Isolator · 8 Pads',
                tag: '2-DECK MIXER',
                iconId: StudioIconId.moduleDjConsole,
                onTap: () => onNavigateToTab(5),
              ),
            ];

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 14,
                vertical: isDesktop ? 16 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCommandBar(context, viewModel, tokens),
                  const SizedBox(height: 10),
                  _buildInstrumentAndAudioStrip(
                    context,
                    viewModel,
                    tokens,
                    instrumentName: instrument.name,
                    instrumentMeta:
                        '${instrument.family.displayName} · ${instrument.key.displayName}',
                    clefSymbol: instrument.clef.symbol,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                    tokens,
                    'WORKBENCH MODULES',
                    trailing: 'SELECT TO FOCUS',
                  ),
                  const SizedBox(height: 8),
                  if (isWideGrid)
                    _buildDesktopModuleMatrix(modules, tokens)
                  else
                    Column(
                      children: [
                        for (int i = 0; i < modules.length; i++) ...[
                          if (i > 0) const SizedBox(height: 6),
                          _ProModuleTile(spec: modules[i], tokens: tokens),
                        ],
                      ],
                    ),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    tokens,
                    'SESSION TEMPLATES',
                    trailing: '.TUNNER · .TNDJ · .WAV · .TNPRESET',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProTemplateTile(
                        key: const Key('template_score_bach'),
                        title: 'Bach: Suite No. 1 Preludio',
                        extension: '.tunner',
                        subtitle: 'Partitura polifónica & stems',
                        iconId: StudioIconId.moduleScoreSheet,
                        tokens: tokens,
                        onTap: () {
                          final bach = viewModel.workspaceScores.where(
                            (s) =>
                                s.title.toLowerCase().contains('bach') ||
                                s.title.toLowerCase().contains('suite'),
                          );
                          if (bach.isNotEmpty) {
                            viewModel.loadSongPackage(bach.first);
                          } else if (viewModel.workspaceScores.isNotEmpty) {
                            viewModel.loadSongPackage(
                              viewModel.workspaceScores.first,
                            );
                          }
                          onNavigateToTab(4);
                        },
                      ),
                      _ProTemplateTile(
                        key: const Key('template_dj_elisa'),
                        title: 'Para Elisa Club Mix (126 BPM)',
                        extension: '.tndj',
                        subtitle: 'Sesión DJ 2-Decks & Beats',
                        iconId: StudioIconId.moduleDjConsole,
                        tokens: tokens,
                        onTap: () {
                          viewModel.updateBpm(126);
                          onLoadDjTemplate?.call('A', 'elisa');
                          onNavigateToTab(5);
                        },
                      ),
                      _ProTemplateTile(
                        key: const Key('template_take_acoustic'),
                        title: 'Toma Acústica 440 Hz',
                        extension: '.wav',
                        subtitle: 'Audio estéreo 24-bit',
                        iconId: StudioIconId.moduleSpectrogram,
                        tokens: tokens,
                        onTap: () {
                          viewModel.setReferencePitch(440.0);
                          viewModel.playReferenceTone('La4');
                          onNavigateToTab(3);
                        },
                      ),
                      _ProTemplateTile(
                        key: const Key('template_preset_philharmonic'),
                        title: 'Afinación Filarmónica (442 Hz)',
                        extension: '.tnpreset',
                        subtitle: 'Estándar orquestal sinfónico',
                        iconId: StudioIconId.filePreset,
                        tokens: tokens,
                        onTap: () {
                          viewModel.setReferencePitch(442.0);
                          onNavigateToTab(1);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    tokens,
                    'HARDWARE & CALIBRATION',
                    trailing: 'QUICK INSPECTOR',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProCalibrationButton(
                        key: const Key('home_quick_mic_btn'),
                        iconId: StudioIconId.audioMicOn,
                        label:
                            'MIC: ${viewModel.acousticRigorProfile.preset.displayName.split(' ').first.toUpperCase()}',
                        tokens: tokens,
                        onTap: () =>
                            MicrophoneCalibrationModal.show(context, viewModel),
                      ),
                      _ProCalibrationButton(
                        key: const Key('home_quick_concert_pitch_btn'),
                        iconId: StudioIconId.moduleDrone,
                        label: 'A4: ${viewModel.referencePitch.toInt()} HZ',
                        tokens: tokens,
                        onTap: () => ConcertPitchSelectorModal.show(context),
                      ),
                      _ProCalibrationButton(
                        key: const Key('home_quick_temperament_btn'),
                        iconId: StudioIconId.moduleScoreEditor,
                        label:
                            'TEMP: ${viewModel.selectedTemperament.name.split(' ').first.toUpperCase()}',
                        tokens: tokens,
                        onTap: () => TemperamentSelectorModal.show(context),
                      ),
                      if (viewModel.lastReport != null)
                        _ProCalibrationButton(
                          key: const Key('home_quick_report_btn'),
                          iconId: StudioIconId.fileExportPdf,
                          label: 'REPORTE PDF',
                          tokens: tokens,
                          onTap: () => PedagogicalReportModal.show(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCommandBar(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens,
  ) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            key: const Key('home_search_trigger_bar'),
            onTap: () => ToolSearchModal.show(
              context,
              viewModel,
              onNavigateToTab: onNavigateToTab,
            ),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                border: Border.all(color: tokens.borderHairline, width: 1),
              ),
              child: Row(
                children: [
                  StudioIcon(
                    StudioIconId.uiSearch,
                    size: 14,
                    color: tokens.textMuted,
                    tintCustomAsset: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buscar módulo, partitura, metrónomo o comando...',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    key: const Key('home_universal_command_palette_trigger'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openDefaultUniversalCommandPalette(
                      context,
                      viewModel,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Text(
                        'CTRL+K',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          height: 34,
          child: IconButton(
            key: const Key('home_search_icon_btn'),
            tooltip: 'Buscar herramienta (Ctrl+K)',
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: tokens.panelBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                side: BorderSide(color: tokens.borderHairline),
              ),
            ),
            icon: StudioIcon(
              StudioIconId.uiSearch,
              size: 15,
              color: tokens.textPrimary,
              tintCustomAsset: true,
            ),
            onPressed: () => ToolSearchModal.show(
              context,
              viewModel,
              onNavigateToTab: onNavigateToTab,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstrumentAndAudioStrip(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens, {
    required String instrumentName,
    required String instrumentMeta,
    required String clefSymbol,
  }) {
    final matrix = viewModel.audioDeviceMatrixService?.matrix;
    final dspLabel = matrix != null
        ? '${(matrix.sampleRate / 1000).toStringAsFixed(1)} kHz · 24-bit · Buffer: ${matrix.bufferSize} (${(matrix.bufferSize / matrix.sampleRate * 1000.0).toStringAsFixed(1)} ms) · RingBuffer 16k'
        : '48.0 kHz · 24-bit · Buffer: 256 (5.3 ms) · RingBuffer 16k';

    return Container(
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(color: tokens.borderHairline, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Text(
                    clefSymbol,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE INSTRUMENT PROFILE',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              instrumentName,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              instrumentMeta,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('home_audition_drone_btn'),
                  tooltip: viewModel.isDronePlaying
                      ? 'Detener Tono Diapasón'
                      : 'Audicionar Tono Diapasón (${viewModel.referencePitch.toInt()} Hz)',
                  icon: StudioIcon(
                    viewModel.isDronePlaying
                        ? StudioIconId.audioVolumeOn
                        : StudioIconId.audioHeadphones,
                    size: 16,
                    color: viewModel.isDronePlaying
                        ? tokens.accentSuccess
                        : tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => viewModel.toggleDrone(),
                ),
                OutlinedButton(
                  key: const Key('home_change_instrument_btn'),
                  onPressed: () =>
                      InstrumentSelectorModal.show(context, viewModel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    backgroundColor: tokens.elevatedSurface,
                    side: BorderSide(color: tokens.borderHairline),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    ),
                  ),
                  child: const Text(
                    'CAMBIAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.borderSubtle),
          Container(
            key: const Key('home_core_audio_hud'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: tokens.panelHeaderBackground,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: tokens.accentSuccess,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CORE AUDIO DSP',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dspLabel,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onOpenTerminal != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    key: const Key('home_open_terminal_hud_btn'),
                    onTap: onOpenTerminal,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StudioIcon(
                            StudioIconId.toolTerminal,
                            size: 12,
                            color: tokens.textPrimary,
                            tintCustomAsset: true,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'TERMINAL (CTRL+~)',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopModuleMatrix(
    List<_ProModuleSpec> modules,
    StudioDesignTokens tokens,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - 8) / 2;
        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: colWidth,
                  child: _ProModuleTile(spec: modules[0], tokens: tokens),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: colWidth,
                  child: _ProModuleTile(spec: modules[1], tokens: tokens),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: colWidth,
                  child: _ProModuleTile(spec: modules[2], tokens: tokens),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: colWidth,
                  child: _ProModuleTile(spec: modules[3], tokens: tokens),
                ),
              ],
            ),
            if (modules.length > 4) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: constraints.maxWidth,
                child: _ProModuleTile(spec: modules[4], tokens: tokens),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    StudioDesignTokens tokens,
    String title, {
    required String trailing,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: tokens.borderSubtle),
        ),
        const SizedBox(width: 10),
        Text(
          trailing,
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 9.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ProModuleSpec {
  final Key key;
  final String title;
  final String spec;
  final String tag;
  final StudioIconId iconId;
  final VoidCallback onTap;

  const _ProModuleSpec({
    required this.key,
    required this.title,
    required this.spec,
    required this.tag,
    required this.iconId,
    required this.onTap,
  });
}

class _ProModuleTile extends StatelessWidget {
  final _ProModuleSpec spec;
  final StudioDesignTokens tokens;

  const _ProModuleTile({
    required this.spec,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: spec.key,
      color: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline, width: 1),
      ),
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        hoverColor: tokens.hoverSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.elevatedSurface,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: StudioIcon(
                  spec.iconId,
                  size: 18,
                  color: tokens.textPrimary,
                  tintCustomAsset: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.spec,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.inputSurface,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Text(
                  spec.tag,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProTemplateTile extends StatelessWidget {
  final String title;
  final String extension;
  final String subtitle;
  final StudioIconId iconId;
  final StudioDesignTokens tokens;
  final VoidCallback onTap;

  const _ProTemplateTile({
    super.key,
    required this.title,
    required this.extension,
    required this.subtitle,
    required this.iconId,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        hoverColor: tokens.hoverSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioIcon(
                iconId,
                size: 15,
                color: tokens.textSecondary,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.inputSurface,
                          borderRadius:
                              BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(color: tokens.borderHairline),
                        ),
                        child: Text(
                          extension,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProCalibrationButton extends StatelessWidget {
  final StudioIconId iconId;
  final String label;
  final StudioDesignTokens tokens;
  final VoidCallback onTap;

  const _ProCalibrationButton({
    super.key,
    required this.iconId,
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        side: BorderSide(color: tokens.borderHairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        hoverColor: tokens.hoverSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioIcon(
                iconId,
                size: 13,
                color: tokens.textSecondary,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
