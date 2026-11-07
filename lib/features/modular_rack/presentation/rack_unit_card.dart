import 'package:flutter/material.dart';
import '../domain/rack_module_entity.dart';
import '../domain/port_id.dart';
import 'modular_rack_viewmodel.dart';
import '../../instrument/presentation/instrument_emulation_surface_widget.dart';

/// Tarjeta contenedora de una unidad de módulo montada en el Rack de Estudio.
/// Soporta reordenamiento por arrastre, colapso compacto, apagado y puertos In/Out.
class RackUnitCard extends StatelessWidget {
  final RackModuleEntity module;
  final ModularRackViewModel viewModel;
  final int index;

  const RackUnitCard({
    super.key,
    required this.module,
    required this.viewModel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final instrument = viewModel.activeInstrument;
    final primaryColor = instrument.visualProfile.primaryAccentColor;
    final isExpanded = module.viewMode == ModuleViewMode.expanded;
    final isPowered = module.isPoweredOn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPowered ? primaryColor.withValues(alpha: 0.4) : Colors.white12,
          width: isPowered ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de cabecera del módulo (Chassis Rack Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: isExpanded ? Radius.zero : const Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                // Manija de arrastre (Drag Handle)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.drag_indicator, color: Colors.white38, size: 20),
                  ),
                ),

                // Icono del tipo de módulo
                Text(module.moduleType.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),

                // Título del módulo
                Expanded(
                  child: Text(
                    module.title.toUpperCase(),
                    style: TextStyle(
                      color: isPowered ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),

                // Interruptor de encendido (Power LED)
                InkWell(
                  onTap: () => viewModel.toggleModulePower(module.moduleId),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPowered ? const Color(0xFF10B981) : Colors.white24,
                            boxShadow: isPowered
                                ? [const BoxShadow(color: Color(0xFF10B981), blurRadius: 6, spreadRadius: 1)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPowered ? 'ON' : 'OFF',
                          style: TextStyle(
                            color: isPowered ? const Color(0xFF10B981) : Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón Compactar / Expandir
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 20,
                  ),
                  tooltip: isExpanded ? 'Modo Compacto' : 'Modo Expandido',
                  onPressed: () => viewModel.toggleViewMode(module.moduleId),
                ),

                // Botón Quitar del Rack
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  tooltip: 'Quitar del Rack',
                  onPressed: () => viewModel.removeModule(module.moduleId),
                ),
              ],
            ),
          ),

          // Fila de Puertos de Entrada y Salida (Signal Badges)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Colors.white.withValues(alpha: 0.02),
              child: Row(
                children: [
                  if (module.inputPorts.isNotEmpty) ...[
                    const Text('IN: ', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    ...module.inputPorts.map((p) => _buildPortBadge(p, isInput: true)),
                  ],
                  const Spacer(),
                  if (module.outputPorts.isNotEmpty) ...[
                    const Text('OUT: ', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    ...module.outputPorts.map((p) => _buildPortBadge(p, isInput: false)),
                  ],
                ],
              ),
            ),

          // Cuerpo expandido interactivo del módulo
          if (isExpanded && isPowered)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildModuleContent(context),
            )
          else if (isExpanded && !isPowered)
            Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text(
                'Módulo apagado en standby para ahorrar batería.',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPortBadge(PortId port, {required bool isInput}) {
    // Verificar si el puerto tiene una conexión activa en el bus
    final hasActiveConn = viewModel.signalBus.activeConnections.any((c) =>
        (isInput ? c.destinationPort == port : c.sourcePort == port));

    final badgeColor = hasActiveConn
        ? const Color(0xFF10B981)
        : (isInput ? const Color(0xFF38BDF8) : const Color(0xFFA855F7));

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasActiveConn ? const Color(0xFF10B981) : Colors.white38,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            port.id,
            style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleContent(BuildContext context) {
    switch (module.moduleType) {
      case RackModuleType.strobeTuner:
        return _buildStrobeTunerContent();
      case RackModuleType.metronome:
        return _buildMetronomeContent();
      case RackModuleType.scoreNotation:
        return _buildScoreNotationContent();
      case RackModuleType.practiceRecorder:
        return _buildRecorderContent();
      case RackModuleType.vocalAutoTune:
        return _buildAutoTuneContent();
      case RackModuleType.harmonicDrone:
        return _buildDroneContent();
      case RackModuleType.spectrogram:
        return _buildSpectrogramContent();
      case RackModuleType.chordAnalyzer:
        return _buildChordAnalyzerContent();
      case RackModuleType.guidedLessons:
        return _buildGuidedLessonsContent();
    }
  }

  // --- SUB-VISTAS INTERACTIVAS POR MÓDULO ---

  Widget _buildStrobeTunerContent() {
    final instrument = viewModel.activeInstrument;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('NOTA CANÓNICA', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text(
                  instrument.acousticRange.standardTuningNoteNames.isNotEmpty
                      ? instrument.acousticRange.standardTuningNoteNames.first
                      : 'A4',
                  style: TextStyle(
                    color: instrument.visualProfile.primaryAccentColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text('DESVIACIÓN EN CENTS', style: TextStyle(color: Colors.white38, fontSize: 9)),
                const Text(
                  '+0.2 ¢ (EN TONO)',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${instrument.acousticRange.minFrequencyHz.toStringAsFixed(1)} Hz',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Superficie táctil interactiva adaptada al instrumento
        InstrumentEmulationSurfaceWidget(instrument: instrument),
      ],
    );
  }

  Widget _buildMetronomeContent() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TEMPO: 120 BPM • 4/4',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ActionChip(
                  label: const Text('TAP TEMPO'),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                  backgroundColor: Colors.white12,
                  onPressed: () {},
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Color(0xFF10B981), size: 28),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: 120,
          min: 40,
          max: 240,
          activeColor: const Color(0xFF10B981),
          inactiveColor: Colors.white12,
          onChanged: (_) {},
        ),
      ],
    );
  }

  Widget _buildScoreNotationContent() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('𝄞', style: TextStyle(fontSize: 40, color: Colors.amber)),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Escuchando entrada en vivo... Transcribiendo notas al pentagrama',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorderContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        const Icon(Icons.graphic_eq, color: Color(0xFFEF4444), size: 36),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOMA 01 (00:45)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('44.1 kHz • 24-bit PCM Flotante', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildAutoTuneContent() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('VELOCIDAD DE CORRECCIÓN: 20 ms', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Text('ESCALA: CROMÁTICA NATURAL', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: 0.75,
          color: const Color(0xFF38BDF8),
          backgroundColor: Colors.white12,
        ),
      ],
    );
  }

  Widget _buildDroneContent() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text('FUNDAMENTAL: A4 (440 Hz)', style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text('+ QUINTA JUSTA: E5', style: TextStyle(color: Color(0xFFA855F7), fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSpectrogramContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(12, (i) {
        final height = (20 + (i * 7) % 50).toDouble();
        return Container(
          width: 8,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildChordAnalyzerContent() {
    return const Center(
      child: Text(
        'ACORDE DETECTADO: Cmaj7 (Do - Mi - Sol - Si)',
        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildGuidedLessonsContent() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('LECCIÓN 04: ESCALA MAYOR DIATÓNICA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text('PRECISIÓN: 98% (GRADO S)', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
