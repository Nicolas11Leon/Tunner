import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/dj_deck_entity.dart';
import '../domain/dj_harmonic_camelot_engine.dart';
import '../domain/dj_loop_and_slip_engine.dart';
import '../domain/dj_sampler_bank_entity.dart';
import '../domain/dj_smart_automix_engine.dart';
import '../domain/dj_stem_isolation_entity.dart';
import 'dj_console_view_model.dart';
import 'dj_parallel_waveform_painter.dart';

/// Standalone Pro DJ Workstation Panel providing:
/// 1. Dual Parallel RGB Waveforms + Beatgrid + Phase Meter
/// 2. 4-Stems Real-Time Isolation (Vocal, Drums, Bass, Melody + Acapella/Instrumental)
/// 3. Harmonic Camelot Wheel Indicator & Key-Sync
/// 4. Quantized Auto-Loops (1/4..8), Halve/Double, Slip Mode & Beat Jump
/// 5. 8-Pad Procedural Club Sampler
/// 6. Smart Automix (Bass-Swap) & PC Split-Cue Headphone Monitor
class DjProWorkstationPanel extends StatelessWidget {
  final DjConsoleViewModel viewModel;
  final TunnerThemePalette palette;

  const DjProWorkstationPanel({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final compatibility = vm.harmonicCompatibility;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101016),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF282836)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Parallel RGB Waveforms + Phase Meter
          SizedBox(
            height: 112,
            child: CustomPaint(
              key: const Key('parallel_rgb_waveform_canvas'),
              painter: DjParallelWaveformPainter(
                deckA: vm.deckA,
                deckB: vm.deckB,
                waveformA: vm.waveformA,
                waveformB: vm.waveformB,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Harmonic Compatibility & Master Utility Strip (Automix + Split-Cue)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Camelot Compatibility Badge
              Container(
                key: const Key('camelot_compatibility_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _compatibilityColor(compatibility).withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _compatibilityColor(compatibility)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note, size: 14, color: _compatibilityColor(compatibility)),
                    const SizedBox(width: 4),
                    Text(
                      '${vm.deckA.effectiveCamelotKey.code} vs ${vm.deckB.effectiveCamelotKey.code}: ${compatibility.label}',
                      style: TextStyle(
                        color: _compatibilityColor(compatibility),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Smart Automix (Bass-Swap) Button
              ElevatedButton.icon(
                key: const Key('smart_automix_btn'),
                onPressed: () {
                  if (vm.automix.isActive) {
                    vm.cancelSmartAutomix();
                  } else {
                    final dir = vm.crossfader.position <= 0.0
                        ? AutomixDirection.deckAToDeckB
                        : AutomixDirection.deckBToDeckA;
                    vm.startSmartAutomix(dir);
                  }
                },
                icon: Icon(vm.automix.isActive ? Icons.stop : Icons.auto_awesome, size: 14),
                label: Text(
                  vm.automix.isActive
                      ? 'AUTOMIX ${(vm.automix.progress * 100).toInt()}%'
                      : 'SMART AUTOMIX (BASS-SWAP)',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: vm.automix.isActive ? Colors.amber : const Color(0xFF1F2430),
                  foregroundColor: vm.automix.isActive ? Colors.black : const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 30),
                ),
              ),

              // PC Split-Cue Headphone Monitor Strip
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilterChip(
                    key: const Key('pfl_cue_a_chip'),
                    label: const Text('PFL A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: vm.cueMonitor.cueDeckA,
                    selectedColor: palette.primaryAccent.withAlpha(180),
                    onSelected: (_) => vm.toggleCueMonitor('A'),
                  ),
                  const SizedBox(width: 4),
                  FilterChip(
                    key: const Key('pfl_cue_b_chip'),
                    label: const Text('PFL B', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: vm.cueMonitor.cueDeckB,
                    selectedColor: palette.secondaryAccent.withAlpha(180),
                    onSelected: (_) => vm.toggleCueMonitor('B'),
                  ),
                  const SizedBox(width: 4),
                  FilterChip(
                    key: const Key('split_cue_mono_chip'),
                    label: const Text('SPLIT-CUE (L/R)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: vm.cueMonitor.isSplitCueActive,
                    selectedColor: Colors.amber,
                    onSelected: (_) => vm.toggleSplitCue(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Dual Deck Pro Controls (Stems + Key-Sync + Loops/Slip)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 680) {
                return Column(
                  children: [
                    _buildDeckProControls(vm.deckA, 'A', palette.primaryAccent),
                    const SizedBox(height: 8),
                    _buildDeckProControls(vm.deckB, 'B', palette.secondaryAccent),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDeckProControls(vm.deckA, 'A', palette.primaryAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDeckProControls(vm.deckB, 'B', palette.secondaryAccent)),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // 4. 8-Pad Procedural Club Sampler Bank
          Text(
            'CLUB SAMPLER (8 PADS DE TRANSICION)',
            style: TextStyle(
              color: palette.textMutedColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: DjSamplerPadType.values.map((pad) {
              final padColor = Color(pad.colorHex);
              final isLast = vm.sampler.lastTriggeredPad == pad;
              return ElevatedButton(
                key: Key('sampler_pad_${pad.name}'),
                onPressed: () => vm.triggerSamplerPad(pad),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLast ? padColor : const Color(0xFF1E1E28),
                  foregroundColor: isLast ? Colors.black : padColor,
                  side: BorderSide(color: padColor.withAlpha(170)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(82, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  pad.label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckProControls(DjDeckEntity deck, String deckId, Color accentColor) {
    final vm = viewModel;
    final camelot = deck.effectiveCamelotKey;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Deck + Camelot Key + Key Sync + Key Lock
          Row(
            children: [
              Text(
                'DECK $deckId PRO',
                style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${camelot.code} (${camelot.musicalName})',
                  style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              TextButton(
                key: Key('deck_${deckId}_key_lock_btn'),
                onPressed: () => vm.toggleKeyLock(deckId),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 24),
                  backgroundColor: deck.isKeyLockEnabled ? accentColor.withAlpha(45) : Colors.transparent,
                ),
                child: Text(
                  'KEY LOCK',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: deck.isKeyLockEnabled ? accentColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                key: Key('deck_${deckId}_key_sync_btn'),
                onPressed: () => vm.syncKey(deckId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 24),
                ),
                child: const Text('KEY SYNC', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4-Stems Buttons
          Row(
            children: [
              _buildStemBtn(deck, deckId, DjStemType.vocals, 'VOCAL', const Color(0xFF00E5FF)),
              const SizedBox(width: 4),
              _buildStemBtn(deck, deckId, DjStemType.drums, 'DRUMS', const Color(0xFFFF9100)),
              const SizedBox(width: 4),
              _buildStemBtn(deck, deckId, DjStemType.bass, 'BASS', const Color(0xFFFF1744)),
              const SizedBox(width: 4),
              _buildStemBtn(deck, deckId, DjStemType.melody, 'MELODY', const Color(0xFFD500F9)),
            ],
          ),
          const SizedBox(height: 4),

          // Stem Quick Presets
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('deck_${deckId}_acapella_btn'),
                  onPressed: () => vm.applyStemPreset(deckId, 'acapella'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    minimumSize: const Size(0, 24),
                    side: const BorderSide(color: Color(0xFF383848)),
                  ),
                  child: const Text('Acapella', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: OutlinedButton(
                  key: Key('deck_${deckId}_instrumental_btn'),
                  onPressed: () => vm.applyStemPreset(deckId, 'instrumental'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    minimumSize: const Size(0, 24),
                    side: const BorderSide(color: Color(0xFF383848)),
                  ),
                  child: const Text('Instrumental', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton(
                key: Key('deck_${deckId}_stems_reset_btn'),
                onPressed: () => vm.applyStemPreset(deckId, 'reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 24),
                  side: const BorderSide(color: Color(0xFF383848)),
                ),
                child: const Text('All', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quantized Auto-Loops, Slip Mode & Beat Jump
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                key: Key('deck_${deckId}_loop_halve_btn'),
                onPressed: () => vm.halveLoop(deckId),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 26),
                ),
                child: const Text('1/2x', style: TextStyle(fontSize: 9.5, color: Colors.white)),
              ),
              ElevatedButton(
                key: Key('deck_${deckId}_loop_toggle_btn'),
                onPressed: () => vm.toggleLoop(deckId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deck.isLoopActive ? Colors.amber : const Color(0xFF282834),
                  foregroundColor: deck.isLoopActive ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 26),
                ),
                child: Text(
                  'LOOP ${DjLoopAndSlipEngine.formatBeatLabel(deck.loopBeats)}',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton(
                key: Key('deck_${deckId}_loop_double_btn'),
                onPressed: () => vm.doubleLoop(deckId),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 26),
                ),
                child: const Text('2x', style: TextStyle(fontSize: 9.5, color: Colors.white)),
              ),
              ElevatedButton(
                key: Key('deck_${deckId}_slip_btn'),
                onPressed: () => vm.toggleSlipMode(deckId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deck.isSlipModeActive ? const Color(0xFFFF9100) : const Color(0xFF282834),
                  foregroundColor: deck.isSlipModeActive ? Colors.black : Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 26),
                ),
                child: const Text('SLIP', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                key: Key('deck_${deckId}_jump_back_btn'),
                icon: const Icon(Icons.fast_rewind, size: 15, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Beat Jump -4',
                onPressed: () => vm.beatJump(deckId, -4.0),
              ),
              IconButton(
                key: Key('deck_${deckId}_jump_fwd_btn'),
                icon: const Icon(Icons.fast_forward, size: 15, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Beat Jump +4',
                onPressed: () => vm.beatJump(deckId, 4.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStemBtn(
    DjDeckEntity deck,
    String deckId,
    DjStemType type,
    String label,
    Color stemColor,
  ) {
    final isMuted = deck.stems.isMuted(type);
    return Expanded(
      child: ElevatedButton(
        key: Key('deck_${deckId}_stem_${type.name}_btn'),
        onPressed: () => viewModel.toggleStem(deckId, type),
        style: ElevatedButton.styleFrom(
          backgroundColor: isMuted ? const Color(0xFF1E1E26) : stemColor.withAlpha(210),
          foregroundColor: isMuted ? Colors.white38 : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(color: isMuted ? const Color(0xFF383848) : stemColor),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Color _compatibilityColor(CamelotCompatibility compat) {
    switch (compat) {
      case CamelotCompatibility.perfectUnison:
      case CamelotCompatibility.relativeSwitch:
        return const Color(0xFF00E676);
      case CamelotCompatibility.harmonicStep:
      case CamelotCompatibility.energyBoost:
        return const Color(0xFF00E5FF);
      case CamelotCompatibility.harmonicClash:
        return const Color(0xFFFF5252);
    }
  }
}
