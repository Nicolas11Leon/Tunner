import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../core/channels/data/studio_patchbay_routing_service.dart';
import '../../../core/channels/domain/studio_modular_plug.dart';
import '../../../core/channels/domain/studio_plug_type.dart';
import '../../../core/channels/presentation/studio_channel_patchbay_bar_widget.dart';
import '../../../core/channels/presentation/studio_modular_plug_widget.dart';
import '../../../core/design_system/atoms/studio_theme_switcher.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../media_vault/domain/media_asset_entity.dart';
import '../../media_vault/domain/media_synergy_target.dart';
import '../../media_vault/presentation/media_vault_viewmodel.dart';
import '../../media_vault/presentation/media_vault_workspace_modal.dart';
import '../data/dj_hardware_catalog.dart';
import '../domain/dj_channel_fx_entity.dart';
import '../domain/dj_crossfader_entity.dart';
import '../domain/dj_deck_entity.dart';
import 'dj_console_view_model.dart';
import 'dj_interactive_keymap_visualizer_modal.dart';
import 'dj_keymap_editor_modal.dart';
import 'dj_pro_workstation_panel.dart';
import 'dj_track_loader_modal.dart';
import 'dj_vertical_channel_strip.dart';
import 'dj_visual_mapping_overlay.dart';
import 'vector_jog_wheel.dart';

/// Full-featured Virtual DJ Performance Console Modal with Physical Hardware Skins & Gamepad.
class DjConsoleModal extends StatefulWidget {
  final DjConsoleViewModel viewModel;
  final TunnerThemePalette palette;

  const DjConsoleModal({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  static Future<void> show(BuildContext context, DjConsoleViewModel viewModel, TunnerThemePalette palette) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height,
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) => DjConsoleModal(viewModel: viewModel, palette: palette),
    );
  }

  @override
  State<DjConsoleModal> createState() => _DjConsoleModalState();
}

class _DjConsoleModalState extends State<DjConsoleModal> {
  late final MediaVaultViewModel _mediaVaultViewModel;
  late final StudioPatchbayRoutingService _patchbayService;
  late final StudioModularPlug _deckAPlug;
  late final StudioModularPlug _deckBPlug;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _patchbayService = StudioPatchbayRoutingService();
    _deckAPlug = const StudioModularPlug(
      id: 'plug_dj_deck_a_in',
      label: 'IN DECK A',
      toolId: 'dj_console',
      type: StudioPlugType.audioInput,
      connectedChannelId: 'canal_a',
    );
    _deckBPlug = const StudioModularPlug(
      id: 'plug_dj_deck_b_in',
      label: 'IN DECK B',
      toolId: 'dj_console',
      type: StudioPlugType.audioInput,
      connectedChannelId: 'canal_b',
    );
    _patchbayService.registerPlug(_deckAPlug);
    _patchbayService.registerPlug(_deckBPlug);

    // Escuchas para sincronización de parámetros a Decks
    _patchbayService.registerSinkListener('plug_dj_deck_a_in', (sourceId, channelId, payload) {
      if (sourceId == 'plug_dj_deck_a_in') return;
      final title = payload['title'] as String?;
      final bpm = (payload['bpm'] as num?)?.toDouble();
      final key = payload['key'] as String?;
      if (title != null || bpm != null || key != null) {
        widget.viewModel.loadTrackSimple(
          'A',
          title: title ?? widget.viewModel.deckA.trackTitle,
          bpm: bpm ?? widget.viewModel.deckA.bpm,
          camelotKey: key ?? widget.viewModel.deckA.camelotKey,
        );
      }
      final isPlaying = payload['isPlaying'] as bool?;
      if (isPlaying != null && isPlaying != widget.viewModel.deckA.isPlaying) {
        widget.viewModel.togglePlay('A');
      }
    });

    _patchbayService.registerSinkListener('plug_dj_deck_b_in', (sourceId, channelId, payload) {
      if (sourceId == 'plug_dj_deck_b_in') return;
      final title = payload['title'] as String?;
      final bpm = (payload['bpm'] as num?)?.toDouble();
      final key = payload['key'] as String?;
      if (title != null || bpm != null || key != null) {
        widget.viewModel.loadTrackSimple(
          'B',
          title: title ?? widget.viewModel.deckB.trackTitle,
          bpm: bpm ?? widget.viewModel.deckB.bpm,
          camelotKey: key ?? widget.viewModel.deckB.camelotKey,
        );
      }
      final isPlaying = payload['isPlaying'] as bool?;
      if (isPlaying != null && isPlaying != widget.viewModel.deckB.isPlaying) {
        widget.viewModel.togglePlay('B');
      }
    });

