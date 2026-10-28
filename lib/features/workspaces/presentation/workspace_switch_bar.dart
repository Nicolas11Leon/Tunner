import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.staffLinesColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: WorkspaceType.values.map((workspace) {
          final isSelected = workspace == activeWorkspace;
          final keyName = 'workspace_tab_${workspace.serializedKey}';

          return Expanded(
            child: InkWell(
              key: Key(keyName),
              onTap: () => onWorkspaceSelected(workspace),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.primaryAccent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? palette.primaryAccent.withValues(alpha: 0.7)
                        : Colors.transparent,
                    width: isSelected ? 1.2 : 0.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _iconForWorkspace(workspace),
                      size: 16,
                      color: isSelected ? palette.primaryAccent : palette.textMutedColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        workspace.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? palette.primaryAccent : palette.textColor,
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

  IconData _iconForWorkspace(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.learning:
        return Icons.school_outlined;
      case WorkspaceType.composition:
        return Icons.auto_stories_outlined;
      case WorkspaceType.production:
        return Icons.graphic_eq_outlined;
    }
  }
}
