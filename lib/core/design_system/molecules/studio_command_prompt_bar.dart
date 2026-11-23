import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../studio_theme_provider.dart';

/// Modelo de una sugerencia o comando autocompletable en el Prompt Bar.
class PromptSuggestion {
  final String id;
  final String trigger; // '/' para acciones, '@' para módulos, o vacía para general
  final String command; // ej. '/afinar', '/metro', '/bpm', '/help', '@rack'
  final String title;
  final String description;
  final String category;
  final String? shortcut;
  final IconData icon;
  final void Function(String rawInput) onExecute;

  const PromptSuggestion({
    required this.id,
    required this.trigger,
    required this.command,
    required this.title,
    required this.description,
    required this.category,
    this.shortcut,
    required this.icon,
    required this.onExecute,
  });
}

/// Molécula de UI: Barra de Comandos Interactiva con Autocompletado (StudioCommandPromptBar).
///
/// Inspirada en la consola omnibox de Antigravity IDE, Claude Code y VS Code.
/// Permite autocompletar acciones con `/`, módulos con `@`, navegar con teclas de dirección,
/// ejecutar comandos con Enter y consultar ayuda con `/help` o el botón `? Help`.
class StudioCommandPromptBar extends StatefulWidget {
  final List<PromptSuggestion> suggestions;
  final VoidCallback onOpenHelp;
  final ValueChanged<String>? onCommandExecuted;
  final String engineName;
  final bool isRecording;
  final VoidCallback? onToggleRecording;

  const StudioCommandPromptBar({
    super.key,
    required this.suggestions,
    required this.onOpenHelp,
    this.onCommandExecuted,
    this.engineName = 'Tartini DSP 2.1',
    this.isRecording = false,
    this.onToggleRecording,
  });

  @override
  State<StudioCommandPromptBar> createState() => _StudioCommandPromptBarState();
}

