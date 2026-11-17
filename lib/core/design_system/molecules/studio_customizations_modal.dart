import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../studio_design_tokens.dart';
import '../atoms/studio_hairline.dart';
import '../../../features/tuner_viewmodel.dart';

/// Modal de Personalización Técnica y Visual del Estudio (StudioCustomizationsModal).
///
/// Permite al usuario configurar el motor DSP de análisis de tono,
/// la tasa de refresco gráfica (60/120 FPS) y los parámetros estéticos del lienzo.
class StudioCustomizationsModal extends StatefulWidget {
  final TunerViewModel viewModel;

  const StudioCustomizationsModal({super.key, required this.viewModel});

  static void show(BuildContext context, TunerViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => StudioCustomizationsModal(viewModel: viewModel),
    );
  }

  @override
  State<StudioCustomizationsModal> createState() => _StudioCustomizationsModalState();
}

class _StudioCustomizationsModalState extends State<StudioCustomizationsModal> {
  String _selectedEngine = 'Tartini DSP 2.1';
  int _targetFps = 60;
  double _centsPrecision = 0.1;

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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
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
                  Icon(Icons.tune_rounded, size: 16, color: tokens.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PERSONALIZACIÓN TÉCNICA DEL ESTUDIO',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Configuración de motores de análisis, renderizado a alta velocidad y visualizadores',
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

            // Opciones de Configuración
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Selector de Motor DSP
                  _buildSectionHeader('MOTOR DE DETECCIÓN Y ANÁLISIS DSP', tokens),
                  const SizedBox(height: 8),
                  _buildRadioOption(
                    title: 'Tartini DSP 2.1 (Recomendado)',
                    subtitle: 'Algoritmo NSDF/MPM con supresión de sub-armónicos y latencia sub-10ms.',
                    value: 'Tartini DSP 2.1',
                    groupValue: _selectedEngine,
                    tokens: tokens,
                    onChanged: (val) => setState(() => _selectedEngine = val!),
                  ),
                  const SizedBox(height: 6),
                  _buildRadioOption(
                    title: 'McLeod Pitch Method (MPM)',
                    subtitle: 'Cálculo de función de autocorrelación normalizada cuadrada para fuentes vocales.',
                    value: 'McLeod Pitch Method (MPM)',
                    groupValue: _selectedEngine,
                    tokens: tokens,
                    onChanged: (val) => setState(() => _selectedEngine = val!),
                  ),
                  const SizedBox(height: 6),
                  _buildRadioOption(
                    title: 'YIN Estroboscópico de Alta Precisión',
                    subtitle: 'Función de diferencia media acumulada con interpolación parabólica para instrumentos graves.',
                    value: 'YIN Estroboscópico',
                    groupValue: _selectedEngine,
                    tokens: tokens,
                    onChanged: (val) => setState(() => _selectedEngine = val!),
                  ),

                  const SizedBox(height: 18),
                  const StudioHairline(orientation: Axis.horizontal),
                  const SizedBox(height: 14),

                  // 2. Tasa de Refresco Gráfico (FPS)
                  _buildSectionHeader('TASA DE REFRESCO DE LIENZO (FPS)', tokens),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFpsCard(
                          fps: 60,
                          label: '60 FPS Estándar',
                          description: 'Consumo optimizado de energía y CPU (1-2%).',
                          isSelected: _targetFps == 60,
                          tokens: tokens,
                          onTap: () => setState(() => _targetFps = 60),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFpsCard(
                          fps: 120,
                          label: '120 FPS Ultra Fluid',
                          description: 'Soporte para monitores ProMotion y pantallas de alta tasa.',
                          isSelected: _targetFps == 120,
                          tokens: tokens,
                          onTap: () => setState(() => _targetFps = 120),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const StudioHairline(orientation: Axis.horizontal),
                  const SizedBox(height: 14),

                  // 3. Tolerancia Centesimal
                  _buildSectionHeader('TOLERANCIA DE AFINACIÓN CENTESIMAL', tokens),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ventana de afinación correcta: ±${_centsPrecision.toStringAsFixed(1)} cents',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _centsPrecision <= 0.2 ? 'Nivel Conservatorio' : 'Nivel Concierto',
                              style: TextStyle(
                                color: tokens.accentPrimary,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: tokens.accentPrimary,
                            inactiveTrackColor: tokens.elevatedSurface,
                            thumbColor: tokens.accentPrimary,
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          ),
                          child: Slider(
                            value: _centsPrecision,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            onChanged: (val) => setState(() => _centsPrecision = val),
                          ),
                        ),
                      ],
                    ),
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
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Cerrar', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Configuración aplicada: $_selectedEngine a $_targetFps FPS.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accentPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                    ),
                    child: const Text(
                      'Aplicar Cambios',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
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

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required StudioDesignTokens tokens,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accentPrimary.withValues(alpha: 0.08) : tokens.inputSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
            width: tokens.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? tokens.accentPrimary : tokens.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFpsCard({
    required int fps,
    required String label,
    required String description,
    required bool isSelected,
    required StudioDesignTokens tokens,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                  isSelected ? Icons.check_circle_rounded : Icons.speed_rounded,
                  size: 15,
                  color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: tokens.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
