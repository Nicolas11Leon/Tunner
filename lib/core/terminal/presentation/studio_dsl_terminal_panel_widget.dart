import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design_system/studio_design_system.dart';
import '../../dsl/domain/tunner_dsl_template_catalog.dart';
import '../application/tunner_os_kernel.dart';

/// Consola REPL y editor interactivo para Tunner DSL en Tunner Studio.
/// Permite redactar, cargar plantillas del catálogo canónico [TunnerDslTemplateCatalog]
/// y evaluar scripts declarativos en caliente.
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
  String _activeTemplateId = 'quick_jam';

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
    if (!mounted) return;

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

  void _loadTemplate(String templateId, String templateCode) {
    setState(() {
      _activeTemplateId = templateId;
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
    final tokens = StudioThemeScope.of(context);
    final catalogTemplates = TunnerDslTemplateCatalog.allTemplates;

    return Container(
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
        borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Barra de Herramientas Superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
              ),
              color: tokens.panelHeaderBackground,
            ),
            child: Row(
              children: [
                StudioIcon(
                  StudioIconId.toolTerminal,
                  size: 16.0,
                  color: tokens.accentPrimary,
                  tintCustomAsset: true,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'TUNNER DSL STUDIO REPL',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(width: 8.0),
                // Presets rápidos y catálogo canónico TunnerDslTemplateCatalog
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        TextButton.icon(
                          onPressed: () => _loadTemplate('quick_jam', _templateQuickJam),
                          icon: StudioIcon(
                            StudioIconId.fileMusicXmlMidi,
                            size: 13.0,
                            color: _activeTemplateId == 'quick_jam'
                                ? tokens.accentPrimary
                                : tokens.textSecondary,
                            tintCustomAsset: true,
                          ),
                          label: Text(
                            'Quick Jam',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: _activeTemplateId == 'quick_jam'
                                  ? tokens.textPrimary
                                  : tokens.textSecondary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        TextButton.icon(
                          onPressed: () => _loadTemplate('mastering', _templateMastering),
                          icon: StudioIcon(
                            StudioIconId.moduleTuner,
                            size: 13.0,
                            color: _activeTemplateId == 'mastering'
                                ? tokens.accentPrimary
                                : tokens.textSecondary,
                            tintCustomAsset: true,
                          ),
                          label: Text(
                            'Mastering Chain',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: _activeTemplateId == 'mastering'
                                  ? tokens.textPrimary
                                  : tokens.textSecondary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
                const SizedBox(width: 6.0),
                PopupMenuButton<TunnerDslTemplate>(
                  key: const Key('dsl_catalog_templates_menu'),
                  tooltip: 'Plantillas canónicas Tunner DSL',
                  color: tokens.panelBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    side: BorderSide(color: tokens.borderHairline),
                  ),
                  onSelected: (template) =>
                      _loadTemplate(template.id, template.sourceCode),
                  itemBuilder: (ctx) => catalogTemplates
                      .map(
                        (template) => PopupMenuItem<TunnerDslTemplate>(
                          key: Key('dsl_template_${template.id}'),
                          value: template,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                template.title,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${template.category} · ${template.defaultBpm.round()} BPM',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10.0,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StudioIcon(
                          StudioIconId.filePreset,
                          size: 12.0,
                          color: tokens.accentPrimary,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          'Catálogo (${catalogTemplates.length})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                IconButton(
                  tooltip: 'Limpiar salida',
                  icon: Icon(Icons.clear_all, size: 16.0, color: tokens.textSecondary),
                  onPressed: _clearOutput,
                  visualDensity: VisualDensity.compact,
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 4.0),
                  IconButton(
                    tooltip: 'Cerrar panel',
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      size: 15.0,
                      color: tokens.textSecondary,
                      tintCustomAsset: true,
                    ),
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
              color: tokens.inputSurface,
              padding: const EdgeInsets.all(8.0),
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: TextField(
                  controller: _codeController,
                  maxLines: null,
                  expands: true,
                  cursorColor: tokens.accentPrimary,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: tokens.textPrimary,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '// Escribe tu script Tunner DSL aqui...',
                    hintStyle: TextStyle(color: tokens.textMuted),
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
                top: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
                bottom: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
              ),
              color: tokens.panelHeaderBackground,
            ),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isEvaluating ? null : _evaluateScript,
                  icon: _isEvaluating
                      ? SizedBox(
                          width: 12.0,
                          height: 12.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: tokens.textOnAccent,
                          ),
                        )
                      : StudioIcon(
                          StudioIconId.transportPlay,
                          size: 13.0,
                          color: tokens.textOnAccent,
                          tintCustomAsset: true,
                        ),
                  label: Text(
                    'Ejecutar (Ctrl+Enter)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textOnAccent,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: tokens.accentPrimary,
                    foregroundColor: tokens.textOnAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    'Sintaxis: tempo, channel, connect, set, note, chord, rest, loop',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: tokens.textMuted,
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
              color: tokens.canvasBackground,
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _outputScrollController,
                itemCount: _outputLog.length,
                itemBuilder: (context, index) {
                  final entry = _outputLog[index];
                  final isError = entry.contains('Error de sintaxis') ||
                      entry.contains('Fallo de evaluacion');
                  return SelectableText(
                    entry,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.0,
                      color: isError ? tokens.accentDanger : tokens.accentSuccess,
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
