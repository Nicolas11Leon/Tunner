import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../data/dj_console_blueprint_storage_service.dart';
import '../domain/dj_action.dart';
import '../domain/dj_console_blueprint_entity.dart';
import '../domain/dj_skin_zone_entity.dart';
import 'dj_console_view_model.dart';

/// Modal interactivo para crear, emular, editar y programar cualquier modelo de consola DJ física.
///
/// Permite al usuario diseñar una consola física desde cero, agregar jogs, pads, faders y botones,
/// asignar teclas físicas a cada control y guardarla como archivo `.djconsole`.
class DjConsoleModelBuilderModal extends StatefulWidget {
  final DjConsoleViewModel viewModel;
  final TunnerThemePalette palette;
  final DjConsoleBlueprintStorageService storageService;

  const DjConsoleModelBuilderModal({
    super.key,
    required this.viewModel,
    required this.palette,
    required this.storageService,
  });

  static Future<void> show(
    BuildContext context,
    DjConsoleViewModel viewModel,
    TunnerThemePalette palette, {
    DjConsoleBlueprintStorageService? storageService,
  }) {
    final service = storageService ?? DjConsoleBlueprintStorageService();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DjConsoleModelBuilderModal(
        viewModel: viewModel,
        palette: palette,
        storageService: service,
      ),
    );
  }

  @override
  State<DjConsoleModelBuilderModal> createState() =>
      _DjConsoleModelBuilderModalState();
}

