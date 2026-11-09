import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/pedagogical_task_contract.dart';
import '../domain/task_catalog_index.dart';
import 'atomic_widgets/task_badge_atom.dart';

/// Modal interactivo de navegación por teclado para el Salto Rápido a Tareas (*Jump to Task*).
///
/// Atajos integrados:
/// - `J` o `Cmd/Ctrl + J`: Abre el modal desde cualquier lugar.
/// - `↓ / ↑`: Navegación vertical entre tareas encontradas.
/// - `Enter`: Ejecuta y salta a la tarea seleccionada.
/// - `Escape`: Cierra el modal de forma instantánea.
class TaskQuickJumpModal extends StatefulWidget {
  final TunnerThemePalette palette;
  final TaskCatalogIndex catalogIndex;
  final ValueChanged<PedagogicalTaskEntity>? onTaskSelected;

  const TaskQuickJumpModal({
    super.key,
    required this.palette,
    required this.catalogIndex,
    this.onTaskSelected,
  });

  static Future<PedagogicalTaskEntity?> show({
    required BuildContext context,
    required TunnerThemePalette palette,
    TaskCatalogIndex? catalogIndex,
    ValueChanged<PedagogicalTaskEntity>? onTaskSelected,
  }) {
    return showDialog<PedagogicalTaskEntity>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => TaskQuickJumpModal(
        palette: palette,
        catalogIndex: catalogIndex ?? TaskCatalogIndex(),
        onTaskSelected: onTaskSelected,
      ),
    );
  }

  @override
  State<TaskQuickJumpModal> createState() => _TaskQuickJumpModalState();
}

class _TaskQuickJumpModalState extends State<TaskQuickJumpModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  List<PedagogicalTaskEntity> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.catalogIndex.allTasks;
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _results = widget.catalogIndex.searchByQuery(_searchCtrl.text);
      _selectedIndex = 0;
    });
  }

  void _confirmSelection(PedagogicalTaskEntity task) {
    widget.onTaskSelected?.call(task);
    Navigator.of(context).pop(task);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _results.length;
        });
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_results.isNotEmpty) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1 + _results.length) % _results.length;
        });
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_results.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < _results.length) {
        _confirmSelection(_results[_selectedIndex]);
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: const Key('task_quick_jump_modal'),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.primaryAccent.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra de búsqueda superior
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.primaryAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.flash_on, color: palette.primaryAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('task_quick_jump_input'),
                            controller: _searchCtrl,
                            autofocus: true,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Saltar a tarea (ej: EAR.01, 001, síncopa)...',
                              hintStyle: TextStyle(
                                color: palette.textColor.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.staffLinesColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'JUMP [J]',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),

                  // Contador de resultados en tiempo real
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${_results.length} ${_results.length == 1 ? 'tarea encontrada' : 'tareas encontradas'}',
                            style: TextStyle(
                              color: palette.textColor.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '[↑/↓] Navegar   [ENTER] Salto',
                          style: TextStyle(
                            color: palette.textColor.withValues(alpha: 0.45),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de resultados
                  Flexible(
                    child: _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 36, color: palette.textColor.withValues(alpha: 0.3)),
                                const SizedBox(height: 10),
                                Text(
                                  'No se encontraron tareas con "${_searchCtrl.text}"',
                                  style: TextStyle(color: palette.textColor.withValues(alpha: 0.6), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            itemCount: _results.length,
                            separatorBuilder: (ctx, _) => const SizedBox(height: 4),
                            itemBuilder: (ctx, index) {
                              final task = _results[index];
                              final isSelected = index == _selectedIndex;

                              return InkWell(
                                key: Key('task_quick_jump_item_$index'),
                                onTap: () => _confirmSelection(task),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? palette.primaryAccent.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? palette.primaryAccent.withValues(alpha: 0.6)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      TaskCodeBadge(
                                        code: task.code,
                                        palette: palette,
                                        compact: true,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                color: palette.textColor,
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              task.description,
                                              style: TextStyle(
                                                color: palette.textColor.withValues(alpha: 0.55),
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TaskLevelPill(level: task.code.level, palette: palette),
                                      const SizedBox(width: 6),
                                      TaskGradeStamp(
                                        grade: task.bestGrade,
                                        status: task.status,
                                        palette: palette,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
