import 'package:flutter/material.dart';
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
    final isSelected = service.selectedNodeId == folder.id;
    final isActiveFolder = service.activeFolderId == folder.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila de encabezado de carpeta
        InkWell(
          onTap: () => service.toggleFolder(folder.id),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: EdgeInsets.only(
              left: 4.0 + (depth * 14.0),
              right: 6.0,
              top: 4.0,
              bottom: 4.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                  : isActiveFolder
                      ? const Color(0xFF1E283C).withValues(alpha: 0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isSelected
                  ? Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35), width: 1.0)
                  : null,
            ),
            child: Row(
              children: [
                // Flecha chevron rotativa
                Icon(
                  folder.isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: const Color(0xFF8E9BAE),
                ),
                const SizedBox(width: 4),

                // Icono de carpeta (abierta o cerrada)
                Icon(
                  folder.isExpanded ? Icons.folder_open : Icons.folder,
                  size: 15,
                  color: folder.isExpanded ? const Color(0xFFFFD54F) : const Color(0xFFFFB74D),
                ),
                const SizedBox(width: 6),

                // Nombre de carpeta
                Expanded(
                  child: Text(
                    folder.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
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
                    color: const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${folder.children.length}',
                    style: const TextStyle(
                      color: Color(0xFF7E8B9E),
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
              child: const Text(
                'Carpeta vacía',
                style: TextStyle(color: Color(0xFF556075), fontSize: 10.0, fontStyle: FontStyle.italic),
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 13, color: Color(0xFF6B7280)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      color: const Color(0xFF141824),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF28324A)),
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
        const PopupMenuItem<String>(
          value: 'new_file',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 13, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Text('Nuevo Archivo Aquí...', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'new_folder',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 13, color: Color(0xFFFFB74D)),
              SizedBox(width: 8),
              Text('Nueva Subcarpeta...', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        if (folder.id != 'root') ...[
          const PopupMenuItem<String>(
            value: 'rename',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 13, color: Color(0xFF8E9BAE)),
                SizedBox(width: 8),
                Text('Renombrar Carpeta', style: TextStyle(fontSize: 11, color: Colors.white)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 13, color: Color(0xFFFF5252)),
                SizedBox(width: 8),
                Text('Eliminar Carpeta', style: TextStyle(fontSize: 11, color: Color(0xFFFF5252))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
