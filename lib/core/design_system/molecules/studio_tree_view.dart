import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../atoms/studio_badge.dart';

/// Modelo de nodo individual dentro del árbol jerárquico de navegación.
class StudioTreeItem {
  final String id;
  final String title;
  final IconData icon;
  final String? shortcut;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onSelect;

  const StudioTreeItem({
    required this.id,
    required this.title,
    required this.icon,
    this.shortcut,
    this.badge,
    this.badgeColor,
    required this.onSelect,
  });
}

/// Sección o categoría colapsable del árbol jerárquico.
class StudioTreeSection {
  final String title;
  final List<StudioTreeItem> items;
  final bool initiallyExpanded;

  const StudioTreeSection({
    required this.title,
    required this.items,
    this.initiallyExpanded = true,
  });
}

/// Molécula de UI: Árbol Jerárquico de Navegación de Estudio (StudioTreeView).
///
/// Inspirado en la barra lateral de proyectos de Antigravity, VS Code y Adobe Creative Cloud.
/// Proporciona navegación estructurada por carpetas/secciones colapsables con selección activa,
/// glifos técnicos y atajos de teclado.
class StudioTreeView extends StatefulWidget {
  final List<StudioTreeSection> sections;
  final String selectedItemId;

  const StudioTreeView({
    super.key,
    required this.sections,
    required this.selectedItemId,
  });

  @override
  State<StudioTreeView> createState() => _StudioTreeViewState();
}

class _StudioTreeViewState extends State<StudioTreeView> {
  late final Map<String, bool> _expansionState;

  @override
  void initState() {
    super.initState();
    _expansionState = {
      for (final s in widget.sections) s.title: s.initiallyExpanded,
    };
  }

  void _toggleSection(String title) {
    setState(() {
      _expansionState[title] = !(_expansionState[title] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      itemCount: widget.sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = widget.sections[sectionIndex];
        final isExpanded = _expansionState[section.title] ?? true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de Categoría Colapsable
            InkWell(
              onTap: () => _toggleSection(section.title),
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      section.title.toUpperCase(),
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Elementos de la Sección
            if (isExpanded)
              ...section.items.map((item) {
                final isSelected = item.id == widget.selectedItemId;

                return Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 1.0, bottom: 1.0),
                  child: InkWell(
                    onTap: item.onSelect,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: isSelected ? tokens.hoverSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: isSelected
                            ? Border.all(
                                color: tokens.borderHairline,
                                width: tokens.borderWidth,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 14,
                            color: isSelected ? tokens.accentPrimary : tokens.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 4),
                            StudioBadge(
                              label: item.badge!,
                              accentColor: item.badgeColor,
                            ),
                          ],
                          if (item.shortcut != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.shortcut!,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 9.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}
