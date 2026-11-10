import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../tuner_viewmodel.dart';
import '../domain/autotune_config_entity.dart';

/// Modal interactivo para configurar el motor de Vocal AutoTune en tiempo real
/// y aplicar corrección tonal en post-producción a tomas multitrack grabadas.
class VocalAutoTuneModal extends StatelessWidget {
  const VocalAutoTuneModal({super.key});

  /// Despliega el modal en un bottom sheet responsivo.
  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const VocalAutoTuneModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;
    final config = viewModel.autoTuneConfig;
    final isEnabled = viewModel.isAutoTuneActive;
    final evalResult = viewModel.lastAutoTuneResult;
    final takes = viewModel.multiTrackSession.takes;

    return Container(
      key: const Key('vocal_autotune_modal'),
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Barra de agarre
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: palette.staffLinesColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.secondaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.graphic_eq, color: palette.secondaryAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vocal AutoTune & Corrección Tonal',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Afinación en tiempo real y post-procesamiento multitrack',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('close_autotune_modal_btn'),
                  icon: Icon(Icons.close, color: palette.textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: palette.staffLinesColor.withValues(alpha: 0.2), height: 1),

          // Contenido desplazable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Interruptor Maestro de Tiempo Real
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? palette.secondaryAccent.withValues(alpha: 0.12)
                        : palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEnabled
                          ? palette.secondaryAccent.withValues(alpha: 0.5)
                          : palette.staffLinesColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Corrección en Tiempo Real',
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Procesamiento continuo sobre el micrófono',
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        key: const Key('autotune_master_toggle'),
                        value: isEnabled,
                        activeThumbColor: palette.secondaryAccent,
                        onChanged: (_) => viewModel.toggleAutoTune(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Monitor de Afinación Vocal en Vivo
                if (isEnabled) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: evalResult.isVoiced
                            ? palette.correctPitchColor.withValues(alpha: 0.5)
                            : palette.staffLinesColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONITOR DE AFINACIÓN VOCAL EN VIVO',
                          style: TextStyle(
                            color: palette.secondaryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (evalResult.isVoiced) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nota Cuantizada',
                                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                                  ),
                                  Text(
                                    evalResult.targetNoteName,
                                    style: TextStyle(
                                      color: palette.correctPitchColor,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${evalResult.detectedFrequencyHz.toStringAsFixed(1)} Hz -> ${evalResult.targetFrequencyHz.toStringAsFixed(1)} Hz',
                                    style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Desviación: ${evalResult.centsDeviation >= 0 ? "+" : ""}${evalResult.centsDeviation.toStringAsFixed(1)} cents',
                                    style: TextStyle(
                                      color: evalResult.centsDeviation.abs() <= 10.0
                                          ? palette.correctPitchColor
                                          : palette.secondaryAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Factor TD-PSOLA: ${evalResult.pitchShiftRatio.toStringAsFixed(3)}x',
                                    style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ] else ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Emite sonido vocal para monitorizar la corrección acústica...',
                                style: TextStyle(
                                  color: palette.textMutedColor,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Barra de Presets Rápidos
                Text(
                  'PRESETS CANÓNICOS',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        key: const Key('preset_natural_studio'),
                        label: const Text('Estudio Natural'),
                        avatar: Icon(Icons.mic, size: 14, color: palette.textColor),
                        backgroundColor: palette.cardBackground,
                        labelStyle: TextStyle(color: palette.textColor, fontSize: 11),
                        side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                        onPressed: () {
                          viewModel.updateAutoTuneConfig(
                            AutoTuneConfigEntity.naturalStudio(
                              scaleRoot: config.scaleRoot,
                              scaleType: config.scaleType,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        key: const Key('preset_smooth_pop'),
                        label: const Text('Pop Suave'),
                        avatar: Icon(Icons.music_note, size: 14, color: palette.textColor),
                        backgroundColor: palette.cardBackground,
                        labelStyle: TextStyle(color: palette.textColor, fontSize: 11),
                        side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                        onPressed: () {
                          viewModel.updateAutoTuneConfig(
                            AutoTuneConfigEntity.smoothPop(
                              scaleRoot: config.scaleRoot,
                              scaleType: config.scaleType,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        key: const Key('preset_hard_tune'),
                        label: const Text('Hard Tune Urbano'),
                        avatar: Icon(Icons.electric_bolt, size: 14, color: palette.secondaryAccent),
                        backgroundColor: palette.secondaryAccent.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: palette.secondaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        side: BorderSide(color: palette.secondaryAccent.withValues(alpha: 0.4)),
                        onPressed: () {
                          viewModel.updateAutoTuneConfig(
                            AutoTuneConfigEntity.hardTuneUrban(
                              scaleRoot: config.scaleRoot,
                              scaleType: config.scaleType,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        key: const Key('preset_vocal_doubler'),
                        label: const Text('Vocal Doubler'),
                        avatar: Icon(Icons.people_outline, size: 14, color: palette.primaryAccent),
                        backgroundColor: palette.cardBackground,
                        labelStyle: TextStyle(color: palette.textColor, fontSize: 11),
                        side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                        onPressed: () {
                          viewModel.updateAutoTuneConfig(
                            AutoTuneConfigEntity.vocalDoubler(
                              scaleRoot: config.scaleRoot,
                              scaleType: config.scaleType,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de Tónica y Escala Musical
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESCALA Y TONALIDAD OBJETIVO',
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tónica (Root Note)
                      Text(
                        'Tónica: ${config.rootNoteDisplayName}',
                        style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(12, (index) {
                            final isSelected = config.scaleRoot == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                key: Key('autotune_root_chip_$index'),
                                label: Text(kChromaticNoteNames[index]),
                                selected: isSelected,
                                selectedColor: palette.secondaryAccent,
                                backgroundColor: palette.staffBackground,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : palette.textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                                onSelected: (_) {
                                  viewModel.updateAutoTuneConfig(config.copyWith(scaleRoot: index));
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tipo de Escala
                      Text(
                        'Modo de Escala:',
                        style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: VocalScaleType.values.map((scale) {
                          final isSelected = config.scaleType == scale;
                          return ChoiceChip(
                            key: Key('scale_type_${scale.name}'),
                            label: Text(scale.displayName),
                            selected: isSelected,
                            selectedColor: palette.primaryAccent,
                            backgroundColor: palette.staffBackground,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : palette.textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                            onSelected: (_) {
                              viewModel.updateAutoTuneConfig(config.copyWith(scaleType: scale));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Tira visual de notas permitidas en la escala
                      Text(
                        'Notas Activas en la Escala:',
                        style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(12, (index) {
                          final isAllowed = config.isPitchClassAllowed(index);
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isAllowed
                                    ? palette.secondaryAccent.withValues(alpha: 0.25)
                                    : palette.staffLinesColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isAllowed
                                      ? palette.secondaryAccent
                                      : Colors.transparent,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                kChromaticNoteNamesInternational[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isAllowed ? palette.secondaryAccent : palette.textMutedColor,
                                  fontSize: 9,
                                  fontWeight: isAllowed ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Parámetros de Control Acústico DSP
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PARÁMETROS ACÚSTICOS DSP',
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Velocidad de Retune
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Velocidad de Retune (Inercia)',
                            style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            config.retuneSpeedMs <= 0.0
                                ? '0 ms (Hard Tune)'
                                : '${config.retuneSpeedMs.toStringAsFixed(0)} ms',
                            style: TextStyle(
                              color: config.retuneSpeedMs <= 0.0
                                  ? palette.secondaryAccent
                                  : palette.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        key: const Key('retune_speed_slider'),
                        value: config.retuneSpeedMs,
                        min: 0.0,
                        max: 60.0,
                        divisions: 12,
                        activeColor: palette.secondaryAccent,
                        inactiveColor: palette.staffLinesColor.withValues(alpha: 0.2),
                        onChanged: (val) {
                          viewModel.updateAutoTuneConfig(config.copyWith(retuneSpeedMs: val));
                        },
                      ),
                      const SizedBox(height: 8),

                      // Cantidad de Corrección
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Intensidad de Corrección',
                            style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(config.correctionAmount * 100).toInt()}%',
                            style: TextStyle(color: palette.textColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        key: const Key('correction_amount_slider'),
                        value: config.correctionAmount,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        activeColor: palette.primaryAccent,
                        inactiveColor: palette.staffLinesColor.withValues(alpha: 0.2),
                        onChanged: (val) {
                          viewModel.updateAutoTuneConfig(config.copyWith(correctionAmount: val));
                        },
                      ),
                      const SizedBox(height: 8),

                      // Mezcla Dry/Wet
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mezcla Dry / Wet',
                            style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(config.leadVocalMix * 100).toInt()}% Wet',
                            style: TextStyle(color: palette.textColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        key: const Key('lead_vocal_mix_slider'),
                        value: config.leadVocalMix,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        activeColor: palette.primaryAccent,
                        inactiveColor: palette.staffLinesColor.withValues(alpha: 0.2),
                        onChanged: (val) {
                          viewModel.updateAutoTuneConfig(config.copyWith(leadVocalMix: val));
                        },
                      ),
                      const SizedBox(height: 4),

                      // Switch de Preservación de Formantes
                      SwitchListTile(
                        key: const Key('formant_preservation_switch'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Preservación de Formantes',
                          style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Mantiene las resonancias del tracto vocal natural',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                        ),
                        value: config.formantPreservation,
                        activeThumbColor: palette.secondaryAccent,
                        onChanged: (val) {
                          viewModel.updateAutoTuneConfig(config.copyWith(formantPreservation: val));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sección de Post-Producción: Tomas Multitrack
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.multitrack_audio, color: palette.primaryAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'POST-PRODUCCIÓN MULTITRACK',
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aplica AutoTune a las tomas grabadas en la consola para afinarlas antes de exportar stems o mezclar.',
                        style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      if (takes.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.staffBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'No hay tomas grabadas en la sesión multitrack actual.',
                              style: TextStyle(
                                color: palette.textMutedColor,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        ...takes.map((take) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: palette.staffBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        take.name,
                                        style: TextStyle(
                                          color: palette.textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${take.duration.inSeconds}s • ${take.pitchTrack.length} muestras',
                                        style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  key: Key('autotune_take_btn_${take.id}'),
                                  onPressed: () {
                                    final tunedTake = viewModel.applyAutoTuneToRecordingTake(take.id);
                                    if (tunedTake != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Toma afinada creada: ${tunedTake.name}'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.auto_fix_high, size: 14),
                                  label: const Text('Afinar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.secondaryAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  key: Key('vocal_to_score_btn_${take.id}'),
                                  onPressed: () {
                                    final result = viewModel.convertActiveRecordingToScorePackage(
                                      takeId: take.id,
                                      preferCorrectedPitch: true,
                                    );
                                    Navigator.of(context).pop();
                                    if (result != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Partitura creada desde ${take.name} (${result.totalNotes} notas).'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.queue_music, size: 14),
                                  label: const Text('Pentagrama'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.cardBackground,
                                    foregroundColor: palette.primaryAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.5)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('snap_active_score_to_scale_btn'),
                    onPressed: () {
                      viewModel.snapActiveScoreToScale();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Partitura alineada a la escala ${config.scaleType.displayName}.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text(
                      'Alinear Partitura a ${config.scaleType.displayName} (Melodyne Snap)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryAccent,
                      side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
