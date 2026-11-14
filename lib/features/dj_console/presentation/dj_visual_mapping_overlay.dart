import 'package:flutter/material.dart';
import '../domain/dj_action.dart';
import '../domain/dj_hardware_skin_entity.dart';
import '../domain/dj_skin_zone_entity.dart';
import 'dj_hardware_console_painter.dart';

/// Interactive vector overlay rendering the hardware skin and capturing touch/click inputs.
class DjVisualMappingOverlay extends StatelessWidget {
  final DjHardwareSkinEntity skin;
  final DjSkinZoneEntity? selectedZone;
  final bool isLearnModeActive;
  final String? lastCapturedInput;
  final ValueChanged<DjSkinZoneEntity>? onZoneSelected;
  final ValueChanged<DjAction>? onActionTriggered;
  final VoidCallback? onToggleLearnMode;
  final double jogRotationA;
  final double jogRotationB;

  const DjVisualMappingOverlay({
    super.key,
    required this.skin,
    this.selectedZone,
    this.isLearnModeActive = false,
    this.lastCapturedInput,
    this.onZoneSelected,
    this.onActionTriggered,
    this.onToggleLearnMode,
    this.jogRotationA = 0.0,
    this.jogRotationB = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isLearnModeActive ? const Color(0xFF261C02) : const Color(0xFF141418),
            border: Border(
              bottom: BorderSide(
                color: isLearnModeActive ? const Color(0xFFFFD700) : const Color(0xFF282832),
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isLearnModeActive ? Icons.videogame_asset : Icons.album,
                color: isLearnModeActive ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
                size: 20,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  isLearnModeActive
                      ? (selectedZone != null
                          ? 'ASIGNANDO: [${selectedZone!.label}] - Presiona tecla o boton de Xbox/PS'
                          : 'MODO MAPEO: Haz tap en un control en pantalla para vincularlo')
                      : 'CONSOLA VIRTUAL: ${skin.name}',
                  style: TextStyle(
                    color: isLearnModeActive ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (lastCapturedInput != null && isLearnModeActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF383848),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    lastCapturedInput!,
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
              ],
              TextButton.icon(
                key: const Key('toggle_learn_mode_btn'),
                onPressed: onToggleLearnMode,
                icon: Icon(
                  isLearnModeActive ? Icons.check_circle : Icons.tune,
                  size: 16,
                  color: isLearnModeActive ? const Color(0xFF00E676) : const Color(0xFFB0B0C0),
                ),
                label: Text(
                  isLearnModeActive ? 'Terminar' : 'Modo Mapeo',
                  style: TextStyle(
                    fontSize: 12,
                    color: isLearnModeActive ? const Color(0xFF00E676) : const Color(0xFFB0B0C0),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: const Color(0xFF1E1E26),
                ),
              ),
            ],
          ),
        ),

        // Responsive Console Canvas
        AspectRatio(
          aspectRatio: skin.aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final localPos = details.localPosition;
                  final nx = localPos.dx / constraints.maxWidth;
                  final ny = localPos.dy / constraints.maxHeight;

                  final hitZone = skin.findZoneAt(nx, ny);
                  if (hitZone != null) {
                    if (isLearnModeActive) {
                      onZoneSelected?.call(hitZone);
                    } else {
                      onActionTriggered?.call(hitZone.action);
                    }
                  }
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: DjHardwareConsolePainter(
                    skin: skin,
                    selectedZone: selectedZone,
                    isLearnModeActive: isLearnModeActive,
                    jogRotationA: jogRotationA,
                    jogRotationB: jogRotationB,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
