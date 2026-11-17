import 'package:flutter/material.dart';
import '../data/studio_patchbay_routing_service.dart';
import '../domain/studio_channel_bus.dart';

/// Paleta de colores canónicos neón para canales de estudio.
class StudioChannelPalette {
  static const List<int> presetColors = [
    0xFF00E5FF, // Cian neón
    0xFFFFAB00, // Ámbar cálido
    0xFF10B981, // Esmeralda club
    0xFF8B5CF6, // Púrpura synthwave
    0xFFFF4081, // Rosa neón
    0xFF00E676, // Verde lima
    0xFF3D5AFE, // Azul índigo
    0xFFFF6D00, // Naranja fuego
  ];
}

/// Diálogo modal interactivo para crear un nuevo canal nombrado de estudio.
class StudioCreateChannelModal extends StatefulWidget {
  final StudioPatchbayRoutingService routingService;
  final ValueChanged<StudioChannelBus>? onChannelCreated;

  const StudioCreateChannelModal({
    super.key,
    required this.routingService,
    this.onChannelCreated,
  });

  static Future<StudioChannelBus?> show(
    BuildContext context, {
    required StudioPatchbayRoutingService routingService,
  }) {
    return showDialog<StudioChannelBus>(
      context: context,
      builder: (ctx) => StudioCreateChannelModal(routingService: routingService),
    );
  }

  @override
  State<StudioCreateChannelModal> createState() => _StudioCreateChannelModalState();
}

class _StudioCreateChannelModalState extends State<StudioCreateChannelModal> {
  late final TextEditingController _nameController;
  int _selectedColor = StudioChannelPalette.presetColors[0];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Canal Melodía');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final created = widget.routingService.createCustomChannel(
      name: name,
      colorHex: _selectedColor,
    );

    widget.onChannelCreated?.call(created);
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
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(_selectedColor).withValues(alpha: 0.2),
                      border: Border.all(color: Color(_selectedColor), width: 1.5),
                    ),
                    child: Icon(Icons.add, color: Color(_selectedColor), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'CREAR NUEVO CANAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Nombre del Canal:',
                style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ej. Voz Principal, Batería Rock, Violín Solo...',
                  hintStyle: const TextStyle(color: Color(0xFF556075), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF161B28),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A344A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A344A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(_selectedColor), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Color del Canal / LED:',
                style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: StudioChannelPalette.presetColors.map((colorHex) {
                  final isSelected = _selectedColor == colorHex;
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(colorHex),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(colorHex).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.black87)
                          : null,
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Crear Canal', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(_selectedColor),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _submit,
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

/// Diálogo interactivo para renombrar un canal existente.
class StudioRenameChannelModal extends StatefulWidget {
  final StudioPatchbayRoutingService routingService;
  final StudioChannelBus channel;

  const StudioRenameChannelModal({
    super.key,
    required this.routingService,
    required this.channel,
  });

  static Future<void> show(
    BuildContext context, {
    required StudioPatchbayRoutingService routingService,
    required StudioChannelBus channel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => StudioRenameChannelModal(
        routingService: routingService,
        channel: channel,
      ),
    );
  }

  @override
  State<StudioRenameChannelModal> createState() => _StudioRenameChannelModalState();
}

class _StudioRenameChannelModalState extends State<StudioRenameChannelModal> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.channel.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      widget.routingService.renameChannel(widget.channel.id, newName);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chColor = Color(widget.channel.colorHex);

    return Dialog(
      backgroundColor: const Color(0xFF10131E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF28324A), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chColor.withValues(alpha: 0.2),
                      border: Border.all(color: chColor, width: 1.5),
                    ),
                    child: Icon(Icons.edit, color: chColor, size: 15),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'RENOMBRAR CANAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
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
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Nuevo nombre del canal',
                  labelStyle: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF161B28),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A344A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: chColor, width: 1.5),
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
                      backgroundColor: chColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _submit,
                    child: const Text('Guardar Nombre', style: TextStyle(fontWeight: FontWeight.bold)),
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
