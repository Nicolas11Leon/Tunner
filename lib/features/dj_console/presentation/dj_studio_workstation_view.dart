import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../media_vault/presentation/media_vault_viewmodel.dart';
import '../../media_vault/presentation/media_vault_workspace_modal.dart';
import '../../song_library/domain/song_decomposer_service.dart';
import '../../tuner_viewmodel.dart';
import '../domain/dj_audio_processor.dart';
import '../../../core/channels/domain/studio_modular_plug.dart';
import '../../../core/channels/domain/studio_plug_type.dart';
import '../../../core/channels/presentation/studio_channel_patchbay_bar_widget.dart';
import '../../../core/channels/presentation/studio_modular_plug_widget.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/dj_action.dart';
import '../domain/dj_deck_entity.dart';
import '../domain/dj_harmonic_camelot_engine.dart';
import '../domain/dj_sampler_bank_entity.dart';
import '../domain/dj_smart_automix_engine.dart';
import '../domain/dj_stem_isolation_entity.dart';
import '../../../core/docking/domain/studio_dock_layout_entity.dart';
import '../../../core/docking/domain/studio_dock_zone.dart';
import '../../../core/docking/presentation/studio_dockable_panel_entity.dart';
import '../../../core/docking/presentation/studio_workspace_docking_container.dart';
import 'dj_console_model_builder_modal.dart';
import 'dj_console_view_model.dart';
import 'dj_deck_patchbay_bridge.dart';
import 'dj_interactive_keymap_visualizer_modal.dart';
import 'dj_parallel_waveform_painter.dart';
import 'dj_track_loader_modal.dart';
import 'dj_vertical_channel_strip.dart';
import 'dj_visual_mapping_overlay.dart';
import 'widgets/dj_hot_cue_pad_grid.dart';
import 'vector_jog_wheel.dart';

/// Espacio de Trabajo Nativo de la Consola DJ Pro (DjStudioWorkstationView).
/// Vista de pantalla completa para mezcla profesional, compatible con resolución de escritorio.
class DjStudioWorkstationView extends StatefulWidget {
  final DjConsoleViewModel? viewModel;
  final String initialViewMode;
  final VoidCallback? onClose;

  const DjStudioWorkstationView({
    super.key,
    this.viewModel,
    this.initialViewMode = 'modular',
    this.onClose,
  });

  @override
  State<DjStudioWorkstationView> createState() => _DjStudioWorkstationViewState();
}

class _DjStudioWorkstationViewState extends State<DjStudioWorkstationView> {
  late final DjConsoleViewModel _viewModel;
  bool _internalVm = false;
  bool _showHudBar = true;
  late final FocusNode _focusNode;
  late String _workstationViewMode;

  late final DjDeckPatchbayBridge _patchbayBridge;
  MediaVaultViewModel? _ownedMediaVaultVm;

  @override
  void initState() {
    super.initState();
    _workstationViewMode = widget.initialViewMode;
    _focusNode = FocusNode();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _viewModel = DjConsoleViewModel();
      _internalVm = true;
    }

