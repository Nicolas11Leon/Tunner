import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';

/// Modal de estudio para auto-escucha crítica (*Practice Recording Player Modal*).
/// Ofrece visualización interactiva de la forma de onda acústica, selector de velocidad y scrubber táctil.
class PracticeRecordingPlayerModal extends StatelessWidget {
  const PracticeRecordingPlayerModal({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final recording = vm.activeRecording;

    if (recording == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Center(
          child: Text(
            "No hay ninguna toma grabada disponible.",
            style: TextStyle(color: palette.textMutedColor),
          ),
        ),
      );
    }

    final totalMs = recording.duration.inMilliseconds > 0
        ? recording.duration.inMilliseconds
        : 1;
    final progress = (vm.playbackPosition.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Píldora de arrastre superior
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: palette.staffLinesColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.headphones_rounded, color: palette.primaryAccent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Auto-Escucha de Práctica",
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${recording.songTitle} • ${recording.formattedDateTime}",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (vm.isPlayingAudio) {
                    vm.pauseActiveRecording();
                  }
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.close_rounded, color: palette.textMutedColor),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Visualizador y Scrubber Interactivo de Forma de Onda (CustomPainter)
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  final tapRatio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                  final targetMs = (tapRatio * totalMs).round();
                  vm.seekPlayback(Duration(milliseconds: targetMs));
                },
                onHorizontalDragUpdate: (details) {
                  final dragRatio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                  final targetMs = (dragRatio * totalMs).round();
                  vm.seekPlayback(Duration(milliseconds: targetMs));
                },
                child: Container(
                  height: 72,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: palette.scaffoldBackground.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  ),
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      peaks: recording.waveformPeaks,
                      progress: progress,
                      activeColor: palette.primaryAccent,
                      inactiveColor: palette.staffLinesColor.withValues(alpha: 0.4),
                      playheadColor: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Etiquetas de Tiempo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(vm.playbackPosition),
                style: TextStyle(
                  color: palette.primaryAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                recording.formattedDuration,
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selector de Velocidades de Reproducción
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Velocidad: ",
                style: TextStyle(color: palette.textMutedColor, fontSize: 12),
              ),
              const SizedBox(width: 8),
              _SpeedPill(
                label: "0.75x",
                isSelected: vm.playbackSpeed == 0.75,
                palette: palette,
                onTap: () => vm.setPlaybackSpeed(0.75),
              ),
              const SizedBox(width: 6),
              _SpeedPill(
                label: "1.0x",
                isSelected: vm.playbackSpeed == 1.0,
                palette: palette,
                onTap: () => vm.setPlaybackSpeed(1.0),
              ),
              const SizedBox(width: 6),
              _SpeedPill(
                label: "1.25x",
                isSelected: vm.playbackSpeed == 1.25,
                palette: palette,
                onTap: () => vm.setPlaybackSpeed(1.25),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Controles de Transporte (Play / Pause / Replay) y Acciones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón Descartar Toma
              IconButton(
                key: const Key('discard_take_button'),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                tooltip: "Descartar toma",
                onPressed: () {
                  vm.discardActiveRecording();
                  Navigator.of(context).pop();
                },
              ),

              // Controles Centrales
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón Rebobinar al inicio
                  IconButton(
                    icon: Icon(Icons.replay_rounded, color: palette.textColor),
                    tooltip: "Reiniciar audio",
                    onPressed: () => vm.seekPlayback(Duration.zero),
                  ),
                  const SizedBox(width: 8),

                  // Botón Principal Play / Pause
                  GestureDetector(
                    key: const Key('play_pause_take_button'),
                    onTap: () {
                      if (vm.isPlayingAudio) {
                        vm.pauseActiveRecording();
                      } else {
                        vm.playActiveRecording();
                      }
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.primaryAccent,
                        boxShadow: [
                          BoxShadow(
                            color: palette.primaryAccent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          vm.isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: palette.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Botón Listo / Guardar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.cardBackground,
                  foregroundColor: palette.textColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.4)),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Conservar"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final TunnerThemePalette palette;
  final VoidCallback onTap;

  const _SpeedPill({
    required this.label,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primaryAccent
              : palette.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? palette.primaryAccent : palette.staffLinesColor.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (palette.brightness == Brightness.dark ? Colors.black : Colors.white)
                : palette.textMutedColor,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final Color playheadColor;

  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.playheadColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final playheadPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.0;

    final center = size.height / 2;

    // Si no hay suficientes picos grabados, generar barras sintéticas armónicas
    final displayPeaks = peaks.isNotEmpty ? peaks : List.generate(40, (i) => 0.2 + (i % 5) * 0.15);
    final count = displayPeaks.length;
    final step = size.width / (count > 0 ? count : 1);

    for (int i = 0; i < count; i++) {
      final x = i * step + step / 2;
      final peak = displayPeaks[i].clamp(0.08, 1.0);
      final barHeight = (peak * (size.height - 12)) / 2;

      final isPlayed = (x / size.width) <= progress;
      final paint = isPlayed ? activePaint : inactivePaint;

      canvas.drawLine(
        Offset(x, center - barHeight),
        Offset(x, center + barHeight),
        paint,
      );
    }

    // Dibujar aguja de reproducción (Playhead)
    final playheadX = progress * size.width;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    // Cabezal de aguja circular
    canvas.drawCircle(
      Offset(playheadX, 4),
      3.5,
      Paint()..color = playheadColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.peaks != peaks ||
        oldDelegate.activeColor != activeColor;
  }
}
