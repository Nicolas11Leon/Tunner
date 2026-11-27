import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../tuner_viewmodel.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/autotune_config_entity.dart';

/// Modal interactivo para configurar el motor de Vocal AutoTune en tiempo real
/// y aplicar corrección tonal en post-producción a tomas multitrack grabadas.
class VocalAutoTuneModal extends StatefulWidget {
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
  State<VocalAutoTuneModal> createState() => _VocalAutoTuneModalState();
}

class _VocalAutoTuneModalState extends State<VocalAutoTuneModal> {
  bool _isAbBypassOriginalActive = false;
  String _activePresetId = 'natural';
  double _savedDryWetMix = 1.0;

  void _toggleAbBypass(TunerViewModel viewModel, AutoTuneConfigEntity config) {
    setState(() {
      if (!_isAbBypassOriginalActive) {
        _savedDryWetMix = config.leadVocalMix > 0.0 ? config.leadVocalMix : 1.0;
        _isAbBypassOriginalActive = true;
        viewModel.updateAutoTuneConfig(config.copyWith(leadVocalMix: 0.0));
      } else {
        _isAbBypassOriginalActive = false;
        viewModel.updateAutoTuneConfig(config.copyWith(leadVocalMix: _savedDryWetMix));
      }
    });
  }

  void _selectPreset(
    TunerViewModel viewModel,
    String presetId,
    AutoTuneConfigEntity nextConfig,
  ) {
    setState(() {
      _activePresetId = presetId;
      _isAbBypassOriginalActive = false;
      if (nextConfig.leadVocalMix > 0.0) {
        _savedDryWetMix = nextConfig.leadVocalMix;
      }
    });
    viewModel.updateAutoTuneConfig(nextConfig);
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

          _buildHeader(context, palette),
          const SizedBox(height: 8),
          Divider(color: palette.staffLinesColor.withValues(alpha: 0.2), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildMasterSwitchCard(viewModel, palette, isEnabled),
                const SizedBox(height: 10),
                _buildAbBypassToggle(viewModel, palette, config),
                const SizedBox(height: 14),
                if (isEnabled) ...[
                  _buildTelemetryCard(palette, evalResult),
                  const SizedBox(height: 14),
                ],
                _buildPresetsSection(viewModel, palette, config),
                const SizedBox(height: 16),
                _buildScaleSelectorCard(viewModel, palette, config),
                const SizedBox(height: 16),
                _buildDspParametersCard(viewModel, palette, config),
                const SizedBox(height: 16),
                _buildPostProductionCard(context, viewModel, palette, config, takes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbBypassToggle(
    TunerViewModel viewModel,
    TunnerThemePalette palette,
    AutoTuneConfigEntity config,
  ) {
    final isOriginal = _isAbBypassOriginalActive;
    final accentColor = isOriginal ? palette.primaryAccent : palette.secondaryAccent;

    return SizedBox(
      width: double.infinity,
      child: ActionChip(
        key: const Key('btn_autotune_ab_bypass_toggle'),
        avatar: Icon(
          isOriginal ? Icons.hearing : Icons.auto_fix_high,
          size: 16,
          color: accentColor,
        ),
        label: Text(
          isOriginal
              ? 'A/B: ESCUCHANDO ORIGINAL (DRY)'
              : 'A/B: ESCUCHANDO AUTOTUNE (WET)',
          style: TextStyle(
            color: accentColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        backgroundColor: accentColor.withValues(alpha: 0.14),
        side: BorderSide(color: accentColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onPressed: () => _toggleAbBypass(viewModel, config),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TunnerThemePalette palette) {
    return Padding(
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
);
  }

  Widget _buildMasterSwitchCard(TunerViewModel viewModel, TunnerThemePalette palette, bool isEnabled) {
    return Container(
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
);
  }

  Widget _buildTelemetryCard(TunnerThemePalette palette, dynamic evalResult) {
    return Container(
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
);
  }

  Widget _buildPresetsSection(TunerViewModel viewModel, TunnerThemePalette palette, AutoTuneConfigEntity config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              _buildPresetChip(
                chipKey: const Key('preset_natural_studio'),
                presetId: 'natural',
                label: 'Estudio Natural',
                icon: Icons.mic,
                palette: palette,
                accentColor: palette.secondaryAccent,
                onTap: () => _selectPreset(
                  viewModel,
                  'natural',
                  AutoTuneConfigEntity.naturalStudio(
                    scaleRoot: config.scaleRoot,
                    scaleType: config.scaleType,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                chipKey: const Key('preset_smooth_pop'),
                presetId: 'pop',
                label: 'Pop Suave',
                icon: Icons.music_note,
                palette: palette,
                accentColor: palette.secondaryAccent,
                onTap: () => _selectPreset(
                  viewModel,
                  'pop',
                  AutoTuneConfigEntity.smoothPop(
                    scaleRoot: config.scaleRoot,
                    scaleType: config.scaleType,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                chipKey: const Key('preset_hard_tune'),
                presetId: 'hard_tune',
                label: 'Hard Tune Urbano',
                icon: Icons.electric_bolt,
                palette: palette,
                accentColor: palette.secondaryAccent,
                onTap: () => _selectPreset(
                  viewModel,
                  'hard_tune',
                  AutoTuneConfigEntity.hardTuneUrban(
                    scaleRoot: config.scaleRoot,
                    scaleType: config.scaleType,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                chipKey: const Key('preset_vocal_doubler'),
                presetId: 'doubler',
                label: 'Vocal Doubler',
                icon: Icons.people_outline,
                palette: palette,
                accentColor: palette.primaryAccent,
                onTap: () => _selectPreset(
                  viewModel,
                  'doubler',
                  AutoTuneConfigEntity.vocalDoubler(
                    scaleRoot: config.scaleRoot,
                    scaleType: config.scaleType,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required Key chipKey,
    required String presetId,
    required String label,
    required IconData icon,
    required TunnerThemePalette palette,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isActive = _activePresetId == presetId;
    return ActionChip(
      key: chipKey,
      label: Text(label),
      avatar: Icon(
        icon,
        size: 14,
        color: isActive ? accentColor : palette.textColor,
      ),
      backgroundColor: isActive
          ? accentColor.withValues(alpha: 0.18)
          : palette.cardBackground,
      labelStyle: TextStyle(
        color: isActive ? accentColor : palette.textColor,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      side: BorderSide(
        color: isActive
            ? accentColor
            : palette.staffLinesColor.withValues(alpha: 0.3),
        width: isActive ? 2.0 : 1.0,
      ),
      onPressed: onTap,
    );
  }

  Widget _buildScaleSelectorCard(TunerViewModel viewModel, TunnerThemePalette palette, AutoTuneConfigEntity config) {
    return Container(
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
);
  }

  Widget _buildDspParametersCard(TunerViewModel viewModel, TunnerThemePalette palette, AutoTuneConfigEntity config) {
    return Container(
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
          if (val > 0.0 && _isAbBypassOriginalActive) {
            setState(() {
              _isAbBypassOriginalActive = false;
              _savedDryWetMix = val;
            });
          } else if (val > 0.0) {
            _savedDryWetMix = val;
          }
          viewModel.updateAutoTuneConfig(config.copyWith(leadVocalMix: val));
        },
      ),
      const SizedBox(height: 4),

      // Switch de Preservación de Formantes
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preservación de Formantes',
                  style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Mantiene las resonancias del tracto vocal natural',
                  style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('formant_preservation_switch'),
            value: config.formantPreservation,
            activeThumbColor: palette.secondaryAccent,
            onChanged: (val) {
              viewModel.updateAutoTuneConfig(config.copyWith(formantPreservation: val));
            },
          ),
        ],
      ),
    ],
  ),
);
  }

  Widget _buildPostProductionCard(BuildContext context, TunerViewModel viewModel, TunnerThemePalette palette, AutoTuneConfigEntity config, List<dynamic> takes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                IconButton(
                  key: Key('play_take_btn_${take.id}'),
                  icon: Icon(
                    viewModel.isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: palette.primaryAccent,
                    size: 24,
                  ),
                  tooltip: viewModel.isPlayingAudio ? 'Pausar Audición' : 'Escuchar Toma',
                  onPressed: () {
                    if (viewModel.isPlayingAudio) {
                      viewModel.stopActiveRecordingPlayback();
                    } else {
                      viewModel.playTakeAudio(take);
                    }
                  },
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  key: Key('autotune_take_btn_${take.id}'),
                  onPressed: () async {
                    final tunedTake = await viewModel.applyAutoTuneToRecordingTake(take.id);
                    if (!context.mounted) return;
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
      ],
    );
  }
}
