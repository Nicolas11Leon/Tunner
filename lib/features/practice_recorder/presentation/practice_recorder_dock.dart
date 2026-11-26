import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../../tuner/presentation/microphone_calibration_modal.dart';
import '../../vocal_autotune/presentation/vocal_autotune_modal.dart';
import 'practice_recording_player_modal.dart';
import 'spectral_comparator_modal.dart';

/// Barra de control y estado de grabación de práctica acústica (*Practice Recorder Dock*).
/// Diseñada con estética de estudio profesional OLED Monochrome, animación de pulso y contador digital.
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
    final tokens = StudioThemeScope.of(context);
    final isRecording = vm.isAudioRecording;
    final hasActiveRecording = vm.activeRecording != null;
    final hasSavedTake = hasActiveRecording ||
        vm.recordingHistory.isNotEmpty ||
        vm.multiTrackSession.takes.isNotEmpty;

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.panelBackground.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecording
              ? tokens.accentDanger.withValues(alpha: 0.85)
              : tokens.borderHairline,
          width: isRecording ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isRecording
                ? tokens.accentDanger.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: isRecording ? 12 : 6,
            spreadRadius: isRecording ? 2 : 0,
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
                          ? tokens.accentDanger
                          : tokens.elevatedSurface,
                      border: Border.all(
                        color: isRecording ? tokens.textPrimary : tokens.accentPrimary,
                        width: 2,
                      ),
                      boxShadow: isRecording
                          ? [
                              BoxShadow(
                                color: tokens.accentDanger.withValues(alpha: 0.55),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: StudioIcon(
                        isRecording
                            ? StudioIconId.transportStop
                            : StudioIconId.transportRecord,
                        color: isRecording ? Colors.white : tokens.accentDanger,
                        size: isRecording ? 18 : 16,
                        tintCustomAsset: true,
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
                  color: isRecording ? tokens.accentDanger : tokens.textMuted,
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
                  color: tokens.textPrimary,
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
                      color: tokens.accentDanger.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // 4. Botón para abrir el reproductor de auto-escucha y puentes de 1 clic si hay toma lista
          if (!isRecording && hasActiveRecording) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              key: const Key('open_practice_player_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accentPrimary,
                foregroundColor: tokens.textOnAccent,
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
              icon: StudioIcon(
                StudioIconId.transportPlay,
                size: 16,
                color: tokens.textOnAccent,
                tintCustomAsset: true,
              ),
              label: const Text(
                "Escuchar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          if (!isRecording && hasSavedTake) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('btn_recorder_send_to_autotune'),
              style: OutlinedButton.styleFrom(
                backgroundColor: tokens.elevatedSurface,
                foregroundColor: tokens.textPrimary,
                side: BorderSide(color: tokens.borderHairline),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => VocalAutoTuneModal.show(context, vm),
              icon: Icon(
                Icons.auto_fix_high_rounded,
                size: 15,
                color: tokens.accentSecondary,
              ),
              label: const Text(
                'AutoTune',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              key: const Key('btn_recorder_transcribe_to_score'),
              style: OutlinedButton.styleFrom(
                backgroundColor: tokens.elevatedSurface,
                foregroundColor: tokens.textPrimary,
                side: BorderSide(color: tokens.borderHairline),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final result = vm.convertActiveRecordingToScorePackage();
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result != null
                          ? 'Toma convertida a partitura (${result.totalNotes} notas detectadas).'
                          : 'No se detectaron notas melódicas válidas en la toma activa.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                Icons.queue_music_rounded,
                size: 15,
                color: tokens.accentPrimary,
              ),
              label: const Text(
                'A Partitura',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ],

          // 5. Botón para abrir el comparador espectral multi-toma
          if (!isRecording) ...[
            const SizedBox(width: 8),
            IconButton(
              key: const Key('open_spectral_comparator_btn'),
              tooltip: "Comparador Espectral de Tomas",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: StudioIcon(
                StudioIconId.moduleSpectrogram,
                size: 18,
                color: tokens.accentSecondary,
                tintCustomAsset: true,
              ),
              onPressed: () => SpectralComparatorModal.show(context, vm),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('recorder_dock_mic_calibration_btn'),
              tooltip: "Calibración de Micrófono & Rigurosidad (${vm.acousticRigorProfile.preset.displayName})",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: StudioIcon(
                StudioIconId.audioMicOn,
                size: 18,
                color: tokens.accentPrimary,
                tintCustomAsset: true,
              ),
              onPressed: () => MicrophoneCalibrationModal.show(context, vm),
            ),
          ],
          ],
        ),
      ),
    );
  }
}
