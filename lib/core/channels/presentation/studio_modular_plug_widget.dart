import 'package:flutter/material.dart';
import '../data/studio_patchbay_routing_service.dart';
import '../domain/studio_modular_plug.dart';
import 'studio_channel_modals.dart';

/// Widget visual que simula un Jack/Plug modular tipo hardware interactivo.
/// Permite conectar o desconectar herramientas a canales nombrables de estudio
/// y sincronizar bidireccionalmente los parámetros de audio y reproducción.
class StudioModularPlugWidget extends StatelessWidget {
  final StudioModularPlug plug;
  final StudioPatchbayRoutingService routingService;
  final double size;
  final bool showLabel;

  const StudioModularPlugWidget({
    super.key,
    required this.plug,
    required this.routingService,
    this.size = 28.0,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: routingService,
      builder: (context, _) {
        final currentPlug = routingService.plugs[plug.id] ?? plug;
        final colorHex = routingService.getColorForPlug(currentPlug);
        final plugColor = Color(colorHex);
        final isPulsing = routingService.activePulsePlugId == currentPlug.id;
        final connectedBus = currentPlug.connectedChannelId != null
            ? routingService.matrix.channels[currentPlug.connectedChannelId!]
            : null;

        final tooltipText = currentPlug.isConnected
            ? '${currentPlug.label} -> Conectado a ${connectedBus?.name ?? currentPlug.connectedChannelId} (${connectedBus?.activeBpm.toStringAsFixed(1) ?? '120'} BPM • ${connectedBus?.activeCamelotKey ?? '8B'})'
            : '${currentPlug.label} (Clic para conectar a un canal)';

        return Tooltip(
          message: tooltipText,
          child: InkWell(
            onTap: () => _showChannelSelectorMenu(context, currentPlug),
            borderRadius: BorderRadius.circular(size),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Conector Jack Circular Vectorial
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141720),
                      border: Border.all(
                        color: isPulsing ? Colors.white : plugColor,
                        width: isPulsing ? 2.5 : 1.8,
                      ),
                      boxShadow: currentPlug.isConnected
                          ? [
                              BoxShadow(
                                color: (isPulsing ? Colors.white : plugColor).withValues(alpha: isPulsing ? 0.9 : 0.45),
                                blurRadius: isPulsing ? 12 : 6,
                                spreadRadius: isPulsing ? 2 : 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.45,
                        height: size * 0.45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF07080C),
                          border: Border.all(color: const Color(0xFF2E3548), width: 1.0),
                        ),
                        child: Center(
                          child: Container(
                            width: size * 0.2,
                            height: size * 0.2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentPlug.isConnected ? plugColor : const Color(0xFF161922),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentPlug.label,
                          style: TextStyle(
                            color: currentPlug.isConnected ? Colors.white : const Color(0xFF8E9BAE),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          currentPlug.isConnected
                              ? (connectedBus?.shortCode ?? currentPlug.connectedChannelId!.replaceAll('_', ' ').toUpperCase())
                              : 'DESCONECTADO',
                          style: TextStyle(
                            color: currentPlug.isConnected ? plugColor : const Color(0xFF556075),
                            fontSize: 8.0,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChannelSelectorMenu(BuildContext context, StudioModularPlug targetPlug) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: routingService,
          builder: (ctx, _) {
            final channels = routingService.channels;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cable, color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CONECTAR PLUG: ${targetPlug.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 12),
                          label: const Text('Crear Canal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            foregroundColor: const Color(0xFF00E5FF),
                            side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            StudioCreateChannelModal.show(
                              context,
                              routingService: routingService,
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Selecciona el canal con el que deseas enlazar esta herramienta (sincroniza BPM, tono y audio en vivo):',
                      style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    // Lista de Canales Dinámica
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: channels.map((channel) {
                            final isSelected = targetPlug.connectedChannelId == channel.id;
                            final chColor = Color(channel.colorHex);

                            return InkWell(
                              onTap: () {
                                routingService.connectPlugToChannel(targetPlug.id, channel.id);
                                Navigator.of(ctx).pop();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? chColor.withValues(alpha: 0.22) : const Color(0xFF161C2A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? chColor : const Color(0xFF283248),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: chColor,
                                        boxShadow: [
                                          BoxShadow(
                                            color: chColor.withValues(alpha: 0.6),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          channel.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : const Color(0xFFB0B9C6),
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${channel.shortCode} • ${channel.activeBpm.toStringAsFixed(1)} BPM • ${channel.activeCamelotKey}',
                                          style: TextStyle(
                                            color: isSelected ? chColor : const Color(0xFF6B7280),
                                            fontSize: 9,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (channel.isPlaying) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                                        ),
                                        child: const Text(
                                          'PLAY',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    // Botón Desconectar Plug
                    OutlinedButton.icon(
                      icon: const Icon(Icons.power_off, size: 14, color: Color(0xFFFF5252)),
                      label: const Text(
                        'Desconectar Plug (Suspender Recepción de Parámetros)',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFF5252)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF5252)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        routingService.disconnectPlug(targetPlug.id);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
