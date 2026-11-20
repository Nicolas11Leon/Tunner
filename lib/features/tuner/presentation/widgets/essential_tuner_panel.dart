import 'package:flutter/material.dart';

import '../../../../core/theme/tunner_theme.dart';
import '../../../persistence/domain/app_user_settings_entity.dart';
import '../strobe_tuner_widget.dart';
import '../tuner_acoustic_telemetry.dart';
import '../tuner_viewmodel.dart';

/// Panel dedicado del modo Esencial de afinación cromática y estroboscópica.
///
/// Extraído de [TunerScreen] para desacoplar la vista simplificada de alto
/// contraste y mantener la suscripción atómica de 60 Hz sobre
/// [TunerViewModel.telemetryListenable].
class EssentialTunerPanel extends StatelessWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;

  const EssentialTunerPanel({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final displayNote = viewModel.hasTransposition
        ? (viewModel.writtenNoteName.isEmpty ? "--" : viewModel.writtenNoteName)
        : (viewModel.noteName.isEmpty ? "--" : viewModel.noteName);
    final cents = viewModel.cents;
    final isListening = viewModel.isRecording;
    final isInTune = cents.abs() <= 5.0 && viewModel.frequency > 0;
    final centsColor = isInTune
        ? palette.correctPitchColor
        : (cents.abs() <= 15
            ? palette.secondaryAccent
            : palette.errorPitchColor);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Tarjeta Heroica Monumental de la Nota
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
                horizontal: 16.0,
              ),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isInTune
                      ? palette.correctPitchColor.withValues(alpha: 0.6)
                      : palette.staffLinesColor.withValues(alpha: 0.2),
                  width: isInTune ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isInTune
                        ? palette.correctPitchColor.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayNote,
                    key: const Key('essential_note_display'),
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color:
                          isInTune ? palette.correctPitchColor : palette.textColor,
                      letterSpacing: -1,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (viewModel.hasTransposition &&
                      viewModel.frequency > 0 &&
                      viewModel.noteName.isNotEmpty &&
                      viewModel.noteName != "--") ...[
                    const SizedBox(height: 2),
                    Container(
                      key: const Key('essential_sounding_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.secondaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.secondaryAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        "Sonando: ${viewModel.noteName} (Tono Real)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.secondaryAccent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    viewModel.frequency > 0
                        ? "${viewModel.frequency.toStringAsFixed(1)} Hz"
                        : "-- Hz",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.textMutedColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: centsColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: centsColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      viewModel.frequency > 0
                          ? (isInTune
                              ? "AFINADO (${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents)"
                              : "${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents")
                          : "ESPERANDO AUDIO",
                      style: TextStyle(
                        color: centsColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Afinador Estroboscópico de Alta Precisión (suscripción atómica 60 Hz)
            ValueListenableBuilder<TunerAcousticTelemetry>(
              valueListenable: viewModel.telemetryListenable,
              builder: (context, telemetry, _) {
                return StrobeTunerWidget(
                  cents: telemetry.cents,
                  frequency: telemetry.frequency,
                  noteName: viewModel.hasTransposition
                      ? viewModel.writtenNoteName
                      : telemetry.noteName,
                  soundingNoteName:
                      viewModel.hasTransposition ? telemetry.noteName : null,
                  isRecording: telemetry.isRecording,
                  onPlayReferenceTone: () => viewModel.playReferenceTone("La4"),
                  palette: palette,
                  centsTolerance: viewModel.centsTolerance,
                );
              },
            ),
            const SizedBox(height: 16),

            // Barra de Controles Esenciales
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
                  key: const Key('essential_mic_toggle_btn'),
                  onPressed: viewModel.toggleRecording,
                  backgroundColor: isListening
                      ? palette.errorPitchColor.withValues(alpha: 0.2)
                      : palette.primaryAccent,
                  elevation: 3,
                  icon: Icon(
                    isListening ? Icons.mic_off : Icons.mic,
                    color: isListening ? palette.errorPitchColor : Colors.black,
                  ),
                  label: Text(
                    isListening ? "Pausar Escucha" : "Activar Afinador",
                    style: TextStyle(
                      color:
                          isListening ? palette.errorPitchColor : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: () => viewModel.playReferenceTone("La4"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.secondaryAccent,
                    side: BorderSide(
                      color: palette.secondaryAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.volume_up_outlined, size: 18),
                  label: const Text(
                    "Tono La4",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Acceso Rápido al Modo Pro
            InkWell(
              key: const Key('essential_switch_to_pro_card'),
              onTap: () =>
                  viewModel.setDisplayMode(AppDisplayMode.conservatoryPro),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.cardBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: palette.staffLinesColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: palette.secondaryAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Modo Conservatorio Pro (Partituras, Stems, Labs)",
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: palette.secondaryAccent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
