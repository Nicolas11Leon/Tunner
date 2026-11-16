import 'package:flutter/material.dart';
import '../domain/studio_dock_zone.dart';
import '../domain/studio_dockable_panel_entity.dart';

/// Tarjeta de ventana desacoplable y arrastrable tipo DAW profesional.
class StudioDockableWindowCard extends StatelessWidget {
  final StudioDockablePanelEntity panel;
  final Widget child;
  final ValueChanged<StudioDockZone>? onMoveToZone;
  final VoidCallback? onClose;
  final VoidCallback? onToggleMaximize;
  final bool isMaximized;

  const StudioDockableWindowCard({
    super.key,
    required this.panel,
    required this.child,
    this.onMoveToZone,
    this.onClose,
    this.onToggleMaximize,
    this.isMaximized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E14),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFF222B3D), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar con agarrador Draggable y atajo de doble clic
          GestureDetector(
            onDoubleTap: onToggleMaximize,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: const BoxDecoration(
                color: Color(0xFF141926),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
                border: Border(bottom: BorderSide(color: Color(0xFF222B3D))),
              ),
              child: Row(
                children: [
                  // Agarrador de Arrastre (Draggable Grip)
                  Draggable<StudioDockablePanelEntity>(
                    data: panel,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E283C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(panel.icon, color: const Color(0xFF00E5FF), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                panel.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.open_with, color: Color(0xFF00E5FF), size: 14),
                          ],
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.drag_indicator, size: 16, color: Color(0xFF7E8B9E)),
                        ),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Arrastrar para reubicar panel',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.drag_indicator, size: 16, color: Color(0xFF7E8B9E)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(panel.icon, size: 15, color: const Color(0xFF00E5FF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      panel.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Botones de Acción Directa de Acoplamiento Rápido (1-Click)
                  if (onMoveToZone != null) ...[
                    if (panel.currentZone != StudioDockZone.left)
                      IconButton(
                        tooltip: 'Mover al Panel Izquierdo',
                        icon: const Icon(Icons.arrow_back, size: 14, color: Color(0xFF8E9BAE)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.left),
                      ),
                    if (panel.currentZone != StudioDockZone.center)
                      IconButton(
                        tooltip: 'Mover al Panel Central',
                        icon: const Icon(Icons.center_focus_strong, size: 14, color: Color(0xFF8E9BAE)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.center),
                      ),
                    if (panel.currentZone != StudioDockZone.right)
                      IconButton(
                        tooltip: 'Mover al Panel Derecho',
                        icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF8E9BAE)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.right),
                      ),
                    if (panel.currentZone != StudioDockZone.bottom)
                      IconButton(
                        tooltip: 'Mover al Panel Inferior',
                        icon: const Icon(Icons.vertical_align_bottom, size: 14, color: Color(0xFF8E9BAE)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.bottom),
                      ),
                  ],

                  // Selector rápido de zona de anclaje (Quick Move desplegable)
                  PopupMenuButton<StudioDockZone>(
                    tooltip: 'Menú de zonas',
                    icon: const Icon(Icons.dashboard_customize, size: 15, color: Color(0xFF8E9BAE)),
                    color: const Color(0xFF181F2C),
                    padding: EdgeInsets.zero,
                    itemBuilder: (ctx) => StudioDockZone.values.map((zone) {
                      final isCurrent = panel.currentZone == zone;
                      return PopupMenuItem<StudioDockZone>(
                        value: zone,
                        child: Row(
                          children: [
                            Icon(
                              isCurrent ? Icons.check_circle : Icons.circle_outlined,
                              size: 14,
                              color: isCurrent ? const Color(0xFF00E5FF) : Colors.white60,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              zone.displayName,
                              style: TextStyle(
                                color: isCurrent ? const Color(0xFF00E5FF) : Colors.white,
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onSelected: onMoveToZone,
                  ),

                  // Botón Maximizar / Restaurar
                  if (onToggleMaximize != null) ...[
                    IconButton(
                      tooltip: isMaximized ? 'Restaurar' : 'Maximizar (Doble clic en barra)',
                      icon: Icon(
                        isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                        size: 16,
                        color: const Color(0xFF8E9BAE),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: onToggleMaximize,
                    ),
                  ],

                  // Botón Cerrar
                  if (panel.isClosable && onClose != null) ...[
                    IconButton(
                      tooltip: 'Cerrar Panel',
                      icon: const Icon(Icons.close, size: 15, color: Color(0xFF8E9BAE)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: onClose,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Cuerpo de la Ventana aislado con RepaintBoundary para alto rendimiento
          Expanded(child: RepaintBoundary(child: child)),
        ],
      ),
    );
  }
}
