import 'package:flutter/material.dart';
import '../../../design_system/atoms/studio_icon.dart';
import '../../../design_system/domain/studio_icon_catalog.dart';
import '../../../design_system/studio_design_tokens.dart';
import '../../domain/audio_device_matrix_entity.dart';
import '../../infrastructure/studio_audio_device_matrix_service.dart';

/// Panel de transductores fisicos de hardware (entrada, salida y tamano de bufer).
class HardwareEndpointsPanel extends StatelessWidget {
  final StudioDesignTokens tokens;
  final AudioDeviceMatrixEntity matrix;
  final StudioAudioDeviceMatrixService matrixService;

  const HardwareEndpointsPanel({
    super.key,
    required this.tokens,
    required this.matrix,
    required this.matrixService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudioIcon(
                StudioIconId.moduleRack,
                size: 14,
                color: tokens.accentPrimary,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'TRANSDUCTORES FÍSICOS DE HARDWARE',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de Entrada Fisica
          Text(
            'ENTRADA DE AUDIO (MIC / INTERFAZ):',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: tokens.panelHeaderBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: matrix.availableInputs.any((d) => d.id == matrix.activeInputDevice.id)
                    ? matrix.activeInputDevice.id
                    : (matrix.availableInputs.isNotEmpty ? matrix.availableInputs.first.id : null),
                isExpanded: true,
                dropdownColor: tokens.panelHeaderBackground,
                style: TextStyle(color: tokens.textPrimary, fontSize: 11),
                items: matrix.availableInputs.map<DropdownMenuItem<String>>((d) {
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Text('${d.label} (${d.channels} ch)'),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) matrixService.selectInputDevice(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Selector de Salida Fisica
          Text(
            'SALIDA MAESTRA (MONITORES / DAC):',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: tokens.panelHeaderBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: matrix.availableOutputs.any((d) => d.id == matrix.activeOutputDevice.id)
                    ? matrix.activeOutputDevice.id
                    : (matrix.availableOutputs.isNotEmpty ? matrix.availableOutputs.first.id : null),
                isExpanded: true,
                dropdownColor: tokens.panelHeaderBackground,
                style: TextStyle(color: tokens.textPrimary, fontSize: 11),
                items: matrix.availableOutputs.map<DropdownMenuItem<String>>((d) {
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Text('${d.label} (${d.channels} ch)'),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) matrixService.selectOutputDevice(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Selector de Tamano de Bufer y Latencia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAMAÑO DE BÚFER & LATENCIA:',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${matrix.estimatedBufferLatencyMs.toStringAsFixed(1)} ms',
                style: TextStyle(
                  color: tokens.accentPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [128, 256, 512, 1024].map((size) {
              final isSel = matrix.bufferSize == size;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      backgroundColor: isSel
                          ? tokens.accentPrimary.withValues(alpha: 0.2)
                          : tokens.panelHeaderBackground,
                      side: BorderSide(
                        color: isSel ? tokens.accentPrimary : tokens.borderHairline,
                      ),
                    ),
                    onPressed: () => matrixService.setBufferSize(size),
                    child: Text(
                      '$size',
                      style: TextStyle(
                        color: isSel ? tokens.accentPrimary : tokens.textSecondary,
                        fontSize: 10,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
