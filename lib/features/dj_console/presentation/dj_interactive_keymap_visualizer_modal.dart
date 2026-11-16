import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/dj_action.dart';
import '../domain/dj_keymap_profile_entity.dart';
import 'dj_console_view_model.dart';

/// Modal interactivo que despliega un teclado QWERTY físico renderizado para mapear controles DJ.
///
/// Permite al usuario visualizar las teclas mapeadas por color (Deck A en cian, Deck B en ámbar,
/// Mezclador en verde, FX en púrpura), cargar perfiles de la industria (VirtualDJ, Traktor, Serato),
/// y reasignar teclas con un clic.
class DjInteractiveKeymapVisualizerModal extends StatefulWidget {
  final DjConsoleViewModel viewModel;
  final TunnerThemePalette palette;

  const DjInteractiveKeymapVisualizerModal({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  static Future<void> show(
    BuildContext context,
    DjConsoleViewModel viewModel,
    TunnerThemePalette palette,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DjInteractiveKeymapVisualizerModal(
        viewModel: viewModel,
        palette: palette,
      ),
    );
  }

  @override
  State<DjInteractiveKeymapVisualizerModal> createState() =>
      _DjInteractiveKeymapVisualizerModalState();
}

class _DjInteractiveKeymapVisualizerModalState
    extends State<DjInteractiveKeymapVisualizerModal> {
  String? _selectedKey;
  String? _lastKeyPressed;

  // QWERTY physical keyboard layout rows: [keyLabel, displayLabel, flexWidth]
  static const List<List<_KeyDef>> _keyboardRows = [
    // Number Row
    [
      _KeyDef('Backquote', '`', 10),
      _KeyDef('Digit 1', '1', 10),
      _KeyDef('Digit 2', '2', 10),
      _KeyDef('Digit 3', '3', 10),
      _KeyDef('Digit 4', '4', 10),
      _KeyDef('Digit 5', '5', 10),
      _KeyDef('Digit 6', '6', 10),
      _KeyDef('Digit 7', '7', 10),
      _KeyDef('Digit 8', '8', 10),
      _KeyDef('Digit 9', '9', 10),
      _KeyDef('Digit 0', '0', 10),
      _KeyDef('Minus', '-', 10),
      _KeyDef('Equal', '=', 10),
      _KeyDef('Backspace', 'BACKSPACE', 16),
    ],
    // Row 1 (Tab / QWERTY)
    [
      _KeyDef('Tab', 'TAB', 15),
      _KeyDef('Key Q', 'Q', 10),
      _KeyDef('Key W', 'W', 10),
      _KeyDef('Key E', 'E', 10),
      _KeyDef('Key R', 'R', 10),
      _KeyDef('Key T', 'T', 10),
      _KeyDef('Key Y', 'Y', 10),
      _KeyDef('Key U', 'U', 10),
      _KeyDef('Key I', 'I', 10),
      _KeyDef('Key O', 'O', 10),
      _KeyDef('Key P', 'P', 10),
      _KeyDef('Bracket Left', '[', 10),
      _KeyDef('Bracket Right', ']', 10),
      _KeyDef('Backslash', r'\', 11),
    ],
    // Row 2 (Caps / ASDF)
    [
      _KeyDef('CapsLock', 'CAPS', 18),
      _KeyDef('Key A', 'A', 10),
      _KeyDef('Key S', 'S', 10),
      _KeyDef('Key D', 'D', 10),
      _KeyDef('Key F', 'F', 10),
      _KeyDef('Key G', 'G', 10),
      _KeyDef('Key H', 'H', 10),
      _KeyDef('Key J', 'J', 10),
      _KeyDef('Key K', 'K', 10),
      _KeyDef('Key L', 'L', 10),
      _KeyDef('Semicolon', ';', 10),
      _KeyDef('Quote', "'", 10),
      _KeyDef('Enter', 'ENTER', 22),
    ],
    // Row 3 (Shift / ZXCV)
    [
      _KeyDef('ShiftLeft', 'SHIFT', 24),
      _KeyDef('Key Z', 'Z', 10),
      _KeyDef('Key X', 'X', 10),
      _KeyDef('Key C', 'C', 10),
      _KeyDef('Key V', 'V', 10),
      _KeyDef('Key B', 'B', 10),
      _KeyDef('Key N', 'N', 10),
      _KeyDef('Key M', 'M', 10),
      _KeyDef('Comma', ',', 10),
      _KeyDef('Period', '.', 10),
      _KeyDef('Slash', '/', 10),
      _KeyDef('ShiftRight', 'SHIFT', 26),
    ],
    // Row 4 (Spacebar)
    [
      _KeyDef('ControlLeft', 'CTRL', 15),
      _KeyDef('AltLeft', 'ALT', 15),
      _KeyDef('Space', 'SPACEBAR', 70),
      _KeyDef('AltRight', 'ALT', 15),
      _KeyDef('ControlRight', 'CTRL', 15),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final vm = widget.viewModel;
    final profile = vm.keymapProfile;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final clean = DjKeymapProfileEntity.cleanKeyLabel(
            event.logicalKey.keyLabel.isNotEmpty
                ? event.logicalKey.keyLabel
                : (event.logicalKey.debugName ?? ''),
          );
          setState(() {
            _lastKeyPressed = clean;
          });
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 960,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(context, profile, palette),

              // Preset Selector Bar & Legend
              _buildPresetsAndLegendBar(vm),

              // Interactive QWERTY Keyboard Canvas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _buildVisualKeyboard(profile),
              ),

              // Action Remap Inspector for Selected Key
              if (_selectedKey != null) ...[
                _buildKeyAssignerSection(profile, vm),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Haz clic en cualquier tecla para ver o modificar su acción asignada',
                    style: TextStyle(color: palette.textMutedColor, fontSize: 12),
                  ),
                ),
              ],

              // Footer Controls
              _buildFooter(context, vm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DjKeymapProfileEntity profile,
    TunnerThemePalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF141924),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFF222B3D))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.keyboard, color: Color(0xFF00E5FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configurador Interactivo de Teclado QWERTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Perfil Activo: ${profile.name} (${profile.keyBindings.length} atajos asignados)',
                  style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                ),
              ],
            ),
          ),
          if (_lastKeyPressed != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
              ),
              child: Text(
                'ÚLTIMA TECLA: $_lastKeyPressed',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsAndLegendBar(DjConsoleViewModel vm) {
    final presets = DjKeymapProfileEntity.factoryProfiles();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFF10141E),
      child: Row(
        children: [
          const Text(
            'Presets Estándar:',
            style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((preset) {
                  final isCurrent = vm.keymapProfile.id == preset.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      key: Key('preset_${preset.id}'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isCurrent ? const Color(0xFF1E283C) : Colors.transparent,
                        foregroundColor: isCurrent ? const Color(0xFF00E5FF) : const Color(0xFFB0B0C4),
                        side: BorderSide(
                          color: isCurrent ? const Color(0xFF00E5FF) : const Color(0xFF28344A),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        vm.setKeymapProfile(preset);
                        setState(() {});
                      },
                      child: Text(preset.name, style: const TextStyle(fontSize: 11)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Legend Color Indicators
          _buildLegendChip('Deck A', const Color(0xFF00E5FF)),
          const SizedBox(width: 6),
          _buildLegendChip('Deck B', const Color(0xFFFFAB00)),
          const SizedBox(width: 6),
          _buildLegendChip('Crossfader', const Color(0xFF00E676)),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildVisualKeyboard(DjKeymapProfileEntity profile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090B10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2433)),
      ),
      child: Column(
        children: _keyboardRows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: row.map((keyDef) {
                return Expanded(
                  flex: keyDef.flexWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _buildKeyWidget(keyDef, profile),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyWidget(_KeyDef keyDef, DjKeymapProfileEntity profile) {
    final action = profile.resolveAction(keyDef.keyId);
    final isSelected = _selectedKey == keyDef.keyId;

    Color keyColor;
    Color textColor = Colors.white;
    String actionLabel = '';

    if (action != null) {
      if (action.name.startsWith('deckA')) {
        keyColor = const Color(0xFF00E5FF).withValues(alpha: 0.25);
        textColor = const Color(0xFF00E5FF);
        actionLabel = action.displayName.replaceAll('Deck A: ', '');
      } else if (action.name.startsWith('deckB')) {
        keyColor = const Color(0xFFFFAB00).withValues(alpha: 0.25);
        textColor = const Color(0xFFFFAB00);
        actionLabel = action.displayName.replaceAll('Deck B: ', '');
      } else {
        keyColor = const Color(0xFF00E676).withValues(alpha: 0.25);
        textColor = const Color(0xFF00E676);
        actionLabel = action.displayName;
      }
    } else {
      keyColor = const Color(0xFF161A24);
      textColor = const Color(0xFF7E8B9E);
    }

    if (isSelected) {
      keyColor = const Color(0xFFFFD700).withValues(alpha: 0.35);
      textColor = const Color(0xFFFFD700);
    }

    return InkWell(
      key: Key('key_${keyDef.keyId}'),
      onTap: () {
        setState(() {
          _selectedKey = keyDef.keyId;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: keyColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : (action != null ? textColor.withValues(alpha: 0.6) : const Color(0xFF262E40)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              keyDef.displayLabel,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (actionLabel.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                actionLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.85),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeyAssignerSection(
    DjKeymapProfileEntity profile,
    DjConsoleViewModel vm,
  ) {
    final currentAction = profile.resolveAction(_selectedKey!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141926),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF28344A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFFD700)),
            ),
            child: Text(
              'TECLA [$_selectedKey]',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DjAction>(
                value: currentAction,
                hint: const Text(
                  'Seleccionar Acción para asignar a esta tecla...',
                  style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                ),
                dropdownColor: const Color(0xFF181E2E),
                isExpanded: true,
                items: DjAction.values.map((action) {
                  return DropdownMenuItem<DjAction>(
                    value: action,
                    child: Text(
                      '[${action.category}] ${action.displayName}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (newAction) {
                  if (newAction != null && _selectedKey != null) {
                    vm.bindKey(_selectedKey!, newAction);
                    setState(() {});
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (currentAction != null) ...[
            TextButton.icon(
              onPressed: () {
                final updated = profile.unbindKey(_selectedKey!);
                vm.setKeymapProfile(updated);
                setState(() {});
              },
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252), size: 16),
              label: const Text('Desvincular', style: TextStyle(color: Color(0xFFFF5252), fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, DjConsoleViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121622),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFF1E2433))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            key: const Key('reset_keymap_visualizer_btn'),
            onPressed: () {
              vm.resetKeymapToDefault();
              setState(() {});
            },
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restablecer a Valores de Fábrica', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8E9BAE),
              side: const BorderSide(color: Color(0xFF28344A)),
            ),
          ),
          ElevatedButton(
            key: const Key('close_keymap_visualizer_btn'),
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Guardar y Cerrar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyDef {
  final String keyId;
  final String displayLabel;
  final int flexWidth;

  const _KeyDef(this.keyId, this.displayLabel, this.flexWidth);
}
