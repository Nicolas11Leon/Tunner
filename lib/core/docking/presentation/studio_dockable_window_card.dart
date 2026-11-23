import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/studio_dock_zone.dart';
import 'studio_dockable_panel_entity.dart';

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
    final tokens = StudioThemeScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: tokens.borderHairline, width: 1.0),
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
              decoration: BoxDecoration(
                color: tokens.panelHeaderBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
                border: Border(bottom: BorderSide(color: tokens.borderHairline)),
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
                          color: tokens.elevatedSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.accentPrimary, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.canvasBackground.withValues(alpha: 0.8),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(panel.icon, color: tokens.accentPrimary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                panel.title,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.open_with, color: tokens.accentPrimary, size: 14),
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
                          child: Icon(Icons.drag_indicator, size: 16, color: tokens.textSecondary),
                        ),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Arrastrar para reubicar panel',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.drag_indicator, size: 16, color: tokens.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(panel.icon, size: 15, color: tokens.accentPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      panel.title,
                      style: TextStyle(
                        color: tokens.textPrimary,
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
                        icon: Icon(Icons.arrow_back, size: 14, color: tokens.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.left),
                      ),
                    if (panel.currentZone != StudioDockZone.center)
                      IconButton(
                        tooltip: 'Mover al Panel Central',
                        icon: Icon(Icons.center_focus_strong, size: 14, color: tokens.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.center),
                      ),
                    if (panel.currentZone != StudioDockZone.right)
                      IconButton(
                        tooltip: 'Mover al Panel Derecho',
                        icon: Icon(Icons.arrow_forward, size: 14, color: tokens.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.right),
                      ),
                    if (panel.currentZone != StudioDockZone.bottom)
                      IconButton(
                        tooltip: 'Mover al Panel Inferior',
                        icon: Icon(Icons.vertical_align_bottom, size: 14, color: tokens.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: () => onMoveToZone?.call(StudioDockZone.bottom),
                      ),
                  ],

                  // Selector rápido de zona de anclaje (Quick Move desplegable)
                  PopupMenuButton<StudioDockZone>(
                    tooltip: 'Menú de zonas',
                    icon: Icon(Icons.dashboard_customize, size: 15, color: tokens.textSecondary),
                    color: tokens.elevatedSurface,
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
                              color: isCurrent ? tokens.accentPrimary : tokens.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              zone.displayName,
                              style: TextStyle(
                                color: isCurrent ? tokens.accentPrimary : tokens.textPrimary,
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
                        color: tokens.textSecondary,
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
                      icon: Icon(Icons.close, size: 15, color: tokens.textSecondary),
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
