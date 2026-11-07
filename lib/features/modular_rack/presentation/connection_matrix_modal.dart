import 'package:flutter/material.dart';
import 'modular_rack_viewmodel.dart';
import '../domain/signal_type.dart';
import '../domain/port_id.dart';
import '../domain/module_connection.dart';

/// Modal interactivo de la Matriz de Ruteo y Gestión de Conexiones por ID.
class ConnectionMatrixModal extends StatefulWidget {
  final ModularRackViewModel viewModel;

  const ConnectionMatrixModal({super.key, required this.viewModel});

  static void show(BuildContext context, ModularRackViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ConnectionMatrixModal(viewModel: viewModel),
    );
  }

  @override
  State<ConnectionMatrixModal> createState() => _ConnectionMatrixModalState();
}

class _ConnectionMatrixModalState extends State<ConnectionMatrixModal> {
  PortId? _selectedSource;

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final connections = viewModel.signalBus.activeConnections;
    final modules = viewModel.activeModules;

    // Recopilar todos los puertos de salida disponibles
    final allOutputPorts = modules.expand((m) => m.outputPorts).toList();
    // Recopilar todos los puertos de entrada disponibles
    final allInputPorts = modules.expand((m) => m.inputPorts).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.cable, color: Color(0xFF10B981), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'MATRIZ DE RUTEO & CANALES POR ID',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Conecta salidas a entradas específicas o difunde en Broadcast global.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 16),

          // Sección 1: Conexiones activas
          const Text(
            'CONEXIONES ACTIVAS EN EL BUS',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (connections.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No hay conexiones activas. Selecciona una salida para comenzar a conectar.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            )
          else
            ...connections.map((conn) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    _getSignalIcon(conn.signalType),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${conn.sourcePort.ownerModuleId} [${conn.sourcePort.id}]',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            conn.scope == ConnectionScope.broadcast
                                ? '-> DIFUSIÓN GLOBAL (BROADCAST A TODOS)'
                                : '-> ${conn.destinationPort!.ownerModuleId} [${conn.destinationPort!.id}]',
                            style: TextStyle(
                              color: conn.scope == ConnectionScope.broadcast ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                      onPressed: () {
                        setState(() {
                          viewModel.disconnect(conn.connectionId);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),

          // Sección 2: Creador interactivo de nueva conexión
          const Text(
            'NUEVA CONEXIÓN DE SEÑAL',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Paso A: Seleccionar Salida
          Text(
            _selectedSource == null
                ? '1. Toca un puerto de salida emisor:'
                : '1. Emisor seleccionado: [${_selectedSource!.ownerModuleId} : ${_selectedSource!.id}]',
            style: TextStyle(
              color: _selectedSource == null ? Colors.white70 : const Color(0xFF38BDF8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: allOutputPorts.map((port) {
                final isSelected = _selectedSource == port;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text('${port.ownerModuleId} • ${port.displayName}'),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 10,
                    ),
                    backgroundColor: Colors.white12,
                    selectedColor: const Color(0xFF38BDF8),
                    onSelected: (selected) {
                      setState(() {
                        _selectedSource = selected ? port : null;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          if (_selectedSource != null) ...[
            const SizedBox(height: 12),
            // Paso B: Conectar a Destino Compatible o Broadcast
            const Text(
              '2. Selecciona destino compatible o haz Broadcast:',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Opción Broadcast
                ActionChip(
                  avatar: const Icon(Icons.podcasts, size: 14, color: Colors.black),
                  label: const Text('Difundir a Todos (Broadcast)'),
                  labelStyle: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  backgroundColor: const Color(0xFF38BDF8),
                  onPressed: () {
                    viewModel.connectPorts(_selectedSource!, _selectedSource!, broadcast: true);
                    setState(() => _selectedSource = null);
                  },
                ),
                // Puertos de entrada compatibles
                ...allInputPorts
                    .where((inPort) => _selectedSource!.canConnectTo(inPort))
                    .map((inPort) {
                  return ActionChip(
                    avatar: const Icon(Icons.arrow_downward, size: 14, color: Colors.white),
                    label: Text('${inPort.ownerModuleId} • ${inPort.displayName}'),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.25),
                    onPressed: () {
                      viewModel.connectPorts(_selectedSource!, inPort);
                      setState(() => _selectedSource = null);
                    },
                  );
                }),
              ],
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _getSignalIcon(SignalType type) {
    switch (type) {
      case SignalType.audioPcm:
        return const Icon(Icons.graphic_eq, color: Color(0xFF38BDF8), size: 18);
      case SignalType.pitchEvents:
        return const Icon(Icons.music_note, color: Color(0xFFA855F7), size: 18);
      case SignalType.musicalNotes:
        return const Icon(Icons.menu_book, color: Color(0xFFF59E0B), size: 18);
      case SignalType.temporalClock:
        return const Icon(Icons.access_time, color: Color(0xFF10B981), size: 18);
      case SignalType.transportControl:
        return const Icon(Icons.play_circle, color: Color(0xFFEC4899), size: 18);
    }
  }
}
