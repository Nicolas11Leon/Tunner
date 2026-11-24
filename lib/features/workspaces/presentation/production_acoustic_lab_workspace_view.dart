import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../../tuner/presentation/concert_pitch_selector_modal.dart';
import '../../tuner/presentation/strobe_tuner_widget.dart';
import '../../tuner/presentation/temperament_selector_modal.dart';
import '../../tuner/presentation/tuner_acoustic_telemetry.dart';
import '../../tuner/domain/temperament_engine.dart';
import '../../acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../practice_recorder/presentation/spectral_comparator_modal.dart';
import '../../vocal_autotune/presentation/vocal_autotune_modal.dart';
import '../../vocal_autotune/domain/autotune_config_entity.dart';

/// Vista especializada para el Modo 3: Laboratorio Acústico & Producción de Audio.
/// Enfocada en ingenieros de sonido, acústica física, calibración microtonal,
/// temperamentos históricos, espectrogramas FFT y análisis armónico polifónico,
/// manteniendo siempre visible el Afinador Estroboscópico en vivo.
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
    final tokens = StudioThemeScope.of(context);
    final chord = viewModel.recognizedChord;
    final isChordActive = viewModel.isChordRecognitionActive;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Afinador Estroboscópico Permanente en Vivo (60 Hz)
          ValueListenableBuilder<TunerAcousticTelemetry>(
            valueListenable: viewModel.telemetryListenable,
            builder: (context, telemetry, _) {
              final effectiveFreq = telemetry.frequency > 0
                  ? telemetry.frequency
                  : viewModel.frequency;
              final rawNote = telemetry.noteName.isNotEmpty &&
                      telemetry.noteName != '--'
                  ? telemetry.noteName
                  : viewModel.noteName;
              final displayNote = viewModel.hasTransposition
                  ? (viewModel.writtenNoteName.isEmpty
                      ? "--"
                      : viewModel.writtenNoteName)
                  : (rawNote.isEmpty ? "--" : rawNote);
              final cents = telemetry.frequency > 0
                  ? telemetry.cents
                  : viewModel.cents;
              final isListening =
                  telemetry.isRecording || viewModel.isRecording;

              return Container(
                margin: const EdgeInsets.only(bottom: 14.0),
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: tokens.panelBackground,
                  borderRadius:
                      BorderRadius.circular(tokens.borderRadiusLarge),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayNote,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  effectiveFreq > 0
                                      ? "${effectiveFreq.toStringAsFixed(1)} Hz"
                                      : "-- Hz",
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  effectiveFreq > 0
                                      ? "${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents"
                                      : "ESPERANDO AUDIO",
                                  style: TextStyle(
                                    color: tokens.accentPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              key: const Key('pro_lab_mic_toggle_btn'),
                              onPressed: viewModel.toggleRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isListening
                                    ? tokens.accentDanger
                                    : tokens.accentPrimary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              icon: Icon(
                                isListening ? Icons.mic_off : Icons.mic,
                                size: 15,
                              ),
                              label: Text(
                                isListening
                                    ? "Pausar Escucha"
                                    : "Activar Afinador",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  viewModel.playReferenceTone("La4"),
                              icon: const Icon(
                                Icons.volume_up_outlined,
                                size: 15,
                              ),
                              label: const Text(
                                "Tono La4",
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StrobeTunerWidget(
                      cents: cents,
                      frequency: effectiveFreq,
                      noteName: displayNote,
                      soundingNoteName:
                          viewModel.hasTransposition ? rawNote : null,
                      isRecording: isListening,
                      onPlayReferenceTone: () =>
                          viewModel.playReferenceTone("La4"),
                      palette: palette,
                      centsTolerance: viewModel.centsTolerance,
                    ),
                  ],
                ),
              );
            },
          ),

          // Tarjeta de Calibración Microtonal y Acústica
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StudioIcon(
                      StudioIconId.moduleTuner,
                      color: tokens.accentPrimary,
                      size: 18,
                      tintCustomAsset: true,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "CALIBRACIÓN ACÚSTICA DE CÁMARA",
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
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
                        borderRadius: BorderRadius.circular(tokens.radiusMedium),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.inputSurface,
                            borderRadius: BorderRadius.circular(tokens.radiusMedium),
                            border: Border.all(
                              color: (viewModel.referencePitch - 440.0).abs() > 0.1
                                  ? tokens.borderFocus
                                  : tokens.borderHairline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Frecuencia de Cámara A4",
                                style: TextStyle(color: tokens.textMuted, fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${viewModel.referencePitch.toStringAsFixed(1)} Hz",
                                style: TextStyle(
                                  color: tokens.textPrimary,
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
                        borderRadius: BorderRadius.circular(tokens.radiusMedium),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.inputSurface,
                            borderRadius: BorderRadius.circular(tokens.radiusMedium),
                            border: Border.all(
                              color: viewModel.selectedTemperament.id != 'equal'
                                  ? tokens.borderFocus
                                  : tokens.borderHairline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Temperamento Histórico",
                                style: TextStyle(color: tokens.textMuted, fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                viewModel.selectedTemperament.id == 'equal'
                                    ? '12-EDO Igual'
                                    : '${viewModel.selectedTemperament.name.split(' ').first} (${TemperamentEngine.chromaticNoteNames[viewModel.temperamentRootKey]})',
                                style: TextStyle(
                                  color: tokens.accentPrimary,
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
          if (viewModel.workspaceConfiguration.showAcousticSpectrogram) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: tokens.panelBackground,
                borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: StudioIcon(
                      StudioIconId.moduleSpectrogram,
                      color: tokens.accentPrimary,
                      size: 24,
                      tintCustomAsset: true,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Espectrograma Armónico en Cascada",
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Análisis FFT de armónicos, formantes y timbre en tiempo real",
                          style: TextStyle(color: tokens.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const Key('open_spectrogram_chip'),
                    onPressed: () => HarmonicSpectrogramModal.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accentPrimary,
                      foregroundColor: tokens.textOnAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                    ),
                    child: Text(
                      "Abrir",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tokens.textOnAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Tarjeta del Analizador de Acordes Polifónico
          if (viewModel.workspaceConfiguration.showChordAnalyzer) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: tokens.panelBackground,
                borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          StudioIcon(
                            StudioIconId.moduleChordAnalyzer,
                            color: tokens.accentSecondary,
                            size: 18,
                            tintCustomAsset: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "ANALIZADOR POLIFÓNICO DE ACORDES",
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: isChordActive,
                        activeTrackColor: tokens.accentPrimary,
                        onChanged: (_) => viewModel.toggleChordRecognition(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: tokens.inputSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                      border: Border.all(color: tokens.borderSubtle),
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
                                    ? tokens.accentPrimary
                                    : tokens.textMuted,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (isChordActive && chord.isRecognized)
                              Text(
                                "${chord.displayName} • Confianza: ${(chord.confidence * 100).toStringAsFixed(0)}%",
                                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
                              ),
                          ],
                        ),
                        IconButton(
                          key: const Key('pro_chord_modal_btn'),
                          icon: Icon(Icons.open_in_new, color: tokens.accentPrimary),
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
          ],

          // Tarjetas de Comparador Espectral y Mezclador de Stems
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('lab_spectral_comparator_chip'),
                  onTap: () => SpectralComparatorModal.show(context, viewModel),
                  borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.panelBackground,
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Column(
                      children: [
                        StudioIcon(
                          StudioIconId.moduleSpectrogram,
                          color: tokens.accentPrimary,
                          size: 24,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Comparador Espectral",
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tomas A/B",
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
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
                  borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.panelBackground,
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Column(
                      children: [
                        StudioIcon(
                          StudioIconId.moduleRack,
                          color: tokens.accentSecondary,
                          size: 24,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Mezclador Multipista",
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Stems de Audio",
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
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
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: viewModel.isAutoTuneActive
                    ? tokens.elevatedSurface
                    : tokens.panelBackground,
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                border: Border.all(
                  color: viewModel.isAutoTuneActive
                      ? tokens.borderFocus
                      : tokens.borderHairline,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: StudioIcon(
                      StudioIconId.moduleAutotune,
                      color: tokens.accentPrimary,
                      size: 22,
                      tintCustomAsset: true,
                    ),
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
                                color: tokens.textPrimary,
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
                                    ? tokens.accentSuccess
                                    : tokens.inputSurface,
                                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                                border: Border.all(color: tokens.borderHairline),
                              ),
                              child: Text(
                                viewModel.isAutoTuneActive ? "ACTIVO" : "OFF",
                                style: TextStyle(
                                  color: viewModel.isAutoTuneActive
                                      ? tokens.textOnAccent
                                      : tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
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
                          style: TextStyle(color: tokens.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.textMuted, size: 20),
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
