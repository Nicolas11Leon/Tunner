import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../data/studio_patchbay_routing_service.dart';
import '../domain/studio_channel_bus.dart';
import 'studio_channel_modals.dart';

/// Barra de parcheo y control de Canales de Grado Profesional.
/// Soporta canales troncales y personalizados nombrables con monitorización
/// reactiva en tiempo real de BPM, tonalidad armónica y estado de transporte.
class StudioChannelPatchbayBarWidget extends StatelessWidget {
  final StudioPatchbayRoutingService routingService;

  const StudioChannelPatchbayBarWidget({
    super.key,
    required this.routingService,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return ListenableBuilder(
      listenable: routingService,
      builder: (context, _) {
        final channels = routingService.channels;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.panelHeaderBackground,
            border: Border(bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Icon(Icons.cable, color: tokens.accentPrimary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'MATRIZ PATCHBAY:',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 10),

                // Botón Crear Nuevo Canal
                ElevatedButton.icon(
                  key: const Key('create_custom_channel_btn'),
                  icon: const Icon(Icons.add_circle_outline, size: 13),
                  label: const Text(
                    'NUEVO CANAL',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accentPrimary.withValues(alpha: 0.15),
                    foregroundColor: tokens.accentPrimary,
                    side: BorderSide(color: tokens.accentPrimary, width: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => StudioCreateChannelModal.show(
                    context,
                    routingService: routingService,
                  ),
                ),
                const SizedBox(width: 10),

                // Lista de Canales (Troncales y Personalizados)
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
    final tokens = StudioThemeScope.tokensOf(context);
    final chColor = Color(channel.colorHex);
    final sources = routingService.matrix.findSourcesForChannel(channel.id);
    final sinks = routingService.matrix.findSinksForChannel(channel.id);
    final totalConnections = sources.length + sinks.length;
    final isCustom = channel.id.startsWith('canal_custom_');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
        border: Border.all(
          color: totalConnections > 0 ? chColor.withValues(alpha: 0.7) : tokens.borderHairline,
          width: totalConnections > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador LED de Estado de Canal
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: totalConnections > 0 ? chColor : tokens.textMuted,
              boxShadow: totalConnections > 0
                  ? [
                      BoxShadow(
                        color: chColor.withValues(alpha: 0.7),
                        blurRadius: channel.isPlaying ? 8 : 4,
                        spreadRadius: channel.isPlaying ? 1 : 0,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),

          // Código Corto del Canal y Nombre
          InkWell(
            onTap: () => StudioRenameChannelModal.show(
              context,
              routingService: routingService,
              channel: channel,
            ),
            borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        channel.shortCode,
                        style: TextStyle(
                          color: totalConnections > 0 ? tokens.textPrimary : tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.edit, size: 9, color: tokens.textMuted),
                    ],
                  ),
                  Text(
                    channel.name,
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Píldora de Parámetros en Vivo (BPM, Key, Play State)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.inputSurface,
              borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (channel.isPlaying) ...[
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.statusSuccess,
                    ),
                  ),
                ],
                Text(
                  '${channel.activeBpm.toStringAsFixed(1)} BPM • ${channel.activeCamelotKey}',
                  style: TextStyle(
                    color: channel.isPlaying ? tokens.statusSuccess : tokens.textSecondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Conteo de Plugs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: tokens.inputSurface,
              borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
            ),
            child: Text(
              '$totalConnections Plugs',
              style: TextStyle(
                color: totalConnections > 0 ? chColor : tokens.textMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Botón Mutear
          IconButton(
            tooltip: channel.isMuted ? 'Desmutear Canal' : 'Mutear Canal',
            icon: Icon(
              channel.isMuted ? Icons.volume_off : Icons.volume_up,
              size: 13,
              color: channel.isMuted ? tokens.statusError : tokens.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            onPressed: () => routingService.toggleChannelMute(channel.id),
          ),

          // Botón Eliminar si es canal personalizado
          if (isCustom) ...[
            IconButton(
              tooltip: 'Eliminar Canal Personalizado',
              icon: Icon(Icons.close, size: 12, color: tokens.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              onPressed: () => routingService.removeCustomChannel(channel.id),
            ),
          ],
        ],
      ),
    );
  }
}
