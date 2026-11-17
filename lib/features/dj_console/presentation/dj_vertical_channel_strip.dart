import 'package:flutter/material.dart';
import '../../../core/design_system/atoms/studio_rotary_knob.dart';
import '../../../core/design_system/atoms/studio_stereo_vu_meter.dart';
import '../domain/dj_deck_entity.dart';
import 'dj_console_view_model.dart';

/// Tira de canal vertical de mezclador DJ profesional (Estándar DJM / Xone).
/// Integra Gain/Trim, EQs rotatorios de 3 bandas con cortes KILL, medidor estéreo VU,
/// filtro bipolar (LPF/HPF), botón CUE de monitoreo y Fader vertical de volumen.
class DjVerticalChannelStrip extends StatelessWidget {
  final String deckId;
  final DjDeckEntity deck;
  final DjConsoleViewModel viewModel;
  final Color accentColor;

  const DjVerticalChannelStrip({
    super.key,
    required this.deckId,
    required this.deck,
    required this.viewModel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final fx = deckId == 'A' ? viewModel.fxA : viewModel.fxB;
    final isPlaying = deck.isPlaying;
    final isCueActive = deckId == 'A' ? viewModel.cueMonitor.cueDeckA : viewModel.cueMonitor.cueDeckB;

    // Calcular niveles simulados en tiempo real basados en reproducción y ganancia
    final signalMultiplier = isPlaying ? (deck.gainLow * 0.4 + deck.gainMid * 0.4 + deck.gainHigh * 0.2) : 0.0;
    final vuLevelL = (signalMultiplier * 0.75).clamp(0.0, 1.15);
    final vuLevelR = (signalMultiplier * 0.70).clamp(0.0, 1.15);

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPlaying ? accentColor.withValues(alpha: 0.35) : Colors.white12,
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Cabecera del canal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              'CH $deckId',
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),

          // TRIM / GAIN
          StudioRotaryKnob(
            label: 'TRIM',
            value: 1.0,
            min: 0.0,
            max: 1.5,
            defaultValue: 1.0,
            activeColor: Colors.white70,
            size: 38,
            onChanged: (val) {},
            valueFormatter: (_) => '0.0 dB',
          ),
          const SizedBox(height: 8),

          // HIGH EQ + KILL
          _buildBandSection(
            label: 'HIGH',
            gain: deck.gainHigh,
            isKilled: deck.isKillHigh,
            color: const Color(0xFF38BDF8),
            onChanged: (val) => viewModel.setEqGains(deckId, high: val),
            onKill: () => viewModel.toggleEqKill(deckId, 'high'),
          ),
          const SizedBox(height: 8),

          // MID EQ + KILL
          _buildBandSection(
            label: 'MID',
            gain: deck.gainMid,
            isKilled: deck.isKillMid,
            color: const Color(0xFF34D399),
            onChanged: (val) => viewModel.setEqGains(deckId, mid: val),
            onKill: () => viewModel.toggleEqKill(deckId, 'mid'),
          ),
          const SizedBox(height: 8),

          // LOW EQ + KILL
          _buildBandSection(
            label: 'LOW',
            gain: deck.gainLow,
            isKilled: deck.isKillLow,
            color: const Color(0xFFF472B6),
            onChanged: (val) => viewModel.setEqGains(deckId, low: val),
            onKill: () => viewModel.toggleEqKill(deckId, 'low'),
          ),
          const SizedBox(height: 8),

          // COLOR FILTER (LPF / HPF)
          StudioRotaryKnob(
            label: 'FILTER',
            value: fx.filterPosition,
            min: -1.0,
            max: 1.0,
            defaultValue: 0.0,
            size: 42,
            activeColor: fx.filterPosition == 0.0
                ? Colors.white30
                : (fx.filterPosition < 0 ? const Color(0xFF38BDF8) : const Color(0xFFF97316)),
            onChanged: (val) => viewModel.setChannelFilter(deckId, val),
            valueFormatter: (v) => v == 0.0 ? 'FLAT' : (v < 0 ? 'LPF ${(v * -100).toInt()}%' : 'HPF ${(v * 100).toInt()}%'),
          ),
          const SizedBox(height: 8),

          // Botón CUE (Auriculares)
          InkWell(
            onTap: () => viewModel.toggleCueMonitor(deckId),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCueActive ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCueActive ? const Color(0xFFF59E0B) : Colors.white24,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.headphones,
                    size: 12,
                    color: isCueActive ? Colors.black : Colors.white60,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'CUE',
                    style: TextStyle(
                      color: isCueActive ? Colors.black : Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Sección de Fader Vertical de Canal y VU-Meter
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // VU-Meter Estéreo
                StudioStereoVuMeter(
                  levelLeft: vuLevelL,
                  levelRight: vuLevelR,
                  peakLeft: vuLevelL * 1.1,
                  peakRight: vuLevelR * 1.1,
                  height: 110,
                  width: 12,
                ),
                const SizedBox(width: 8),

                // Fader vertical de volumen
                SizedBox(
                  height: 110,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: accentColor,
                        inactiveTrackColor: Colors.white12,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        thumbColor: Colors.white,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: isPlaying ? 1.0 : 0.8,
                        min: 0.0,
                        max: 1.2,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBandSection({
    required String label,
    required double gain,
    required bool isKilled,
    required Color color,
    required ValueChanged<double> onChanged,
    required VoidCallback onKill,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioRotaryKnob(
          label: label,
          value: isKilled ? 0.0 : gain,
          min: 0.0,
          max: 1.5,
          defaultValue: 1.0,
          size: 40,
          activeColor: isKilled ? const Color(0xFFEF4444) : color,
          onChanged: onChanged,
        ),
        const SizedBox(height: 2),
        InkWell(
          onTap: onKill,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: isKilled ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: isKilled ? const Color(0xFFEF4444) : Colors.white24,
                width: 0.8,
              ),
            ),
            child: Text(
              'KILL',
              style: TextStyle(
                color: isKilled ? Colors.white : Colors.white38,
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
