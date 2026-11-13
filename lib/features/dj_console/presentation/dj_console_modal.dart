import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../data/dj_audio_processor.dart';
import '../domain/dj_channel_fx_entity.dart';
import '../domain/dj_crossfader_entity.dart';
import '../domain/dj_deck_entity.dart';
import 'dj_console_view_model.dart';
import 'dj_keymap_editor_modal.dart';
import 'vector_jog_wheel.dart';

/// Full-featured Virtual DJ Performance Console Modal.
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => DjConsoleModal(viewModel: viewModel, palette: palette),
    );
  }

  @override
  State<DjConsoleModal> createState() => _DjConsoleModalState();
}

class _DjConsoleModalState extends State<DjConsoleModal> {
  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: palette.scaffoldBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              // 1. Header Bar with REC button and Keymap editor
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.album, color: palette.primaryAccent, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consola de DJ Virtual',
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Mezcla dual, FX de filtro/delay, beat tracking y grabación máster WAV',
                            style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Live Mix Recording Master Button
                    ElevatedButton.icon(
                      key: const Key('toggle_live_recording_btn'),
                      onPressed: () {
                        if (vm.recorder.isRecording) {
                          final duration = vm.recorder.durationSeconds;
                          final wavBytes = vm.stopRecording();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Grabación finalizada: ${duration}s (${wavBytes?.lengthInBytes ?? 0} bytes WAV)'),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),

              // 2. Main Mixing Workspace: Deck A - Mixer Center - Deck B
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
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
                      const SizedBox(height: 16),

                      // 3. Crossfader & Master Section
                      _buildCrossfaderSection(vm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
              label: const Text('Cargar Stem & Detectar BPM', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              onPressed: () {
                final demoGroove = DjAudioProcessor().generateDemoGroove(
                  bpm: deckId == 'A' ? 124.0 : 128.0,
                  frequencyHz: deckId == 'A' ? 55.0 : 65.0,
                  durationMs: 4000,
                );
                final detectedBpm = vm.loadTrackWithBeatTracking(
                  deckId,
                  title: 'Stem Groove $deckId',
                  artist: 'Algorithmic Tracker',
                  audioSamples: demoGroove,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stem cargado en Deck $deckId - BPM detectado: ${detectedBpm.toStringAsFixed(1)}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

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

            // Channel FX: Bipolar Sweep Filter Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FILTER',
                        style: TextStyle(color: palette.textMutedColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fx.filterPosition < -0.01
                            ? 'LPF ${(fx.cutoffFrequencyHz).round()} Hz'
                            : fx.filterPosition > 0.01
                                ? 'HPF ${(fx.cutoffFrequencyHz).round()} Hz'
                                : 'BYPASS',
                        style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        key: Key('deck_${deckId}_filter_reset_btn'),
                        onTap: () => vm.setChannelFilter(deckId, 0.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text('RESET', style: TextStyle(color: palette.textMutedColor, fontSize: 9)),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      key: Key('deck_${deckId}_filter_slider'),
                      value: fx.filterPosition.clamp(-1.0, 1.0),
                      min: -1.0,
                      max: 1.0,
                      activeColor: accentColor,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => vm.setChannelFilter(deckId, val),
                    ),
                  ),
                ],
              ),
            ),

            // Channel FX: Beat-Synced Delay Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  FilterChip(
                    key: Key('deck_${deckId}_delay_toggle_chip'),
                    label: const Text('DELAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: fx.isDelayActive,
                    selectedColor: accentColor.withValues(alpha: 0.3),
                    checkmarkColor: accentColor,
                    onSelected: (_) => vm.toggleChannelDelay(deckId),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<DjDelayDivision>(
                      value: fx.delayDivision,
                      isDense: true,
                      dropdownColor: palette.cardBackground,
                      style: TextStyle(color: palette.textColor, fontSize: 11),
                      underline: const SizedBox(),
                      items: DjDelayDivision.values.map((div) {
                        return DropdownMenuItem(
                          value: div,
                          child: Text(div.label),
                        );
                      }).toList(),
                      onChanged: (div) {
                        if (div != null) vm.setChannelDelayDivision(deckId, div);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Hot Cues (1..4)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (i) {
                final cueIndex = i + 1;
                final isSet = deck.hotCues.containsKey(cueIndex);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlinedButton(
                      key: Key('deck_${deckId}_cue_$cueIndex'),
                      onPressed: () => vm.triggerHotCue(deckId, cueIndex),
                      onLongPress: () => vm.clearHotCue(deckId, cueIndex),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSet ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
                        side: BorderSide(color: isSet ? accentColor : Colors.white12),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'CUE $cueIndex',
                        style: TextStyle(
                          color: isSet ? accentColor : palette.textMutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),

            // Main Transport Buttons: Cue & Play/Pause
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: Key('deck_${deckId}_cue_main_btn'),
                    onPressed: () => vm.triggerCue(deckId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A38),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('CUE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('deck_${deckId}_play_btn'),
                    onPressed: () => vm.togglePlay(deckId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deck.isPlaying ? const Color(0xFFE53935) : const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(deck.isPlaying ? Icons.pause : Icons.play_arrow, size: 18),
                    label: Text(deck.isPlaying ? 'PAUSE' : 'PLAY', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
              'MEZCLADOR',
              style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),

            // Dual EQ Controls
            Row(
              children: [
                // Deck A EQ
                Expanded(
                  child: Column(
                    children: [
                      Text('HIGH', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                      _buildEqSlider('A', 'high', vm.deckA.gainHigh, vm.deckA.isKillHigh, vm),
                      Text('MID', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                      _buildEqSlider('A', 'mid', vm.deckA.gainMid, vm.deckA.isKillMid, vm),
                      Text('LOW', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                      _buildEqSlider('A', 'low', vm.deckA.gainLow, vm.deckA.isKillLow, vm),
                    ],
                  ),
                ),
                Container(width: 1, height: 160, color: palette.staffLinesColor.withValues(alpha: 0.2)),
                // Deck B EQ
                Expanded(
                  child: Column(
                    children: [
                      Text('HIGH', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                      _buildEqSlider('B', 'high', vm.deckB.gainHigh, vm.deckB.isKillHigh, vm),
                      Text('MID', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                      _buildEqSlider('B', 'mid', vm.deckB.gainMid, vm.deckB.isKillMid, vm),
                      Text('LOW', style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
                      _buildEqSlider('B', 'low', vm.deckB.gainLow, vm.deckB.isKillLow, vm),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqSlider(String deckId, String band, double gain, bool isKilled, DjConsoleViewModel vm) {
    final palette = widget.palette;

    return Row(
      children: [
        IconButton(
          key: Key('kill_${deckId}_$band'),
          icon: Icon(Icons.flash_off, size: 14, color: isKilled ? Colors.redAccent : palette.textMutedColor),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
          tooltip: 'Kill $band',
          onPressed: () => vm.toggleEqKill(deckId, band),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: gain.clamp(0.0, 1.5),
              min: 0.0,
              max: 1.5,
              activeColor: isKilled ? Colors.redAccent : palette.primaryAccent,
              inactiveColor: Colors.white10,
              onChanged: (val) {
                if (band == 'low') vm.setEqGains(deckId, low: val);
                if (band == 'mid') vm.setEqGains(deckId, mid: val);
                if (band == 'high') vm.setEqGains(deckId, high: val);
              },
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(16),
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
