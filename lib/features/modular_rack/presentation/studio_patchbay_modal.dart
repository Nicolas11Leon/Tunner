import 'package:flutter/material.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../domain/module_connection.dart';
import '../domain/port_id.dart';
import '../domain/rack_module_entity.dart';
import '../domain/synergy_policy_engine.dart';
import 'modular_rack_viewmodel.dart';

/// Modal de Grado Profesional para el Patchbay Virtual y Matriz de Conectores.
/// Permite enrutar salidas a entradas compatibles con hiper-sincronía en el SignalBus.
class StudioPatchbayModal extends StatelessWidget {
  final ModularRackViewModel viewModel;
  final PortId? focusPort;

  const StudioPatchbayModal({
    super.key,
    required this.viewModel,
    this.focusPort,
  });

  static Future<void> show(BuildContext context, ModularRackViewModel viewModel, {PortId? focusPort}) {
    final tokens = StudioThemeScope.tokensOf(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      builder: (_) => StudioPatchbayModal(
        viewModel: viewModel,
        focusPort: focusPort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final modules = viewModel.activeModules;
    final activeConnections = viewModel.signalBus.activeConnections;

    // Recopilar todos los puertos de salida y de entrada de los módulos activos
    final allOutputs = <PortId>[];
    final allInputs = <PortId>[];

    for (final mod in modules) {
      allOutputs.addAll(mod.outputPorts);
      allInputs.addAll(mod.inputPorts);
    }

    if (focusPort != null) {
      allOutputs.sort((a, b) {
        final aMatch = a == focusPort ||
            (focusPort!.direction == PortDirection.input &&
                a.signalType == focusPort!.signalType &&
                a.ownerModuleId != focusPort!.ownerModuleId);
        final bMatch = b == focusPort ||
            (focusPort!.direction == PortDirection.input &&
                b.signalType == focusPort!.signalType &&
                b.ownerModuleId != focusPort!.ownerModuleId);
        if (aMatch == bMatch) return 0;
        return aMatch ? -1 : 1;
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de agarre
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título de la matriz de enrutamiento
          Row(
            children: [
              Icon(Icons.alt_route, color: tokens.accentPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'MATRIZ DE CONECTORES Y PATCHBAY VIRTUAL',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.accentSuccess.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(color: tokens.accentSuccess.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${activeConnections.length} RUTAS ACTIVAS',
                  style: TextStyle(
                    color: tokens.accentSuccess,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enruta las salidas de tus herramientas hacia entradas compatibles con latencia cero (<1 ms).',
            style: TextStyle(color: tokens.textMuted, fontSize: 11),
          ),
          if (focusPort != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.accentPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.center_focus_strong, size: 14, color: tokens.accentPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'FOCO ACTIVO: ${focusPort!.displayName} (${focusPort!.signalType.name})',
                      style: TextStyle(
                        color: tokens.accentPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Lista de conexiones activas
          Text(
            'CONEXIONES Y CABLES ACTIVOS',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          if (activeConnections.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.elevatedSurface,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
              ),
              child: Text(
                'No hay cables conectados. Selecciona una salida y una entrada abajo para enlazar.',
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activeConnections.length,
                separatorBuilder: (context, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final conn = activeConnections[index];
                  final sourceMod = modules.cast<RackModuleEntity?>().firstWhere(
                    (m) => m?.moduleId == conn.sourcePort.ownerModuleId,
                    orElse: () => null,
                  );
                  final destMod = conn.destinationPort != null
                      ? modules.cast<RackModuleEntity?>().firstWhere(
                          (m) => m?.moduleId == conn.destinationPort!.ownerModuleId,
                          orElse: () => null,
                        )
                      : null;

                  return Container(
                    width: 240,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(
                        color: tokens.accentPrimary.withValues(alpha: 0.4),
                        width: tokens.borderWidth,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.accentSuccess,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                conn.signalType.name.toUpperCase(),
                                style: TextStyle(
                                  color: tokens.accentPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: tokens.textMuted,
                              onPressed: () {
                                viewModel.disconnect(conn.connectionId);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${sourceMod?.title ?? conn.sourcePort.ownerModuleId} → ${conn.sourcePort.id}',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          conn.scope == ConnectionScope.broadcast
                              ? '→ Broadcast General'
                              : '→ ${destMod?.title ?? conn.destinationPort?.ownerModuleId} (${conn.destinationPort?.id})',
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),

          // Selector de nuevo enlace
          Text(
            'ENRUTAR NUEVA SEÑAL (SALIDA → ENTRADA)',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: allOutputs.isEmpty || allInputs.isEmpty
                ? Center(
                    child: Text(
                      'No hay suficientes puertos activos para crear enlaces.',
                      style: TextStyle(color: tokens.textMuted, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    itemCount: allOutputs.length,
                    itemBuilder: (context, outIndex) {
                      final outPort = allOutputs[outIndex];
                      final sourceMod = modules.cast<RackModuleEntity?>().firstWhere(
                        (m) => m?.moduleId == outPort.ownerModuleId,
                        orElse: () => null,
                      );

                      // Entradas compatibles con este tipo de señal
                      final compatibleInputs = allInputs.where(
                        (inp) => inp.ownerModuleId != outPort.ownerModuleId && inp.signalType == outPort.signalType,
                      ).toList();

                      final isFocusedOut = focusPort != null &&
                          (outPort == focusPort ||
                              (focusPort!.direction == PortDirection.input &&
                                  outPort.signalType == focusPort!.signalType &&
                                  outPort.ownerModuleId != focusPort!.ownerModuleId));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isFocusedOut
                              ? tokens.accentPrimary.withValues(alpha: 0.08)
                              : tokens.canvasBackground,
                          borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          border: Border.all(
                            color: isFocusedOut ? tokens.accentPrimary : tokens.borderHairline,
                            width: isFocusedOut ? 1.5 : tokens.borderWidth,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tokens.accentPrimary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'OUT',
                                    style: TextStyle(
                                      color: tokens.accentPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${sourceMod?.title ?? outPort.ownerModuleId} :: ${outPort.displayName}',
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  outPort.signalType.name,
                                  style: TextStyle(color: tokens.textMuted, fontSize: 9, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (compatibleInputs.isEmpty)
                              Text(
                                'No hay entradas compatibles activas para este tipo de señal.',
                                style: TextStyle(color: tokens.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: compatibleInputs.map((inp) {
                                  final isConnected = activeConnections.any(
                                    (c) => c.sourcePort == outPort && c.destinationPort == inp,
                                  );
                                  final validation = SynergyPolicyEngine.validateConnection(
                                    sourcePort: outPort,
                                    destinationPort: inp,
                                  );
                                  final isFocusedInput = focusPort == inp;
                                  final targetMod = modules.cast<RackModuleEntity?>().firstWhere(
                                    (m) => m?.moduleId == inp.ownerModuleId,
                                    orElse: () => null,
                                  );

                                  final chipBg = !validation.isApproved
                                      ? Colors.redAccent.withValues(alpha: 0.14)
                                      : isConnected
                                          ? tokens.accentSuccess.withValues(alpha: 0.2)
                                          : validation.isHyperSynergy
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                                              : tokens.elevatedSurface;

                                  final chipBorder = !validation.isApproved
                                      ? Colors.redAccent
                                      : isConnected
                                          ? tokens.accentSuccess
                                          : isFocusedInput
                                              ? tokens.accentPrimary
                                              : validation.isHyperSynergy
                                                  ? const Color(0xFFF59E0B)
                                                  : tokens.borderHairline;

                                  final chipIcon = !validation.isApproved
                                      ? Icons.block
                                      : isConnected
                                          ? Icons.check_circle
                                          : validation.isHyperSynergy
                                              ? Icons.auto_awesome
                                              : Icons.add_link;

                                  final chipColor = !validation.isApproved
                                      ? Colors.redAccent
                                      : isConnected
                                          ? tokens.accentSuccess
                                          : validation.isHyperSynergy
                                              ? const Color(0xFFF59E0B)
                                              : tokens.accentPrimary;

                                  return Tooltip(
                                    message: validation.rejectionReason ??
                                        validation.pedagogicalNote ??
                                        'Conectar ${outPort.displayName} con ${inp.displayName}',
                                    child: ActionChip(
                                      backgroundColor: chipBg,
                                      side: BorderSide(
                                        color: chipBorder,
                                        width: isFocusedInput ? 1.5 : 0.8,
                                      ),
                                      avatar: Icon(chipIcon, size: 14, color: chipColor),
                                      label: Text(
                                        '${targetMod?.title ?? inp.ownerModuleId} (${inp.id})',
                                        style: TextStyle(
                                          color: !validation.isApproved
                                              ? Colors.redAccent
                                              : isConnected
                                                  ? tokens.accentSuccess
                                                  : tokens.textPrimary,
                                          fontSize: 10,
                                          fontWeight: (isConnected || isFocusedInput)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (isConnected) {
                                          final conn = activeConnections.firstWhere(
                                            (c) => c.sourcePort == outPort && c.destinationPort == inp,
                                          );
                                          viewModel.disconnect(conn.connectionId);
                                          return;
                                        }
                                        if (!validation.isApproved) {
                                          final msg = [
                                            validation.rejectionReason ?? 'Conexion no permitida.',
                                            if (validation.pedagogicalNote != null) validation.pedagogicalNote!,
                                          ].join(' ');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(msg),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                          return;
                                        }
                                        viewModel.connectPorts(outPort, inp);
                                        if (validation.isHyperSynergy && validation.pedagogicalNote != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Hiper-Sinergia: ${validation.pedagogicalNote!}'),
                                              backgroundColor: const Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
