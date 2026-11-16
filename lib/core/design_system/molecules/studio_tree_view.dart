import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../studio_design_tokens.dart';
import '../atoms/studio_badge.dart';

/// Modelo de nodo individual dentro del árbol jerárquico de navegación (Sesión / Archivo / Vista).
class StudioTreeItem {
  final String id;
  final String title;
  final IconData? icon;
  final String? subtitle;
  final String? timestamp;
  final Color? statusDotColor;
  final bool hasDragHandle;
  final String? shortcut;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onSelect;

  const StudioTreeItem({
    required this.id,
    required this.title,
    this.icon,
    this.subtitle,
    this.timestamp,
    this.statusDotColor,
    this.hasDragHandle = false,
    this.shortcut,
    this.badge,
    this.badgeColor,
    required this.onSelect,
  });
}

/// Carpeta colapsable dentro de una sección de proyectos (Directorio / Grupo).
class StudioTreeFolder {
  final String id;
  final String title;
  final IconData icon;
  final IconData expandedIcon;
  final List<StudioTreeItem> items;
  final bool initiallyExpanded;
  final Color? accentColor;

  const StudioTreeFolder({
    required this.id,
    required this.title,
    this.icon = Icons.folder_outlined,
    this.expandedIcon = Icons.folder_open_outlined,
    required this.items,
    this.initiallyExpanded = true,
    this.accentColor,
  });
}

/// Sección o categoría de primer nivel del árbol jerárquico.
class StudioTreeSection {
  final String title;
  final List<StudioTreeItem> items;
  final List<StudioTreeFolder> folders;
  final bool initiallyExpanded;
  final Widget? headerAction;

  const StudioTreeSection({
    required this.title,
    this.items = const [],
    this.folders = const [],
    this.initiallyExpanded = true,
    this.headerAction,
  });
}

/// Molécula de UI: Árbol Jerárquico de Navegación de Estudio (StudioTreeView).
///
/// Inspirado con exactitud en la barra lateral de proyectos de Antigravity IDE,
/// VS Code y Adobe Creative Cloud (Audition / Premiere).
/// Proporciona estructura de carpetas colapsables con chevron animado, iconos de carpeta,
/// drag handles, dots de estado en vivo, timestamps relativos y badges técnicos.
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
  late final Map<String, bool> _sectionExpansionState;
  late final Map<String, bool> _folderExpansionState;

  @override
  void initState() {
    super.initState();
    _sectionExpansionState = {
      for (final s in widget.sections) s.title: s.initiallyExpanded,
    };
    _folderExpansionState = {
      for (final s in widget.sections)
        for (final f in s.folders) f.id: f.initiallyExpanded,
    };
  }

  void _toggleSection(String title) {
    setState(() {
      _sectionExpansionState[title] = !(_sectionExpansionState[title] ?? true);
    });
  }

  void _toggleFolder(String folderId) {
    setState(() {
      _folderExpansionState[folderId] = !(_folderExpansionState[folderId] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
      itemCount: widget.sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = widget.sections[sectionIndex];
        final isSectionExpanded = _sectionExpansionState[section.title] ?? true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cabecera de Categoría Principal (ej. "Projects")
            if (section.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                child: InkWell(
                  onTap: () => _toggleSection(section.title),
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        if (section.headerAction != null)
                          section.headerAction!
                        else ...[
                          Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: tokens.textMuted.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.create_new_folder_outlined,
                            size: 13,
                            color: tokens.textMuted.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Contenido de la Sección (Carpetas e Items)
            if (isSectionExpanded) ...[
              // Carpetas anidadas (ej. tunner, Pizza, Orion...)
              ...section.folders.map((folder) => _buildFolderWidget(folder, tokens)),

              // Items directos sin carpeta (retrocompatibilidad)
              ...section.items.map((item) => _buildItemWidget(item, tokens, indentLevel: 0)),
            ],

            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Widget _buildFolderWidget(StudioTreeFolder folder, StudioDesignTokens tokens) {
    final isFolderExpanded = _folderExpansionState[folder.id] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de la Carpeta
        InkWell(
          onTap: () => _toggleFolder(folder.id),
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isFolderExpanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 140),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 13,
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isFolderExpanded ? folder.expandedIcon : folder.icon,
                  size: 14,
                  color: folder.accentColor ?? tokens.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    folder.title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Nodos Hijos de la Carpeta (Indentados con sangría técnica)
        if (isFolderExpanded)
          ...folder.items.map(
            (item) => _buildItemWidget(item, tokens, indentLevel: 1),
          ),
      ],
    );
  }

  Widget _buildItemWidget(
    StudioTreeItem item,
    StudioDesignTokens tokens, {
    required int indentLevel,
  }) {
    final isSelected = item.id == widget.selectedItemId;
    final double leftPadding = indentLevel == 0 ? 10.0 : 20.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, right: 4.0, top: 1.0, bottom: 1.0),
      child: InkWell(
        onTap: item.onSelect,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.5),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.hoverSurface.withValues(alpha: 0.85)
                : Colors.transparent,
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
              // Drag Handle opcional o indicador de selección
              if (item.hasDragHandle || isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 12,
                    color: isSelected ? tokens.accentPrimary : tokens.textMuted,
                  ),
                )
              else if (item.statusDotColor != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: item.statusDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // Icono de archivo o glifo técnico
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 13,
                  color: isSelected ? tokens.accentPrimary : tokens.textSecondary,
                ),
                const SizedBox(width: 7),
              ],

              // Título con truncado elegante
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Badge opcional (ej. "Review", "Live")
              if (item.badge != null) ...[
                const SizedBox(width: 4),
                StudioBadge(
                  label: item.badge!,
                  accentColor: item.badgeColor,
                ),
              ],

              // Timestamp o indicador relativo (ej. "1h ago", "3d", "440 Hz")
              if (item.timestamp != null) ...[
                const SizedBox(width: 6),
                Text(
                  item.timestamp!,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],

              // Atajo de teclado
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
  }
}
