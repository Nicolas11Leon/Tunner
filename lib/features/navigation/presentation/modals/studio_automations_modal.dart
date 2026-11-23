import 'package:flutter/material.dart';
import '../../../../core/design_system/studio_theme_provider.dart';
import '../../../../core/design_system/studio_design_tokens.dart';
import '../../../../core/design_system/atoms/studio_hairline.dart';
import '../../../tuner_viewmodel.dart';

/// Modal Profesional de Automatizaciones del Estudio.
///
/// Permite al músico configurar y activar rutinas acústicas y de práctica
/// autónomas (rampas de tempo, calentamiento guiado y auto-grabación).
class StudioAutomationsModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const StudioAutomationsModal({super.key, required this.viewModel});

  static void show(BuildContext context, TunerViewModel viewModel) {
    showDialog(
      context: context,
      builder: (ctx) => StudioAutomationsModal(viewModel: viewModel),
    );
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
                  Icon(Icons.access_time_rounded, size: 16, color: tokens.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUTOMATIZACIONES DE ESTUDIO',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Rutinas autónomas para aceleración de tempo, calentamiento y auto-captura',
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

            // Lista de Automatizaciones
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAutomationCard(
                    context,
                    tokens,
                    title: 'Rampa Progresiva de Metrónomo',
                    description: 'Inicia el metrónomo al tempo actual (${viewModel.bpm.round()} BPM) e incrementa 2 BPM cada 4 compases de práctica.',
                    icon: Icons.trending_up_rounded,
                    actionLabel: viewModel.isBpmRampActive ? 'Detener Rampa' : 'Activar Rampa',
                    onAction: () {
                      final wasActive = viewModel.isBpmRampActive;
                      if (wasActive) {
                        viewModel.stopProgressiveBpmRamp();
                      } else {
                        viewModel.startProgressiveBpmRamp(stepBpm: 2, measuresInterval: 4);
                      }
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(wasActive
                              ? 'Rampa progresiva de metrónomo detenida.'
                              : 'Rampa progresiva de metrónomo inicializada (+2 BPM cada 4 compases).'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildAutomationCard(
                    context,
                    tokens,
                    title: 'Detección y Auto-Grabación WAV',
                    description: 'Arma el motor de audio para iniciar automáticamente una nueva toma de práctica en cuanto detecte sonido en el micrófono.',
                    icon: Icons.mic_rounded,
                    actionLabel: viewModel.isAudioRecording
                        ? 'Detener Grabación'
                        : (viewModel.isAutoRecordArmed ? 'Desarmar Auto-Grabación' : 'Armar Auto-Grabación'),
                    onAction: () {
                      final wasRecording = viewModel.isAudioRecording;
                      final wasArmed = viewModel.isAutoRecordArmed;
                      if (wasRecording) {
                        viewModel.stopPracticeRecording();
                      } else if (wasArmed) {
                        viewModel.disarmAutoRecord();
                      } else {
                        viewModel.armAutoRecord();
                      }
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(wasRecording
                              ? 'Grabación de práctica detenida.'
                              : (wasArmed
                                  ? 'Auto-Grabación desarmada.'
                                  : 'Auto-Grabación armada: comenzará al detectar señal en micrófono.')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildAutomationCard(
                    context,
                    tokens,
                    title: 'Calentamiento Técnico Guiado',
                    description: 'Inicia una secuencia de 5 minutos combinando sostenimiento de notas con afinador estroboscópico y dron de quintas armónicas.',
                    icon: Icons.fitness_center_rounded,
                    actionLabel: viewModel.isWarmupActive ? 'Detener Calentamiento' : 'Iniciar Calentamiento',
                    onAction: () {
                      final wasActive = viewModel.isWarmupActive;
                      if (wasActive) {
                        viewModel.stopGuidedWarmupRoutine();
                      } else {
                        viewModel.startGuidedWarmupRoutine();
                      }
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(wasActive
                              ? 'Sesión de calentamiento técnico detenida.'
                              : 'Sesión de calentamiento técnico iniciada (5 min círculo de quintas + Dron armónico).'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationCard(
    BuildContext context,
    StudioDesignTokens tokens, {
    required String title,
    required String description,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.elevatedSurface,
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              border: Border.all(color: tokens.borderHairline, width: 0.5),
            ),
            child: Icon(icon, size: 18, color: tokens.accentPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: tokens.textMuted, fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.accentPrimary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
