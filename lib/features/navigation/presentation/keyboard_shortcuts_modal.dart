import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';

/// Modal informativo con el mapa de atajos de teclado y gestos rápidos.
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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
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
                          'Atajos de Teclado y Gestos Rápidos',
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
                  'Optimizado para práctica musical continua con manos libres, teclados Bluetooth y pedales.',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),
                const SizedBox(height: 16),

                // Lista de Atajos
                Expanded(
                  child: ListView(
                    children: [
                      _buildSection('Transporte y Grabación', [
                        _buildRow('Espacio (Space)', 'Play / Pause maestro (Metrónomo y Playhead)'),
                        _buildRow('R', 'Grabar Toma de Audio / Detener Grabación'),
                        _buildRow('T', 'Tap Tempo inmediato al ritmo de la música'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Herramientas Rápidas', [
                        _buildRow('A', 'Salto directo al Afinador Estroboscópico'),
                        _buildRow('M', 'Silencio general / Mute rápido'),
                        _buildRow('Cmd / Ctrl + K', 'Abrir Command Palette (Buscador Spotlight)'),
                        _buildRow('?', 'Abrir esta guía de atajos de teclado'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Navegación de Pestañas', [
                        _buildRow('1', 'Pestaña Inicio (Dashboard y Búsqueda)'),
                        _buildRow('2', 'Pestaña Afinador y Metrónomo'),
                        _buildRow('3', 'Pestaña Tutor Interactivo y Ejercicios'),
                        _buildRow('4', 'Pestaña Rack Modular de Estudio'),
                        _buildRow('5', 'Pestaña Partituras y Canciones'),
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
