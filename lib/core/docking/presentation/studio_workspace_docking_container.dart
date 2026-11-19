import 'package:flutter/material.dart';
import '../domain/studio_dock_layout_entity.dart';
import '../domain/studio_dock_zone.dart';
import 'studio_dockable_panel_entity.dart';
import 'studio_dock_drop_zone_target.dart';
import 'studio_dockable_window_card.dart';
import 'studio_splitter_divider.dart';

/// Contenedor maestro de acoplamiento multi-panel tipo DAW profesional.
///
/// Soporta arrastre de ventanas hacia zonas (Izquierda, Centro, Derecha, Inferior),
/// redimensionamiento fluido con divisores y pestañas dinámicas cuando conviven múltiples herramientas.
class StudioWorkspaceDockingContainer extends StatefulWidget {
  final List<StudioDockablePanelEntity> panels;
  final StudioDockLayoutEntity? initialLayout;
  final ValueChanged<StudioDockLayoutEntity>? onLayoutChanged;

  const StudioWorkspaceDockingContainer({
    super.key,
    required this.panels,
    this.initialLayout,
    this.onLayoutChanged,
  });

  @override
  State<StudioWorkspaceDockingContainer> createState() =>
      _StudioWorkspaceDockingContainerState();
}

class _StudioWorkspaceDockingContainerState
    extends State<StudioWorkspaceDockingContainer> {
  late StudioDockLayoutEntity _layout;
  String? _maximizedPanelId;

  @override
  void initState() {
    super.initState();
    if (widget.initialLayout != null) {
      _layout = widget.initialLayout!;
    } else {
      _layout = StudioDockLayoutEntity.defaultLayout(
        centerPanelIds: widget.panels.map((p) => p.id).toList(),
      );
    }
  }

  void _handlePanelDropped(StudioDockablePanelEntity panel, StudioDockZone targetZone) {
    setState(() {
      _layout = _layout.movePanel(panel.id, targetZone);
      _maximizedPanelId = null; // Restaurar si estaba maximizado
    });
    widget.onLayoutChanged?.call(_layout);
  }

  void _applyPreset(StudioDockLayoutEntity preset) {
    // Asegurar que todos los paneles existentes en widget.panels se preserven
    var updated = preset;
    final allPresetIds = preset.zonePanelIds.values.expand((list) => list).toSet();
    final missingIds = widget.panels.map((p) => p.id).where((id) => !allPresetIds.contains(id)).toList();
    if (missingIds.isNotEmpty) {
      final currentCenter = List<String>.from(updated.zonePanelIds[StudioDockZone.center] ?? []);
      currentCenter.addAll(missingIds);
      final newMap = Map<StudioDockZone, List<String>>.from(updated.zonePanelIds);
      newMap[StudioDockZone.center] = currentCenter;
      updated = StudioDockLayoutEntity(
        zonePanelIds: newMap,
        leftSplitRatio: preset.leftSplitRatio,
        rightSplitRatio: preset.rightSplitRatio,
        bottomSplitRatio: preset.bottomSplitRatio,
      );
    }

    setState(() {
      _layout = updated;
      _maximizedPanelId = null;
    });
    widget.onLayoutChanged?.call(_layout);
  }

  Widget _buildLayoutPresetsBar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFF0F121A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2538))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.dashboard_customize, size: 14, color: Color(0xFF00E5FF)),
            const SizedBox(width: 6),
            const Text(
              'DISPOSICIÓN DAW:',
              style: TextStyle(
                color: Color(0xFF8E9BAE),
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            _buildPresetChip('Club Clásico', Icons.dashboard, () => _applyPreset(StudioDockLayoutEntity.presetClubClassic())),
            const SizedBox(width: 6),
            _buildPresetChip('Consola Fiel', Icons.album, () => _applyPreset(StudioDockLayoutEntity.presetHardwareFocus())),
            const SizedBox(width: 6),
            _buildPresetChip('Estudio Stems', Icons.grid_view, () => _applyPreset(StudioDockLayoutEntity.presetStemsStudio())),
            const SizedBox(width: 6),
            _buildPresetChip('3 Columnas', Icons.view_column, () => _applyPreset(StudioDockLayoutEntity.presetThreeColumns())),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 12, color: Color(0xFF8E9BAE)),
              label: const Text('Restablecer', style: TextStyle(fontSize: 10, color: Color(0xFF8E9BAE))),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
              ),
              onPressed: () => _applyPreset(widget.initialLayout ?? StudioDockLayoutEntity.presetClubClassic()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        backgroundColor: const Color(0xFF161C2A),
        side: const BorderSide(color: Color(0xFF263248), width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si hay un panel maximizado, ocupa el 100% de la pantalla
    if (_maximizedPanelId != null) {
      final panel = widget.panels.firstWhere(
        (p) => p.id == _maximizedPanelId,
        orElse: () => widget.panels.first,
      );
      return StudioDockableWindowCard(
        panel: panel,
        isMaximized: true,
        onToggleMaximize: () => setState(() => _maximizedPanelId = null),
        child: panel.builder?.call(context) ?? const SizedBox.shrink(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;
        final availableHeight = (totalHeight - 34.0).clamp(100.0, double.infinity);

        final leftPanels = _getPanelsForZone(StudioDockZone.left);
        final rightPanels = _getPanelsForZone(StudioDockZone.right);
        final bottomPanels = _getPanelsForZone(StudioDockZone.bottom);
        final centerPanels = _getPanelsForZone(StudioDockZone.center);

        // 1. Área Horizontal Superior (Izquierda + Centro + Derecha)
        final hasBottom = bottomPanels.isNotEmpty;
        final bottomHeight = hasBottom ? availableHeight * _layout.bottomSplitRatio : 0.0;
        final topHeight = availableHeight - bottomHeight;

        return Column(
          children: [
            // Barra de Presets de Disposición en 1 Clic
            _buildLayoutPresetsBar(),

            // Fila Superior (Left - Center - Right)
            SizedBox(
              height: hasBottom ? topHeight : availableHeight,
              child: Row(
                children: [
                  // Panel Izquierdo
                  if (leftPanels.isNotEmpty) ...[
                    SizedBox(
                      width: totalWidth * _layout.leftSplitRatio,
                      child: StudioDockDropZoneTarget(
                        zone: StudioDockZone.left,
                        onPanelDropped: (p) => _handlePanelDropped(p, StudioDockZone.left),
                        child: _buildZoneContent(leftPanels, StudioDockZone.left),
                      ),
                    ),
                    StudioSplitterDivider(
                      direction: Axis.horizontal,
                      onDragDelta: (delta) {
                        setState(() {
                          final newRatio = _layout.leftSplitRatio + (delta / totalWidth);
                          _layout = _layout.updateRatio(left: newRatio);
                        });
                        widget.onLayoutChanged?.call(_layout);
                      },
                    ),
                  ],

                  // Panel Central (Principal)
                  Expanded(
                    child: StudioDockDropZoneTarget(
                      zone: StudioDockZone.center,
                      onPanelDropped: (p) => _handlePanelDropped(p, StudioDockZone.center),
                      child: _buildZoneContent(centerPanels, StudioDockZone.center),
                    ),
                  ),

                  // Panel Derecho
                  if (rightPanels.isNotEmpty) ...[
                    StudioSplitterDivider(
                      direction: Axis.horizontal,
                      onDragDelta: (delta) {
                        setState(() {
                          final newRatio = _layout.rightSplitRatio - (delta / totalWidth);
                          _layout = _layout.updateRatio(right: newRatio);
                        });
                        widget.onLayoutChanged?.call(_layout);
                      },
                    ),
                    SizedBox(
                      width: totalWidth * _layout.rightSplitRatio,
                      child: StudioDockDropZoneTarget(
                        zone: StudioDockZone.right,
                        onPanelDropped: (p) => _handlePanelDropped(p, StudioDockZone.right),
                        child: _buildZoneContent(rightPanels, StudioDockZone.right),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Panel Inferior Dividido
            if (hasBottom) ...[
              StudioSplitterDivider(
                direction: Axis.vertical,
                onDragDelta: (delta) {
                  setState(() {
                    final newRatio = _layout.bottomSplitRatio - (delta / totalHeight);
                    _layout = _layout.updateRatio(bottom: newRatio);
                  });
                  widget.onLayoutChanged?.call(_layout);
                },
              ),
              SizedBox(
                height: bottomHeight - 6.0,
                child: StudioDockDropZoneTarget(
                  zone: StudioDockZone.bottom,
                  onPanelDropped: (p) => _handlePanelDropped(p, StudioDockZone.bottom),
                  child: _buildZoneContent(bottomPanels, StudioDockZone.bottom),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<StudioDockablePanelEntity> _getPanelsForZone(StudioDockZone zone) {
    final ids = _layout.zonePanelIds[zone] ?? [];
    return ids
        .map((id) => widget.panels.where((p) => p.id == id).firstOrNull)
        .whereType<StudioDockablePanelEntity>()
        .map((p) => p.copyWith(currentZone: zone))
        .toList();
  }

  Widget _buildZoneContent(
    List<StudioDockablePanelEntity> zonePanels,
    StudioDockZone zone,
  ) {
    if (zonePanels.isEmpty) {
      return Container(
        color: const Color(0xFF090B10),
        child: Center(
          child: Text(
            'Arrastra una herramienta aquí (${zone.displayName})',
            style: const TextStyle(color: Color(0xFF4A5568), fontSize: 11),
          ),
        ),
      );
    }

    if (zonePanels.length == 1) {
      final panel = zonePanels.first;
      return StudioDockableWindowCard(
        panel: panel,
        onMoveToZone: (newZone) => _handlePanelDropped(panel, newZone),
        onToggleMaximize: () => setState(() => _maximizedPanelId = panel.id),
        child: panel.builder?.call(context) ?? const SizedBox.shrink(),
      );
    }

    // Múltiples paneles en la misma zona: se despliegan con selector de pestañas
    return DefaultTabController(
      length: zonePanels.length,
      child: Column(
        children: [
          Container(
            height: 32,
            color: const Color(0xFF141926),
            child: TabBar(
              isScrollable: true,
              indicatorColor: const Color(0xFF00E5FF),
              labelColor: const Color(0xFF00E5FF),
              unselectedLabelColor: const Color(0xFF8E9BAE),
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: zonePanels.map((p) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.icon, size: 13),
                      const SizedBox(width: 6),
                      Text(p.title),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: zonePanels.map((panel) {
                return StudioDockableWindowCard(
                  panel: panel,
                  onMoveToZone: (newZone) => _handlePanelDropped(panel, newZone),
                  onToggleMaximize: () => setState(() => _maximizedPanelId = panel.id),
                  child: panel.builder?.call(context) ?? const SizedBox.shrink(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
