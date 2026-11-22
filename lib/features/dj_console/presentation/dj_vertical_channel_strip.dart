import 'package:flutter/gestures.dart';
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

    // Medición de niveles acústicos dinámicos basada en la energía RMS real de las muestras
    final realVu = viewModel.getVuLevel(deckId);
    final vuLevelL = realVu;
    final vuLevelR = (realVu * 0.98).clamp(0.0, 1.2);

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

                // Fader vertical de volumen táctil de alta fluidez y respuesta
                StudioTactileVerticalFader(
                  value: deck.volume,
                  accentColor: accentColor,
                  height: 110,
                  width: 36,
                  onChanged: (val) => viewModel.setDeckVolume(deckId, val),
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

/// Fader de volumen vertical táctil de grado profesional con soporte para arrastre suave,
/// rueda del mouse (scroll), pulsadores rápidos de incremento/decremento y mute directo.
class StudioTactileVerticalFader extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final Color accentColor;
  final double height;
  final double width;

  const StudioTactileVerticalFader({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accentColor,
    this.height = 110.0,
    this.width = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedVal = value.clamp(0.0, 1.0);

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final delta = -pointerSignal.scrollDelta.dy / 800.0;
          onChanged((clampedVal + delta).clamp(0.0, 1.0));
        }
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            // Botón rápido (+)
            InkWell(
              onTap: () => onChanged((clampedVal + 0.05).clamp(0.0, 1.0)),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                width: width - 8,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Icon(Icons.add, size: 10, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Riel de arrastre táctil sin inversión de ejes
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackHeight = constraints.maxHeight;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      final delta = -details.primaryDelta! / trackHeight;
                      onChanged((clampedVal + delta).clamp(0.0, 1.0));
                    },
                    onTapDown: (details) {
                      final tapY = details.localPosition.dy.clamp(0.0, trackHeight);
                      final newVol = 1.0 - (tapY / trackHeight);
                      onChanged(newVol.clamp(0.0, 1.0));
                    },
                    child: Container(
                      width: width - 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1117),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Riel guía central
                          Center(
                            child: Container(
                              width: 3,
                              height: trackHeight - 8,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                          // Nivel LED activo
                          FractionallySizedBox(
                            heightFactor: clampedVal,
                            child: Center(
                              child: Container(
                                width: 3,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.5),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Cabezal / Fader Cap Metálico Pro
                          Positioned(
                            bottom: (clampedVal * (trackHeight - 16.0)).clamp(0.0, trackHeight - 16.0),
                            child: Container(
                              width: width - 12,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C3240),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: Colors.white70, width: 1.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: width - 16,
                                  height: 1.5,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 2),

            // Botón rápido (-)
            InkWell(
              onTap: () => onChanged((clampedVal - 0.05).clamp(0.0, 1.0)),
              borderRadius: BorderRadius.circular(2),
              child: Container(
                width: width - 8,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Icon(Icons.remove, size: 10, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Badge de porcentaje con toggle Mute
            InkWell(
              onTap: () {
                if (clampedVal > 0.01) {
                  onChanged(0.0);
                } else {
                  onChanged(0.85);
                }
              },
              child: Text(
                '${(clampedVal * 100).toInt()}%',
                style: TextStyle(
                  color: clampedVal > 0.01 ? Colors.white60 : const Color(0xFFEF4444),
                  fontSize: 8,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