    _patchbayBridge = DjDeckPatchbayBridge(
      viewModel: _viewModel,
      scopePrefix: DjDeckPatchbayBridge.nextScopePrefix('dj_workstation'),
      includeMasterOut: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _patchbayBridge.dispose();
    _ownedMediaVaultVm?.dispose();
    _focusNode.dispose();
    if (_internalVm) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final vm = _viewModel;

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (vm.handleKeyEvent(event)) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
              }
            },
            child: Scaffold(
              backgroundColor: tokens.canvasBackground,
              body: SafeArea(
                child: Column(
                  children: [
                    // 1. Barra de Control Superior (Master Header & Transporte Global)
                    _buildMasterHeader(context, vm, tokens),

                    // 2. HUD de Atajos Rápidos
                    _buildShortcutsHud(context, tokens, vm),

                    // 3. Barra Modular de Parcheo Troncal (Canal A, B, C, D)
                    StudioChannelPatchbayBarWidget(routingService: _patchbayBridge.routingService),

                    // 4. Visor Central Condicional según Modo de Vista
                    Expanded(
                      child: _buildCentralContent(context, vm, tokens),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCentralContent(BuildContext context, DjConsoleViewModel vm, dynamic tokens) {
    if (_workstationViewMode == 'docking') {
      // Modo Multi-Panel Docking: Arrastre libre a paneles divididos (Left, Center, Right, Bottom)
      final dockablePanels = [
        StudioDockablePanelEntity(
          id: 'panel_hardware_console',
          title: 'Consola Hardware Emulada (${vm.activeSkin.name})',
          icon: Icons.album,
          currentZone: StudioDockZone.center,
          builder: (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: DjVisualMappingOverlay(
              skin: vm.activeSkin,
              selectedZone: vm.selectedZoneForMapping,
              isLearnModeActive: vm.isLearnModeActive,
              lastCapturedInput: vm.lastCapturedInputToken,
              jogRotationA: vm.rotationAngleA,
              jogRotationB: vm.rotationAngleB,
              keymapProfile: vm.keymapProfile,
              showKeyBadges: vm.showKeyBadges,
              onSkinSelected: (skinId) => vm.selectSkin(skinId),
              onZoneSelected: (zone) => vm.selectZoneForMapping(zone),
              onActionTriggered: (action) => vm.executeAction(action),
              onToggleLearnMode: () => vm.toggleLearnMode(),
              getControlValue: (zone) => vm.getControlValue(zone),
              onContinuousControl: (zone, delta) => vm.updateContinuousControl(zone, delta),
              onOpenKeymapVisualizer: () => DjInteractiveKeymapVisualizerModal.show(
                ctx,
                vm,
                TunnerThemePalette.obsidianStudio,
              ),
            ),
          ),
        ),
        StudioDockablePanelEntity(
          id: 'panel_waveforms',
          title: 'Formas de Onda RGB y Espectro',
          icon: Icons.graphic_eq,
          currentZone: StudioDockZone.center,
          builder: (ctx) => Container(
            height: 90,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E14),
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              child: CustomPaint(
                painter: DjParallelWaveformPainter(
                  deckA: vm.deckA,
                  deckB: vm.deckB,
                  waveformA: vm.waveformA,
                  waveformB: vm.waveformB,
                ),
              ),
            ),
          ),
        ),
        StudioDockablePanelEntity(
          id: 'panel_club_mixer',
          title: 'Mezclador Dual de Grado Club',
          icon: Icons.tune,
          currentZone: StudioDockZone.right,
          builder: (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: _buildClubMixerCenter(ctx, vm, tokens),
          ),
        ),
        StudioDockablePanelEntity(
          id: 'panel_stems_sampler',
          title: 'Aislamiento 4-Stems y Sampler Pads',
          icon: Icons.grid_view,
          currentZone: StudioDockZone.bottom,
          builder: (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: _buildPerformanceStemsAndSampler(ctx, vm, tokens),
          ),
        ),
      ];

      return StudioWorkspaceDockingContainer(
        panels: dockablePanels,
        initialLayout: const StudioDockLayoutEntity(
          zonePanelIds: {
            StudioDockZone.center: ['panel_hardware_console', 'panel_waveforms'],
            StudioDockZone.right: ['panel_club_mixer'],
            StudioDockZone.bottom: ['panel_stems_sampler'],
            StudioDockZone.left: [],
            StudioDockZone.floating: [],
          },
        ),
      );
    }

    if (_workstationViewMode == 'hardware') {
      // Modo Hardware Fiel Puro a Pantalla Completa
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DjVisualMappingOverlay(
          skin: vm.activeSkin,
          selectedZone: vm.selectedZoneForMapping,
          isLearnModeActive: vm.isLearnModeActive,
          lastCapturedInput: vm.lastCapturedInputToken,
          jogRotationA: vm.rotationAngleA,
          jogRotationB: vm.rotationAngleB,
          keymapProfile: vm.keymapProfile,
          showKeyBadges: vm.showKeyBadges,
          onSkinSelected: (skinId) => vm.selectSkin(skinId),
          onZoneSelected: (zone) => vm.selectZoneForMapping(zone),
          onActionTriggered: (action) => vm.executeAction(action),
          onToggleLearnMode: () => vm.toggleLearnMode(),
          getControlValue: (zone) => vm.getControlValue(zone),
          onContinuousControl: (zone, delta) => vm.updateContinuousControl(zone, delta),
          onOpenKeymapVisualizer: () => DjInteractiveKeymapVisualizerModal.show(
            context,
            vm,
            TunnerThemePalette.obsidianStudio,
          ),
        ),
      );
    }

    if (_workstationViewMode == 'split') {
      // Modo Split-Screen: Formas de Onda RGB + Consola Hardware Fiel
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            // Waveforms
            Container(
              height: 85,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E14),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: CustomPaint(
                  painter: DjParallelWaveformPainter(
                    deckA: vm.deckA,
                    deckB: vm.deckB,
                    waveformA: vm.waveformA,
                    waveformB: vm.waveformB,
                  ),
                ),
              ),
            ),

            // Hardware Console
            DjVisualMappingOverlay(
              skin: vm.activeSkin,
              selectedZone: vm.selectedZoneForMapping,
              isLearnModeActive: vm.isLearnModeActive,
              lastCapturedInput: vm.lastCapturedInputToken,
              jogRotationA: vm.rotationAngleA,
              jogRotationB: vm.rotationAngleB,
              keymapProfile: vm.keymapProfile,
              showKeyBadges: vm.showKeyBadges,
              onSkinSelected: (skinId) => vm.selectSkin(skinId),
              onZoneSelected: (zone) => vm.selectZoneForMapping(zone),
              onActionTriggered: (action) => vm.executeAction(action),
              onToggleLearnMode: () => vm.toggleLearnMode(),
              getControlValue: (zone) => vm.getControlValue(zone),
              onContinuousControl: (zone, delta) => vm.updateContinuousControl(zone, delta),
              onOpenKeymapVisualizer: () => DjInteractiveKeymapVisualizerModal.show(
                context,
                vm,
                TunnerThemePalette.obsidianStudio,
              ),
            ),
          ],
        ),
      );
    }

    // Modo Modular DAW (Clásico con Channel Strips)
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Waveforms
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E14),
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              child: CustomPaint(
                painter: DjParallelWaveformPainter(
                  deckA: vm.deckA,
                  deckB: vm.deckB,
                  waveformA: vm.waveformA,
                  waveformB: vm.waveformB,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildDeckPanel(context, vm.deckA, 'A', const Color(0xFF00E5FF), vm.rotationAngleA),
              ),
              const SizedBox(width: 12),
              _buildClubMixerCenter(context, vm, tokens),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildDeckPanel(context, vm.deckB, 'B', const Color(0xFFFF4081), vm.rotationAngleB),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPerformanceStemsAndSampler(context, vm, tokens),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildShortcutsHud(BuildContext context, dynamic tokens, DjConsoleViewModel vm) {
    if (!_showHudBar) {
      return Container(
        height: 20,
        color: const Color(0xFF0F131C),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => setState(() => _showHudBar = true),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white54),
              SizedBox(width: 4),
              Text(
                'MOSTRAR HUD DE ATAJOS RAPIDOS',
                style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    final profile = vm.keymapProfile;
    final playA = profile.findKeyBadgeForAction(DjAction.deckAPlayPause) ?? 'ESPACIO';
    final playB = profile.findKeyBadgeForAction(DjAction.deckBPlayPause) ?? 'ENTER';
    final cueA = profile.findKeyBadgeForAction(DjAction.deckACue) ?? 'Q';
    final cueB = profile.findKeyBadgeForAction(DjAction.deckBCue) ?? 'U';
    final syncA = profile.findKeyBadgeForAction(DjAction.deckASync) ?? 'E';
    final syncB = profile.findKeyBadgeForAction(DjAction.deckBSync) ?? 'O';
    final xfader = profile.findKeyBadgeForAction(DjAction.crossfaderCenter) ?? 'N';
    final pitchA = profile.findKeyBadgeForAction(DjAction.deckAPitchUp) ?? 'S';
    final pitchB = profile.findKeyBadgeForAction(DjAction.deckBPitchUp) ?? 'K';
    final hotCueA = profile.findKeyBadgeForAction(DjAction.deckAHotCue1) ?? '1..4';
    final hotCueB = profile.findKeyBadgeForAction(DjAction.deckBHotCue1) ?? '5..8';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0F131C),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 14, color: Color(0xFF00E5FF)),
          const SizedBox(width: 6),
          const Text(
            'HUD EN VIVO:',
            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHudBadge('[$playA]', 'Play/Pause A'),
                  _buildHudBadge('[$playB]', 'Play/Pause B'),
                  _buildHudBadge('[$cueA / $cueB]', 'CUE A / B'),
                  _buildHudBadge('[$syncA / $syncB]', 'SYNC A / B'),
                  _buildHudBadge('[$xfader]', 'X-Fader Centro'),
                  _buildHudBadge('[$pitchA / $pitchB]', 'Pitch Up A / B'),
                  _buildHudBadge('[$hotCueA]', 'Hot Cues A'),
                  _buildHudBadge('[$hotCueB]', 'Hot Cues B'),
                  _buildHudBadge('[PADS 1..8]', 'Sampler Club'),
                  _buildHudBadge('[JOG / RUEDA]', 'Scratch / Nudge'),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 14, color: Colors.white54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Ocultar HUD',
            onPressed: () => setState(() => _showHudBar = false),
          ),
        ],
      ),
    );
  }

  Widget _buildHudBadge(String keyText, String desc) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyText,
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 4),
          Text(
            desc,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterHeader(BuildContext context, DjConsoleViewModel vm, dynamic tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        border: Border(
          bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.album_rounded, color: tokens.accentPrimary, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSOLA DJ PRO STUDIO',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Modelos Fieles • Mapeo QWERTY • Club 4-Band Isolator',
                  style: TextStyle(color: tokens.textMuted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Selector de Modo de Trabajo (Split / Hardware / Modular / Docking)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'split',
                  icon: Icon(Icons.vertical_split, size: 13),
                  label: Text('Split Híbrido', style: TextStyle(fontSize: 10)),
                ),
                ButtonSegment(
                  value: 'hardware',
                  icon: Icon(Icons.album, size: 13),
                  label: Text('Consola Hardware', style: TextStyle(fontSize: 10)),
                ),
                ButtonSegment(
                  value: 'modular',
                  icon: Icon(Icons.view_quilt, size: 13),
                  label: Text('Modular DAW', style: TextStyle(fontSize: 10)),
                ),
                ButtonSegment(
                  value: 'docking',
                  icon: Icon(Icons.dashboard_customize, size: 13),
                  label: Text('Docking DAW (Arrastrar)', style: TextStyle(fontSize: 10)),
                ),
              ],
              selected: {_workstationViewMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _workstationViewMode = newSelection.first;
                });
              },
              style: SegmentedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                backgroundColor: tokens.canvasBackground,
                selectedBackgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                selectedForegroundColor: const Color(0xFF00E5FF),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 24),

            // Compatibilidad Camelot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, size: 12, color: Color(0xFFA78BFA)),
                  const SizedBox(width: 4),
                  Text(
                    '${vm.deckA.effectiveCamelotKey.code} vs ${vm.deckB.effectiveCamelotKey.code}: ${vm.harmonicCompatibility.label}',
                    style: const TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Botón Grabación WAV
            ElevatedButton.icon(
              icon: Icon(
                vm.recorder.isRecording ? Icons.stop : Icons.fiber_manual_record,
                size: 14,
                color: vm.recorder.isRecording ? Colors.white : Colors.redAccent,
              ),
              label: Text(
                vm.recorder.isRecording ? 'REC ${vm.recorder.durationSeconds}s' : 'GRABAR',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: vm.recorder.isRecording ? Colors.redAccent : tokens.elevatedSurface,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () async {
                if (vm.recorder.isRecording) {
                  final duration = vm.recorder.durationSeconds;
                  final bytes = vm.stopRecording();
                  final filename = 'dj_mix_${DateTime.now().millisecondsSinceEpoch}.wav';
                  await vm.saveRecordingToDisk(filename);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sesión guardada como $filename ($duration seg, ${bytes?.lengthInBytes ?? 0} bytes WAV)'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } else {
                  vm.startRecording();
                }
              },
            ),
            const SizedBox(width: 8),

            // Emular Consola (+)
            ElevatedButton.icon(
              key: const Key('open_console_builder_btn'),
              icon: const Icon(Icons.add_circle_outline, size: 14),
              label: const Text('EMULAR CONSOLA (+)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.18),
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () => DjConsoleModelBuilderModal.show(
                context,
                vm,
                TunnerThemePalette.obsidianStudio,
                storageService: vm.blueprintStorageService,
              ),
            ),
            const SizedBox(width: 8),

            // Teclado QWERTY Visualizer
            ElevatedButton.icon(
              key: const Key('open_interactive_keymap_btn'),
              icon: const Icon(Icons.keyboard, size: 14),
              label: const Text('TECLADO QWERTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E283C),
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () => DjInteractiveKeymapVisualizerModal.show(
                context,
                vm,
                TunnerThemePalette.obsidianStudio,
              ),
            ),
            const SizedBox(width: 8),

            // Botón Modular Enviar Partitura (Canal A)
            ElevatedButton.icon(
              key: const Key('inject_score_melody_btn'),
              icon: const Icon(Icons.music_note, size: 14),
              label: const Text('ENVIAR PARTITURA (CH A)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                foregroundColor: const Color(0xFFA78BFA),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                TunerViewModel? tunerVm;
                try {
                  tunerVm = Provider.of<TunerViewModel>(context, listen: false);
                } catch (_) {
                  tunerVm = null;
                }

                final String scoreTitle = tunerVm != null
                    ? 'Partitura: ${tunerVm.activePackage.title}'
                    : 'Partitura: Sonata No. 1 en C Mayor';
                final double scoreBpm = tunerVm != null
                    ? tunerVm.bpm.toDouble()
                    : 120.0;
                final List<String> measureNotes = (tunerVm != null &&
                        tunerVm.activePackage.score.measures.isNotEmpty)
                    ? tunerVm.currentMeasureNotes.map((n) => n.noteName).toList()
                    : const <String>[];

                const scorePlug = StudioModularPlug(
                  id: 'plug_score_melody_out',
                  label: 'OUT PARTITURA',
                  toolId: 'score_editor',
                  type: StudioPlugType.audioOutput,
                  connectedChannelId: 'canal_a',
                );
                _patchbayBridge.routingService.registerPlug(scorePlug);
                _patchbayBridge.routingService.publishChannelParameters(
                  'canal_a',
                  title: scoreTitle,
                  bpm: scoreBpm,
                  key: '8B',
                  initiatorPlugId: 'plug_score_melody_out',
                );
                _patchbayBridge.routingService.dispatchSignalFromPlug(
                  sourcePlugId: 'plug_score_melody_out',
                  payload: {
                    'title': scoreTitle,
                    'bpm': scoreBpm,
                    'key': '8B',
                    if (tunerVm != null) 'notes': measureNotes,
                  },
                );
                _viewModel.loadTrackSimple(
                  'A',
                  title: scoreTitle,
                  bpm: scoreBpm,
                  camelotKey: '8B',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Partitura enviada por CANAL A y sincronizada en Deck A'),
                    backgroundColor: Color(0xFF00E5FF),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),

            // Botón Directo Bóveda Multimedia / Timeline
            ElevatedButton.icon(
              key: const Key('dj_open_media_vault_header_btn'),
              icon: const Icon(Icons.video_library_rounded, size: 14),
              label: const Text('BÓVEDA / TIMELINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                MediaVaultViewModel? vaultVm;
                try {
                  vaultVm = Provider.of<MediaVaultViewModel>(context, listen: false);
                } catch (_) {
                  vaultVm = _ownedMediaVaultVm ??= MediaVaultViewModel();
                }
                MediaVaultWorkspaceModal.show(context, viewModel: vaultVm);
              },
            ),
            const SizedBox(width: 8),

            // Botón Showcase Auto (15s)
            ElevatedButton.icon(
              key: const Key('dj_showcase_routine_btn'),
              icon: Icon(
                vm.isShowcaseRunning ? Icons.stop_circle_outlined : Icons.play_circle_filled,
                size: 14,
                color: vm.isShowcaseRunning ? Colors.white : const Color(0xFFF59E0B),
              ),
              label: Text(
                vm.isShowcaseRunning ? 'SHOWCASE ACTIVO (${15 - vm.showcaseStep}s)' : 'SHOWCASE DEMO (15S)',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: vm.isShowcaseRunning
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                foregroundColor: vm.isShowcaseRunning ? Colors.white : const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
              ),
              onPressed: () => vm.runShowcaseRoutine(),
            ),
            if (widget.onClose != null) ...[
              const SizedBox(width: 8),
              IconButton(
                key: const Key('close_dj_studio_workstation_btn'),
                tooltip: 'Cerrar Estación DJ',
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeckPanel(
    BuildContext context,
    DjDeckEntity deck,
    String deckId,
    Color accentColor,
    double rotationAngle,
  ) {
    final isCueActive = _viewModel.momentaryLitAction == (deckId == 'A' ? DjAction.deckACue : DjAction.deckBCue);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12141D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: deck.isPlaying ? accentColor.withValues(alpha: 0.45) : Colors.white12,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila Superior de Información de Pista y Carga
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accentColor),
                ),
                child: Text(
                  'DECK $deckId',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 10.5, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),

              // Plug Modular Interactivo de Entrada
              StudioModularPlugWidget(
                plug: deckId == 'A' ? _patchbayBridge.deckAPlug : _patchbayBridge.deckBPlug,
                routingService: _patchbayBridge.routingService,
                showLabel: false,
                size: 24.0,
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.trackTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${deck.effectiveBpm.toStringAsFixed(1)} BPM • Pitch: ${deck.pitchPercentage >= 0 ? "+" : ""}${deck.pitchPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _viewModel.syncBpm(deckId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: deck.isSyncActive ? Colors.black : accentColor,
                  backgroundColor: deck.isSyncActive ? accentColor : Colors.transparent,
                  side: BorderSide(color: accentColor),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila de Carga de Pistas: Modal Completo + Carga Rápida de Géneros (Lightning)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.music_note, size: 14),
                  label: const Text('CARGAR PISTA / STEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => DjTrackLoaderModal.show(context, deckId: deckId, viewModel: _viewModel),
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<DjStudioPresetTrack>(
                key: Key('quick_genre_selector_$deckId'),
                tooltip: 'Carga Rápida de Géneros de Estudio',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.flash_on, size: 14, color: accentColor),
                ),
                padding: EdgeInsets.zero,
                color: const Color(0xFF1E2433),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (track) {
                  final samples = DjAudioProcessor().generateDemoGroove(
                    bpm: track.bpm,
                    frequencyHz: deckId == 'A' ? 55.0 : 65.0,
                    durationMs: 8000,
                  );
                  _viewModel.loadTrackWithBeatTracking(
                    deckId,
                    title: track.title,
                    artist: track.artist,
                    audioSamples: samples,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pista rápida en Deck $deckId: "${track.title}" (${track.bpm} BPM)'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                itemBuilder: (ctx) => DjTrackLoaderModal.studioLibrary.map((track) {
                  return PopupMenuItem<DjStudioPresetTrack>(
                    value: track,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${track.bpm} BPM • ${track.genre}',
                          style: TextStyle(color: accentColor, fontSize: 9.5, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Chips rápidos de un solo toque para carga instantánea de repertorio curado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickLoadChip(
                  label: 'Elisa 126',
                  color: accentColor,
                  onTap: () {
                    final curated = SongDecomposerService.getCuratedLibrary();
                    final furElise = curated.firstWhere(
                      (s) => s.id == 'beethoven_fur_elise' || s.title.toLowerCase().contains('elisa'),
                      orElse: () => curated.first,
                    );
                    final samples = DjAudioProcessor().synthesizeSongPackageTrack(
                      furElise,
                      deckId: deckId,
                      durationMs: 16000,
                    );
                    _viewModel.loadTrackWithBeatTracking(
                      deckId,
                      title: furElise.title,
                      artist: furElise.composer,
                      audioSamples: samples,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Para Elisa cargada en Deck $deckId (126 BPM)'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _QuickLoadChip(
                  label: 'Canon 68',
                  color: accentColor,
                  onTap: () {
                    final curated = SongDecomposerService.getCuratedLibrary();
                    final canon = curated.firstWhere(
                      (s) => s.id == 'pachelbel_canon' || s.title.toLowerCase().contains('canon'),
                      orElse: () => curated.first,
                    );
                    final samples = DjAudioProcessor().synthesizeSongPackageTrack(
                      canon,
                      deckId: deckId,
                      durationMs: 16000,
                    );
                    _viewModel.loadTrackWithBeatTracking(
                      deckId,
                      title: canon.title,
                      artist: canon.composer,
                      audioSamples: samples,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Canon en Re cargado en Deck $deckId (68 BPM)'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _QuickLoadChip(
                  label: 'House 124',
                  color: accentColor,
                  onTap: () {
                    final samples = DjAudioProcessor().synthesizePresetTrack(
                      'Deep Horizon House & Groove',
                      bpm: 124.0,
                      deckId: deckId,
                      durationMs: 16000,
                    );
                    _viewModel.loadTrackWithBeatTracking(
                      deckId,
                      title: 'Deep Horizon House & Groove',
                      artist: 'Klub Monolith',
                      audioSamples: samples,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deep House cargado en Deck $deckId (124 BPM)'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _QuickLoadChip(
                  label: 'Cyber 128',
                  color: accentColor,
                  onTap: () {
                    final samples = DjAudioProcessor().synthesizePresetTrack(
                      'Midnight Cyber Synthwave',
                      bpm: 128.0,
                      deckId: deckId,
                      durationMs: 16000,
                    );
                    _viewModel.loadTrackWithBeatTracking(
                      deckId,
                      title: 'Midnight Cyber Synthwave',
                      artist: 'Tunner Studio',
                      audioSamples: samples,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cyber Synthwave cargado en Deck $deckId (128 BPM)'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Jog Wheel Vectorial con Física de Scratch y Scroll de Rueda
          Center(
            child: VectorJogWheel(
              deckLabel: deckId,
              accentColor: accentColor,
              isPlaying: deck.isPlaying,
              rotationAngle: rotationAngle,
              onScratch: (delta) => _viewModel.scratchDeck(deckId, delta),
              onTap: () => _viewModel.togglePlay(deckId),
            ),
          ),
          const SizedBox(height: 8),

          // Barra Rápida de Rebobinado y Salto de Compás (Quick Scrub & Rewind)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141720),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickScrubChip(
                    label: '-10s',
                    icon: Icons.replay_10,
                    tooltip: 'Rebobinar 10 segundos',
                    onTap: () => _viewModel.rewindDeck(deckId, milliseconds: 10000),
                  ),
                  const SizedBox(width: 4),
                  _QuickScrubChip(
                    label: '-5s',
                    icon: Icons.replay_5,
                    tooltip: 'Rebobinar 5 segundos',
                    onTap: () => _viewModel.rewindDeck(deckId, milliseconds: 5000),
                  ),
                  const SizedBox(width: 4),
                  _QuickScrubChip(
                    label: '0:00',
                    icon: Icons.first_page,
                    tooltip: 'Ir al inicio absoluto',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _viewModel.jumpToStart(deckId),
                  ),
                  const SizedBox(width: 4),
                  _QuickScrubChip(
                    label: '+5s',
                    icon: Icons.forward_5,
                    tooltip: 'Avanzar 5 segundos',
                    onTap: () => _viewModel.fastForwardDeck(deckId, milliseconds: 5000),
                  ),
                  const SizedBox(width: 4),
                  _QuickScrubChip(
                    label: '+10s',
                    icon: Icons.forward_10,
                    tooltip: 'Avanzar 10 segundos',
                    onTap: () => _viewModel.fastForwardDeck(deckId, milliseconds: 10000),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Control Rápido de Volumen de Deck con Pulsadores e Indicador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141720),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _viewModel.adjustDeckVolume(deckId, -0.05),
                  borderRadius: BorderRadius.circular(3),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.volume_down, size: 16, color: Colors.white60),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: accentColor,
                      inactiveTrackColor: Colors.white12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      thumbColor: accentColor,
                    ),
                    child: Slider(
                      value: deck.volume.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) => _viewModel.setDeckVolume(deckId, val),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _viewModel.adjustDeckVolume(deckId, 0.05),
                  borderRadius: BorderRadius.circular(3),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.volume_up, size: 16, color: Colors.white60),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _viewModel.setDeckVolume(deckId, deck.volume > 0.01 ? 0.0 : 1.0),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${(deck.volume * 100).toInt()}%',
                      style: TextStyle(
                        color: deck.volume > 0.01 ? accentColor : const Color(0xFFEF4444),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Fader de Pitch (Control de BPM fino)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 14, color: Colors.white60),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _viewModel.adjustPitch(deckId, -0.005),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    activeTrackColor: accentColor,
                    inactiveTrackColor: Colors.white12,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    thumbColor: accentColor,
                  ),
                  child: Slider(
                    value: deck.pitchMultiplier.clamp(0.92, 1.08),
                    min: 0.92,
                    max: 1.08,
                    onChanged: (val) => _viewModel.adjustPitch(deckId, val - deck.pitchMultiplier),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: Colors.white60),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _viewModel.adjustPitch(deckId, 0.005),
              ),
              TextButton(
                onPressed: () => _viewModel.resetPitch(deckId),
                child: const Text('RESET', style: TextStyle(color: Colors.white38, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Botones de Transporte Táctiles de Alta Respuesta (CUE y PLAY/PAUSE)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _viewModel.triggerCue(deckId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCueActive ? const Color(0xFFF59E0B) : const Color(0xFF78350F),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: isCueActive ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                      width: isCueActive ? 2.0 : 1.0,
                    ),
                    shadowColor: isCueActive ? const Color(0xFFF59E0B) : Colors.transparent,
                    elevation: isCueActive ? 6.0 : 1.0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('CUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _viewModel.togglePlay(deckId),
                  icon: Icon(
                    deck.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 18,
                    color: deck.isPlaying ? Colors.white : Colors.black,
                  ),
                  label: Text(
                    deck.isPlaying ? 'PAUSE' : 'PLAY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.0,
                      color: deck.isPlaying ? Colors.white : Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deck.isPlaying ? const Color(0xFF059669) : accentColor,
                    foregroundColor: deck.isPlaying ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: deck.isPlaying ? const Color(0xFF34D399) : Colors.transparent,
                      width: deck.isPlaying ? 2.0 : 0.0,
                    ),
                    shadowColor: deck.isPlaying ? const Color(0xFF10B981) : Colors.transparent,
                    elevation: deck.isPlaying ? 6.0 : 2.0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Hot Cues
          const Text(
            'HOT CUES',
            style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          DjHotCuePadGrid(
            deckId: deckId,
            deck: deck,
            accentColor: accentColor,
            momentaryLitAction: _viewModel.momentaryLitAction,
            onTriggerHotCue: (idx) => _viewModel.triggerHotCue(deckId, idx),
            onClearHotCue: (idx) => _viewModel.clearHotCue(deckId, idx),
          ),
        ],
      ),
    );
  }

  Widget _buildClubMixerCenter(BuildContext context, DjConsoleViewModel vm, dynamic tokens) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1118),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 1.0),
      ),
      child: Column(
        children: [
          Text(
            'MEZCLADOR DUAL CLUB',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          // Tiras de Canales Verticales (CH A y CH B)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DjVerticalChannelStrip(
                deckId: 'A',
                deck: vm.deckA,
                viewModel: vm,
                accentColor: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              DjVerticalChannelStrip(
                deckId: 'B',
                deck: vm.deckB,
                viewModel: vm,
                accentColor: const Color(0xFFFF4081),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Master Output Volume
          Container(
            width: 288,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF141720),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                const Text(
                  'MASTER',
                  style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveTrackColor: Colors.white12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      thumbColor: const Color(0xFF10B981),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: vm.masterVolume.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) => vm.setMasterVolume(val),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(vm.masterVolume * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Crossfader Horizontal
          Container(
            width: 288,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141720),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('A', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('CROSSFADER', style: TextStyle(color: Colors.white38, fontSize: 8.5, letterSpacing: 0.8)),
                    Text('B', style: TextStyle(color: Color(0xFFFF4081), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white30,
                    inactiveTrackColor: Colors.white12,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: vm.crossfader.position.clamp(-1.0, 1.0),
                    min: -1.0,
                    max: 1.0,
                    onChanged: (val) => vm.setCrossfaderPosition(val),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildCompactActionChip(
                      chipKey: const Key('dj_crossfader_snap_a'),
                      label: 'DECK A (-1.0)',
                      isActive: (vm.crossfader.position - (-1.0)).abs() < 0.01,
                      activeColor: const Color(0xFF00E5FF),
                      onTap: () => vm.setCrossfaderPosition(-1.0),
                    ),
                    const SizedBox(width: 4),
                    _buildCompactActionChip(
                      chipKey: const Key('dj_crossfader_snap_center'),
                      label: 'CENTRO (0.0)',
                      isActive: vm.crossfader.position.abs() < 0.01,
                      activeColor: const Color(0xFF38BDF8),
                      onTap: () => vm.setCrossfaderPosition(0.0),
                    ),
                    const SizedBox(width: 4),
                    _buildCompactActionChip(
                      chipKey: const Key('dj_crossfader_snap_b'),
                      label: 'DECK B (+1.0)',
                      isActive: (vm.crossfader.position - 1.0).abs() < 0.01,
                      activeColor: const Color(0xFFFF4081),
                      onTap: () => vm.setCrossfaderPosition(1.0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStemsAndSampler(BuildContext context, DjConsoleViewModel vm, dynamic tokens) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grain, color: tokens.accentPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AISLAMIENTO DE 4-STEMS (CLUB ISOLATOR) EN TIEMPO REAL & BANCO DE SAMPLER (8 PADS)',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Smart Automix Button
              ElevatedButton.icon(
                icon: Icon(Icons.swap_horiz, size: 14, color: vm.automix.isActive ? Colors.black : Colors.white),
                label: Text(
                  vm.automix.isActive ? 'AUTOMIX: EN CURSO' : 'SMART AUTOMIX (BASS-SWAP)',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: vm.automix.isActive ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  foregroundColor: vm.automix.isActive ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  if (vm.automix.isActive) {
                    vm.cancelSmartAutomix();
                  } else {
                    final dir = vm.crossfader.position <= 0.0 ? AutomixDirection.deckAToDeckB : AutomixDirection.deckBToDeckA;
                    vm.startSmartAutomix(dir);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stems Isolation Controls (Deck A & Deck B)
          Row(
            children: [
              Expanded(
                child: _buildStemStrip('DECK A', 'A', vm.deckA.stems, vm, const Color(0xFF00E5FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStemStrip('DECK B', 'B', vm.deckB.stems, vm, const Color(0xFFFF4081)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 8 Performance Sampler Pads
          Text(
            'BANCO DE SAMPLER TÁCTIL (ONE-SHOTS DE CLUB)',
            style: TextStyle(color: tokens.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: DjSamplerPadType.values.map((pad) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2230),
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8), width: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => vm.triggerSamplerPad(pad),
                    child: Text(
                      pad.label.toUpperCase(),
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStemStrip(String title, String deckId, DjStemIsolationEntity stems, DjConsoleViewModel vm, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF151822),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: accentColor, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildStemChip('VOCAL', !stems.isVocalMuted, () => vm.toggleStem(deckId, DjStemType.vocals)),
              _buildStemChip('MELODY', !stems.isMelodyMuted, () => vm.toggleStem(deckId, DjStemType.melody)),
              _buildStemChip('BASS', !stems.isBassMuted, () => vm.toggleStem(deckId, DjStemType.bass)),
              _buildStemChip('DRUMS', !stems.isDrumsMuted, () => vm.toggleStem(deckId, DjStemType.drums)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildCompactActionChip(
                chipKey: Key('dj_stem_preset_acapella_$deckId'),
                label: 'Acapella',
                isActive: !stems.isVocalMuted && stems.isDrumsMuted && stems.isBassMuted && stems.isMelodyMuted,
                activeColor: accentColor,
                onTap: () => vm.applyStemPreset(deckId, 'acapella'),
              ),
              const SizedBox(width: 4),
              _buildCompactActionChip(
                chipKey: Key('dj_stem_preset_instrumental_$deckId'),
                label: 'Instrumental',
                isActive: stems.isVocalMuted && !stems.isDrumsMuted && !stems.isBassMuted && !stems.isMelodyMuted,
                activeColor: accentColor,
                onTap: () => vm.applyStemPreset(deckId, 'instrumental'),
              ),
              const SizedBox(width: 4),
              _buildCompactActionChip(
                chipKey: Key('dj_stem_preset_all_$deckId'),
                label: 'Todos',
                isActive: !stems.isVocalMuted && !stems.isDrumsMuted && !stems.isBassMuted && !stems.isMelodyMuted,
                activeColor: accentColor,
                onTap: () => vm.applyStemPreset(deckId, 'all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionChip({
    required Key chipKey,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? activeColor : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white70,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStemChip(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isActive ? const Color(0xFF10B981) : Colors.white12,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF10B981) : Colors.white38,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickLoadChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLoadChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class _QuickScrubChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _QuickScrubChip({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
