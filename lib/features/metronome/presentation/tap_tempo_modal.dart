import 'package:flutter/material.dart';
import '../../tuner_viewmodel.dart';
import '../domain/tempo_entity.dart';

/// Modal interactivo para la calibración rítmica manual y diagnóstico de regularidad métrica (Tap Tempo).
class TapTempoModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const TapTempoModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TapTempoModal(viewModel: viewModel),
    );
  }

  @override
  State<TapTempoModal> createState() => _TapTempoModalState();
}

class _TapTempoModalState extends State<TapTempoModal> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTap() {
    _pulseController.forward().then((_) => _pulseController.reverse());
    widget.viewModel.recordTapTempo();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final palette = widget.viewModel.currentPalette;
        final tapResult = widget.viewModel.lastTapTempoResult;
        final currentBpm = widget.viewModel.bpm;
        final mark = TempoMark.fromBpm(currentBpm);

        return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: palette.staffLinesColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: palette.staffLinesColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado del modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined, color: palette.primaryAccent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calibración Rítmica Tap Tempo',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Medición y Diagnóstico de Jitter Métrico',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tapResult != null && tapResult.isCalibrated)
                  IconButton(
                    key: const Key('reset_tap_tempo_btn'),
                    icon: Icon(Icons.refresh, color: palette.textMutedColor),
                    tooltip: 'Reiniciar medición',
                    onPressed: () => widget.viewModel.resetTapTempo(),
                  ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Tarjeta Monumental de BPM y Marca Italiana
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.staffLinesColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$currentBpm',
                            key: const Key('tap_tempo_bpm_display'),
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'BPM',
                            style: TextStyle(
                              color: palette.secondaryAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mark.italianName,
                        key: const Key('tap_tempo_mark_text'),
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        mark.description,
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Pad Táctil Pulsante de Alta Precisión
                Center(
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: GestureDetector(
                      key: const Key('tap_tempo_pad'),
                      onTap: _onTap,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              palette.primaryAccent.withValues(alpha: 0.35),
                              palette.cardBackground,
                            ],
                            radius: 0.85,
                          ),
                          border: Border.all(
                            color: palette.primaryAccent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryAccent.withValues(alpha: 0.2),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: palette.primaryAccent,
                              size: 42,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'PULSAR AQUÍ',
                              style: TextStyle(
                                color: palette.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              tapResult != null && tapResult.isCalibrated
                                  ? '${tapResult.tapCount} pulsaciones'
                                  : 'Marca el pulso',
                              style: TextStyle(
                                color: palette.textMutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Tarjeta de Diagnóstico de Estabilidad Métrica (Jitter)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.staffLinesColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Precisión y Regularidad Rítmica',
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: palette.secondaryAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tapResult != null && tapResult.isCalibrated
                                  ? '±${tapResult.jitterMs.toStringAsFixed(1)} ms'
                                  : '-- ms',
                              key: const Key('tap_tempo_jitter_text'),
                              style: TextStyle(
                                color: palette.secondaryAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tapResult != null
                            ? tapResult.stabilityDescription
                            : 'Pulsa rítmicamente al menos 2 veces para calibrar el tempo.',
                        key: const Key('tap_tempo_stability_description'),
                        style: TextStyle(
                          color: tapResult != null && tapResult.isCalibrated
                              ? palette.primaryAccent
                              : palette.textMutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'El jitter cuantifica la fluctuación motriz en milisegundos respecto al pulso medio.',
                        style: TextStyle(
                          color: palette.textMutedColor.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
  }
}
