import 'package:flutter/material.dart';
import '../data/studio_workspace_file_system_service.dart';
import '../domain/studio_file_system_node.dart';
import '../domain/studio_file_type.dart';

/// Colección de diálogos modulares y atomizados para operaciones del sistema de archivos.
class StudioFileSystemModals {
  /// Modal para crear un nuevo archivo seleccionando su tipo o extensión.
  static Future<StudioFileEntity?> showCreateFileModal(
    BuildContext context, {
    required StudioWorkspaceFileSystemService service,
    String? targetFolderId,
  }) {
    return showDialog<StudioFileEntity>(
      context: context,
      builder: (ctx) => _CreateFileModalDialog(
        service: service,
        targetFolderId: targetFolderId,
      ),
    );
  }

  /// Modal para crear una nueva carpeta o directorio.
  static Future<StudioFolderEntity?> showCreateFolderModal(
    BuildContext context, {
    required StudioWorkspaceFileSystemService service,
    String? targetFolderId,
  }) {
    return showDialog<StudioFolderEntity>(
      context: context,
      builder: (ctx) => _CreateFolderModalDialog(
        service: service,
        targetFolderId: targetFolderId,
      ),
    );
  }

  /// Modal para renombrar un archivo o carpeta.
  static Future<void> showRenameNodeModal(
    BuildContext context, {
    required StudioWorkspaceFileSystemService service,
    required StudioFileSystemNode node,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _RenameNodeModalDialog(
        service: service,
        node: node,
      ),
    );
  }

  /// Diálogo de confirmación para eliminación de nodos.
  static Future<bool?> showDeleteConfirmDialog(
    BuildContext context, {
    required StudioWorkspaceFileSystemService service,
    required StudioFileSystemNode node,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10131E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF28324A)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 20),
            const SizedBox(width: 8),
            Text(
              node.isFolder ? '¿Eliminar Carpeta?' : '¿Eliminar Archivo?',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          node.isFolder
              ? 'Se eliminará la carpeta "${node.name}" y todos los archivos contenidos de forma irreversible.'
              : '¿Deseas eliminar permanentemente "${node.name}"?',
          style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8E9BAE))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              service.deleteNode(node.id);
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _CreateFileModalDialog extends StatefulWidget {
  final StudioWorkspaceFileSystemService service;
  final String? targetFolderId;

  const _CreateFileModalDialog({
    required this.service,
    this.targetFolderId,
  });

  @override
  State<_CreateFileModalDialog> createState() => _CreateFileModalDialogState();
}

class _CreateFileModalDialogState extends State<_CreateFileModalDialog> {
  late final TextEditingController _nameController;
  StudioFileType _selectedType = StudioFileType.score;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Nueva_Partitura');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;

    final created = widget.service.createFile(
      name: rawName,
      parentFolderId: widget.targetFolderId,
      fileType: _selectedType,
    );
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10131E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF28324A), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.note_add_outlined, color: Color(0xFF00E5FF), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'CREAR NUEVO ARCHIVO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Nombre del Documento:',
                style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Ej. Preludio_Sol_Menor...',
                  hintStyle: const TextStyle(color: Color(0xFF556075), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF161B28),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tipo de Documento:',
                style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: StudioFileType.values.map((type) {
                  final isSelected = _selectedType == type;
                  final typeColor = Color(type.colorHex);

                  return InkWell(
                    onTap: () => setState(() => _selectedType = type),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? typeColor.withValues(alpha: 0.22) : const Color(0xFF161B28),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? typeColor : const Color(0xFF283248),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: typeColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type.displayName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF8E9BAE),
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8E9BAE))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _submit,
                    child: const Text('Crear Archivo', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateFolderModalDialog extends StatefulWidget {
  final StudioWorkspaceFileSystemService service;
  final String? targetFolderId;

  const _CreateFolderModalDialog({
    required this.service,
    this.targetFolderId,
  });

  @override
  State<_CreateFolderModalDialog> createState() => _CreateFolderModalDialogState();
}

class _CreateFolderModalDialogState extends State<_CreateFolderModalDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Nueva Carpeta');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final created = widget.service.createFolder(
      name: name,
      parentFolderId: widget.targetFolderId,
    );
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10131E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF28324A), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.create_new_folder_outlined, color: Color(0xFFFFB74D), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'NUEVA CARPETA',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Nombre de la carpeta',
                  labelStyle: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF161B28),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFB74D), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8E9BAE))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB74D),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _submit,
                    child: const Text('Crear Carpeta', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameNodeModalDialog extends StatefulWidget {
  final StudioWorkspaceFileSystemService service;
  final StudioFileSystemNode node;

  const _RenameNodeModalDialog({
    required this.service,
    required this.node,
  });

  @override
  State<_RenameNodeModalDialog> createState() => _RenameNodeModalDialogState();
}

class _RenameNodeModalDialogState extends State<_RenameNodeModalDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.node.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      widget.service.renameNode(widget.node.id, newName);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10131E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF28324A), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_outlined, color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.node.isFolder ? 'RENOMBRAR CARPETA' : 'RENOMBRAR ARCHIVO',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Nuevo nombre',
                  labelStyle: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF161B28),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8E9BAE))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _submit,
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
