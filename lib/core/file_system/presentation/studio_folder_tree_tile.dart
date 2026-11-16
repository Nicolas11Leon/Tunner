import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../data/studio_workspace_file_system_service.dart';
import '../domain/studio_file_system_node.dart';
import 'studio_file_system_modals.dart';
import 'studio_file_tree_tile.dart';

/// Tile atomizado recursivo para renderizar una carpeta en el explorador estilo VS Code.
class StudioFolderTreeTile extends StatelessWidget {
  final StudioFolderEntity folder;
  final StudioWorkspaceFileSystemService service;
  final int depth;
  final VoidCallback? onFileTapped;

  const StudioFolderTreeTile({
    super.key,
    required this.folder,
    required this.service,
    this.depth = 0,
    this.onFileTapped,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final isSelected = service.selectedNodeId == folder.id;
    final isActiveFolder = service.activeFolderId == folder.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila de encabezado de carpeta
        InkWell(
          onTap: () => service.toggleFolder(folder.id),
          borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
          child: Container(
            padding: EdgeInsets.only(
              left: 4.0 + (depth * 14.0),
              right: 6.0,
              top: 4.0,
              bottom: 4.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? tokens.accentPrimary.withValues(alpha: 0.14)
                  : isActiveFolder
                      ? tokens.hoverSurface
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
              border: isSelected
                  ? Border.all(color: tokens.borderFocus, width: 1.0)
                  : null,
            ),
            child: Row(
              children: [
                // Flecha chevron rotativa
                Icon(
                  folder.isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 4),

                // Icono de carpeta (abierta o cerrada)
                Icon(
                  folder.isExpanded ? Icons.folder_open : Icons.folder,
                  size: 15,
                  color: folder.isExpanded ? tokens.accentSecondary : tokens.accentSecondary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),

                // Nombre de carpeta
                Expanded(
                  child: Text(
                    folder.name,
                    style: TextStyle(
                      color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Conteo de elementos contenidos
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: tokens.inputSurface,
                    borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
                  ),
                  child: Text(
                    '${folder.children.length}',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 9.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Menú contextual de carpeta
                _buildFolderContextMenu(context),
              ],
            ),
          ),
        ),

        // Sub-árbol de hijos (renderizado recursivo cuando está expandido)
        if (folder.isExpanded) ...[
          if (folder.children.isEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 20.0 + (depth * 14.0), top: 2.0, bottom: 2.0),
              child: Text(
                'Carpeta vacía',
                style: TextStyle(color: tokens.textMuted, fontSize: 10.0, fontStyle: FontStyle.italic),
              ),
            ),
          ] else ...[
            ...folder.children.map((child) {
              if (child is StudioFolderEntity) {
                return StudioFolderTreeTile(
                  key: ValueKey(child.id),
                  folder: child,
                  service: service,
                  depth: depth + 1,
                  onFileTapped: onFileTapped,
                );
              } else if (child is StudioFileEntity) {
                return StudioFileTreeTile(
                  key: ValueKey(child.id),
                  file: child,
                  service: service,
                  depth: depth + 1,
                  onFileTapped: onFileTapped,
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ],
      ],
    );
  }

  Widget _buildFolderContextMenu(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 13, color: tokens.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      color: tokens.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
        side: BorderSide(color: tokens.borderHairline),
      ),
      onSelected: (value) {
        if (value == 'new_file') {
          StudioFileSystemModals.showCreateFileModal(
            context,
            service: service,
            targetFolderId: folder.id,
          );
        } else if (value == 'new_folder') {
          StudioFileSystemModals.showCreateFolderModal(
            context,
            service: service,
            targetFolderId: folder.id,
          );
        } else if (value == 'rename') {
          StudioFileSystemModals.showRenameNodeModal(
            context,
            service: service,
            node: folder,
          );
        } else if (value == 'delete') {
          StudioFileSystemModals.showDeleteConfirmDialog(
            context,
            service: service,
            node: folder,
          );
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'new_file',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 13, color: tokens.accentPrimary),
              const SizedBox(width: 8),
              Text('Nuevo Archivo Aquí...', style: TextStyle(fontSize: 11, color: tokens.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'new_folder',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 13, color: tokens.accentSecondary),
              const SizedBox(width: 8),
              Text('Nueva Subcarpeta...', style: TextStyle(fontSize: 11, color: tokens.textPrimary)),
            ],
          ),
        ),
        if (folder.id != 'root') ...[
          PopupMenuItem<String>(
            value: 'rename',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 13, color: tokens.textSecondary),
                const SizedBox(width: 8),
                Text('Renombrar Carpeta', style: TextStyle(fontSize: 11, color: tokens.textPrimary)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 13, color: tokens.statusError),
                const SizedBox(width: 8),
                Text('Eliminar Carpeta', style: TextStyle(fontSize: 11, color: tokens.statusError)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
