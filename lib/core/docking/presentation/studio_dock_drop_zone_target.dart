import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/studio_dock_zone.dart';
import 'studio_dockable_panel_entity.dart';

/// Área de anclaje que detecta cuando un panel arrastrado se sitúa sobre ella para acoplarlo.
class StudioDockDropZoneTarget extends StatelessWidget {
  final StudioDockZone zone;
  final ValueChanged<StudioDockablePanelEntity> onPanelDropped;
  final Widget child;

  const StudioDockDropZoneTarget({
    super.key,
    required this.zone,
    required this.onPanelDropped,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return DragTarget<StudioDockablePanelEntity>(
      onWillAcceptWithDetails: (details) => details.data.currentZone != zone,
      onAcceptWithDetails: (details) {
        onPanelDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Stack(
          children: [
            child,
            if (isHovering) ...[
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.accentPrimary.withValues(alpha: 0.15),
                    border: Border.all(color: tokens.accentPrimary, width: 2.5),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.panelBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.accentPrimary),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.accentPrimary.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vertical_split, color: tokens.accentPrimary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ACOPLAR EN: ${zone.displayName.toUpperCase()}',
                            style: TextStyle(
                              color: tokens.accentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