class _DjConsoleModelBuilderModalState
    extends State<DjConsoleModelBuilderModal> {
  final _nameController = TextEditingController(text: 'Mi Consola Emulada');
  final _manufacturerController = TextEditingController(text: 'Custom Lab');
  int _chassisColor = 0xFF141722;
  final double _aspectRatio = 16.0 / 9.0;

  final List<DjSkinZoneEntity> _zones = [];
  final Map<String, DjAction> _keyBindings = {};

  @override
  void initState() {
    super.initState();
    _loadBaseTemplate();
  }

  void _loadBaseTemplate() {
    // Plantilla inicial con controles básicos para agilizar la creación
    _zones.addAll([
      const DjSkinZoneEntity(
        id: 'user_deck_a_jog',
        label: 'JOG A',
        deckId: 'deckA',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckANudgeForward,
        normalizedX: 0.06,
        normalizedY: 0.18,
        normalizedWidth: 0.28,
        normalizedHeight: 0.46,
        ledColor: 0xFF00E5FF,
      ),
      const DjSkinZoneEntity(
        id: 'user_deck_a_play',
        label: 'PLAY',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.06,
        normalizedY: 0.80,
        normalizedWidth: 0.07,
        normalizedHeight: 0.13,
        ledColor: 0xFF00E676,
      ),
      const DjSkinZoneEntity(
        id: 'user_deck_a_cue',
        label: 'CUE',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckACue,
        normalizedX: 0.06,
        normalizedY: 0.65,
        normalizedWidth: 0.07,
        normalizedHeight: 0.13,
        ledColor: 0xFFFFAB00,
      ),
      const DjSkinZoneEntity(
        id: 'user_crossfader',
        label: 'X-FADER',
        controlType: DjControlType.fader,
        action: DjAction.crossfaderCenter,
        normalizedX: 0.40,
        normalizedY: 0.82,
        normalizedWidth: 0.20,
        normalizedHeight: 0.12,
        ledColor: 0xFFFFFFFF,
      ),
      const DjSkinZoneEntity(
        id: 'user_deck_b_jog',
        label: 'JOG B',
        deckId: 'deckB',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckBNudgeForward,
        normalizedX: 0.66,
        normalizedY: 0.18,
        normalizedWidth: 0.28,
        normalizedHeight: 0.46,
        ledColor: 0xFFFFAB00,
      ),
      const DjSkinZoneEntity(
        id: 'user_deck_b_play',
        label: 'PLAY',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBPlayPause,
        normalizedX: 0.66,
        normalizedY: 0.80,
        normalizedWidth: 0.07,
        normalizedHeight: 0.13,
        ledColor: 0xFF00E676,
      ),
      const DjSkinZoneEntity(
        id: 'user_deck_b_cue',
        label: 'CUE',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBCue,
        normalizedX: 0.66,
        normalizedY: 0.65,
        normalizedWidth: 0.07,
        normalizedHeight: 0.13,
        ledColor: 0xFFFFAB00,
      ),
    ]);

    // Mapeos básicos iniciales
    _keyBindings['Key W'] = DjAction.deckAPlayPause;
    _keyBindings['Key Q'] = DjAction.deckACue;
    _keyBindings['Key I'] = DjAction.deckBPlayPause;
    _keyBindings['Key U'] = DjAction.deckBCue;
    _keyBindings['Key N'] = DjAction.crossfaderCenter;
  }

  void _addControl(DjControlType type, String deckId, DjAction action, String label) {
    setState(() {
      final id = 'custom_${type.name}_${DateTime.now().millisecondsSinceEpoch}';
      final isDeckA = deckId == 'deckA';

      _zones.add(
        DjSkinZoneEntity(
          id: id,
          label: label,
          deckId: deckId,
          controlType: type,
          action: action,
          normalizedX: isDeckA ? 0.15 : 0.75,
          normalizedY: 0.50,
          normalizedWidth: type == DjControlType.fader ? 0.04 : 0.06,
          normalizedHeight: type == DjControlType.fader ? 0.20 : 0.08,
          ledColor: isDeckA ? 0xFF00E5FF : 0xFFFFAB00,
        ),
      );
    });
  }

  Future<void> _saveAndEmulate() async {
    final rawId = _nameController.text.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final uniqueId = 'emulated_${rawId}_${DateTime.now().millisecondsSinceEpoch}';

    final blueprint = DjConsoleBlueprintEntity(
      id: uniqueId,
      name: _nameController.text.trim().isEmpty ? 'Consola Emulada' : _nameController.text.trim(),
      manufacturer: _manufacturerController.text.trim().isEmpty ? 'Custom' : _manufacturerController.text.trim(),
      aspectRatio: _aspectRatio,
      chassisColor: _chassisColor,
      zones: _zones,
      keyBindings: _keyBindings,
    );

    await widget.storageService.saveBlueprint(blueprint);
    widget.viewModel.selectSkin(uniqueId);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Consola "${blueprint.name}" guardada y cargada en el emulador'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 860,
        height: 640,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF283044), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF141924),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFF222B3D))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.build_circle, color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Constructor y Emulador Universal de Consolas DJ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Emula cualquier controlador de hardware físico y programa sus botones con el teclado',
                          style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Formulario de Parámetros
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Modelo / Consola',
                        labelStyle: TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _manufacturerController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Fabricante',
                        labelStyle: TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Color del Chasis
                  DropdownButton<int>(
                    value: _chassisColor,
                    dropdownColor: const Color(0xFF181F2C),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 0xFF141722, child: Text('Negro Mate Industrial')),
                      DropdownMenuItem(value: 0xFF2A2D38, child: Text('Aluminio Cepillado')),
                      DropdownMenuItem(value: 0xFF1E1428, child: Text('Club Edición Púrpura')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _chassisColor = val);
                    },
                  ),
                ],
              ),
            ),

            // Toolbar para agregar controles
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF141926),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Agregar Controles:',
                      style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.circle, size: 14, color: Color(0xFF00E5FF)),
                          label: const Text('Pad Cue A', style: TextStyle(fontSize: 10)),
                          onPressed: () => _addControl(DjControlType.pad, 'deckA', DjAction.deckAHotCue1, 'HOT CUE 1'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.tune, size: 14, color: Color(0xFF00E5FF)),
                          label: const Text('Fader Pitch A', style: TextStyle(fontSize: 10)),
                          onPressed: () => _addControl(DjControlType.fader, 'deckA', DjAction.deckAPitchUp, 'TEMPO A'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.graphic_eq, size: 14, color: Color(0xFF00E5FF)),
                          label: const Text('EQ Mid A', style: TextStyle(fontSize: 10)),
                          onPressed: () => _addControl(DjControlType.knob, 'deckA', DjAction.deckAKillMid, 'MID A'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.circle, size: 14, color: Color(0xFFFFAB00)),
                          label: const Text('Pad Cue B', style: TextStyle(fontSize: 10)),
                          onPressed: () => _addControl(DjControlType.pad, 'deckB', DjAction.deckBHotCue1, 'HOT CUE 1'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.tune, size: 14, color: Color(0xFFFFAB00)),
                          label: const Text('Fader Pitch B', style: TextStyle(fontSize: 10)),
                          onPressed: () => _addControl(DjControlType.fader, 'deckB', DjAction.deckBPitchUp, 'TEMPO B'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Lista de Controles en la Consola
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _zones.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final zone = _zones[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161C2A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF263248)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          zone.controlType == DjControlType.jogWheel
                              ? Icons.album
                              : (zone.controlType == DjControlType.fader ? Icons.linear_scale : Icons.radio_button_checked),
                          color: Color(zone.ledColor),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${zone.label} (${zone.controlType.name.toUpperCase()})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                'Acción: ${zone.action.displayName} | Deck: ${zone.deckId ?? "Master"}',
                                style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252), size: 18),
                          onPressed: () {
                            setState(() {
                              _zones.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF141924),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFF222B3D))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_zones.length} controles configurados',
                      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                    ),
                    const SizedBox(width: 24),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          key: const Key('save_and_emulate_btn'),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Guardar y Emular Consola', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: _saveAndEmulate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
