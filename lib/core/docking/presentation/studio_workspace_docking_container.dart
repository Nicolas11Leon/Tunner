import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/studio_dock_layout_entity.dart';
import '../domain/studio_dock_zone.dart';
import 'studio_dockable_panel_entity.dart';
import 'studio_dock_drop_zone_target.dart';
import 'studio_dockable_window_card.dart';
import 'studio_splitter_divider.dart';

/// Contenedor maestro de acoplamiento multi-panel tipo DAW profesional.
///
/// Soporta arrastre de ventanas hacia zonas (Izquierda, Centro, Derecha, Inferior, Flotante),
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
  final Map<String, Offset> _floatingOffsets = <String, Offset>{};

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
      if (targetZone == StudioDockZone.floating &&
          !_floatingOffsets.containsKey(panel.id)) {
        final index = _floatingOffsets.length;
        _floatingOffsets[panel.id] = Offset(24.0 + index * 20.0, 44.0 + index * 20.0);
      }
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

  Widget _buildLayoutPresetsBar(BuildContext context, double barHeight) {
    if (barHeight <= 0) return const SizedBox.shrink();
    final tokens = StudioThemeScope.of(context);

    return Container(
      height: barHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        border: Border(bottom: BorderSide(color: tokens.borderHairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.dashboard_customize, size: 14, color: tokens.accentPrimary),
            const SizedBox(width: 6),
            Text(
              'DISPOSICIÓN DAW:',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            _buildPresetChip(context, 'Club Clásico', Icons.dashboard, () => _applyPreset(StudioDockLayoutEntity.presetClubClassic())),
            const SizedBox(width: 6),
            _buildPresetChip(context, 'Consola Fiel', Icons.album, () => _applyPreset(StudioDockLayoutEntity.presetHardwareFocus())),
            const SizedBox(width: 6),
            _buildPresetChip(context, 'Estudio Stems', Icons.grid_view, () => _applyPreset(StudioDockLayoutEntity.presetStemsStudio())),
            const SizedBox(width: 6),
            _buildPresetChip(context, '3 Columnas', Icons.view_column, () => _applyPreset(StudioDockLayoutEntity.presetThreeColumns())),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: Icon(Icons.refresh, size: 12, color: tokens.textSecondary),
              label: Text('Restablecer', style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
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

  Widget _buildPresetChip(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final tokens = StudioThemeScope.of(context);
    return OutlinedButton.icon(
      icon: Icon(icon, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textPrimary,
        backgroundColor: tokens.elevatedSurface,
        side: BorderSide(color: tokens.borderHairline, width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.panels.isEmpty) return const SizedBox.shrink();

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
        final headerHeight = math.min(34.0, totalHeight);
        final minAvailableHeight = math.min(100.0, math.max(0.0, totalHeight - 34.0));
        final availableHeight = (totalHeight - headerHeight).clamp(minAvailableHeight, double.infinity);

        final leftPanels = _getPanelsForZone(StudioDockZone.left);
        final rightPanels = _getPanelsForZone(StudioDockZone.right);
        final bottomPanels = _getPanelsForZone(StudioDockZone.bottom);
        final centerPanels = _getPanelsForZone(StudioDockZone.center);
        final floatingPanels = _getPanelsForZone(StudioDockZone.floating);

        // 1. Área Horizontal Superior (Izquierda + Centro + Derecha)
        final hasBottom = bottomPanels.isNotEmpty;
        final bottomHeight = hasBottom ? availableHeight * _layout.bottomSplitRatio : 0.0;
        final minTopHeight = math.min(100.0, math.max(0.0, availableHeight - bottomHeight));
        final topHeight = (availableHeight - bottomHeight).clamp(minTopHeight, double.infinity);

        final splitterWidth = (leftPanels.isNotEmpty ? 6.0 : 0.0) + (rightPanels.isNotEmpty ? 6.0 : 0.0);
        final contentWidth = (totalWidth - splitterWidth).clamp(0.0, double.infinity);
        double leftWidth = leftPanels.isNotEmpty ? contentWidth * _layout.leftSplitRatio : 0.0;
        double rightWidth = rightPanels.isNotEmpty ? contentWidth * _layout.rightSplitRatio : 0.0;
        final maxSideWidth = contentWidth * 0.85;
        if (leftWidth + rightWidth > maxSideWidth && (leftWidth + rightWidth) > 0) {
          final scale = maxSideWidth / (leftWidth + rightWidth);
          leftWidth *= scale;
          rightWidth *= scale;
        }

        final minBottomBoxHeight = math.min(100.0, math.max(0.0, bottomHeight - 6.0));
        final bottomBoxHeight = (bottomHeight - 6.0).clamp(minBottomBoxHeight, double.infinity);

        return Stack(
          children: [
            Column(
              children: [
                // Barra de Presets de Disposición en 1 Clic
                _buildLayoutPresetsBar(context, headerHeight),

                // Fila Superior (Left - Center - Right)
                SizedBox(
                  height: hasBottom ? topHeight : availableHeight,
                  child: Row(
                    children: [
                      // Panel Izquierdo
                      if (leftPanels.isNotEmpty) ...[
                        SizedBox(
                          width: leftWidth,
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
                          width: rightWidth,
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
                  if (bottomHeight >= 6.0)
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
                    height: bottomBoxHeight,
                    child: StudioDockDropZoneTarget(
                      zone: StudioDockZone.bottom,
                      onPanelDropped: (p) => _handlePanelDropped(p, StudioDockZone.bottom),
                      child: _buildZoneContent(bottomPanels, StudioDockZone.bottom),
                    ),
                  ),
                ],
              ],
            ),

            // Capa de paneles en StudioDockZone.floating
            if (floatingPanels.isNotEmpty)
              ...floatingPanels.asMap().entries.map((entry) {
                final idx = entry.key;
                final panel = entry.value;
                final rawOffset = _floatingOffsets[panel.id] ??
                    Offset(16.0 + idx * 18.0, math.min(headerHeight + 8.0, math.max(0.0, totalHeight - 40.0)));
                final floatWidth = math.min(420.0, math.max(40.0, totalWidth * 0.75));
                final floatHeight = math.min(300.0, math.max(40.0, totalHeight * 0.75));
                final maxLeft = math.max(0.0, totalWidth - floatWidth);
                final maxTop = math.max(0.0, totalHeight - floatHeight);
                final clampedLeft = rawOffset.dx.clamp(0.0, maxLeft);
                final clampedTop = rawOffset.dy.clamp(0.0, maxTop);

                return Positioned(
                  key: ValueKey('floating_panel_${panel.id}'),
                  left: clampedLeft,
                  top: clampedTop,
                  width: floatWidth,
                  height: floatHeight,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _floatingOffsets[panel.id] = Offset(
                          (clampedLeft + details.delta.dx).clamp(0.0, maxLeft),
                          (clampedTop + details.delta.dy).clamp(0.0, maxTop),
                        );
                      });
                    },
                    child: Material(
                      elevation: 12,
                      color: Colors.transparent,
                      child: StudioDockableWindowCard(
                        panel: panel,
                        onMoveToZone: (newZone) => _handlePanelDropped(panel, newZone),
                        onToggleMaximize: () => setState(() => _maximizedPanelId = panel.id),
                        child: panel.builder?.call(context) ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                );
              }),
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
    final tokens = StudioThemeScope.of(context);

    if (zonePanels.isEmpty) {
      return Container(
        color: tokens.canvasBackground,
        child: Center(
          child: Text(
            'Arrastra una herramienta aquí (${zone.displayName})',
            style: TextStyle(color: tokens.textMuted, fontSize: 11),
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
      key: ValueKey('tab_ctrl_${zone.name}_${zonePanels.length}'),
      length: zonePanels.length,
      child: Column(
        children: [
          Container(
            height: 32,
            color: tokens.panelHeaderBackground,
            child: TabBar(
              isScrollable: true,
              indicatorColor: tokens.accentPrimary,
              labelColor: tokens.accentPrimary,
              unselectedLabelColor: tokens.textSecondary,
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
