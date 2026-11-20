import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/i_studio_workspace_file_system.dart';
import '../domain/studio_file_system_node.dart';
import '../domain/studio_file_type.dart';
import 'studio_file_system_modals.dart';

/// Tile atomizado para renderizar un archivo en el explorador estilo VS Code.
class StudioFileTreeTile extends StatelessWidget {
  final StudioFileEntity file;
  final IStudioWorkspaceFileSystem service;
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
    final tokens = StudioThemeScope.tokensOf(context);
    final isSelected = service.selectedNodeId == file.id;
    final fileColor = Color(file.fileType.colorHex);

    return InkWell(
      onTap: () {
        service.selectNode(file.id);
        onFileTapped?.call();
      },
      borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + (depth * 14.0),
          right: 6.0,
          top: 3.5,
          bottom: 3.5,
        ),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accentPrimary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
          border: isSelected
              ? Border.all(color: tokens.borderFocus, width: 1.0)
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
                  color: isSelected ? tokens.textPrimary : tokens.textSecondary,
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
              style: TextStyle(
                color: tokens.textMuted,
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
    final tokens = StudioThemeScope.tokensOf(context);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 12, color: tokens.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      color: tokens.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
        side: BorderSide(color: tokens.borderHairline),
      ),
      onSelected: (value) {
        if (value == 'rename') {
          StudioFileSystemModals.showRenameNodeModal(
            context,
            service: service,
            node: file,
          );
        } else if (value == 'move') {
          StudioFileSystemModals.showMoveNodeModal(
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
        PopupMenuItem<String>(
          value: 'rename',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 13, color: tokens.accentPrimary),
              const SizedBox(width: 8),
              Text('Renombrar', style: TextStyle(fontSize: 11, color: tokens.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'move',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outlined, size: 13, color: tokens.accentSecondary),
              const SizedBox(width: 8),
              Text('Mover a...', style: TextStyle(fontSize: 11, color: tokens.textPrimary)),
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
              Text('Eliminar', style: TextStyle(fontSize: 11, color: tokens.statusError)),
            ],
          ),
        ),
      ],
    );
  }
}
