import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';

/// Barra flotante ergonómica de control rápido de sesión y transporte.
/// Diseñada para estar permanentemente accesible sobre la barra de navegación
/// reduciendo los toques y aumentando la velocidad de respuesta del músico.
class QuickActionDockWidget extends StatefulWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;
  final VoidCallback onOpenCommandPalette;
  final VoidCallback onOpenShortcutsGuide;
  final VoidCallback onOpenTunerTab;

  const QuickActionDockWidget({
    super.key,
    required this.viewModel,
    required this.palette,
    required this.onOpenCommandPalette,
    required this.onOpenShortcutsGuide,
    required this.onOpenTunerTab,
  });

  @override
  State<QuickActionDockWidget> createState() => _QuickActionDockWidgetState();
}

class _QuickActionDockWidgetState extends State<QuickActionDockWidget> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final palette = widget.palette;

    final isMetroActive = vm.isMetronomeActive;
    final isRecording = vm.isRecording;
    final detectedNote = vm.noteName.isNotEmpty ? vm.noteName : null;

    if (_isCollapsed) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: FloatingActionButton.small(
            key: const Key('quick_dock_expand_btn'),
            backgroundColor: palette.cardBackground,
            foregroundColor: palette.primaryAccent,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: palette.primaryAccent.withValues(alpha: 0.3),
              ),
            ),
            onPressed: () => setState(() => _isCollapsed = false),
            child: const Icon(Icons.flash_on, size: 20),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.cardBackground.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: palette.primaryAccent.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Play / Pause Transporte Maestro
            _buildDockButton(
              key: const Key('quick_dock_play_btn'),
              icon: isMetroActive ? Icons.pause_circle_filled : Icons.play_circle_filled,
              label: isMetroActive ? 'Pausar' : 'Play',
              color: isMetroActive ? const Color(0xFFF59E0B) : palette.primaryAccent,
              isActive: isMetroActive,
              onTap: () => vm.toggleMetronome(),
            ),

            const SizedBox(width: 6),

            // 2. Grabar Toma Rápida (Quick Rec)
            _buildDockButton(
              key: const Key('quick_dock_rec_btn'),
              icon: Icons.fiber_manual_record,
              label: isRecording ? 'Grabando' : 'Grabar',
              color: isRecording ? const Color(0xFFEF4444) : palette.textMutedColor,
              isActive: isRecording,
              isPulsing: isRecording,
              onTap: () {
                if (isRecording) {
                  vm.stopPracticeRecording();
                } else {
                  vm.startPracticeRecording();
                }
              },
            ),

            const SizedBox(width: 6),

            // 3. Tap Tempo
            _buildDockButton(
              key: const Key('quick_dock_tap_btn'),
              icon: Icons.touch_app,
              label: '${vm.bpm.round()} BPM',
              color: const Color(0xFF10B981),
              onTap: () => vm.recordTapTempo(),
            ),

            const SizedBox(width: 6),

            // 4. Salto directo al Afinador
            InkWell(
              key: const Key('quick_dock_tuner_shortcut_btn'),
              onTap: widget.onOpenTunerTab,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.staffLinesColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: palette.primaryAccent, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      detectedNote ?? 'Afinador',
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 5. Botón Command Palette (Spotlight)
            IconButton(
              key: const Key('quick_dock_command_palette_btn'),
              tooltip: 'Buscador de Comandos (Cmd+K)',
              icon: Icon(Icons.search, color: palette.primaryAccent, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: widget.onOpenCommandPalette,
            ),

            // 6. Botón Guía de Atajos
            IconButton(
              key: const Key('quick_dock_shortcuts_btn'),
              tooltip: 'Atajos de Teclado (?)',
              icon: Icon(Icons.keyboard, color: palette.textMutedColor, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: widget.onOpenShortcutsGuide,
            ),

            // 7. Colapsar
            IconButton(
              key: const Key('quick_dock_collapse_btn'),
              tooltip: 'Minimizar barra',
              icon: Icon(Icons.close, color: palette.textMutedColor.withValues(alpha: 0.6), size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _isCollapsed = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
    bool isPulsing = false,
  }) {
    final palette = widget.palette;

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.18) : palette.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : palette.staffLinesColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : palette.textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
