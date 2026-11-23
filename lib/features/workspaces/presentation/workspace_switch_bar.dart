import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../domain/workspace_type.dart';

/// Barra de conmutación de espacios de trabajo minimalista y fluida.
/// Permite alternar entre los modos Aprender, Componer y Producir en un solo toque.
class WorkspaceSwitchBar extends StatelessWidget {
  final WorkspaceType activeWorkspace;
  final ValueChanged<WorkspaceType> onWorkspaceSelected;
  final TunnerThemePalette palette;

  const WorkspaceSwitchBar({
    super.key,
    required this.activeWorkspace,
    required this.onWorkspaceSelected,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
        border: Border.all(
          color: tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Row(
        children: WorkspaceType.values.map((workspace) {
          final isSelected = workspace == activeWorkspace;
          final keyName = 'workspace_tab_${workspace.serializedKey}';

          return Expanded(
            child: InkWell(
              key: Key(keyName),
              onTap: () => onWorkspaceSelected(workspace),
              borderRadius: BorderRadius.circular(tokens.radiusMedium),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tokens.elevatedSurface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  border: Border.all(
                    color: isSelected
                        ? tokens.borderFocus
                        : Colors.transparent,
                    width: tokens.borderWidth,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StudioIcon(
                      _iconIdForWorkspace(workspace),
                      size: 15,
                      color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                      tintCustomAsset: true,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        workspace.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  StudioIconId _iconIdForWorkspace(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.learning:
        return StudioIconId.modulePedagogy;
      case WorkspaceType.composition:
        return StudioIconId.moduleScoreSheet;
      case WorkspaceType.production:
        return StudioIconId.moduleSpectrogram;
    }
  }
}
