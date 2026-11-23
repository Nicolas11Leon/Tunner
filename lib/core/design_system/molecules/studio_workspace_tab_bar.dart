import 'package:flutter/material.dart';
import '../atoms/studio_icon.dart';
import '../domain/studio_icon_catalog.dart';
import '../domain/studio_workspace_tab_spec.dart';
import '../studio_theme_provider.dart';

/// Modelo descriptivo de una pestaña de espacio de trabajo en la estación de trabajo.
class StudioWorkspaceTabItem {
  final int index;
  final String label;
  final IconData icon;
  final StudioIconId? iconId;
  final String shortcut;

  const StudioWorkspaceTabItem({
    required this.index,
    required this.label,
    required this.icon,
    this.iconId,
    required this.shortcut,
  });

  factory StudioWorkspaceTabItem.fromSpec(StudioWorkspaceTabSpec spec) {
    return StudioWorkspaceTabItem(
      index: spec.index,
      label: spec.desktopLabel,
      icon: StudioIcon.fallbackIconFor(spec.iconId),
      iconId: spec.iconId,
      shortcut: spec.desktopShortcut,
    );
  }
}

/// Barra de pestañas de espacios de trabajo estilo DAW comercial (StudioWorkspaceTabBar).
/// Deriva sus 6 pestañas canónicas desde [StudioWorkspaceTabSpec.canonicalTabs].
class StudioWorkspaceTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final List<StudioWorkspaceTabItem>? tabs;

  const StudioWorkspaceTabBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    this.tabs,
  });

  static List<StudioWorkspaceTabItem> get defaultTabs =>
      StudioWorkspaceTabSpec.canonicalTabs
          .map(StudioWorkspaceTabItem.fromSpec)
          .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final effectiveTabs = tabs ?? defaultTabs;

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
          children: effectiveTabs.map((tab) {
          final isSelected = activeIndex == tab.index;

          return Tooltip(
            message: '${tab.label} (${tab.shortcut})',
            waitDuration: const Duration(milliseconds: 400),
            child: InkWell(
              onTap: () => onTabSelected(tab.index),
              borderRadius: BorderRadius.circular(4.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
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
                    if (tab.iconId != null)
                      StudioIcon(
                        tab.iconId!,
                        size: 13.0,
                        color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                        tintCustomAsset: true,
                      )
                    else
                      Icon(
                        tab.icon,
                        size: 13.0,
                        color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                      ),
                    const SizedBox(width: 4.0),
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
