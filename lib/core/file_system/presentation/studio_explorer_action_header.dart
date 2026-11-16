import 'package:flutter/material.dart';
import '../data/studio_workspace_file_system_service.dart';
import 'studio_file_system_modals.dart';

/// Barra de acciones de cabecera estilo VS Code con botones de archivo/carpeta y buscador en vivo.
class StudioExplorerActionHeader extends StatefulWidget {
  final StudioWorkspaceFileSystemService service;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0F121C),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2538), width: 1.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_special_outlined, size: 14, color: Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'EXPLORADOR DE PROYECTO',
                  style: TextStyle(
                    color: Color(0xFF8E9BAE),
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // Botón Buscar
              IconButton(
                key: const Key('btn_toggle_search'),
                tooltip: 'Buscar / Filtrar archivos',
                icon: Icon(
                  _showSearchBar ? Icons.search_off : Icons.search,
                  size: 13,
                  color: _showSearchBar ? const Color(0xFF00E5FF) : const Color(0xFF8E9BAE),
                ),
                padding: EdgeInsets.zero,
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
                icon: const Icon(Icons.note_add_outlined, size: 14, color: Color(0xFF00E5FF)),
                padding: EdgeInsets.zero,
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
                icon: const Icon(Icons.create_new_folder_outlined, size: 14, color: Color(0xFFFFB74D)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () => StudioFileSystemModals.showCreateFolderModal(
                  context,
                  service: widget.service,
                ),
              ),

              // Botón Refrescar
              IconButton(
                key: const Key('btn_refresh_tree'),
                tooltip: 'Refrescar Explorador',
                icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF8E9BAE)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                onPressed: () {
                  _searchController.clear();
                  widget.service.setSearchQuery('');
                },
              ),

              // Botón Colapsar Todo
              IconButton(
                key: const Key('btn_collapse_all'),
                tooltip: 'Colapsar Carpetas',
                icon: const Icon(Icons.unfold_less, size: 14, color: Color(0xFF8E9BAE)),
                padding: EdgeInsets.zero,
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
                color: const Color(0xFF161B28),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF28324A)),
              ),
              child: TextField(
                key: const Key('file_explorer_search_input'),
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Filtrar archivos o carpetas...',
                  hintStyle: const TextStyle(color: Color(0xFF556075), fontSize: 10),
                  prefixIcon: const Icon(Icons.filter_list, size: 12, color: Color(0xFF00E5FF)),
                  prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 11, color: Colors.white54),
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
