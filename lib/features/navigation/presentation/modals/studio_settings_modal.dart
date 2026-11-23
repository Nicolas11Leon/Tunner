import 'package:flutter/material.dart';
import '../../../../core/design_system/studio_theme_provider.dart';
import '../../../../core/design_system/studio_design_tokens.dart';
import '../../../../core/design_system/atoms/studio_hairline.dart';
import '../../../tuner_viewmodel.dart';
import '../../../tuner/presentation/microphone_calibration_modal.dart';
import '../../../instrument/presentation/instrument_selector_modal.dart';

/// Modal Profesional de Configuración General del Estudio (StudioSettingsModal).
///
/// Permite calibrar la frecuencia de afinación de concierto A4, seleccionar temperamentos,
/// umbral de ruido ambiental y enrutar a calibraciones de micrófono e instrumentos.
class StudioSettingsModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const StudioSettingsModal({super.key, required this.viewModel});

  static void show(BuildContext context, TunerViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => StudioSettingsModal(viewModel: viewModel),
    );
  }

  @override
  State<StudioSettingsModal> createState() => _StudioSettingsModalState();
}

class _StudioSettingsModalState extends State<StudioSettingsModal> {
  late double _referencePitch;
  late String _temperamentId;

  @override
  void initState() {
    super.initState();
    _referencePitch = widget.viewModel.referencePitch;
    _temperamentId = widget.viewModel.selectedTemperament.id;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.panelHeaderBackground,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(tokens.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 16, color: tokens.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREFERENCIAS Y CONFIGURACIÓN DEL ESTUDIO',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Calibración acústica base, sistemas de entonación y dispositivos de entrada',
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 16, color: tokens.textMuted),
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const StudioHairline(orientation: Axis.horizontal),

            // Contenido
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Calibración de A4
                  _buildSectionHeader('FRECUENCIA DE CONCIERTO A4 (HERTZ)', tokens),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.inputSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A4 = ${_referencePitch.toStringAsFixed(1)} Hz',
                          style: TextStyle(
                            color: tokens.accentPrimary,
                            fontSize: 15,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildPitchChip(415.0, '415 Hz Barroco', tokens),
                            _buildPitchChip(432.0, '432 Hz Filosófico', tokens),
                            _buildPitchChip(440.0, '440 Hz Estándar', tokens),
                            _buildPitchChip(442.0, '442 Hz Orquestal', tokens),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: tokens.accentPrimary,
                            inactiveTrackColor: tokens.elevatedSurface,
                            thumbColor: tokens.accentPrimary,
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          ),
                          child: Slider(
                            value: _referencePitch.clamp(400.0, 480.0),
                            min: 400.0,
                            max: 480.0,
                            divisions: 160,
                            onChanged: (val) {
                              setState(() => _referencePitch = val);
                              widget.viewModel.setReferencePitch(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  const StudioHairline(orientation: Axis.horizontal),
                  const SizedBox(height: 14),

                  // 2. Sistema de Temperamento Histórico
                  _buildSectionHeader('SISTEMA DE TEMPERAMENTO HISTÓRICO', tokens),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTemperamentCard('equal', 'Temperamento Igual (12-EDO)', 'Estándar moderno simétrico.', tokens),
                      _buildTemperamentCard('just_intonation', 'Entonación Justa', 'Intervalos puros basados en la serie armónica.', tokens),
                      _buildTemperamentCard('pythagorean', 'Pitagórico', 'Basado en cadenas de quintas 3:2 perfectas.', tokens),
                      _buildTemperamentCard('meantone_quarter', 'Mesotónico (1/4 de coma)', 'Terceras mayores puras renacentistas.', tokens),
                      _buildTemperamentCard('werckmeister_iii', 'Werckmeister III', 'Buen temperamento para órgano barroco.', tokens),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const StudioHairline(orientation: Axis.horizontal),
                  const SizedBox(height: 14),

                  // 3. Accesos Directos a Hardware y Perfiles
                  _buildSectionHeader('HARDWARE Y ENRUTAMIENTO', tokens),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.mic_external_on_rounded, size: 16, color: tokens.accentPrimary),
                          label: const Text('Calibrar Micrófono', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.textPrimary,
                            side: BorderSide(color: tokens.borderHairline),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusSmall),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            MicrophoneCalibrationModal.show(context, widget.viewModel);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.music_note_rounded, size: 16, color: tokens.accentPrimary),
                          label: const Text('Cambiar Instrumento', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.textPrimary,
                            side: BorderSide(color: tokens.borderHairline),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusSmall),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            InstrumentSelectorModal.show(context, widget.viewModel);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const StudioHairline(orientation: Axis.horizontal),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: tokens.panelHeaderBackground,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accentPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                    ),
                    child: const Text('Listo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, StudioDesignTokens tokens) {
    return Text(
      title,
      style: TextStyle(
        color: tokens.textSecondary,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildPitchChip(double pitch, String label, StudioDesignTokens tokens) {
    final isSelected = (_referencePitch - pitch).abs() < 0.1;

    return InkWell(
      onTap: () {
        setState(() => _referencePitch = pitch);
        widget.viewModel.setReferencePitch(pitch);
      },
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accentPrimary : tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : tokens.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTemperamentCard(String id, String title, String subtitle, StudioDesignTokens tokens) {
    final isSelected = _temperamentId == id;

    return InkWell(
      onTap: () {
        setState(() => _temperamentId = id);
        widget.viewModel.setTemperament(id);
      },
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accentPrimary.withValues(alpha: 0.08) : tokens.inputSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
            width: tokens.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 14,
                  color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(color: tokens.textMuted, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}