class _StudioCommandPromptBarState extends State<StudioCommandPromptBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  int _selectedIndex = 0;
  List<PromptSuggestion> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _filteredSuggestions = widget.suggestions;

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(StudioCommandPromptBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      _applySuggestionFilter(_controller.text);
      if (_overlayEntry != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _overlayEntry?.markNeedsBuild();
        });
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    _filterSuggestions(_controller.text);
    if (_focusNode.hasFocus) {
      _showOverlay();
    }
  }

  void _applySuggestionFilter(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      // Muestra sugerencias principales por defecto
      _filteredSuggestions = widget.suggestions;
    } else if (query.startsWith('/')) {
      final commandToken = query.split(RegExp(r'\s+')).first;
      final commandQuery = commandToken.length > 1 ? commandToken.substring(1) : '';
      _filteredSuggestions = widget.suggestions
          .where((s) =>
              s.trigger == '/' &&
              (s.command.toLowerCase().startsWith(commandToken) ||
                  s.title.toLowerCase().contains(commandQuery) ||
                  s.description.toLowerCase().contains(commandQuery)))
          .toList();
    } else if (query.startsWith('@')) {
      final moduleToken = query.split(RegExp(r'\s+')).first;
      final moduleQuery = moduleToken.length > 1 ? moduleToken.substring(1) : '';
      _filteredSuggestions = widget.suggestions
          .where((s) =>
              s.trigger == '@' &&
              (s.command.toLowerCase().startsWith(moduleToken) ||
                  s.title.toLowerCase().contains(moduleQuery)))
          .toList();
    } else {
      _filteredSuggestions = widget.suggestions
          .where((s) =>
              s.command.toLowerCase().contains(query) ||
              s.title.toLowerCase().contains(query) ||
              s.description.toLowerCase().contains(query) ||
              s.category.toLowerCase().contains(query))
          .toList();
    }

    if (_selectedIndex >= _filteredSuggestions.length) {
      _selectedIndex = 0;
    }
  }

  void _filterSuggestions(String rawQuery) {
    setState(() {
      _applySuggestionFilter(rawQuery);
    });

    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    final bool openDownward = position != null && position.dy < 280;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final tokens = StudioThemeScope.tokensOf(context);

        return Positioned(
          width: 520.0,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: openDownward ? Alignment.bottomLeft : Alignment.topLeft,
            followerAnchor: openDownward ? Alignment.topLeft : Alignment.bottomLeft,
            offset: Offset(0.0, openDownward ? 8.0 : -8.0),
            child: Material(
              color: Colors.transparent,
              elevation: 8.0,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280.0),
                decoration: BoxDecoration(
                  color: tokens.panelBackground,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(
                    color: tokens.borderHairline,
                    width: tokens.borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16.0,
                      offset: Offset(0, openDownward ? 4 : -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera del popup con ayuda de navegación
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: tokens.panelHeaderBackground,
                        border: Border(
                          bottom: BorderSide(
                            color: tokens.borderHairline,
                            width: tokens.borderWidth,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 12, color: tokens.accentPrimary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'COMANDOS (${_filteredSuggestions.length})',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Tab: Completar  •  Enter: Ejecutar',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 9.0,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lista de sugerencias filtradas
                    Flexible(
                      child: _filteredSuggestions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No se encontraron comandos para "${_controller.text}". Escribe /help para ver el catálogo.',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              shrinkWrap: true,
                              itemCount: _filteredSuggestions.length,
                              itemBuilder: (context, index) {
                                final item = _filteredSuggestions[index];
                                final isHovered = index == _selectedIndex;

                                return InkWell(
                                  onTap: () => _executeSuggestion(item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                      vertical: 6.0,
                                    ),
                                    color: isHovered
                                        ? tokens.hoverSurface.withValues(alpha: 0.9)
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 14,
                                          color: isHovered
                                              ? tokens.accentPrimary
                                              : tokens.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.command,
                                          style: TextStyle(
                                            color: tokens.accentPrimary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontSize: 11.5,
                                              fontWeight: isHovered
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (item.shortcut != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tokens.elevatedSurface,
                                              borderRadius: BorderRadius.circular(
                                                tokens.radiusSmall,
                                              ),
                                              border: Border.all(
                                                color: tokens.borderHairline,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              item.shortcut!,
                                              style: TextStyle(
                                                color: tokens.textMuted,
                                                fontSize: 8.5,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
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
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _executeSuggestion(PromptSuggestion item) {
    final rawText = _controller.text;
    item.onExecute(rawText);

    _controller.clear();
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _autocompleteSelected() {
    if (_filteredSuggestions.isNotEmpty && _selectedIndex < _filteredSuggestions.length) {
      final selected = _filteredSuggestions[_selectedIndex];
      _controller.text = '${selected.command} ';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  void _submitCurrentText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (text == '/help' || text == '/ayuda' || text == '?') {
      widget.onOpenHelp();
      _controller.clear();
      _removeOverlay();
      _focusNode.unfocus();
      return;
    }

    final commandToken = text.split(RegExp(r'\s+')).first.toLowerCase();

    // Buscar si coincide con el comando base de alguna sugerencia disponible
    PromptSuggestion? matchingSuggestion;
    for (final s in _filteredSuggestions) {
      if (s.command.toLowerCase() == commandToken) {
        matchingSuggestion = s;
        break;
      }
    }
    matchingSuggestion ??= (_filteredSuggestions.isNotEmpty ? _filteredSuggestions[_selectedIndex] : null);

    if (matchingSuggestion != null &&
        (text.startsWith('/') || text.startsWith('@') || matchingSuggestion.command.toLowerCase() == commandToken)) {
      _executeSuggestion(matchingSuggestion);
    } else {
      widget.onCommandExecuted?.call(text);
      _controller.clear();
      _removeOverlay();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          border: Border(
            top: BorderSide(
              color: tokens.borderHairline,
              width: tokens.borderWidth,
            ),
          ),
        ),
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;

            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (_filteredSuggestions.isNotEmpty) {
                setState(() {
                  _selectedIndex = (_selectedIndex + 1) % _filteredSuggestions.length;
                });
                _overlayEntry?.markNeedsBuild();
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_filteredSuggestions.isNotEmpty) {
                setState(() {
                  _selectedIndex = (_selectedIndex - 1 + _filteredSuggestions.length) %
                      _filteredSuggestions.length;
                });
                _overlayEntry?.markNeedsBuild();
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.tab) {
              _autocompleteSelected();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              _removeOverlay();
              _focusNode.unfocus();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              _submitCurrentText();
              return KeyEventResult.handled;
            }

            return KeyEventResult.ignored;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: tokens.inputSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMedium),
              border: Border.all(
                color: _focusNode.hasFocus ? tokens.accentPrimary : tokens.borderHairline,
                width: tokens.borderWidth,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 15,
                  color: _focusNode.hasFocus ? tokens.accentPrimary : tokens.textMuted,
                ),
                const SizedBox(width: 8),

                // Campo de Entrada Interactivo
                Expanded(
                  child: TextField(
                    key: const Key('studio_command_prompt_input'),
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Comandos (@ para módulos, / para acciones, /help para ayuda)...',
                      hintStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11.5,
                        fontFamily: 'sans-serif',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6.0),
                    ),
                    onSubmitted: (_) => _submitCurrentText(),
                  ),
                ),

                const SizedBox(width: 8),

                // Botón ? Help de Ayuda Universal
                InkWell(
                  key: const Key('studio_command_help_btn'),
                  onTap: widget.onOpenHelp,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.borderHairline, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded, size: 12, color: tokens.accentPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Help',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Selector de Motor DSP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(color: tokens.borderHairline, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.engineName,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: tokens.textMuted),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Botón / Indicador de Micrófono
                InkWell(
                  onTap: widget.onToggleRecording,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      widget.isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 15,
                      color: widget.isRecording ? Colors.redAccent : tokens.accentPrimary,
                    ),
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
