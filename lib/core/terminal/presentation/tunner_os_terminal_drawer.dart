import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design_system/studio_design_system.dart';
import '../domain/tunner_os_command_entity.dart';
import '../application/tunner_os_kernel.dart';

/// Cajón interactivo de Terminal Tunner OS CLI.
/// Emula una consola de comandos embebida de alta fidelidad estilo Quake / VS Code para DAWs.
class TunnerOsTerminalDrawer extends StatefulWidget {
  final TunnerOsKernel kernel;
  final VoidCallback onClose;
  final List<TunnerOsCommandHistoryItem> externalHistory;

  const TunnerOsTerminalDrawer({
    super.key,
    required this.kernel,
    required this.onClose,
    this.externalHistory = const <TunnerOsCommandHistoryItem>[],
  });

  @override
  State<TunnerOsTerminalDrawer> createState() => _TunnerOsTerminalDrawerState();
}

class _TunnerOsTerminalDrawerState extends State<TunnerOsTerminalDrawer> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _drawerListenerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<TunnerOsCommandHistoryItem> _history = [];
  final List<String> _sentCommands = [];
  int _historyNavIndex = -1;
  int _syncedExternalCount = 0;

  @override
  void initState() {
    super.initState();
    _history.add(
      TunnerOsCommandHistoryItem(
        commandLine: 'system.boot',
        result: TunnerOsCommandResult.success(
          'TUNNER OS KERNEL v1.0.0 [AUDIO WORKSTATION ENGINE]\nEscribe "help" para ver los comandos disponibles o usa los chips rápidos.',
        ),
      ),
    );
    if (widget.externalHistory.isNotEmpty) {
      _history.addAll(widget.externalHistory);
      _syncedExternalCount = widget.externalHistory.length;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TunnerOsTerminalDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalHistory.length > _syncedExternalCount) {
      final incoming = widget.externalHistory.sublist(_syncedExternalCount);
      _history.addAll(incoming);
      _syncedExternalCount = widget.externalHistory.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    } else if (widget.externalHistory.length < _syncedExternalCount) {
      _syncedExternalCount = widget.externalHistory.length;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _drawerListenerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _submitCommand(String text) async {
    final cmd = text.trim();
    if (cmd.isEmpty) return;

    _inputController.clear();
    _sentCommands.add(cmd);
    _historyNavIndex = -1;

    final result = await widget.kernel.execute(cmd);
    if (!mounted) return;

    setState(() {
      if (result.message == 'CLEAR_SCREEN') {
        _history.clear();
      } else {
        _history.add(
          TunnerOsCommandHistoryItem(
            commandLine: cmd,
            result: result,
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
      _focusNode.requestFocus();
    });
  }

  void _onKeyDown(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_sentCommands.isEmpty) return;
        if (_historyNavIndex == -1) {
          _historyNavIndex = _sentCommands.length - 1;
        } else if (_historyNavIndex > 0) {
          _historyNavIndex--;
        }
        _inputController.text = _sentCommands[_historyNavIndex];
        _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_sentCommands.isEmpty || _historyNavIndex == -1) return;
        if (_historyNavIndex < _sentCommands.length - 1) {
          _historyNavIndex++;
          _inputController.text = _sentCommands[_historyNavIndex];
        } else {
          _historyNavIndex = -1;
          _inputController.clear();
        }
        _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return Material(
      color: Colors.transparent,
      child: KeyboardListener(
        focusNode: _drawerListenerFocusNode,
        onKeyEvent: _onKeyDown,
        child: Container(
        key: const Key('tunner_os_terminal_drawer'),
        height: 280,
        decoration: BoxDecoration(
          color: tokens.panelBackground.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: tokens.borderFocus, width: tokens.borderWidth),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Barra superior de la terminal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.panelHeaderBackground,
                border: Border(
                  bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
                ),
              ),
              child: Row(
                children: [
                  StudioIcon(
                    StudioIconId.toolTerminal,
                    size: 15,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TUNNER OS TERMINAL & CLI',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  // Chips de comandos rápidos
                  _quickChip('dsp status', tokens),
                  const SizedBox(width: 6),
                  _quickChip('fs ls', tokens),
                  const SizedBox(width: 6),
                  _quickChip('tuner run dj', tokens),
                  const SizedBox(width: 6),
                  _quickChip('help', tokens),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      size: 15,
                      color: tokens.textSecondary,
                      tintCustomAsset: true,
                    ),
                    tooltip: 'Cerrar Terminal (Esc o Ctrl + ~)',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Historial de comandos
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  final isErr = !item.result.isSuccess;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'tunner> ',
                              style: TextStyle(
                                color: tokens.accentSuccess,
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.commandLine,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (item.result.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 14, top: 2),
                            child: SelectableText(
                              item.result.message,
                              style: TextStyle(
                                color: isErr ? tokens.accentDanger : tokens.textSecondary,
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Entrada de texto inferior
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                border: Border(
                  top: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'tunner> ',
                    style: TextStyle(
                      color: tokens.accentPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('tunner_os_terminal_input'),
                      controller: _inputController,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                      cursorColor: tokens.accentPrimary,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Escribe un comando... (e.g. dj load A "Para Elisa", help)',
                        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _submitCommand,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _submitCommand(_inputController.text),
                    icon: Icon(
                      Icons.subdirectory_arrow_left,
                      size: 16,
                      color: tokens.accentPrimary,
                    ),
                    tooltip: 'Ejecutar (Enter)',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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

  Widget _quickChip(String cmd, StudioDesignTokens tokens) {
    return InkWell(
      onTap: () => _submitCommand(cmd),
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Text(
          cmd,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 9.5,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
