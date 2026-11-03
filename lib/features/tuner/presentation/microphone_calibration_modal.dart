import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../tuner_viewmodel.dart';
import '../domain/acoustic_rigor_profile.dart';

/// Modal interactivo para la calibración acústica, presets de rigurosidad por contexto
/// (versión sencilla para principiantes y versión avanzada para productores/técnicos - UC-41 & UC-44).
class MicrophoneCalibrationModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const MicrophoneCalibrationModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => MicrophoneCalibrationModal(viewModel: viewModel),
    );
  }

  @override
  State<MicrophoneCalibrationModal> createState() => _MicrophoneCalibrationModalState();
}

class _MicrophoneCalibrationModalState extends State<MicrophoneCalibrationModal> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.refreshAudioDevices();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final palette = viewModel.currentPalette;
        final profile = viewModel.micProfile;
        final rigorProfile = viewModel.acousticRigorProfile;
        final isAdvanced = rigorProfile.isAdvancedMode;
        final rms = viewModel.currentMicRmsLevel;

        // Conversión a escala logarítmica dBFS para el medidor VU (-60 dBFS a 0 dBFS)
        final double dbfs = rms > 0.00001 ? (20.0 * (rms.clamp(0.00001, 1.0)).log10()) : -60.0;
        final double normalizedVu = ((dbfs + 60.0) / 60.0).clamp(0.0, 1.0);

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Principal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.mic_external_on, color: palette.primaryAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrada y Rigurosidad Acústica',
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isAdvanced ? 'Modo Productor / Ajuste Manual' : 'Presets Inteligentes por Contexto',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Medidor VU de nivel de entrada en tiempo real
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.scaffoldBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NIVEL DE ENTRADA (VU METER)',
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '${dbfs.toStringAsFixed(1)} dBFS',
                        style: TextStyle(
                          color: dbfs > -3.0 ? Colors.redAccent : palette.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: normalizedVu,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                palette.primaryAccent,
                                palette.secondaryAccent,
                                if (normalizedVu > 0.85) Colors.redAccent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      // Marca visual del umbral Noise Gate
                      Positioned(
                        left: ((profile.noiseGateThreshold * 5.0).clamp(0.0, 1.0)) * 250,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'La línea blanca indica el corte del Noise Gate. Tu sonido debe superarla para ser detectado.',
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Nivel de Experiencia: Presets Sencillos vs. Modo Avanzado
            Container(
              decoration: BoxDecoration(
                color: palette.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const Key('mic_tab_simple_presets'),
                      onTap: isAdvanced ? () => viewModel.toggleAcousticRigorAdvancedView() : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isAdvanced
                              ? palette.primaryAccent.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: !isAdvanced ? palette.primaryAccent : palette.textMutedColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Presets Sencillos',
                              style: TextStyle(
                                color: !isAdvanced ? palette.primaryAccent : palette.textMutedColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      key: const Key('mic_tab_advanced_controls'),
                      onTap: !isAdvanced ? () => viewModel.toggleAcousticRigorAdvancedView() : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isAdvanced
                              ? palette.secondaryAccent.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 16,
                              color: isAdvanced ? palette.secondaryAccent : palette.textMutedColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Modo Avanzado / Pro',
                              style: TextStyle(
                                color: isAdvanced ? palette.secondaryAccent : palette.textMutedColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vista 1: Presets Sencillos ("Para Noobs" y Músicos Prácticos)
            if (!isAdvanced) ...[
              Text(
                'Selecciona el contexto acústico actual:',
                style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ...AcousticRigorPreset.values
                  .where((p) => p != AcousticRigorPreset.custom)
                  .map((preset) => _buildPresetCard(context, viewModel, preset, rigorProfile)),
              const SizedBox(height: 12),
            ],

            // Vista 2: Controles Granulares para Productores y Técnicos
            if (isAdvanced) ...[
              _buildAdvancedControls(context, viewModel, profile, rigorProfile),
              const SizedBox(height: 16),
            ],

            // Botón de Auto-Calibración de Ruido Ambiental (disponible en ambos modos)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.scaffoldBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: palette.secondaryAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'AUTO-CALIBRAR RUIDO DE LA HABITACIÓN',
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Permanece en silencio durante 1.5 segundos para ajustar automáticamente la compuerta acústica.',
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: viewModel.isCalibratingNoiseFloor
                            ? Colors.white12
                            : palette.secondaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: viewModel.isCalibratingNoiseFloor
                          ? null
                          : () async {
                              await viewModel.calibrateAmbientNoiseFloor();
                              if (mounted) setState(() {});
                            },
                      icon: viewModel.isCalibratingNoiseFloor
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.graphic_eq, size: 16),
                      label: Text(
                        viewModel.isCalibratingNoiseFloor
                            ? 'Midiendo ruido de sala...'
                            : 'Calibrar Silencio de Sala',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Selector de dispositivo de entrada físico si hay más de 1
            if (viewModel.availableAudioDevices.isNotEmpty) ...[
              Text(
                'Dispositivo de Entrada Físico:',
                style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.scaffoldBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: palette.cardBackground,
                    value: viewModel.availableAudioDevices.contains(profile.deviceId)
                        ? profile.deviceId
                        : viewModel.availableAudioDevices.first,
                    items: viewModel.availableAudioDevices.map((dev) {
                      return DropdownMenuItem<String>(
                        value: dev,
                        child: Text(dev, style: TextStyle(color: palette.textColor, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) viewModel.selectAudioDevice(val);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  },
);
  }

  /// Construye una tarjeta táctil para cada preset acústico simple.
  Widget _buildPresetCard(
    BuildContext context,
    TunerViewModel viewModel,
    AcousticRigorPreset preset,
    AcousticRigorProfile currentProfile,
  ) {
    final palette = viewModel.currentPalette;
    final isSelected = currentProfile.preset == preset;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        key: Key('rigor_preset_card_${preset.name}'),
        onTap: () {
          viewModel.setAcousticRigorPreset(preset);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.primaryAccent.withValues(alpha: 0.12)
                : palette.scaffoldBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? palette.primaryAccent
                  : palette.staffLinesColor.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.primaryAccent.withValues(alpha: 0.25)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  preset.icon,
                  size: 20,
                  color: isSelected ? palette.primaryAccent : palette.textMutedColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          preset.displayName,
                          style: TextStyle(
                            color: isSelected ? palette.primaryAccent : palette.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: palette.primaryAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ACTIVO',
                              style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.subtitle,
                      style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected ? palette.primaryAccent : palette.textMutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye los controles avanzados de DSP para usuarios pro y productores.
  Widget _buildAdvancedControls(
    BuildContext context,
    TunerViewModel viewModel,
    dynamic profile,
    AcousticRigorProfile rigor,
  ) {
    final palette = viewModel.currentPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PARÁMETROS GRANULARES DSP',
                style: TextStyle(
                  color: palette.secondaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.secondaryAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rigor.preset.displayName,
                  style: TextStyle(color: palette.secondaryAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Claridad Armónica MPM
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Claridad Armónica Mínima:', style: TextStyle(color: palette.textColor, fontSize: 12)),
              Text(
                '${(rigor.minClarity * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          Slider(
            key: const Key('advanced_clarity_slider'),
            value: rigor.minClarity,
            min: 0.55,
            max: 0.96,
            divisions: 41,
            activeColor: palette.primaryAccent,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              viewModel.setAcousticRigorAdvancedParameters(minClarity: val);
            },
          ),

          // 2. Tolerancia de Tono (Tone Lock Cents)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tolerancia de Tono (Tone Lock):', style: TextStyle(color: palette.textColor, fontSize: 12)),
              Text(
                '±${rigor.maxCentsDeviation.toStringAsFixed(0)} cents',
                style: TextStyle(color: palette.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          Slider(
            key: const Key('advanced_cents_slider'),
            value: rigor.maxCentsDeviation,
            min: 10.0,
            max: 60.0,
            divisions: 25,
            activeColor: palette.secondaryAccent,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              viewModel.setAcousticRigorAdvancedParameters(maxCentsDeviation: val);
            },
          ),

          // 3. Estabilidad Temporal (Frames de Confirmación)
          Text('Frames de Confirmación (Latencia vs. Estabilidad):', style: TextStyle(color: palette.textColor, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [1, 2, 3, 4].map((frames) {
              final isSel = rigor.minConsecutiveFrames == frames;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSel ? palette.primaryAccent.withValues(alpha: 0.2) : Colors.transparent,
                      side: BorderSide(
                        color: isSel ? palette.primaryAccent : palette.staffLinesColor.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      viewModel.setAcousticRigorAdvancedParameters(minConsecutiveFrames: frames);
                    },
                    child: Text(
                      '${frames}F (~${(frames * 23)}ms)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? palette.primaryAccent : palette.textMutedColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 4. Umbral de Noise Gate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Umbral Noise Gate:', style: TextStyle(color: palette.textColor, fontSize: 12)),
              Text(
                '${(profile.noiseGateThreshold * 1000).toStringAsFixed(1)} mRMS',
                style: TextStyle(color: palette.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          Slider(
            key: const Key('advanced_noise_gate_slider'),
            value: profile.noiseGateThreshold.clamp(0.001, 0.080),
            min: 0.001,
            max: 0.080,
            divisions: 30,
            activeColor: palette.secondaryAccent,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              viewModel.setAcousticRigorAdvancedParameters(noiseGateThreshold: val);
            },
          ),

          // 5. Ganancia Digital Pre-Amp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ganancia Digital de Entrada:', style: TextStyle(color: palette.textColor, fontSize: 12)),
              Text(
                '${profile.digitalGain.toStringAsFixed(1)}x',
                style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          Slider(
            key: const Key('advanced_gain_slider'),
            value: profile.digitalGain,
            min: 0.2,
            max: 5.0,
            divisions: 24,
            activeColor: palette.primaryAccent,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              viewModel.setAcousticRigorAdvancedParameters(digitalGain: val);
            },
          ),

          // 6. Switches: Aislamiento por Tesitura y DC-Blocker
          SwitchListTile(
            key: const Key('advanced_isolation_switch'),
            contentPadding: EdgeInsets.zero,
            title: Text('Aislamiento por Tesitura Instrumental', style: TextStyle(color: palette.textColor, fontSize: 13)),
            subtitle: Text(
              'Confina la detección al registro físico del instrumento activo',
              style: TextStyle(color: palette.textMutedColor, fontSize: 11),
            ),
            activeThumbColor: palette.primaryAccent,
            value: rigor.enableInstrumentIsolation,
            onChanged: (val) {
              viewModel.setAcousticRigorAdvancedParameters(enableInstrumentIsolation: val);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Filtro DC-Blocker (15 Hz)', style: TextStyle(color: palette.textColor, fontSize: 13)),
            subtitle: Text(
              'Elimina polarización de corriente continua de interfaces de audio',
              style: TextStyle(color: palette.textMutedColor, fontSize: 11),
            ),
            activeThumbColor: palette.secondaryAccent,
            value: profile.enableDcBlocker,
            onChanged: (val) {
              viewModel.setAcousticRigorAdvancedParameters(enableDcBlocker: val);
            },
          ),
        ],
      ),
    );
  }
}

extension on double {
  double log10() => this > 0 ? (math.log(this) / math.ln10) : -100.0;
}
