import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Modelo descriptivo de una pestaña de espacio de trabajo en la estación de trabajo.
class StudioWorkspaceTabItem {
  final int index;
  final String label;
  final IconData icon;
  final String shortcut;

  const StudioWorkspaceTabItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.shortcut,
  });
}

/// Barra de pestañas de espacios de trabajo estilo DAW comercial (StudioWorkspaceTabBar).
/// Ofrece selección rápida entre los espacios principales de Tunner:
/// - Aprender & Afinar (F1)
/// - Rack Modular Pro (F2)
/// - Notación & Partitura (F3)
/// - Consola DJ & Mezcla (F4)
class StudioWorkspaceTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final List<StudioWorkspaceTabItem> tabs;

  const StudioWorkspaceTabBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    this.tabs = defaultTabs,
  });

  static const List<StudioWorkspaceTabItem> defaultTabs = [
    StudioWorkspaceTabItem(
      index: 0,
      label: 'Aprender',
      icon: Icons.graphic_eq_rounded,
      shortcut: 'F1',
    ),
    StudioWorkspaceTabItem(
      index: 3,
      label: 'Rack Modular',
      icon: Icons.developer_board_rounded,
      shortcut: 'F2',
    ),
    StudioWorkspaceTabItem(
      index: 4,
      label: 'Partituras',
      icon: Icons.music_note_rounded,
      shortcut: 'F3',
    ),
    StudioWorkspaceTabItem(
      index: 5,
      label: 'Consola DJ',
      icon: Icons.album_rounded,
      shortcut: 'F4',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Container(
      height: 28.0,
      decoration: BoxDecoration(
        color: tokens.panelBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      padding: const EdgeInsets.all(2.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((tab) {
          final isSelected = activeIndex == tab.index;

          return Tooltip(
            message: '${tab.label} (${tab.shortcut})',
            waitDuration: const Duration(milliseconds: 400),
            child: InkWell(
              onTap: () => onTabSelected(tab.index),
              borderRadius: BorderRadius.circular(4.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tokens.panelHeaderBackground
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4.0),
                  border: isSelected
                      ? Border.all(color: tokens.borderHairline, width: tokens.borderWidth)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 13.0,
                      color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                        fontSize: 11.0,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }
}
