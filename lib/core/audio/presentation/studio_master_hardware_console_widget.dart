import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../../design_system/atoms/studio_stereo_vu_meter.dart';
import '../../design_system/atoms/studio_hairline.dart';
import '../domain/studio_master_clock_service.dart';
import '../infrastructure/studio_audio_device_matrix_service.dart';

/// Consola Maestra de E/S de Hardware y Reloj de Transporte Global de Tunner Studio.
/// Permite conmutar transductores físicos en caliente, ajustar ganancia maestra logarítmica,
/// aplicar atenuación DIM (-20 dB), MUTE y suma MONO, así como sincronizar el reloj de tempo.
class StudioMasterHardwareConsoleWidget extends StatelessWidget {
  final StudioAudioDeviceMatrixService matrixService;
  final StudioMasterClockService clockService;

  const StudioMasterHardwareConsoleWidget({
    super.key,
    required this.matrixService,
    required this.clockService,
  });

  /// Despliega la consola maestra en un modal modal de alta fidelidad.
  static void show(
    BuildContext context, {
    required StudioAudioDeviceMatrixService matrixService,
    required StudioMasterClockService clockService,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
          child: StudioMasterHardwareConsoleWidget(
            matrixService: matrixService,
            clockService: clockService,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge([matrixService, clockService]),
      builder: (context, _) {
        final matrix = matrixService.matrix;

        return Container(
          decoration: BoxDecoration(
            color: tokens.panelBackground,
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
            border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Barra de Cabecera Hardware
              _buildHeader(context, tokens),
              const StudioHairline(),

              // 2. Cuerpo Principal de la Consola
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Fila Superior: Hardware I/O + Master Transport Clock
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Columna Izquierda: Dispositivos Físicos y Búfer
                          Expanded(
                            flex: 5,
                            child: _buildHardwareEndpointsCard(context, tokens, matrix),
                          ),
                          const SizedBox(width: 16),

                          // Columna Derecha: Reloj Maestro de Transporte
                          Expanded(
                            flex: 4,
                            child: _buildMasterClockCard(context, tokens),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16, height: 16),

                      // Fila Inferior: Tira de Canal Maestro con Vúmetros y Fader
                      _buildMasterStripCard(context, tokens, matrix),
                    ],
                  ),
                ),
              ),

              // 3. Barra de Pie de Estado
              const StudioHairline(),
              _buildFooter(context, tokens, matrix),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, dynamic tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusMedium)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: tokens.accentPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSOLA MAESTRA DE E/S & RELOJ GLOBAL',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Matriz de transductores físicos y sincronización de transporte unificado',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Tartini DSP 2.1',
              style: TextStyle(
                color: tokens.accentPrimary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: tokens.textSecondary,
            tooltip: 'Cerrar Consola',
            onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareEndpointsCard(BuildContext context, dynamic tokens, dynamic matrix) {
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
              Icon(Icons.settings_input_component, size: 14, color: tokens.accentPrimary),
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

          // Selector de Entrada Física
          Text(
            'ENTRADA DE AUDIO (MIC / INTERFAZ):',
            style: TextStyle(color: tokens.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
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

          // Selector de Salida Física
          Text(
            'SALIDA MAESTRA (MONITORES / DAC):',
            style: TextStyle(color: tokens.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
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

          // Selector de Tamaño de Búfer y Latencia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAMAÑO DE BÚFER & LATENCIA:',
                style: TextStyle(color: tokens.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
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

  Widget _buildMasterClockCard(BuildContext context, dynamic tokens) {
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
              Icon(Icons.access_time_filled, size: 14, color: tokens.accentSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'RELOJ MAESTRO DE TRANSPORTE',
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

          // Display Grande de BPM y Tap Tempo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.panelHeaderBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Row(
                  children: [
                    Text(
                      clockService.bpm.toStringAsFixed(1),
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BPM',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botones +/- BPM
              Column(
                children: [
                  InkWell(
                    key: const Key('bpm_increment_btn'),
                    onTap: () => clockService.setBpm(clockService.bpm + 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: tokens.panelHeaderBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.arrow_drop_up, size: 16, color: tokens.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    key: const Key('bpm_decrement_btn'),
                    onTap: () => clockService.setBpm(clockService.bpm - 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: tokens.panelHeaderBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.arrow_drop_down, size: 16, color: tokens.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Botón Tap Tempo
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accentSecondary.withValues(alpha: 0.15),
                    foregroundColor: tokens.accentSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: tokens.accentSecondary.withValues(alpha: 0.5)),
                  ),
                  onPressed: clockService.registerTap,
                  child: const Text(
                    'TAP TEMPO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Posición de Compás y Métrica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'COMPÁS: ${clockService.currentMeasure} | TIEMPO: ${clockService.currentBeat} / ${clockService.meterNumerator}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clockService.isDownbeat ? tokens.accentPrimary : tokens.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: clockService.isPlaying
                      ? (clockService.isDownbeat ? tokens.accentPrimary : Colors.amber)
                      : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botones Maestros PLAY ALL / STOP ALL
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: clockService.isPlaying ? Colors.green : tokens.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: Icon(clockService.isPlaying ? Icons.pause : Icons.play_arrow, size: 16),
                  label: Text(
                    clockService.isPlaying ? 'PAUSE ALL' : 'PLAY ALL',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: clockService.togglePlayPause,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                icon: const Icon(Icons.stop, size: 16),
                label: const Text(
                  'STOP ALL',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                onPressed: clockService.stopTransport,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasterStripCard(BuildContext context, dynamic tokens, dynamic matrix) {
    final meter = matrixService.masterMeterData;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vúmetros Estéreo L/R
          Column(
            children: [
              Text(
                'VÚMETRO MASTER',
                style: TextStyle(color: tokens.textSecondary, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  StudioStereoVuMeter(
                    levelLeft: meter.leftRms,
                    levelRight: meter.rightRms,
                    peakLeft: (meter.leftPeakDb + 60.0) / 60.0,
                    peakRight: (meter.rightPeakDb + 60.0) / 60.0,
                    height: 110,
                    width: 24,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${meter.leftPeakDb.toStringAsFixed(1)} dB',
                    style: TextStyle(
                      color: meter.isClipping ? Colors.redAccent : tokens.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Fader Maestro Táctil Proporcional
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GANANCIA MAESTRA (MASTER GAIN):',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${matrix.masterGainDb.toStringAsFixed(1)} dB (${(matrix.masterGain * 100).toInt()}%)',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: tokens.accentPrimary,
                    inactiveTrackColor: tokens.panelHeaderBackground,
                    thumbColor: tokens.accentPrimary,
                    overlayColor: tokens.accentPrimary.withValues(alpha: 0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: matrix.masterGain,
                    min: 0.0,
                    max: 1.5,
                    onChanged: (val) => matrixService.setMasterGain(val),
                  ),
                ),
                const SizedBox(height: 10),

                // Botones Utilitarios de Estudio: MUTE, DIM, MONO
                Row(
                  children: [
                    // Botón MUTE
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isMuted
                              ? Colors.redAccent
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isMuted ? Colors.white : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isMuted ? Colors.redAccent : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: matrixService.toggleMute,
                        child: const Text('MUTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón DIM (-20 dB)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isDimmed
                              ? Colors.amber.shade700
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isDimmed ? Colors.white : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isDimmed ? Colors.amber.shade700 : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: matrixService.toggleDim,
                        child: const Text('DIM (-20dB)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón MONO
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isMono
                              ? Colors.cyan.shade700
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isMono ? Colors.white : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isMono ? Colors.cyan.shade700 : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: matrixService.toggleMono,
                        child: const Text('MONO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, dynamic tokens, dynamic matrix) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(tokens.radiusMedium)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.cable, size: 14, color: tokens.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Canales Activos: ${matrix.channelRoutings.length} asignados a bus Master',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Ctrl+Shift+I',
            style: TextStyle(
              color: tokens.accentPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
