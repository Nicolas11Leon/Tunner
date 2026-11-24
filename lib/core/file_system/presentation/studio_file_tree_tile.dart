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
      onSecondaryTapDown: (details) => _showFileContextMenu(context, details.globalPosition),
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

  Future<void> _showFileContextMenu(BuildContext context, Offset globalPosition) async {
    final tokens = StudioThemeScope.tokensOf(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      color: tokens.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.borderRadiusSmall),
        side: BorderSide(color: tokens.borderHairline),
      ),
      items: _buildContextMenuItems(context),
    );
    if (selected != null && context.mounted) {
      _handleContextMenuSelection(context, selected);
    }
  }

  void _handleContextMenuSelection(BuildContext context, String value) {
    if (value == 'action_score_stems') {
      service.triggerFileMusicalAction(file, StudioFileMusicalAction.transformToScoreAndStems);
    } else if (value == 'action_dj_deck_a') {
      service.triggerFileMusicalAction(file, StudioFileMusicalAction.loadInDjDeckA);
    } else if (value == 'action_dj_deck_b') {
      service.triggerFileMusicalAction(file, StudioFileMusicalAction.loadInDjDeckB);
    } else if (value == 'action_open_score') {
      service.triggerFileMusicalAction(file, StudioFileMusicalAction.openInScoreEditor);
    } else if (value == 'open_in_explorer') {
      service.openInSystemExplorer(file.relativePath);
    } else if (value == 'rename') {
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
  }

  PopupMenuItem<String> _buildActionMenuItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color textColor,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildContextMenuItems(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return <PopupMenuEntry<String>>[
      if (file.fileType == StudioFileType.audioWav) ...[
        _buildActionMenuItem(
          value: 'action_score_stems',
          icon: Icons.auto_awesome_outlined,
          iconColor: tokens.accentPrimary,
          label: 'Transformar a Partitura y 4 Stems',
          textColor: tokens.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        _buildActionMenuItem(
          value: 'action_dj_deck_a',
          icon: Icons.album_outlined,
          iconColor: tokens.accentSecondary,
          label: 'Cargar en Deck A (Consola DJ)',
          textColor: tokens.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        _buildActionMenuItem(
          value: 'action_dj_deck_b',
          icon: Icons.album_rounded,
          iconColor: tokens.accentWarning,
          label: 'Cargar en Deck B (Consola DJ)',
          textColor: tokens.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        const PopupMenuDivider(height: 1),
      ] else if (file.fileType == StudioFileType.score) ...[
        _buildActionMenuItem(
          value: 'action_open_score',
          icon: Icons.music_note_outlined,
          iconColor: tokens.accentSuccess,
          label: 'Abrir en Editor de Partituras',
          textColor: tokens.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        const PopupMenuDivider(height: 1),
      ],
      _buildActionMenuItem(
        value: 'open_in_explorer',
        icon: Icons.folder_open_rounded,
        iconColor: tokens.accentPrimary,
        label: 'Abrir ubicación en explorador',
        textColor: tokens.textPrimary,
      ),
      _buildActionMenuItem(
        value: 'rename',
        icon: Icons.edit_outlined,
        iconColor: tokens.accentPrimary,
        label: 'Renombrar',
        textColor: tokens.textPrimary,
      ),
      _buildActionMenuItem(
        value: 'move',
        icon: Icons.drive_file_move_outlined,
        iconColor: tokens.accentSecondary,
        label: 'Mover a...',
        textColor: tokens.textPrimary,
      ),
      _buildActionMenuItem(
        value: 'delete',
        icon: Icons.delete_outline,
        iconColor: tokens.statusError,
        label: 'Eliminar',
        textColor: tokens.statusError,
      ),
    ];
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
      onSelected: (value) => _handleContextMenuSelection(context, value),
      itemBuilder: _buildContextMenuItems,
    );
  }
}
