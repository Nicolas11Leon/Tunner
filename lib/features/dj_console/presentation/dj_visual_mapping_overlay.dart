import 'package:flutter/material.dart';
import '../domain/dj_hardware_catalog.dart';
import '../domain/dj_action.dart';
import '../domain/dj_hardware_skin_entity.dart';
import '../domain/dj_keymap_profile_entity.dart';
import '../domain/dj_skin_zone_entity.dart';
import 'dj_hardware_console_painter.dart';

/// Interactive vector overlay rendering real hardware DJ consoles and capturing keyboard/touch inputs.
class DjVisualMappingOverlay extends StatefulWidget {
  final DjHardwareSkinEntity skin;
  final DjSkinZoneEntity? selectedZone;
  final bool isLearnModeActive;
  final String? lastCapturedInput;
  final ValueChanged<DjSkinZoneEntity>? onZoneSelected;
  final ValueChanged<DjAction>? onActionTriggered;
  final VoidCallback? onToggleLearnMode;
  final double jogRotationA;
  final double jogRotationB;
  final DjKeymapProfileEntity? keymapProfile;
  final bool showKeyBadges;
  final ValueChanged<bool>? onToggleShowKeyBadges;
  final ValueChanged<String>? onSkinSelected;
  final VoidCallback? onOpenKeymapVisualizer;

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
    this.keymapProfile,
    this.showKeyBadges = true,
    this.onToggleShowKeyBadges,
    this.onSkinSelected,
    this.onOpenKeymapVisualizer,
  });

  @override
  State<DjVisualMappingOverlay> createState() => _DjVisualMappingOverlayState();
}

class _DjVisualMappingOverlayState extends State<DjVisualMappingOverlay> {
  late bool _showBadges;

  @override
  void initState() {
    super.initState();
    _showBadges = widget.showKeyBadges;
  }

  @override
  void didUpdateWidget(covariant DjVisualMappingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showKeyBadges != widget.showKeyBadges) {
      _showBadges = widget.showKeyBadges;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSkins = DjHardwareCatalog.allSkins();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode & Model Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: widget.isLearnModeActive ? const Color(0xFF261C02) : const Color(0xFF141722),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: widget.isLearnModeActive ? const Color(0xFFFFD700) : const Color(0xFF283244),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.isLearnModeActive ? Icons.videogame_asset : Icons.album,
                color: widget.isLearnModeActive ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
                size: 20,
              ),
              const SizedBox(width: 8.0),

              // Console Model Dropdown Switcher
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.skin.id,
                  dropdownColor: const Color(0xFF181F2C),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF), size: 18),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  items: allSkins.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      widget.onSkinSelected?.call(newId);
                    }
                  },
                ),
              ),

              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  widget.isLearnModeActive
                      ? (widget.selectedZone != null
                          ? 'ASIGNANDO [${widget.selectedZone!.label}]: Presiona cualquier tecla...'
                          : 'MODO MAPEO: Haz clic en un botón o perilla para asignarle una tecla')
                      : 'Acabado Industrial Fiel | 60 FPS Vector Canvas',
                  style: TextStyle(
                    color: widget.isLearnModeActive ? const Color(0xFFFFD700) : const Color(0xFF8E9BAE),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Last Captured Input Pill
              if (widget.lastCapturedInput != null && widget.isLearnModeActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF383848),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    widget.lastCapturedInput!,
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

              // Toggle Key Badges Switch
              IconButton(
                tooltip: _showBadges ? 'Ocultar Atajos de Teclas' : 'Mostrar Atajos de Teclas',
                icon: Icon(
                  _showBadges ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: _showBadges ? const Color(0xFF00E5FF) : const Color(0xFF7E8B9E),
                ),
                onPressed: () {
                  setState(() {
                    _showBadges = !_showBadges;
                  });
                  widget.onToggleShowKeyBadges?.call(_showBadges);
                },
              ),
              const SizedBox(width: 4.0),

              // Open QWERTY Keymap Visualizer Button
              if (widget.onOpenKeymapVisualizer != null) ...[
                TextButton.icon(
                  key: const Key('open_qwerty_visualizer_btn'),
                  onPressed: widget.onOpenKeymapVisualizer,
                  icon: const Icon(Icons.keyboard, size: 15, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'Teclado QWERTY',
                    style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: const Color(0xFF1E283C),
                  ),
                ),
                const SizedBox(width: 8.0),
              ],

              // Toggle Learn Mode Button
              TextButton.icon(
                key: const Key('toggle_learn_mode_btn'),
                onPressed: widget.onToggleLearnMode,
                icon: Icon(
                  widget.isLearnModeActive ? Icons.check_circle : Icons.tune,
                  size: 16,
                  color: widget.isLearnModeActive ? const Color(0xFF00E676) : const Color(0xFFB0B0C0),
                ),
                label: Text(
                  widget.isLearnModeActive ? 'Terminar' : 'Modo Mapeo',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isLearnModeActive ? const Color(0xFF00E676) : const Color(0xFFB0B0C0),
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
          aspectRatio: widget.skin.aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final localPos = details.localPosition;
                  final nx = localPos.dx / constraints.maxWidth;
                  final ny = localPos.dy / constraints.maxHeight;

                  final hitZone = widget.skin.findZoneAt(nx, ny);
                  if (hitZone != null) {
                    if (widget.isLearnModeActive) {
                      widget.onZoneSelected?.call(hitZone);
                    } else {
                      widget.onActionTriggered?.call(hitZone.action);
                    }
                  }
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: DjHardwareConsolePainter(
                      skin: widget.skin,
                      selectedZone: widget.selectedZone,
                      isLearnModeActive: widget.isLearnModeActive,
                      jogRotationA: widget.jogRotationA,
                      jogRotationB: widget.jogRotationB,
                      keymapProfile: widget.keymapProfile,
                      showKeyBadges: _showBadges,
                    ),
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
