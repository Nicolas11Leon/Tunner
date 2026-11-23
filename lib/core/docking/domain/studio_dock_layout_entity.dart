import 'studio_dock_zone.dart';

/// Estado de distribución inmutable del sistema multi-panel de ventanas.
class StudioDockLayoutEntity {
  final Map<StudioDockZone, List<String>> zonePanelIds;
  final double leftSplitRatio;
  final double rightSplitRatio;
  final double bottomSplitRatio;

  const StudioDockLayoutEntity({
    required this.zonePanelIds,
    this.leftSplitRatio = 0.28,
    this.rightSplitRatio = 0.32,
    this.bottomSplitRatio = 0.35,
  });

  /// Configuración canónica por defecto para la estación de trabajo.
  factory StudioDockLayoutEntity.defaultLayout({
    List<String> centerPanelIds = const ['dj_console_main'],
    List<String> leftPanelIds = const [],
    List<String> rightPanelIds = const [],
    List<String> bottomPanelIds = const [],
  }) {
    return StudioDockLayoutEntity(
      zonePanelIds: {
        StudioDockZone.center: List.from(centerPanelIds),
        StudioDockZone.left: List.from(leftPanelIds),
        StudioDockZone.right: List.from(rightPanelIds),
        StudioDockZone.bottom: List.from(bottomPanelIds),
        StudioDockZone.floating: [],
      },
    );
  }

  /// Preset 1: DJ Club Clásico (Centro: Consola + Formas de Onda, Derecha: Mezclador, Inferior: Stems)
  factory StudioDockLayoutEntity.presetClubClassic() {
    return const StudioDockLayoutEntity(
      zonePanelIds: {
        StudioDockZone.center: ['panel_hardware_console', 'panel_waveforms'],
        StudioDockZone.right: ['panel_club_mixer'],
        StudioDockZone.bottom: ['panel_stems_sampler'],
        StudioDockZone.left: [],
        StudioDockZone.floating: [],
      },
      leftSplitRatio: 0.25,
      rightSplitRatio: 0.32,
      bottomSplitRatio: 0.35,
    );
  }

  /// Preset 2: Consola Hardware Fiel a Pantalla Principal (Centro: Consola pura, Inferior: Waveforms)
  factory StudioDockLayoutEntity.presetHardwareFocus() {
    return const StudioDockLayoutEntity(
      zonePanelIds: {
        StudioDockZone.center: ['panel_hardware_console'],
        StudioDockZone.bottom: ['panel_waveforms'],
        StudioDockZone.left: [],
        StudioDockZone.right: [],
        StudioDockZone.floating: [],
      },
      bottomSplitRatio: 0.20,
    );
  }

  /// Preset 3: Estudio 4-Stems & Performance (Izquierda: Mezclador, Centro: Consola, Inferior: Stems y Sampler)
  factory StudioDockLayoutEntity.presetStemsStudio() {
    return const StudioDockLayoutEntity(
      zonePanelIds: {
        StudioDockZone.left: ['panel_club_mixer'],
        StudioDockZone.center: ['panel_hardware_console', 'panel_waveforms'],
        StudioDockZone.bottom: ['panel_stems_sampler'],
        StudioDockZone.right: [],
        StudioDockZone.floating: [],
      },
      leftSplitRatio: 0.30,
      bottomSplitRatio: 0.38,
    );
  }

  /// Preset 4: Dividido DAW en 3 Columnas (Izquierda: Stems, Centro: Consola/Ondas, Derecha: Mezclador)
  factory StudioDockLayoutEntity.presetThreeColumns() {
    return const StudioDockLayoutEntity(
      zonePanelIds: {
        StudioDockZone.left: ['panel_stems_sampler'],
        StudioDockZone.center: ['panel_hardware_console', 'panel_waveforms'],
        StudioDockZone.right: ['panel_club_mixer'],
        StudioDockZone.bottom: [],
        StudioDockZone.floating: [],
      },
      leftSplitRatio: 0.28,
      rightSplitRatio: 0.30,
      bottomSplitRatio: 0.30,
    );
  }

  /// Mueve un panel de su zona actual a una nueva zona de destino.
  StudioDockLayoutEntity movePanel(String panelId, StudioDockZone targetZone) {
    final updated = <StudioDockZone, List<String>>{};
    for (final zone in StudioDockZone.values) {
      final list = List<String>.from(zonePanelIds[zone] ?? []);
      list.remove(panelId);
      updated[zone] = list;
    }

    // Agregar a la zona destino
    final targetList = updated[targetZone] ?? [];
    if (!targetList.contains(panelId)) {
      targetList.add(panelId);
    }
    updated[targetZone] = targetList;

    return StudioDockLayoutEntity(
      zonePanelIds: updated,
      leftSplitRatio: leftSplitRatio,
      rightSplitRatio: rightSplitRatio,
      bottomSplitRatio: bottomSplitRatio,
    );
  }

  /// Actualiza la proporción de división de un panel garantizando left + right <= 0.85.
  StudioDockLayoutEntity updateRatio({
    double? left,
    double? right,
    double? bottom,
  }) {
    double newLeft = (left ?? leftSplitRatio).clamp(0.15, 0.60);
    double newRight = (right ?? rightSplitRatio).clamp(0.15, 0.60);
    if (newLeft + newRight > 0.85) {
      if (left != null && right == null) {
        newLeft = (0.85 - newRight).clamp(0.15, 0.60);
      } else if (right != null && left == null) {
        newRight = (0.85 - newLeft).clamp(0.15, 0.60);
      } else {
        final scale = 0.85 / (newLeft + newRight);
        newLeft *= scale;
        newRight *= scale;
      }
    }
    return StudioDockLayoutEntity(
      zonePanelIds: zonePanelIds,
      leftSplitRatio: newLeft,
      rightSplitRatio: newRight,
      bottomSplitRatio: (bottom ?? bottomSplitRatio).clamp(0.15, 0.60),
    );
  }

  /// Retorna la zona donde se encuentra ubicado un panel.
  StudioDockZone? findZoneOfPanel(String panelId) {
    for (final entry in zonePanelIds.entries) {
      if (entry.value.contains(panelId)) {
        return entry.key;
      }
    }
    return null;
  }
}
