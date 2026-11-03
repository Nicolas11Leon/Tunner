import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../tuner_viewmodel.dart';

/// Modal interactivo para la calibración acústica, perfilado de piso de ruido
/// y adaptación del hardware de micrófono en tiempo real (UC-41).
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
    final viewModel = widget.viewModel;
    final palette = viewModel.currentPalette;
    final profile = viewModel.micProfile;
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
                          'Calibración de Micrófono',
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Adaptación acústica y eliminación de ruido',
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
            const SizedBox(height: 20),

            // Medidor VU de nivel de entrada en tiempo real
            Container(
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
                        'NIVEL DE ENTRADA (VU METER)',
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 11,
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
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: normalizedVu,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                palette.primaryAccent,
                                palette.secondaryAccent,
                                if (normalizedVu > 0.85) Colors.redAccent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(7),
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
                    'La línea blanca indica el corte del Noise Gate. Toca o canta para verificar que el nivel supere la línea.',
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón de Perfilado de Ruido Ambiental
            Container(
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
                    children: [
                      Icon(Icons.auto_fix_high, color: palette.secondaryAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AUTO-CALIBRACIÓN DE RUIDO AMBIENTAL',
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Permanece en silencio durante 1.5 segundos. El sistema medirá el ruido del ventilador o sala y ajustará la compuerta acústica óptima.',
                    style: TextStyle(color: palette.textMutedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: viewModel.isCalibratingNoiseFloor
                            ? Colors.white12
                            : palette.secondaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: viewModel.isCalibratingNoiseFloor
                          ? null
                          : () async {
                              await viewModel.calibrateAmbientNoiseFloor();
                              if (mounted) setState(() {});
                            },
                      icon: viewModel.isCalibratingNoiseFloor
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.graphic_eq, size: 18),
                      label: Text(
                        viewModel.isCalibratingNoiseFloor
                            ? 'Midiendo ruido de sala...'
                            : 'Calibrar Silencio Ahora',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (viewModel.lastNoiseReport != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Piso de ruido medido: ${(viewModel.lastNoiseReport!.meanRms * 1000).toStringAsFixed(1)} mRMS | Gate adaptativo: ${(viewModel.lastNoiseReport!.recommendedNoiseGate * 1000).toStringAsFixed(1)} mRMS',
                      style: TextStyle(color: palette.primaryAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Controles Manuales: Ganancia y Noise Gate
            Text(
              'Ajustes Manuales de Entrada:',
              style: TextStyle(color: palette.textColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Ganancia Digital Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ganancia Digital:', style: TextStyle(color: palette.textColor, fontSize: 13)),
                Text(
                  '${profile.digitalGain.toStringAsFixed(1)}x',
                  style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: profile.digitalGain,
              min: 0.2,
              max: 5.0,
              divisions: 24,
              activeColor: palette.primaryAccent,
              inactiveColor: Colors.white10,
              onChanged: (val) => viewModel.setMicrophoneGain(val),
            ),

            // Noise Gate Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Umbral Noise Gate:', style: TextStyle(color: palette.textColor, fontSize: 13)),
                Text(
                  '${(profile.noiseGateThreshold * 1000).toStringAsFixed(1)} mRMS',
                  style: TextStyle(color: palette.secondaryAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: profile.noiseGateThreshold.clamp(0.001, 0.080),
              min: 0.001,
              max: 0.080,
              divisions: 30,
              activeColor: palette.secondaryAccent,
              inactiveColor: Colors.white10,
              onChanged: (val) => viewModel.setNoiseGateThreshold(val),
            ),

            // Switch Filtro DC-Blocker
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Filtro DC-Blocker (15 Hz)', style: TextStyle(color: palette.textColor, fontSize: 14)),
              subtitle: Text(
                'Elimina la polarización de corriente directa de tarjetas de sonido',
                style: TextStyle(color: palette.textMutedColor, fontSize: 11),
              ),
              activeThumbColor: palette.primaryAccent,
              value: profile.enableDcBlocker,
              onChanged: (val) => viewModel.toggleDcBlocker(val),
            ),

            // Selector de dispositivo de entrada si hay más de 1
            if (viewModel.availableAudioDevices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Dispositivo de Entrada Físico:',
                style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
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
                        child: Text(dev, style: TextStyle(color: palette.textColor, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) viewModel.selectAudioDevice(val);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

extension on double {
  double log10() => this > 0 ? (math.log(this) / math.ln10) : -100.0;
}
