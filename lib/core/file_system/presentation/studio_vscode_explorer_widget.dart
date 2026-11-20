import 'package:flutter/material.dart';
import '../../design_system/atoms/studio_listenable_builder.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/i_studio_workspace_file_system.dart';
import '../domain/studio_file_system_node.dart';
import 'studio_explorer_action_header.dart';
import 'studio_file_tree_tile.dart';
import 'studio_folder_tree_tile.dart';

/// Widget principal que emula con fidelidad el Explorador de Archivos y Carpetas de VS Code.
/// Soporta navegación recursiva profunda, creación de carpetas/archivos,
/// búsqueda instantánea y apertura contextual de documentos en herramientas DAW.
class StudioVsCodeExplorerWidget extends StatelessWidget {
  final IStudioWorkspaceFileSystem service;
  final VoidCallback? onFileTapped;

  const StudioVsCodeExplorerWidget({
    super.key,
    required this.service,
    this.onFileTapped,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return StudioListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final filteredRoot = service.filteredRootFolder;

        return Container(
          decoration: BoxDecoration(
            color: tokens.panelBackground,
            border: Border(right: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Herramientas Superior estilo VS Code ([+] File, [+] Folder, Refresh, Collapse, Search)
              StudioExplorerActionHeader(service: service),

              // Árbol jerárquico de carpetas y archivos
              Expanded(
                child: filteredRoot.children.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            service.searchQuery.isNotEmpty
                                ? 'No se encontraron archivos coincidentes con "${service.searchQuery}"'
                                : 'Proyecto vacío.\nUsa los botones superiores para agregar archivos o carpetas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: filteredRoot.children.map((node) {
                            if (node is StudioFolderEntity) {
                              return StudioFolderTreeTile(
                                key: ValueKey(node.id),
                                folder: node,
                                service: service,
                                depth: 0,
                                onFileTapped: onFileTapped,
                              );
                            } else if (node is StudioFileEntity) {
                              return StudioFileTreeTile(
                                key: ValueKey(node.id),
                                file: node,
                                service: service,
                                depth: 0,
                                onFileTapped: onFileTapped,
                              );
                            }
                            return const SizedBox.shrink();
                          }).toList(),
                        ),
                      ),
              ),

              // Barra inferior de estado del Explorador
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.panelHeaderBackground,
                  border: Border(top: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.data_usage, size: 10, color: tokens.accentPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${filteredRoot.totalFilesCount} Archivos',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ZLIB BINARY',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
