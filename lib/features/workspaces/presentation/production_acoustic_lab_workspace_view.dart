import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import '../../tuner/presentation/concert_pitch_selector_modal.dart';
import '../../tuner/presentation/temperament_selector_modal.dart';
import '../../tuner/domain/temperament_engine.dart';
import '../../acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../practice_recorder/presentation/spectral_comparator_modal.dart';
import '../../vocal_autotune/presentation/vocal_autotune_modal.dart';
import '../../vocal_autotune/domain/autotune_config_entity.dart';

/// Vista especializada para el Modo 3: Laboratorio Acústico & Producción de Audio.
/// Enfocada en ingenieros de sonido, acústica física, calibración microtonal,
/// temperamentos históricos, espectrogramas FFT y análisis armónico polifónico.
class ProductionAcousticLabWorkspaceView extends StatelessWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;
  final VoidCallback onOpenMixerModal;

  const ProductionAcousticLabWorkspaceView({
    super.key,
    required this.viewModel,
    required this.palette,
    required this.onOpenMixerModal,
  });

  @override
  Widget build(BuildContext context) {
    final chord = viewModel.recognizedChord;
    final isChordActive = viewModel.isChordRecognitionActive;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta de Calibración Microtonal y Acústica
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: palette.secondaryAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "CALIBRACIÓN ACÚSTICA DE CÁMARA",
                      style: TextStyle(
                        color: palette.secondaryAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Calibración de A4
                    Expanded(
                      child: InkWell(
                        onTap: () => ConcertPitchSelectorModal.show(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.staffBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (viewModel.referencePitch - 440.0).abs() > 0.1
                                  ? palette.secondaryAccent
                                  : palette.staffLinesColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Frecuencia de Cámara A4",
                                style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${viewModel.referencePitch.toStringAsFixed(1)} Hz",
                                style: TextStyle(
                                  color: palette.textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Temperamento Histórico
                    Expanded(
                      child: InkWell(
                        key: const Key('pro_temperament_selector_chip'),
                        onTap: () => TemperamentSelectorModal.show(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.staffBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: viewModel.selectedTemperament.id != 'equal'
                                  ? palette.primaryAccent
                                  : palette.staffLinesColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Temperamento Histórico",
                                style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                viewModel.selectedTemperament.id == 'equal'
                                    ? '12-EDO Igual'
                                    : '${viewModel.selectedTemperament.name.split(' ').first} (${TemperamentEngine.chromaticNoteNames[viewModel.temperamentRootKey]})',
                                style: TextStyle(
                                  color: palette.primaryAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tarjeta de Espectrograma FFT en Cascada
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.waterfall_chart, color: palette.primaryAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Espectrograma Armónico en Cascada",
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Análisis FFT de armónicos, formantes y timbre en tiempo real",
                        style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  key: const Key('open_spectrogram_chip'),
                  onPressed: () => HarmonicSpectrogramModal.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Abrir", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tarjeta del Analizador de Acordes Polifónico
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hub_outlined, color: palette.secondaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "ANALIZADOR POLIFÓNICO DE ACORDES",
                          style: TextStyle(
                            color: palette.secondaryAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: isChordActive,
                      activeTrackColor: palette.secondaryAccent,
                      onChanged: (_) => viewModel.toggleChordRecognition(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: palette.staffBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isChordActive && chord.isRecognized
                                ? chord.symbol
                                : (isChordActive ? "Escuchando armonía..." : "Inactivo"),
                            style: TextStyle(
                              color: isChordActive && chord.isRecognized
                                  ? palette.secondaryAccent
                                  : palette.textMutedColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (isChordActive && chord.isRecognized)
                            Text(
                              "${chord.displayName} • Confianza: ${(chord.confidence * 100).toStringAsFixed(0)}%",
                              style: TextStyle(color: palette.textColor, fontSize: 11),
                            ),
                        ],
                      ),
                      IconButton(
                        key: const Key('pro_chord_modal_btn'),
                        icon: Icon(Icons.open_in_new, color: palette.secondaryAccent),
                        tooltip: "Consola de Cromas",
                        onPressed: () => ChordAnalyzerModal.show(context, viewModel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tarjetas de Comparador Espectral y Mezclador de Stems
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('lab_spectral_comparator_chip'),
                  onTap: () => SpectralComparatorModal.show(context, viewModel),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.compare_arrows_rounded, color: palette.primaryAccent, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          "Comparador Espectral",
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tomas A/B",
                          style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onOpenMixerModal,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.equalizer, color: palette.secondaryAccent, size: 26),
                        const SizedBox(height: 8),
                        Text(
                          "Mezclador Multipista",
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Stems de Audio",
                          style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tarjeta de Vocal AutoTune & Corrección Tonal
          InkWell(
            key: const Key('lab_vocal_autotune_card'),
            onTap: () => VocalAutoTuneModal.show(context, viewModel),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: viewModel.isAutoTuneActive
                    ? palette.secondaryAccent.withValues(alpha: 0.12)
                    : palette.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: viewModel.isAutoTuneActive
                      ? palette.secondaryAccent.withValues(alpha: 0.5)
                      : palette.staffLinesColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.secondaryAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.graphic_eq, color: palette.secondaryAccent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "VOCAL AUTOTUNE & DSP",
                              style: TextStyle(
                                color: palette.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: viewModel.isAutoTuneActive
                                    ? palette.secondaryAccent
                                    : palette.staffLinesColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                viewModel.isAutoTuneActive ? "ACTIVO" : "OFF",
                                style: TextStyle(
                                  color: viewModel.isAutoTuneActive ? Colors.black : palette.textMutedColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          viewModel.isAutoTuneActive
                              ? "${viewModel.autoTuneConfig.rootNoteDisplayName} • ${viewModel.autoTuneConfig.scaleType.displayName} • ${viewModel.autoTuneConfig.retuneSpeedMs.toStringAsFixed(0)}ms"
                              : "Corrección en vivo sobre micrófono y afinación de tomas multitrack",
                          style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: palette.textMutedColor, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
