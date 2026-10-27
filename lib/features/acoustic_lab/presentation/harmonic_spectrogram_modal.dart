import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../tuner_viewmodel.dart';
import '../domain/harmonic_series_analyzer.dart';

/// Modal interactivo que renderiza el espectrograma de armónicos, centroide y calidad timbral en tiempo real.
class HarmonicSpectrogramModal extends StatelessWidget {
  const HarmonicSpectrogramModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HarmonicSpectrogramModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);

    final analysis = analyzer.analyze(
      fundamentalHz: vm.frequency > 20.0 ? vm.frequency : 440.0,
    );

    final hasSignal = vm.frequency > 20.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Barra de agarre superior
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: palette.textMutedColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "LABORATORIO DE TIMBRE Y ARMÓNICOS",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSignal ? "${vm.noteName} (${vm.frequency.toStringAsFixed(1)} Hz)" : "Esperando señal acústica...",
                      style: TextStyle(
                        color: hasSignal ? palette.primaryAccent : palette.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Cuerpo del espectrograma y métricas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Espectrograma de 8 armónicos
                  Container(
                    height: 190,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.scaffoldBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: analysis.harmonics.map((h) {
                        final heightFactor = hasSignal ? h.relativeAmplitude.clamp(0.06, 1.0) : 0.08;
                        final isFund = h.harmonicNumber == 1;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Nivel en decibelios
                                Text(
                                  "${h.dbLevel.toStringAsFixed(0)}dB",
                                  style: TextStyle(
                                    color: palette.textMutedColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Barra vectorial
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: heightFactor,
                                      widthFactor: 0.85,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: isFund
                                                ? [palette.primaryAccent, palette.primaryAccent.withValues(alpha: 0.7)]
                                                : [palette.secondaryAccent, palette.secondaryAccent.withValues(alpha: 0.6)],
                                          ),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Número de armónico
                                Text(
                                  "H${h.harmonicNumber}",
                                  style: TextStyle(
                                    color: isFund ? palette.primaryAccent : palette.textColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${h.frequencyHz.round()}Hz",
                                  style: TextStyle(
                                    color: palette.textMutedColor,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tarjetas de Métricas Psicoacústicas
                  Row(
                    children: [
                      // Centroide Espectral (Brillo)
                      Expanded(
                        child: _metricCard(
                          title: "CENTROIDE ESPECTRAL",
                          value: "${analysis.spectralCentroidHz.round()} Hz",
                          subtitle: "Centro de masa de brillo",
                          palette: palette,
                          icon: Icons.wb_sunny_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // THD (Tasa de Distorsión Armónica)
                      Expanded(
                        child: _metricCard(
                          title: "ENERGÍA DE SOBRETONOS",
                          value: "${analysis.totalHarmonicDistortionPercent.toStringAsFixed(1)}%",
                          subtitle: "Tasa THD armónica",
                          palette: palette,
                          icon: Icons.bubble_chart_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Diagnóstico de Cualidad Timbral
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: palette.scaffoldBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.graphic_eq, color: palette.primaryAccent, size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CUALIDAD DEL TIMBRE",
                                style: TextStyle(
                                  color: palette.textMutedColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                analysis.timbreClassification,
                                style: TextStyle(
                                  color: palette.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required dynamic palette,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 14, color: palette.secondaryAccent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: palette.textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textMutedColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
