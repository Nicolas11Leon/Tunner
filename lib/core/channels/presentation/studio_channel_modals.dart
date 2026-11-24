import 'package:flutter/material.dart';
import '../../design_system/studio_design_system.dart';
import '../domain/i_studio_patchbay_routing_service.dart';
import '../domain/studio_channel_bus.dart';

/// Paleta de colores identificadores de LED para canales de parcheo de estudio.
class StudioChannelPalette {
  static const List<int> presetColors = [
    0xFFE5E9F0, // Plata OLED
    0xFF22C55E, // Verde señal
    0xFFF59E0B, // Ámbar cálido
    0xFFEF4444, // Rojo grabación
    0xFF38BDF8, // Azul telemetría
    0xFFA78BFA, // Violeta auxiliar
    0xFFFB923C, // Naranja bus
    0xFF94A3B8, // Grafito neutro
  ];
}

/// Diálogo modal interactivo para crear un nuevo canal nombrado de estudio.
class StudioCreateChannelModal extends StatefulWidget {
  final IStudioPatchbayRoutingService routingService;
  final ValueChanged<StudioChannelBus>? onChannelCreated;

  const StudioCreateChannelModal({
    super.key,
    required this.routingService,
    this.onChannelCreated,
  });

  static Future<StudioChannelBus?> show(
    BuildContext context, {
    required IStudioPatchbayRoutingService routingService,
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
    final tokens = StudioThemeScope.of(context);
    final selectedChannelColor = Color(_selectedColor);

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
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
                      color: selectedChannelColor.withValues(alpha: 0.16),
                      border: Border.all(color: selectedChannelColor, width: 1.5),
                    ),
                    child: Center(
                      child: StudioIcon(
                        StudioIconId.uiAddRemove,
                        color: selectedChannelColor,
                        size: 16,
                        tintCustomAsset: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'CREAR NUEVO CANAL',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textMuted,
                      size: 16,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Nombre del Canal:',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ej. Voz Principal, Batería Rock, Violín Solo...',
                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: tokens.inputSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    borderSide: BorderSide(color: tokens.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    borderSide: BorderSide(color: tokens.borderHairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    borderSide: BorderSide(color: tokens.borderFocus, width: 1.2),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text(
                'Color del Canal / LED:',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
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
                          color: isSelected ? tokens.borderFocus : tokens.borderHairline,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 14, color: tokens.textOnAccent)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancelar', style: TextStyle(color: tokens.textSecondary)),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.check, size: 14, color: tokens.textOnAccent),
                      label: Text(
                        'Crear Canal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: tokens.textOnAccent,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.accentPrimary,
                        foregroundColor: tokens.textOnAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusMedium),
                        ),
                      ),
                      onPressed: _submit,
                    ),
                  ],
                ),
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
  final IStudioPatchbayRoutingService routingService;
  final StudioChannelBus channel;

  const StudioRenameChannelModal({
    super.key,
    required this.routingService,
    required this.channel,
  });

  static Future<void> show(
    BuildContext context, {
    required IStudioPatchbayRoutingService routingService,
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
    final tokens = StudioThemeScope.of(context);
    final liveChannel = widget.routingService.channels.firstWhere(
      (c) => c.id == widget.channel.id,
      orElse: () => widget.channel,
    );
    final chColor = Color(liveChannel.colorHex);
    final allPlugs = widget.routingService.plugs.values.toList();
    final connectedSources = widget.routingService.matrix.findSourcesForChannel(liveChannel.id);
    final connectedSinks = widget.routingService.matrix.findSinksForChannel(liveChannel.id);

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
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
                      color: chColor.withValues(alpha: 0.18),
                      border: Border.all(color: chColor, width: 1.5),
                    ),
                    child: Center(
                      child: StudioIcon(
                        StudioIconId.moduleScoreEditor,
                        color: chColor,
                        size: 14,
                        tintCustomAsset: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RENOMBRAR CANAL',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Inspector de Mezcla, Fader y Matriz de Ruteo (${liveChannel.shortCode})',
                          style: TextStyle(color: tokens.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textMuted,
                      size: 16,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Nuevo nombre del canal',
                  labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: tokens.inputSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    borderSide: BorderSide(color: tokens.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    borderSide: BorderSide(color: tokens.borderHairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    borderSide: BorderSide(color: tokens.borderFocus, width: 1.2),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),

              // Sección de Fader de Ganancia, Mute y Estado de Transporte del Canal
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.inputSurface,
                  borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          'FADER DE CANAL (${(liveChannel.gain * 100).round()}%)',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              key: const Key('channel_inspector_mute_btn'),
                              onTap: () {
                                widget.routingService.toggleChannelMute(liveChannel.id);
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: liveChannel.isMuted
                                      ? tokens.statusError.withValues(alpha: 0.2)
                                      : tokens.elevatedSurface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: liveChannel.isMuted ? tokens.statusError : tokens.borderHairline,
                                  ),
                                ),
                                child: Text(
                                  liveChannel.isMuted ? 'MUTEADO' : 'ACTIVO',
                                  style: TextStyle(
                                    color: liveChannel.isMuted ? tokens.statusError : tokens.statusSuccess,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              key: const Key('channel_inspector_toggle_play_btn'),
                              onTap: () {
                                widget.routingService.publishChannelParameters(
                                  liveChannel.id,
                                  isPlaying: !liveChannel.isPlaying,
                                );
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: liveChannel.isPlaying
                                      ? chColor.withValues(alpha: 0.2)
                                      : tokens.elevatedSurface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: liveChannel.isPlaying ? chColor : tokens.borderHairline,
                                  ),
                                ),
                                child: Text(
                                  liveChannel.isPlaying ? 'STOP BUS' : 'PLAY BUS',
                                  style: TextStyle(
                                    color: liveChannel.isPlaying ? chColor : tokens.textSecondary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Slider(
                      value: liveChannel.gain.clamp(0.0, 2.0),
                      min: 0.0,
                      max: 2.0,
                      divisions: 40,
                      activeColor: chColor,
                      onChanged: (val) {
                        widget.routingService.setChannelGain(liveChannel.id, val);
                        setState(() {});
                      },
                    ),
                    if (allPlugs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'CONEXIONES PATCHBAY EN ESTE CANAL (${connectedSources.length + connectedSinks.length} activas):',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: allPlugs.map((plug) {
                          final isConnected =
                              connectedSources.any((p) => p.id == plug.id) ||
                              connectedSinks.any((p) => p.id == plug.id);
                          return FilterChip(
                            label: Text(
                              plug.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: isConnected ? tokens.textPrimary : tokens.textSecondary,
                              ),
                            ),
                            selected: isConnected,
                            selectedColor: chColor.withValues(alpha: 0.25),
                            backgroundColor: tokens.elevatedSurface,
                            checkmarkColor: chColor,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onSelected: (selected) {
                              if (selected) {
                                widget.routingService.connectPlugToChannel(plug.id, liveChannel.id);
                              } else {
                                widget.routingService.disconnectPlug(plug.id);
                              }
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancelar', style: TextStyle(color: tokens.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.accentPrimary,
                        foregroundColor: tokens.textOnAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusMedium),
                        ),
                      ),
                      onPressed: _submit,
                      child: Text(
                        'Guardar Nombre',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: tokens.textOnAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
