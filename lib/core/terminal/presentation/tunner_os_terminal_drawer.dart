import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/tunner_os_command_entity.dart';
import '../application/tunner_os_kernel.dart';

/// Cajón interactivo de Terminal Tunner OS CLI.
/// Emula una consola de comandos embebida de alta fidelidad estilo Quake / VS Code para DAWs.
class TunnerOsTerminalDrawer extends StatefulWidget {
  final TunnerOsKernel kernel;
  final VoidCallback onClose;

  const TunnerOsTerminalDrawer({
    super.key,
    required this.kernel,
    required this.onClose,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    _drawerListenerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
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
    return KeyboardListener(
      focusNode: _drawerListenerFocusNode,
      onKeyEvent: _onKeyDown,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF090D16).withValues(alpha: 0.96),
          border: const Border(
            top: BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
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
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  const Icon(Icons.terminal, size: 16, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 8),
                  const Text(
                    'TUNNER OS TERMINAL & CLI',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  // Chips de comandos rápidos
                  _quickChip('dsp status'),
                  const SizedBox(width: 6),
                  _quickChip('fs ls'),
                  const SizedBox(width: 6),
                  _quickChip('tuner run dj'),
                  const SizedBox(width: 6),
                  _quickChip('help'),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 16, color: Colors.white70),
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
                            const Text(
                              'tunner> ',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.commandLine,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 12,
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
                                color: isErr ? const Color(0xFFF87171) : const Color(0xFF94A3B8),
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
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  const Text(
                    'tunner> ',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                      cursorColor: const Color(0xFF00E5FF),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Escribe un comando... (e.g. dj load A "Para Elisa", help)',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _submitCommand,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _submitCommand(_inputController.text),
                    icon: const Icon(Icons.subdirectory_arrow_left, size: 16, color: Color(0xFF00E5FF)),
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
    );
  }

  Widget _quickChip(String cmd) {
    return InkWell(
      onTap: () => _submitCommand(cmd),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          cmd,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9.5,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
