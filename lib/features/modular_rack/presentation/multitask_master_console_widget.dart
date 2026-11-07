import 'package:flutter/material.dart';
import 'modular_rack_viewmodel.dart';
import 'connection_matrix_modal.dart';
import 'universal_instrument_search_modal.dart';

/// Consola Central Multitarea de Coordinación y Control Maestro.
/// Muestra transporte global sincronizado (Play, Rec, Stop), estado de sincronía,
/// botón de Matriz de Conexiones por ID y selector del instrumento activo.
class MultitaskMasterConsoleWidget extends StatelessWidget {
  final ModularRackViewModel viewModel;

  const MultitaskMasterConsoleWidget({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final instrument = viewModel.activeInstrument;
        final primaryColor = instrument.visualProfile.primaryAccentColor;
        final isRunning = viewModel.isSessionRunning;
        final isRecording = viewModel.isRecording;
        final connectionsCount = viewModel.signalBus.activeConnections.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila superior: Selector de Instrumento & Matriz de IDs
              Row(
                children: [
                  // Badge interactivo de instrumento con su estética
                  InkWell(
                    onTap: () => UniversalInstrumentSearchModal.show(context, viewModel),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: instrument.visualProfile.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            instrument.displayName,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: primaryColor, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Botón de Matriz de Canales / IDs de Conexión
                  InkWell(
                    onTap: () => ConnectionMatrixModal.show(context, viewModel),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: connectionsCount > 0 ? const Color(0xFF10B981) : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cable,
                            size: 14,
                            color: connectionsCount > 0 ? const Color(0xFF10B981) : Colors.white60,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RUTEO ($connectionsCount)',
                            style: TextStyle(
                              color: connectionsCount > 0 ? const Color(0xFF10B981) : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Menú rápido de Presets de Estudio
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                    color: const Color(0xFF1E293B),
                    tooltip: 'Presets de Sesión',
                    onSelected: (preset) => viewModel.loadPreset(preset),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'calentamiento',
                        child: Text('🔥 Preset Calentamiento (Afinador + Dron + Metrónomo)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'transcripcion_partitura',
                        child: Text('🎼 Preset Transcripción (Tocar -> Escribir en Pentagrama)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'produccion_vocal',
                        child: Text('✨ Preset Vocal (Autotune + Grabador + Espectro)', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Fila inferior: Barra de Transporte Maestro Global
              Row(
                children: [
                  // Indicador luminoso de sincronía
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? const Color(0xFF10B981) : Colors.white24,
                      boxShadow: isRunning
                          ? [const BoxShadow(color: Color(0xFF10B981), blurRadius: 8, spreadRadius: 2)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRunning
                        ? (isRecording ? 'MULTITAREA: GRABANDO & EN VIVO' : 'MULTITAREA: ACTIVA')
                        : 'MULTITAREA: EN ESPERA',
                    style: TextStyle(
                      color: isRunning ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),

                  const Spacer(),

                  // Botón STOP Maestro
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.white70, size: 22),
                    tooltip: 'Detener Todo',
                    onPressed: isRunning || isRecording ? viewModel.stopMasterSession : null,
                  ),

                  // Botón PLAY / PAUSE Maestro
                  IconButton(
                    icon: Icon(
                      isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: primaryColor,
                      size: 32,
                    ),
                    tooltip: isRunning ? 'Pausar Sesión' : 'Iniciar Sesión',
                    onPressed: viewModel.toggleMasterSession,
                  ),

                  // Botón RECORD Maestro
                  IconButton(
                    icon: Icon(
                      isRecording ? Icons.radio_button_checked : Icons.fiber_manual_record,
                      color: isRecording ? const Color(0xFFEF4444) : Colors.white60,
                      size: 26,
                    ),
                    tooltip: isRecording ? 'Detener Grabación' : 'Grabar Sesión',
                    onPressed: viewModel.toggleMasterRecording,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
