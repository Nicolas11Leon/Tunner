import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/i_studio_workspace_file_system.dart';
import 'studio_file_system_modals.dart';

/// Barra de acciones de cabecera estilo VS Code con botones de archivo/carpeta y buscador en vivo.
class StudioExplorerActionHeader extends StatefulWidget {
  final IStudioWorkspaceFileSystem service;

  const StudioExplorerActionHeader({
    super.key,
    required this.service,
  });

  @override
  State<StudioExplorerActionHeader> createState() => _StudioExplorerActionHeaderState();
}

class _StudioExplorerActionHeaderState extends State<StudioExplorerActionHeader> {
  late final TextEditingController _searchController;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.service.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        border: Border(bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.folder_special_outlined, size: 14, color: tokens.accentPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'EXPLORADOR DE PROYECTO',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Botón Buscar
              IconButton(
                key: const Key('btn_toggle_search'),
                tooltip: 'Buscar / Filtrar archivos',
                icon: Icon(
                  _showSearchBar ? Icons.search_off : Icons.search,
                  size: 13,
                  color: _showSearchBar ? tokens.accentPrimary : tokens.textSecondary,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                      widget.service.setSearchQuery('');
                    }
                  });
                },
              ),

              // Botón Nuevo Archivo
              IconButton(
                key: const Key('btn_new_file'),
                tooltip: 'Nuevo Archivo...',
                icon: Icon(Icons.note_add_outlined, size: 14, color: tokens.accentPrimary),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () => StudioFileSystemModals.showCreateFileModal(
                  context,
                  service: widget.service,
                ),
              ),

              // Botón Nueva Carpeta
              IconButton(
                key: const Key('btn_new_folder'),
                tooltip: 'Nueva Carpeta...',
                icon: Icon(Icons.create_new_folder_outlined, size: 14, color: tokens.accentSecondary),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () => StudioFileSystemModals.showCreateFolderModal(
                  context,
                  service: widget.service,
                ),
              ),

              // Botón Abrir en Explorador del Sistema
              IconButton(
                key: const Key('btn_open_in_system_explorer'),
                tooltip: 'Abrir carpeta del proyecto en explorador',
                icon: Icon(Icons.folder_open_rounded, size: 14, color: tokens.textSecondary),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () => widget.service.openInSystemExplorer('/'),
              ),

              // Botón Refrescar
              IconButton(
                key: const Key('btn_refresh_tree'),
                tooltip: 'Refrescar Explorador',
                icon: Icon(Icons.refresh, size: 14, color: tokens.textSecondary),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  _searchController.clear();
                  widget.service.setSearchQuery('');
                  widget.service.refreshFromDisk();
                },
              ),

              // Botón Colapsar Todo
              IconButton(
                key: const Key('btn_collapse_all'),
                tooltip: 'Colapsar Carpetas',
                icon: Icon(Icons.unfold_less, size: 14, color: tokens.textSecondary),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(20, 20),
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () => widget.service.collapseAll(),
              ),
            ],
          ),

          // Barra de búsqueda expandible
          if (_showSearchBar) ...[
            const SizedBox(height: 4),
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: TextField(
                key: const Key('file_explorer_search_input'),
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: tokens.textPrimary, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Filtrar archivos o carpetas...',
                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 10),
                  prefixIcon: Icon(Icons.filter_list, size: 12, color: tokens.accentPrimary),
                  prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 11, color: tokens.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            widget.service.setSearchQuery('');
                          },
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onChanged: (query) => widget.service.setSearchQuery(query),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
