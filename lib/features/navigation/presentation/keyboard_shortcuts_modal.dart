import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';

/// Modal informativo con el mapa de atajos de teclado y convenciones de memoria muscular (DAWs y Suites Creativas).
class KeyboardShortcutsCheatSheetModal extends StatelessWidget {
  final TunnerThemePalette palette;

  const KeyboardShortcutsCheatSheetModal({
    super.key,
    required this.palette,
  });

  static Future<void> show({
    required BuildContext context,
    required TunnerThemePalette palette,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => KeyboardShortcutsCheatSheetModal(palette: palette),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 700),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.primaryAccent.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.keyboard, color: palette.primaryAccent, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Matriz de Atajos de Grado Profesional',
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textMutedColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Basado en las convenciones universales de memoria muscular de la industria (Ableton, Logic, Pro Tools y Photoshop).',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),
                const SizedBox(height: 16),

                // Lista de Atajos por Categorías
                Expanded(
                  child: ListView(
                    children: [
                      _buildSection('Transporte y Navegación de Línea de Tiempo (DAW)', [
                        _buildRow('Espacio (Space)', 'Play / Stop universal de transporte'),
                        _buildRow('Enter / Return', 'Rebobinar al inicio (Compás 1) - Estándar Pro Tools/Logic'),
                        _buildRow('C', 'Alternar modo Bucle / Ciclo continuo - Estándar Logic/Ableton'),
                        _buildRow(', (Coma) / . (Punto)', 'Nudge de Compás: Retroceder / Avanzar 1 compás'),
                        _buildRow('R', 'Grabar Toma de Práctica / Detener Grabación'),
                        _buildRow('B / T', 'Tap Tempo interactivo con el pulso musical'),
                        _buildRow('] / [', 'Incrementar / Disminuir tempo en ±1 BPM'),
                        _buildRow('Shift + ] / [', 'Aumentar / Reducir tempo en ±5 BPM'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Herramientas Primarias (Single-Key Tool Focus)', [
                        _buildRow('A / T', 'Afinador Estroboscópico de Ultra Precisión (±0.1 cents)'),
                        _buildRow('M', 'Alternar Metrónomo Determinista en Isolate'),
                        _buildRow('S', 'Pentagrama Interactivo SMuFL & Transcripción en Vivo'),
                        _buildRow('L', 'Tutor de Lecciones & Rushing/Dragging'),
                        _buildRow('Shift + E', 'Entrenador Auditivo a Ciegas (Intervalos de Oído)'),
                        _buildRow('Shift + C', 'Visualizador Polifónico de Acordes & Armónicos H1-H8'),
                        _buildRow('0', 'Silencio Total / Panic Mute (detener todo el sonido)'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Afinación, Tono y Búsqueda Global', [
                        _buildRow('Alt + ↑ / ↓', 'Calibrar tono de concierto A4 (±1 Hz)'),
                        _buildRow('Cmd / Ctrl + I', 'Abrir Selector Universal de Instrumentos (60+)'),
                        _buildRow('Cmd / Ctrl + K (o F)', 'Command Palette Spotlight (Buscador Global)'),
                        _buildRow('J (o Cmd / Ctrl + J)', 'Salto Rápido a Tareas Pedagógicas (TTC)'),
                        _buildRow('?', 'Abrir este mapa completo de atajos'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Navegación Inmediata de Pestañas', [
                        _buildRow('1', 'Pestaña 1: Inicio y Dashboard General'),
                        _buildRow('2', 'Pestaña 2: Afinador y Metrónomo'),
                        _buildRow('3', 'Pestaña 3: Tutor de Aprendizaje'),
                        _buildRow('4', 'Pestaña 4: Rack de Estudio Modular'),
                        _buildRow('5', 'Pestaña 5: Canciones y Partituras'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: palette.primaryAccent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _buildRow(String keyCombination, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: palette.scaffoldBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: palette.staffLinesColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              keyCombination,
              style: TextStyle(
                color: palette.textColor,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: palette.textMutedColor,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