    widget.viewModel.addListener(_syncDecksToChannels);

    _mediaVaultViewModel = MediaVaultViewModel(
      onDispatchToTool: (asset, target) {
        if (target == MediaSynergyTarget.djDeckA ||
            target == MediaSynergyTarget.djDeckB) {
          final deckId = target == MediaSynergyTarget.djDeckA ? 'A' : 'B';
          final samples = (asset.pcmSamples != null && asset.pcmSamples!.isNotEmpty)
              ? Float32List.fromList(asset.pcmSamples!)
              : Float32List(4410);
          widget.viewModel.loadTrackWithBeatTracking(
            deckId,
            title: asset.title,
            artist: asset.kind.displayName,
            audioSamples: samples,
            sampleRate: asset.sampleRate,
          );
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _syncDecksToChannels() {
    final plugA = _patchbayService.plugs['plug_dj_deck_a_in'];
    if (plugA != null && plugA.isConnected) {
      _patchbayService.publishChannelParameters(
        plugA.connectedChannelId!,
        title: widget.viewModel.deckA.trackTitle,
        bpm: widget.viewModel.deckA.effectiveBpm,
        key: widget.viewModel.deckA.effectiveCamelotKey.code,
        isPlaying: widget.viewModel.deckA.isPlaying,
        positionMs: widget.viewModel.deckA.currentPositionMs,
        initiatorPlugId: 'plug_dj_deck_a_in',
      );
    }

    final plugB = _patchbayService.plugs['plug_dj_deck_b_in'];
    if (plugB != null && plugB.isConnected) {
      _patchbayService.publishChannelParameters(
        plugB.connectedChannelId!,
        title: widget.viewModel.deckB.trackTitle,
        bpm: widget.viewModel.deckB.effectiveBpm,
        key: widget.viewModel.deckB.effectiveCamelotKey.code,
        isPlaying: widget.viewModel.deckB.isPlaying,
        positionMs: widget.viewModel.deckB.currentPositionMs,
        initiatorPlugId: 'plug_dj_deck_b_in',
      );
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_syncDecksToChannels);
    _patchbayService.unregisterSinkListener('plug_dj_deck_a_in');
    _patchbayService.unregisterSinkListener('plug_dj_deck_b_in');
    _focusNode.dispose();
    _mediaVaultViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final tokens = StudioThemeScope.of(context);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (vm.handleKeyEvent(event)) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            color: tokens.canvasBackground,
            border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
          ),
          child: Column(
            children: [
              // 1. Studio Header Bar with Skin selector, Theme Switcher, View Toggle, REC & Keymap
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.panelHeaderBackground,
                  border: Border(
                    bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.album, color: tokens.accentPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONSOLA DJ STUDIO',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Stems | Camelot | Hardware | Gamepad | WAV',
                            style: TextStyle(color: tokens.textMuted, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 5,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const StudioThemeSwitcher(),

                    // Skin Selector Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E28),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF383848)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('skin_selector_dropdown'),
                          value: vm.activeSkin.id,
                          dropdownColor: const Color(0xFF1E1E28),
                          style: TextStyle(color: palette.textColor, fontSize: 11),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF), size: 16),
                          items: DjHardwareCatalog.allSkins().map((s) {
                            final shortName = s.name.split('(').first.trim();
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(shortName, style: const TextStyle(fontSize: 11)),
                            );
                          }).toList(),
                          onChanged: (skinId) {
                            if (skinId != null) vm.selectSkin(skinId);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Multimedia Vault & Timeline Studio Button
                    OutlinedButton.icon(
                      key: const Key('open_media_vault_btn'),
                      onPressed: () => MediaVaultWorkspaceModal.show(
                        context,
                        viewModel: _mediaVaultViewModel,
                      ),
                      icon: Icon(
                        Icons.library_music_outlined,
                        size: 16,
                        color: palette.primaryAccent,
                      ),
                      label: Text(
                        'Boveda / I/O',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: palette.textColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF383848)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Pro Workstation Toggle (4-Stems, Camelot, RGB Waveforms, Sampler, Split-Cue)
                    OutlinedButton.icon(
                      key: const Key('toggle_pro_workstation_btn'),
                      onPressed: () => vm.toggleProWorkstation(),
                      icon: Icon(
                        Icons.auto_graph,
                        size: 16,
                        color: vm.isProWorkstationActive ? const Color(0xFFFFD700) : palette.textColor,
                      ),
                      label: Text(
                        vm.isProWorkstationActive ? 'Pro: ON' : 'Pro Studio',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: vm.isProWorkstationActive ? const Color(0xFFFFD700) : palette.textColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: vm.isProWorkstationActive ? const Color(0xFFFFD700) : const Color(0xFF383848),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // View Toggle (Hardware Skin visibility)
                    OutlinedButton.icon(
                      key: const Key('toggle_hardware_view_btn'),
                      onPressed: () => vm.toggleHardwareView(),
                      icon: Icon(
                        vm.isHardwareViewActive ? Icons.videogame_asset : Icons.view_quilt,
                        size: 16,
                        color: vm.isHardwareViewActive ? const Color(0xFF00E5FF) : palette.textColor,
                      ),
                      label: Text(
                        vm.isHardwareViewActive ? 'Hardware: ON' : 'Hardware: OFF',
                        style: TextStyle(
                          fontSize: 11,
                          color: vm.isHardwareViewActive ? const Color(0xFF00E5FF) : palette.textColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: vm.isHardwareViewActive ? const Color(0xFF00E5FF) : const Color(0xFF383848),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Live Mix Recording Master Button
                    ElevatedButton.icon(
                      key: const Key('toggle_live_recording_btn'),
                      onPressed: () {
                        if (vm.recorder.isRecording) {
                          final duration = vm.recorder.durationSeconds;
                          final wavBytes = vm.stopRecording();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Grabacion finalizada: ${duration}s (${wavBytes?.lengthInBytes ?? 0} bytes WAV)'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } else {
                          vm.startRecording();
                        }
                      },
                      icon: Icon(
                        vm.recorder.isRecording ? Icons.stop : Icons.fiber_manual_record,
                        size: 16,
                        color: vm.recorder.isRecording ? Colors.white : Colors.redAccent,
                      ),
                      label: Text(
                        vm.recorder.isRecording ? 'REC ${vm.recorder.durationSeconds}s' : 'REC',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: vm.recorder.isRecording ? Colors.redAccent : const Color(0xFF2A2A38),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('open_keymap_editor_btn'),
                      onPressed: () => DjKeymapEditorModal.show(context, vm, palette),
                      icon: const Icon(Icons.keyboard, size: 16),
                      label: const Text('Mapear Teclado', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.close, color: tokens.textSecondary, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),

              // Barra Troncal y Personalizada de Canales Modulares
              StudioChannelPatchbayBarWidget(routingService: _patchbayService),

              // 2. Main Mixing Workspace
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      if (vm.isProWorkstationActive) ...[
                        DjProWorkstationPanel(
                          viewModel: vm,
                          palette: palette,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (vm.isHardwareViewActive) ...[
                        // Vector Hardware Console Skin with Interactive Mapping Overlay
                        DjVisualMappingOverlay(
                          skin: vm.activeSkin,
                          selectedZone: vm.selectedZoneForMapping,
                          isLearnModeActive: vm.isLearnModeActive,
                          lastCapturedInput: vm.lastCapturedInputToken,
                          jogRotationA: vm.rotationAngleA,
                          jogRotationB: vm.rotationAngleB,
                          keymapProfile: vm.keymapProfile,
                          showKeyBadges: vm.showKeyBadges,
                          onSkinSelected: (id) => vm.selectSkin(id),
                          onZoneSelected: (zone) => vm.selectZoneForMapping(zone),
                          onActionTriggered: (action) => vm.executeAction(action),
                          onToggleLearnMode: () => vm.toggleLearnMode(),
                          onOpenKeymapVisualizer: () => DjInteractiveKeymapVisualizerModal.show(context, vm, palette),
                        ),
                        const SizedBox(height: 12),

                        // Xbox / Playstation Gamepad quick simulator testbar
                        _buildGamepadSimulatorBar(vm, palette),
                        const SizedBox(height: 16),
                      ],

                      // Classic Modular Cards (Deck A - Mixer - Deck B)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 650;
                          if (isNarrow) {
                            return Column(
                              children: [
                                _buildDeckCard(vm.deckA, 'A', palette.primaryAccent, vm.rotationAngleA),
                                const SizedBox(height: 12),
                                _buildMixerCenter(vm),
                                const SizedBox(height: 12),
                                _buildDeckCard(vm.deckB, 'B', palette.secondaryAccent, vm.rotationAngleB),
                              ],
                            );
                          } else {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 4, child: _buildDeckCard(vm.deckA, 'A', palette.primaryAccent, vm.rotationAngleA)),
                                const SizedBox(width: 12),
                                Expanded(flex: 3, child: _buildMixerCenter(vm)),
                                const SizedBox(width: 12),
                                Expanded(flex: 4, child: _buildDeckCard(vm.deckB, 'B', palette.secondaryAccent, vm.rotationAngleB)),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),

                      // 3. Crossfader & Master Section
                      _buildCrossfaderSection(vm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildGamepadSimulatorBar(DjConsoleViewModel vm, TunnerThemePalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports, color: Color(0xFF00E5FF), size: 16),
              const SizedBox(width: 6),
              Text(
                'SIMULADOR DE MANDO (Xbox / PlayStation)',
                style: TextStyle(
                  color: palette.textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                'Toca para probar respuestas del mando',
                style: TextStyle(color: palette.textMutedColor, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGamepadTestChip(vm, 'Xbox_A', 'A (Play A)', Colors.green),
                _buildGamepadTestChip(vm, 'Xbox_X', 'X (Cue A)', Colors.blue),
                _buildGamepadTestChip(vm, 'Xbox_B', 'B (Play B)', Colors.red),
                _buildGamepadTestChip(vm, 'Xbox_Y', 'Y (Cue B)', Colors.amber),
                _buildGamepadTestChip(vm, 'Xbox_LB', 'LB (Sync A)', Colors.cyan),
                _buildGamepadTestChip(vm, 'Xbox_RB', 'RB (Sync B)', Colors.cyan),
                _buildGamepadTestChip(vm, 'Xbox_LT', 'LT (Filter A)', Colors.orange),
                _buildGamepadTestChip(vm, 'Xbox_RT', 'RT (Filter B)', Colors.orange),
                _buildGamepadTestChip(vm, 'Xbox_LS', 'LS (Snap A)', Colors.purple),
                _buildGamepadTestChip(vm, 'Xbox_RS', 'RS (Snap B)', Colors.purple),
                _buildGamepadTestChip(vm, 'Xbox_Select', 'Select (Center)', Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamepadTestChip(DjConsoleViewModel vm, String token, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        key: Key('gamepad_chip_$token'),
        label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF22222A),
        side: BorderSide(color: color.withAlpha(160)),
        labelStyle: TextStyle(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onPressed: () {
          vm.injectGamepadInput(token, isDown: true);
        },
      ),
    );
  }

  Widget _buildDeckCard(DjDeckEntity deck, String deckId, Color accentColor, double rotationAngle) {
    final palette = widget.palette;
    final vm = widget.viewModel;
    final fx = deckId == 'A' ? vm.fxA : vm.fxB;

    return Material(
      color: palette.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: deck.isPlaying ? accentColor.withValues(alpha: 0.5) : palette.staffLinesColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Track Info & BPM
            Row(
              children: [
                StudioModularPlugWidget(
                  plug: deckId == 'A' ? _deckAPlug : _deckBPlug,
                  routingService: _patchbayService,
                  size: 26,
                  showLabel: false,
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor),
                  ),
                  child: Text(
                    'DECK $deckId',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.trackTitle,
                        style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${deck.effectiveBpm.toStringAsFixed(1)} BPM (${deck.pitchPercentage >= 0 ? "+" : ""}${deck.pitchPercentage.toStringAsFixed(1)}%)',
                        style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  key: Key('deck_${deckId}_sync_btn'),
                  onPressed: () => vm.syncBpm(deckId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: deck.isSyncActive ? Colors.black : accentColor,
                    backgroundColor: deck.isSyncActive ? accentColor : Colors.transparent,
                    side: BorderSide(color: accentColor),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(48, 28),
                  ),
                  child: const Text('SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stem & Beat Tracking Ingestion Button
            OutlinedButton.icon(
              key: Key('deck_${deckId}_load_stem_btn'),
              icon: const Icon(Icons.graphic_eq, size: 14),
              label: const Text('Cargar Pista / Stem de Estudio', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              onPressed: () => DjTrackLoaderModal.show(context, deckId: deckId, viewModel: vm),
            ),
            const SizedBox(height: 6),

            // Vector Jog Wheel
            Center(
              child: VectorJogWheel(
                deckLabel: deckId,
                accentColor: accentColor,
                isPlaying: deck.isPlaying,
                rotationAngle: rotationAngle,
                onScratch: (delta) => vm.scratchDeck(deckId, delta),
                onTap: () => vm.togglePlay(deckId),
              ),
            ),
            const SizedBox(height: 6),

            // Pitch Slider Controls (-8% to +8%)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove, size: 16, color: palette.textColor),
                  onPressed: () => vm.adjustPitch(deckId, -0.005),
                ),
                Expanded(
                  child: Slider(
                    value: deck.pitchMultiplier.clamp(0.92, 1.08),
                    min: 0.92,
                    max: 1.08,
                    activeColor: accentColor,
                    inactiveColor: Colors.white10,
                    onChanged: (val) => vm.adjustPitch(deckId, val - deck.pitchMultiplier),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 16, color: palette.textColor),
                  onPressed: () => vm.adjustPitch(deckId, 0.005),
                ),
                TextButton(
                  onPressed: () => vm.resetPitch(deckId),
                  child: Text('0%', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                ),
              ],
            ),

            // Transport Buttons (Cue & Play)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: Key('deck_${deckId}_cue_btn'),
                    onPressed: () => vm.triggerCue(deckId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('CUE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    key: Key('deck_${deckId}_play_btn'),
                    onPressed: () => vm.togglePlay(deckId),
                    icon: Icon(deck.isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(deck.isPlaying ? 'PAUSE' : 'PLAY', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deck.isPlaying ? Colors.green.shade700 : accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 4 Hot Cues
            Text(
              'HOT CUES',
              style: TextStyle(color: palette.textMutedColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(4, (idx) {
                final pos = deck.hotCues[idx];
                final isSet = pos != null;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: idx < 3 ? 4 : 0),
                    child: OutlinedButton(
                      key: Key('deck_${deckId}_hotcue_$idx'),
                      onPressed: () => vm.triggerHotCue(deckId, idx),
                      onLongPress: () => vm.clearHotCue(deckId, idx),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSet ? accentColor.withValues(alpha: 0.3) : Colors.transparent,
                        side: BorderSide(color: isSet ? accentColor : palette.staffLinesColor.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(color: isSet ? accentColor : palette.textMutedColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),

            // Performance FX: Bipolar Filter Sweep
            Text(
              'FILTRO BIPOLAR (LPF <-> FLAT <-> HPF)',
              style: TextStyle(color: palette.textMutedColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            Row(
              children: [
                Text('LPF', style: TextStyle(color: palette.textMutedColor, fontSize: 9)),
                Expanded(
                  child: Slider(
                    key: Key('deck_${deckId}_filter_slider'),
                    value: fx.filterPosition.clamp(-1.0, 1.0),
                    min: -1.0,
                    max: 1.0,
                    activeColor: fx.filterPosition == 0.0 ? Colors.grey : (fx.filterPosition < 0 ? Colors.blueAccent : Colors.redAccent),
                    onChanged: (val) => vm.setChannelFilter(deckId, val),
                  ),
                ),
                Text('HPF', style: TextStyle(color: palette.textMutedColor, fontSize: 9)),
                TextButton(
                  key: Key('deck_${deckId}_filter_reset_btn'),
                  onPressed: () => vm.setChannelFilter(deckId, 0.0),
                  child: Text('Reset', style: TextStyle(color: palette.textMutedColor, fontSize: 9)),
                ),
              ],
            ),

            // Performance FX: Beat-Synced Delay
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DELAY SINCRONIZADO',
                  style: TextStyle(color: palette.textMutedColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
                ActionChip(
                  key: Key('deck_${deckId}_delay_toggle_chip'),
                  label: Text(fx.isDelayActive ? 'ON' : 'OFF', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: fx.isDelayActive ? accentColor : const Color(0xFF22222E),
                  labelStyle: TextStyle(color: fx.isDelayActive ? Colors.black : palette.textMutedColor),
                  onPressed: () => vm.toggleChannelDelay(deckId),
                ),
              ],
            ),
            if (fx.isDelayActive) ...[
              Row(
                children: [
                  Text('División:', style: TextStyle(color: palette.textColor, fontSize: 10)),
                  const SizedBox(width: 8),
                  DropdownButton<DjDelayDivision>(
                    value: fx.delayDivision,
                    dropdownColor: palette.cardBackground,
                    style: TextStyle(color: palette.textColor, fontSize: 10),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: DjDelayDivision.halfBeat, child: Text('1/2 Beat')),
                      DropdownMenuItem(value: DjDelayDivision.quarterBeat, child: Text('1/4 Beat')),
                      DropdownMenuItem(value: DjDelayDivision.eighthBeat, child: Text('1/8 Beat')),
                      DropdownMenuItem(value: DjDelayDivision.sixteenthBeat, child: Text('1/16 Beat')),
                    ],
                    onChanged: (div) {
                      if (div != null) vm.setChannelDelayDivision(deckId, div);
                    },
                  ),
                  const Spacer(),
                  Text('Fdbk: ${(fx.delayFeedback * 100).toInt()}%', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMixerCenter(DjConsoleViewModel vm) {
    final palette = widget.palette;

    return Material(
      color: palette.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'MEZCLADOR DUAL CLUB',
              style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),

            // Tiras de Canales Verticales (CH A y CH B)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DjVerticalChannelStrip(
                  deckId: 'A',
                  deck: vm.deckA,
                  viewModel: vm,
                  accentColor: palette.primaryAccent,
                ),
                const SizedBox(width: 8),
                DjVerticalChannelStrip(
                  deckId: 'B',
                  deck: vm.deckB,
                  viewModel: vm,
                  accentColor: palette.secondaryAccent,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Master Volume
            Row(
              children: [
                Icon(Icons.volume_up, size: 16, color: palette.textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: palette.primaryAccent,
                      inactiveTrackColor: Colors.white12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: vm.masterVolume,
                      min: 0.0,
                      max: 1.5,
                      activeColor: palette.primaryAccent,
                      onChanged: (val) => vm.setMasterVolume(val),
                    ),
                  ),
                ),
                Text(
                  '${(vm.masterVolume * 100).toInt()}%',
                  style: TextStyle(color: palette.textColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossfaderSection(DjConsoleViewModel vm) {
    final palette = widget.palette;
    final xfader = vm.crossfader;

    return Material(
      color: palette.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CROSSFADER',
                  style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                // Curve selector
                DropdownButton<CrossfaderCurve>(
                  value: xfader.curve,
                  dropdownColor: palette.cardBackground,
                  style: TextStyle(color: palette.textColor, fontSize: 11),
                  underline: const SizedBox(),
                  onChanged: (c) {
                    if (c != null) vm.setCrossfaderCurve(c);
                  },
                  items: const [
                    DropdownMenuItem(value: CrossfaderCurve.equalPower, child: Text('Potencia Constante (Suave)')),
                    DropdownMenuItem(value: CrossfaderCurve.linear, child: Text('Lineal')),
                    DropdownMenuItem(value: CrossfaderCurve.fastCut, child: Text('Fast Cut (Scratch)')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Horizontal crossfader slider
            Row(
              children: [
                TextButton(
                  key: const Key('xfader_hard_left_btn'),
                  onPressed: () => vm.setCrossfaderPosition(-1.0),
                  child: Text('DECK A', style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('crossfader_slider'),
                    value: xfader.position.clamp(-1.0, 1.0),
                    min: -1.0,
                    max: 1.0,
                    activeColor: palette.primaryAccent,
                    inactiveColor: Colors.white12,
                    onChanged: (val) => vm.setCrossfaderPosition(val),
                  ),
                ),
                TextButton(
                  key: const Key('xfader_hard_right_btn'),
                  onPressed: () => vm.setCrossfaderPosition(1.0),
                  child: Text('DECK B', style: TextStyle(color: palette.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),

            Center(
              child: OutlinedButton(
                key: const Key('xfader_center_btn'),
                onPressed: () => vm.setCrossfaderPosition(0.0),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  minimumSize: const Size(60, 26),
                ),
                child: Text('CENTRO (0.0)', style: TextStyle(color: palette.textColor, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
