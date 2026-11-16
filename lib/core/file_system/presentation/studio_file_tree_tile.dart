import 'package:flutter/material.dart';
import '../data/studio_workspace_file_system_service.dart';
import '../domain/studio_file_system_node.dart';
import '../domain/studio_file_type.dart';
import 'studio_file_system_modals.dart';

/// Tile atomizado para renderizar un archivo en el explorador estilo VS Code.
class StudioFileTreeTile extends StatelessWidget {
  final StudioFileEntity file;
  final StudioWorkspaceFileSystemService service;
  final int depth;
  final VoidCallback? onFileTapped;

  const StudioFileTreeTile({
    super.key,
    required this.file,
    required this.service,
    this.depth = 1,
    this.onFileTapped,
  });

  IconData _iconForType(StudioFileType type) {
    switch (type) {
      case StudioFileType.project:
        return Icons.layers_outlined;
      case StudioFileType.score:
        return Icons.music_note_outlined;
      case StudioFileType.audioWav:
        return Icons.graphic_eq_outlined;
      case StudioFileType.rackTool:
        return Icons.view_agenda_outlined;
      case StudioFileType.tuningPreset:
        return Icons.tune_outlined;
      case StudioFileType.djBlueprint:
        return Icons.album_outlined;
      case StudioFileType.genericFile:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = service.selectedNodeId == file.id;
    final fileColor = Color(file.fileType.colorHex);

    return InkWell(
      onTap: () {
        service.selectNode(file.id);
        onFileTapped?.call();
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + (depth * 14.0),
          right: 6.0,
          top: 3.5,
          bottom: 3.5,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 1.0)
              : null,
        ),
        child: Row(
          children: [
            // Icono del tipo de archivo con su color distintivo
            Icon(
              _iconForType(file.fileType),
              size: 14,
              color: fileColor,
            ),
            const SizedBox(width: 6),

            // Nombre del archivo
            Expanded(
              child: Text(
                file.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFB0B9C6),
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Tamaño en bytes
            Text(
              file.formattedSize,
              style: const TextStyle(
                color: Color(0xFF556075),
                fontSize: 9.0,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),

            // Menú contextual rápido (Renombrar / Eliminar)
            _buildContextMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 12, color: Color(0xFF6B7280)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      color: const Color(0xFF141824),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF28324A)),
      ),
      onSelected: (value) {
        if (value == 'rename') {
          StudioFileSystemModals.showRenameNodeModal(
            context,
            service: service,
            node: file,
          );
        } else if (value == 'delete') {
          StudioFileSystemModals.showDeleteConfirmDialog(
            context,
            service: service,
            node: file,
          );
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem<String>(
          value: 'rename',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 13, color: Color(0xFF00E5FF)),
              SizedBox(width: 8),
              Text('Renombrar', style: TextStyle(fontSize: 11, color: Colors.white)),
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
              Text('Eliminar', style: TextStyle(fontSize: 11, color: Color(0xFFFF5252))),
            ],
          ),
        ),
      ],
    );
  }
}
