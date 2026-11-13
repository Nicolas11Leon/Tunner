import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/dj_action.dart';
import 'dj_console_view_model.dart';

/// Interactive modal allowing users to inspect and remap physical QWERTY keys to DJ actions.
class DjKeymapEditorModal extends StatefulWidget {
  final DjConsoleViewModel viewModel;
  final TunnerThemePalette palette;

  const DjKeymapEditorModal({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  static Future<void> show(BuildContext context, DjConsoleViewModel viewModel, TunnerThemePalette palette) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DjKeymapEditorModal(viewModel: viewModel, palette: palette),
    );
  }

  @override
  State<DjKeymapEditorModal> createState() => _DjKeymapEditorModalState();
}

class _DjKeymapEditorModalState extends State<DjKeymapEditorModal> {
  String _selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final profile = widget.viewModel.keymapProfile;

    final categories = ['Todos', 'Deck A', 'Deck B', 'Crossfader', 'Master'];

    // Invert map to show: action -> bound keys
    final actionToKeys = <DjAction, List<String>>{};
    for (final entry in profile.keyBindings.entries) {
      actionToKeys.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    final filteredActions = DjAction.values.where((action) {
      if (_selectedCategory == 'Todos') return true;
      return action.category == _selectedCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.keyboard, color: palette.primaryAccent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mapeo Universal de Teclado QWERTY',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Personaliza atajos para tocar tu mezcla sin consola fisica',
                        style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const Key('reset_keymap_btn'),
                  onPressed: () {
                    widget.viewModel.resetKeymapToDefault();
                    setState(() {});
                  },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restablecer', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: palette.secondaryAccent),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : palette.textColor)),
                    selected: isSelected,
                    selectedColor: palette.primaryAccent,
                    backgroundColor: palette.cardBackground,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Actions List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredActions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final action = filteredActions[index];
                final boundKeys = actionToKeys[action] ?? [];

                return Material(
                  color: palette.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.displayName,
                                style: TextStyle(
                                  color: palette.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                action.category,
                                style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        // Bound keys badges
                        if (boundKeys.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: boundKeys.map((k) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: palette.primaryAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  k,
                                  style: TextStyle(
                                    color: palette.primaryAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Text(
                            'Sin asignar',
                            style: TextStyle(color: palette.textMutedColor, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: Key('rebind_action_${action.name}'),
                          icon: Icon(Icons.edit, size: 18, color: palette.primaryAccent),
                          tooltip: 'Reasignar tecla',
                          onPressed: () => _promptRebindKey(action),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _promptRebindKey(DjAction action) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _KeyCaptureDialog(
          action: action,
          palette: widget.palette,
          onKeyCaptured: (keyLabel) {
            widget.viewModel.bindKey(keyLabel, action);
            setState(() {});
          },
        );
      },
    );
  }
}

class _KeyCaptureDialog extends StatefulWidget {
  final DjAction action;
  final TunnerThemePalette palette;
  final ValueChanged<String> onKeyCaptured;

  const _KeyCaptureDialog({
    required this.action,
    required this.palette,
    required this.onKeyCaptured,
  });

  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final label = event.logicalKey.keyLabel.isNotEmpty ? event.logicalKey.keyLabel : event.logicalKey.debugName ?? 'Key';
          widget.onKeyCaptured(label);
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: palette.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Presiona una tecla',
          style: TextStyle(color: palette.textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Asignando accion:',
              style: TextStyle(color: palette.textMutedColor, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              widget.action.displayName,
              style: TextStyle(color: palette.primaryAccent, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Presiona cualquier tecla de tu teclado fisico ahora...',
                style: TextStyle(color: palette.textColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(color: palette.textMutedColor)),
          ),
        ],
      ),
    );
  }
}
