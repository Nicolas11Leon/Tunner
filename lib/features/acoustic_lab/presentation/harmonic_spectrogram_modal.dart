import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/studio_design_system.dart';
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
    final tokens = StudioThemeScope.of(context);
    const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);

    final hasSignal = vm.frequency > 20.0;
    final activeSampleRate =
        vm.audioDeviceMatrixService?.matrix.sampleRate.toDouble() ?? 44100.0;
    final analysis = hasSignal
        ? analyzer.analyze(
            fundamentalHz: vm.frequency,
            samples: vm.latestAudioSamples,
            sampleRate: activeSampleRate,
          )
        : TimbreAnalysisResult.empty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.borderHairline),
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
                color: tokens.borderHairline,
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
                Row(
                  children: [
                    StudioIcon(
                      StudioIconId.moduleSpectrogram,
                      color: tokens.accentPrimary,
                      size: 20,
                      tintCustomAsset: true,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "LABORATORIO DE TIMBRE Y ARMÓNICOS",
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasSignal ? "${vm.noteName} (${vm.frequency.toStringAsFixed(1)} Hz)" : "Esperando señal acústica...",
                          style: TextStyle(
                            color: hasSignal ? tokens.accentPrimary : tokens.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.uiCloseConfirm,
                    size: 18,
                    color: tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: tokens.borderSubtle),

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
                      color: tokens.canvasBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: () {
                        final bars = analysis.harmonics.isNotEmpty
                            ? analysis.harmonics
                            : List.generate(
                                8,
                                (i) => HarmonicBarEntity(
                                  harmonicNumber: i + 1,
                                  frequencyHz: hasSignal ? vm.frequency * (i + 1) : 0.0,
                                  relativeAmplitude: 0.0,
                                  dbLevel: -60.0,
                                  intervalLabel: HarmonicBarEntity.getLabelForHarmonic(i + 1),
                                ),
                              );
                        return bars.map((h) {
                          final heightFactor = hasSignal && h.relativeAmplitude > 0.0
                              ? h.relativeAmplitude.clamp(0.06, 1.0)
                              : 0.06;
                          final isFund = h.harmonicNumber == 1;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Nivel en decibelios
                                  Text(
                                    hasSignal && h.relativeAmplitude > 0.0
                                        ? "${h.dbLevel.toStringAsFixed(0)}dB"
                                        : "--",
                                    style: TextStyle(
                                      color: tokens.textMuted,
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
                                              colors: hasSignal && h.relativeAmplitude > 0.0
                                                  ? (isFund
                                                      ? [tokens.accentPrimary, tokens.accentPrimary.withValues(alpha: 0.7)]
                                                      : [tokens.accentSecondary, tokens.accentSecondary.withValues(alpha: 0.6)])
                                                  : [
                                                      tokens.borderHairline,
                                                      tokens.borderSubtle,
                                                    ],
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
                                      color: hasSignal && isFund ? tokens.accentPrimary : tokens.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    h.frequencyHz > 0 ? "${h.frequencyHz.round()}Hz" : "--",
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList();
                      }(),
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
                          tokens: tokens,
                          iconId: StudioIconId.moduleSpectrogram,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // THD (Tasa de Distorsión Armónica)
                      Expanded(
                        child: _metricCard(
                          title: "ENERGÍA DE SOBRETONOS",
                          value: "${analysis.totalHarmonicDistortionPercent.toStringAsFixed(1)}%",
                          subtitle: "Tasa THD armónica",
                          tokens: tokens,
                          iconId: StudioIconId.moduleDrone,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Diagnóstico de Cualidad Timbral
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: tokens.canvasBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Row(
                      children: [
                        StudioIcon(
                          StudioIconId.moduleSpectrogram,
                          color: tokens.accentPrimary,
                          size: 22,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CUALIDAD DEL TIMBRE",
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                analysis.timbreClassification,
                                style: TextStyle(
                                  color: tokens.textPrimary,
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
    required StudioDesignTokens tokens,
    required StudioIconId iconId,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.canvasBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StudioIcon(
                iconId,
                size: 14,
                color: tokens.accentSecondary,
                tintCustomAsset: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
