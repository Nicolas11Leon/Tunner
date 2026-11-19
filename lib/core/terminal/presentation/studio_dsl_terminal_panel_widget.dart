import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/tunner_os_kernel.dart';

/// Consola REPL y editor interactivo para Tunner DSL en Tunner Studio.
/// Permite redactar, cargar plantillas y evaluar scripts declarativos en caliente.
class StudioDslTerminalPanelWidget extends StatefulWidget {
  final TunnerOsKernel kernel;
  final VoidCallback? onClose;

  const StudioDslTerminalPanelWidget({
    super.key,
    required this.kernel,
    this.onClose,
  });

  @override
  State<StudioDslTerminalPanelWidget> createState() => _StudioDslTerminalPanelWidgetState();
}

class _StudioDslTerminalPanelWidgetState extends State<StudioDslTerminalPanelWidget> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _outputScrollController = ScrollController();

  final List<String> _outputLog = [];
  bool _isEvaluating = false;

  static const String _templateQuickJam = '''
// Plantilla: Quick Jam
tempo 128;
channel synth;
connect @synth.out -> @master.in;
set @synth.waveform = "saw";
set @master.gain = -3.0 dB;
note C4 1/4;
note E4 1/4;
note G4 1/4;
chord [C4, E4, G4, B4] 1/2;
play;
''';

  static const String _templateMastering = '''
// Plantilla: Mastering Chain
set @master.gain = 0.0 dB;
set @eq.low = 2.5 dB;
set @eq.mid = -1.0 dB;
set @eq.high = 1.5 dB;
set @comp.threshold = -14.0 dB;
set @comp.ratio = 3.5;
''';

  @override
  void initState() {
    super.initState();
    _codeController.text = _templateQuickJam.trim();
    _outputLog.add('[TUNNER STUDIO REPL READY] Presiona Ctrl+Enter o pulsa "Ejecutar" para evaluar.');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }

  Future<void> _evaluateScript() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isEvaluating = true;
    });

    final cmd = 'dsl $code';
    final result = await widget.kernel.execute(cmd);

    setState(() {
      _isEvaluating = false;
      _outputLog.add('>>> EVALUACION [${DateTime.now().toIso8601String().substring(11, 19)}]:\n${result.message}\n');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outputScrollController.hasClients) {
        _outputScrollController.animateTo(
          _outputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _loadTemplate(String templateCode) {
    setState(() {
      _codeController.text = templateCode.trim();
    });
    _focusNode.requestFocus();
  }

  void _clearOutput() {
    setState(() {
      _outputLog.clear();
      _outputLog.add('[CONSOLA LIMPIADA]');
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isControlPressed && event.logicalKey == LogicalKeyboardKey.enter) {
        _evaluateScript();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final editorBg = isDark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Barra de Herramientas Superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
              color: isDark ? const Color(0xFF202024) : const Color(0xFFEBEBEF),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16.0),
                const SizedBox(width: 8.0),
                Text(
                  'TUNNER DSL STUDIO REPL',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                // Selector de Plantillas
                TextButton.icon(
                  onPressed: () => _loadTemplate(_templateQuickJam),
                  icon: const Icon(Icons.music_note, size: 14.0),
                  label: const Text('Quick Jam', style: TextStyle(fontSize: 11.0)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                ),
                const SizedBox(width: 4.0),
                TextButton.icon(
                  onPressed: () => _loadTemplate(_templateMastering),
                  icon: const Icon(Icons.tune, size: 14.0),
                  label: const Text('Mastering Chain', style: TextStyle(fontSize: 11.0)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  tooltip: 'Limpiar salida',
                  icon: const Icon(Icons.clear_all, size: 16.0),
                  onPressed: _clearOutput,
                  visualDensity: VisualDensity.compact,
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 4.0),
                  IconButton(
                    tooltip: 'Cerrar panel',
                    icon: const Icon(Icons.close, size: 16.0),
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),

          // 2. Cuerpo del Editor Multilínea
          Expanded(
            flex: 3,
            child: Container(
              color: editorBg,
              padding: const EdgeInsets.all(8.0),
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: TextField(
                  controller: _codeController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: textColor,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '// Escribe tu script Tunner DSL aqui...',
                  ),
                ),
              ),
            ),
          ),

          // 3. Barra de Acciones de Ejecución
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1.0),
                bottom: BorderSide(color: borderColor, width: 1.0),
              ),
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFECECEE),
            ),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isEvaluating ? null : _evaluateScript,
                  icon: _isEvaluating
                      ? const SizedBox(
                          width: 12.0,
                          height: 12.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Icon(Icons.play_arrow, size: 14.0),
                  label: const Text('Ejecutar (Ctrl+Enter)', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    'Sintaxis: tempo, channel, connect, set, note, chord, rest, loop',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Panel Inferior de Salida y Telemetría
          Expanded(
            flex: 2,
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFFAFAFA),
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _outputScrollController,
                itemCount: _outputLog.length,
                itemBuilder: (context, index) {
                  final entry = _outputLog[index];
                  final isError = entry.contains('Error de sintaxis') || entry.contains('Fallo de evaluacion');
                  return SelectableText(
                    entry,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.0,
                      color: isError
                          ? const Color(0xFFF87171)
                          : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D)),
                      height: 1.35,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
