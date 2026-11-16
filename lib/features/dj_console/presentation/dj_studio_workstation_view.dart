import 'package:flutter/material.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/dj_deck_entity.dart';
import '../domain/dj_harmonic_camelot_engine.dart';
import '../domain/dj_sampler_bank_entity.dart';
import '../domain/dj_smart_automix_engine.dart';
import '../domain/dj_stem_isolation_entity.dart';
import 'dj_console_view_model.dart';
import 'dj_interactive_keymap_visualizer_modal.dart';
import 'dj_parallel_waveform_painter.dart';
import 'dj_track_loader_modal.dart';
import 'dj_vertical_channel_strip.dart';
import 'dj_visual_mapping_overlay.dart';
import 'vector_jog_wheel.dart';

/// Espacio de Trabajo Nativo de la Consola DJ Pro (DjStudioWorkstationView).
/// Vista de pantalla completa para mezcla profesional, compatible con resolución de escritorio.
class DjStudioWorkstationView extends StatefulWidget {
  final DjConsoleViewModel? viewModel;
  final String initialViewMode;

  const DjStudioWorkstationView({
    super.key,
    this.viewModel,
    this.initialViewMode = 'modular',
  });

  @override
  State<DjStudioWorkstationView> createState() => _DjStudioWorkstationViewState();
}

class _DjStudioWorkstationViewState extends State<DjStudioWorkstationView> {
  late final DjConsoleViewModel _viewModel;
  bool _internalVm = false;
  late final FocusNode _focusNode;
  late String _workstationViewMode;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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
          child: Scaffold(
            backgroundColor: tokens.canvasBackground,
            body: SafeArea(
              child: Column(
                children: [
                  // 1. Barra de Control Superior (Master Header & Transporte Global)
                  _buildMasterHeader(context, vm, tokens),

                  // 2. Visor Central Condicional según Modo de Vista
                  Expanded(
                    child: _buildCentralContent(context, vm, tokens),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCentralContent(BuildContext context, DjConsoleViewModel vm, dynamic tokens) {
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
                  'Modelos Fieles • Mapeo QWERTY • 4-Stems DSP',
                  style: TextStyle(color: tokens.textMuted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Selector de Modo de Trabajo (Split / Hardware / Modular)
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
              onPressed: () {
                if (vm.recorder.isRecording) {
                  final duration = vm.recorder.durationSeconds;
                  final bytes = vm.stopRecording();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sesión guardada ($duration seg, ${bytes?.lengthInBytes ?? 0} bytes WAV)'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } else {
                  vm.startRecording();
                }
              },
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

          // Botón Real Cargar Pista / Stem
          OutlinedButton.icon(
            icon: const Icon(Icons.music_note, size: 14),
            label: const Text('CARGAR PISTA / STEM DE ESTUDIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: accentColor,
              side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () => DjTrackLoaderModal.show(context, deckId: deckId, viewModel: _viewModel),
          ),
          const SizedBox(height: 8),

          // Jog Wheel Vectorial con Física de Scratch
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

          // Botones de Transporte Táctiles (CUE y PLAY/PAUSE)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _viewModel.triggerCue(deckId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('CUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _viewModel.togglePlay(deckId),
                  icon: Icon(deck.isPlaying ? Icons.pause : Icons.play_arrow, size: 16),
                  label: Text(deck.isPlaying ? 'PAUSE' : 'PLAY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deck.isPlaying ? const Color(0xFF10B981) : accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Hot Cues
          Text(
            'HOT CUES',
            style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(4, (idx) {
              final isSet = deck.hotCues[idx] != null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx < 3 ? 4 : 0),
                  child: OutlinedButton(
                    onPressed: () => _viewModel.triggerHotCue(deckId, idx),
                    onLongPress: () => _viewModel.clearHotCue(deckId, idx),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSet ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
                      side: BorderSide(color: isSet ? accentColor : Colors.white12),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        color: isSet ? accentColor : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              );
            }),
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
              Text(
                'AISLAMIENTO DE 4-STEMS EN TIEMPO REAL & BANCO DE SAMPLER (8 PADS)',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
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
        ],
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
