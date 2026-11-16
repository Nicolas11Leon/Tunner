import 'package:flutter/material.dart';
import '../data/studio_patchbay_routing_service.dart';
import '../domain/studio_channel_bus.dart';

/// Barra de parcheo y control de Canales Troncales (Canal A, B, C, D) de grado profesional.
class StudioChannelPatchbayBarWidget extends StatelessWidget {
  final StudioPatchbayRoutingService routingService;

  const StudioChannelPatchbayBarWidget({
    super.key,
    required this.routingService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: routingService,
      builder: (context, _) {
        final channels = routingService.channels;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF0C0E15),
            border: Border(bottom: BorderSide(color: Color(0xFF1E2538))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.cable, color: Color(0xFF00E5FF), size: 16),
                const SizedBox(width: 8),
                const Text(
                  'MATRIZ PATCHBAY:',
                  style: TextStyle(
                    color: Color(0xFF8E9BAE),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 12),

                // Lista de Canales A, B, C, D
                ...channels.map((channel) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildChannelPill(context, channel),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChannelPill(BuildContext context, StudioChannelBus channel) {
    final chColor = Color(channel.colorHex);
    final sources = routingService.matrix.findSourcesForChannel(channel.id);
    final sinks = routingService.matrix.findSinksForChannel(channel.id);
    final totalConnections = sources.length + sinks.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: totalConnections > 0 ? chColor.withValues(alpha: 0.6) : const Color(0xFF242C3E),
          width: totalConnections > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: totalConnections > 0 ? chColor : const Color(0xFF384358),
              boxShadow: totalConnections > 0
                  ? [
                      BoxShadow(
                        color: chColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            channel.shortCode,
            style: TextStyle(
              color: totalConnections > 0 ? Colors.white : const Color(0xFF8E9BAE),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$totalConnections Plugs',
              style: TextStyle(
                color: totalConnections > 0 ? chColor : const Color(0xFF556075),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: channel.isMuted ? 'Desmutear Canal' : 'Mutear Canal',
            icon: Icon(
              channel.isMuted ? Icons.volume_off : Icons.volume_up,
              size: 13,
              color: channel.isMuted ? const Color(0xFFFF5252) : const Color(0xFF8E9BAE),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            onPressed: () => routingService.toggleChannelMute(channel.id),
          ),
        ],
      ),
    );
  }
}
