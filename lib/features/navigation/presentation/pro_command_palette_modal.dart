import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tunner_theme.dart';

/// Modelo de un elemento o comando ejecutable en la Command Palette.
class CommandItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final String? shortcutLabel;
  final VoidCallback onSelect;

  const CommandItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    this.shortcutLabel,
    required this.onSelect,
  });
}

/// Modal estilo Spotlight / Command Palette profesional para búsqueda ultrarrápida.
class ProCommandPaletteModal extends StatefulWidget {
  final TunnerThemePalette palette;
  final List<CommandItem> commands;

  const ProCommandPaletteModal({
    super.key,
    required this.palette,
    required this.commands,
  });

  static Future<void> show({
    required BuildContext context,
    required TunnerThemePalette palette,
    required List<CommandItem> commands,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => ProCommandPaletteModal(
        palette: palette,
        commands: commands,
      ),
    );
  }

  @override
  State<ProCommandPaletteModal> createState() => _ProCommandPaletteModalState();
}

class _ProCommandPaletteModalState extends State<ProCommandPaletteModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  String _searchQuery = '';
  String _selectedCategoryFilter = 'all';
  int _selectedIndex = 0;

  static const List<({String id, String keyName, String label})> _categoryFilters = [
    (id: 'all', keyName: 'cmd_filter_all', label: 'Todos'),
    (id: 'navigation', keyName: 'cmd_filter_navigation', label: 'Espacios'),
    (id: 'dsp', keyName: 'cmd_filter_dsp', label: 'Afinación & DSP'),
    (id: 'scores', keyName: 'cmd_filter_scores', label: 'Partituras & Archivos'),
    (id: 'pedagogy', keyName: 'cmd_filter_pedagogy', label: 'Pedagogía'),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _selectedIndex = 0;
      });
    });

    _focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      final results = _filteredCommands;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (results.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % results.length;
          });
          _scrollToSelected();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (results.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex - 1 + results.length) % results.length;
          });
          _scrollToSelected();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (results.isNotEmpty && _selectedIndex < results.length) {
          final chosen = results[_selectedIndex];
          Navigator.of(context).pop();
          chosen.onSelect();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _scrollToSelected() {
    if (!_scrollCtrl.hasClients) return;
    const itemHeight = 60.0;
    final targetOffset = (_selectedIndex * itemHeight).clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );
    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutQuad,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _matchesCategoryFilter(CommandItem cmd) {
    if (_selectedCategoryFilter == 'all') return true;
    final cat = cmd.category.toLowerCase();
    switch (_selectedCategoryFilter) {
      case 'navigation':
        return cat.contains('navegación') ||
            cat.contains('espacios') ||
            cat.contains('interfaz') ||
            cat.contains('sistema');
      case 'dsp':
        return cat.contains('afinación') ||
            cat.contains('dsp') ||
            cat.contains('audio') ||
            cat.contains('metrónomo') ||
            cat.contains('transporte') ||
            cat.contains('ajustes');
      case 'scores':
        return cat.contains('archivo') ||
            cat.contains('partitura') ||
            cat.contains('composición') ||
            cat.contains('producción') ||
            cat.contains('grabación');
      case 'pedagogy':
        return cat.contains('pedagogía') ||
            cat.contains('conservatorio') ||
            cat.contains('entrenamiento') ||
            cat.contains('armonía') ||
            cat.contains('instrumento');
      default:
        return true;
    }
  }

  List<CommandItem> get _filteredCommands {
    return widget.commands.where((cmd) {
      if (!_matchesCategoryFilter(cmd)) return false;
      if (_searchQuery.isEmpty) return true;
      return cmd.title.toLowerCase().contains(_searchQuery) ||
          cmd.subtitle.toLowerCase().contains(_searchQuery) ||
          cmd.category.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final results = _filteredCommands;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
          maxHeight: 520,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.primaryAccent.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input de búsqueda rápida
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: palette.primaryAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('command_palette_search_input'),
                          controller: _searchCtrl,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          onSubmitted: (_) {
                            if (results.isNotEmpty && _selectedIndex < results.length) {
                              final chosen = results[_selectedIndex];
                              Navigator.of(context).pop();
                              chosen.onSelect();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar comando, herramienta o instrumento (ej: metrónomo, guitarra)...',
                            hintStyle: TextStyle(
                              color: palette.textMutedColor.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Container(
                        key: const Key('command_palette_shortcut_hint_badge'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.scaffoldBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: palette.staffLinesColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'CTRL+K / CTRL+P',
                          style: TextStyle(
                            color: palette.textMutedColor,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.scaffoldBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: palette.staffLinesColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'ESC para salir',
                          style: TextStyle(
                            color: palette.textMutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Barra horizontal de Píldoras de Filtro por Categoría
                Container(
                  key: const Key('command_palette_category_filter_bar'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < _categoryFilters.length; i++)
                        Builder(
                          builder: (context) {
                            final filter = _categoryFilters[i];
                            final isActive = _selectedCategoryFilter == filter.id;
                            return InkWell(
                              key: Key(filter.keyName),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _selectedCategoryFilter = filter.id;
                                  _selectedIndex = 0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? palette.primaryAccent.withValues(alpha: 0.22)
                                      : palette.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? palette.primaryAccent
                                        : palette.staffLinesColor.withValues(alpha: 0.25),
                                    width: isActive ? 1.3 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  filter.label,
                                  style: TextStyle(
                                    color: isActive
                                        ? palette.textColor
                                        : palette.textMutedColor,
                                    fontSize: 11.0,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: palette.staffLinesColor.withValues(alpha: 0.2),
                ),

                // Lista de resultados
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron comandos para "$_searchQuery"',
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollCtrl,
                          cacheExtent: 2000,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: palette.staffLinesColor.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final cmd = results[index];
                            final isSelected = index == _selectedIndex;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.primaryAccent.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: palette.primaryAccent.withValues(alpha: 0.5),
                                        width: 1.2,
                                      )
                                    : null,
                              ),
                              child: InkWell(
                                key: Key('command_item_${cmd.id}'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  cmd.onSelect();
                                },
                                hoverColor: palette.primaryAccent.withValues(alpha: 0.1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? palette.primaryAccent.withValues(alpha: 0.3)
                                              : palette.primaryAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          cmd.icon,
                                          color: palette.primaryAccent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cmd.title,
                                              style: TextStyle(
                                                color: palette.textColor,
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              cmd.subtitle,
                                              style: TextStyle(
                                                color: palette.textMutedColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Icon(
                                            Icons.keyboard_return_rounded,
                                            size: 16,
                                            color: palette.primaryAccent,
                                          ),
                                        ),
                                      if (cmd.shortcutLabel != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: palette.scaffoldBackground,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: palette.staffLinesColor.withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Text(
                                            cmd.shortcutLabel!,
                                            style: TextStyle(
                                              color: palette.textMutedColor,
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
