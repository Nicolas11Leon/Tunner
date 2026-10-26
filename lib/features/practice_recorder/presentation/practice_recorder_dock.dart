import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../tuner_viewmodel.dart';
import 'practice_recording_player_modal.dart';

/// Barra de control y estado de grabación de práctica acústica (*Practice Recorder Dock*).
/// Diseñada con estética de estudio profesional, animación de pulso carmesí y contador digital.
class PracticeRecorderDock extends StatefulWidget {
  const PracticeRecorderDock({super.key});

  @override
  State<PracticeRecorderDock> createState() => _PracticeRecorderDockState();
}

class _PracticeRecorderDockState extends State<PracticeRecorderDock>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final isRecording = vm.isAudioRecording;
    final hasActiveRecording = vm.activeRecording != null;

    if (isRecording) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecording
              ? Colors.redAccent.withValues(alpha: 0.8)
              : palette.staffLinesColor.withValues(alpha: 0.3),
          width: isRecording ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isRecording
                ? Colors.redAccent.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.20),
            blurRadius: isRecording ? 12 : 6,
            spreadRadius: isRecording ? 2 : 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Botón de Disparo de Grabación (Círculo animado)
          GestureDetector(
            key: const Key('practice_record_button'),
            behavior: HitTestBehavior.opaque,
            onTap: () => vm.togglePracticeRecording(),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = isRecording ? _pulseAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecording
                          ? Colors.redAccent
                          : palette.primaryAccent.withValues(alpha: 0.15),
                      border: Border.all(
                        color: isRecording ? Colors.white : palette.primaryAccent,
                        width: 2,
                      ),
                      boxShadow: isRecording
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                        color: isRecording ? Colors.white : Colors.redAccent,
                        size: isRecording ? 20 : 18,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // 2. Estado y Temporizador Digital
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRecording ? "GRABANDO TOMA" : "AUTO-ESCUCHA",
                style: TextStyle(
                  color: isRecording ? Colors.redAccent : palette.textMutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                isRecording
                    ? _formatDuration(vm.recordingDuration)
                    : (hasActiveRecording
                        ? "Toma lista (${vm.activeRecording!.formattedDuration})"
                        : "Micrófono listo"),
                style: TextStyle(
                  color: palette.textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          // 3. Mini visualizador de picos activos durante la grabación
          if (isRecording && vm.currentWaveformPeaks.isNotEmpty) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              height: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: vm.currentWaveformPeaks.reversed
                    .take(8)
                    .toList()
                    .reversed
                    .map((peak) {
                  return Container(
                    width: 3.5,
                    height: (peak * 20.0).clamp(3.0, 20.0),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 4. Botón para abrir el reproductor de auto-escucha si hay toma lista
          if (!isRecording && hasActiveRecording) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              key: const Key('open_practice_player_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryAccent,
                foregroundColor: palette.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const PracticeRecordingPlayerModal(),
                );
              },
              icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
              label: const Text(
                "Escuchar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
