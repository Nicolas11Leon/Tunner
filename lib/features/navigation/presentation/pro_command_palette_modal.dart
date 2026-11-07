import 'package:flutter/material.dart';
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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CommandItem> get _filteredCommands {
    if (_query.isEmpty) return widget.commands;
    return widget.commands.where((cmd) {
      return cmd.title.toLowerCase().contains(_query) ||
          cmd.subtitle.toLowerCase().contains(_query) ||
          cmd.category.toLowerCase().contains(_query);
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
                          autofocus: true,
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
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
                Divider(
                  height: 1,
                  color: palette.staffLinesColor.withValues(alpha: 0.2),
                ),

                // Lista de resultados
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron comandos para "$_query"',
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: results.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: palette.staffLinesColor.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final cmd = results[index];
                            return InkWell(
                              key: Key('command_item_${cmd.id}'),
                              onTap: () {
                                Navigator.of(context).pop();
                                cmd.onSelect();
                              },
                              hoverColor: palette.primaryAccent.withValues(alpha: 0.1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: palette.primaryAccent.withValues(alpha: 0.15),
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
                                              fontWeight: FontWeight.bold,
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
