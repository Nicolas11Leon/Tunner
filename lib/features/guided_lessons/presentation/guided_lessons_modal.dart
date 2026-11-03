import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import '../domain/guided_lesson_entity.dart';

/// Modal interactivo de Lecciones Guiadas con Validación Acústica Paso a Paso.
/// Permite al instrumentista elegir rutinas estructuradas, observar la nota objetivo
/// con micro-afinación en cents, acumular tiempo de sostenimiento y recibir consejos biomecánicos.
class GuidedLessonsModal extends StatelessWidget {
  const GuidedLessonsModal({super.key});

  /// Muestra el modal en un bottom sheet responsivo.
  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const GuidedLessonsModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;
    final hasActive = viewModel.hasActiveGuidedLesson;
    final progress = viewModel.activeLessonProgress;

    return Container(
      key: const Key('guided_lessons_modal'),
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Barra de agarre superior
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: palette.staffLinesColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Barra de encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    color: palette.primaryAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActive && progress != null
                            ? progress.lesson.title
                            : 'Lecciones Guiadas de Afinación',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hasActive && progress != null
                            ? 'Paso ${progress.currentStepIndex + 1} de ${progress.lesson.totalSteps}: ${progress.currentStep.targetNoteName}'
                            : 'Práctica estructurada con validación acústica continua',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.secondaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.secondaryAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        viewModel.activeInstrument.clef.symbol,
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        viewModel.activeInstrument.name,
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('close_guided_lessons_btn'),
                  icon: Icon(Icons.close, color: palette.textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: palette.staffLinesColor.withValues(alpha: 0.2), height: 1),

          // Cuerpo dinámico: Vista Activa vs. Catálogo de Lecciones
          Expanded(
            child: hasActive && progress != null
                ? _ActiveLessonPracticeView(
                    viewModel: viewModel,
                    progress: progress,
                    palette: palette,
                  )
                : _LessonCatalogListView(
                    viewModel: viewModel,
                    palette: palette,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Vista interactiva para practicar la lección activa paso a paso.
class _ActiveLessonPracticeView extends StatelessWidget {
  final TunerViewModel viewModel;
  final GuidedLessonProgressEntity progress;
  final TunnerThemePalette palette;

  const _ActiveLessonPracticeView({
    required this.viewModel,
    required this.progress,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final step = progress.currentStep;
    final isListening = viewModel.isRecording;
    final detectedPitch = viewModel.frequency;
    final detectedCents = viewModel.cents;
    final targetHz = step.targetFrequencyHz;
    final tol = step.toleranceCents;

    final bool noteMatches = detectedPitch > 20.0 &&
        (viewModel.noteName.toUpperCase().contains(step.targetNoteName.toUpperCase().substring(0, 1)) ||
            (detectedPitch / targetHz >= 0.95 && detectedPitch / targetHz <= 1.05));
    final bool inTune = noteMatches && detectedCents.abs() <= tol;

    final progressRatio = progress.stepProgressRatio.clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector horizontal de pasos (Stepper)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(progress.lesson.totalSteps, (index) {
              final isCurrent = index == progress.currentStepIndex;
              final isDone = index < progress.currentStepIndex ||
                  (index == progress.currentStepIndex && progress.isStepComplete);

              Color dotColor;
              if (isDone) {
                dotColor = palette.correctPitchColor;
              } else if (isCurrent) {
                dotColor = palette.primaryAccent;
              } else {
                dotColor = palette.staffLinesColor.withValues(alpha: 0.3);
              }

              return InkWell(
                key: Key('lesson_step_dot_$index'),
                onTap: () => viewModel.jumpToLessonStep(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dotColor,
                      width: isCurrent ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    'Paso ${index + 1}',
                    style: TextStyle(
                      color: dotColor,
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Tarjeta Hero: Nota Objetivo y Estado de Afinación
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: inTune
                    ? palette.correctPitchColor
                    : palette.staffLinesColor.withValues(alpha: 0.25),
                width: inTune ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.primaryAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        step.writtenNoteName != null
                            ? 'Escrito: ${step.writtenNoteName} (Suena: ${step.targetNoteName})'
                            : 'Objetivo: ${step.targetNoteName}',
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${targetHz.toStringAsFixed(1)} Hz (±${tol.toStringAsFixed(1)} cents)',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nota Gigante
                Text(
                  step.writtenNoteName ?? step.targetNoteName,
                  style: TextStyle(
                    color: inTune ? palette.correctPitchColor : palette.textColor,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
                if (step.writtenNoteName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tono Real de Concierto: ${step.targetNoteName}',
                    style: TextStyle(
                      color: palette.secondaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),

                // Desviación en tiempo real
                if (detectedPitch > 20.0) ...[
                  Text(
                    'Detectado: ${viewModel.noteName} (${detectedPitch.toStringAsFixed(1)} Hz) • ${detectedCents >= 0 ? "+" : ""}${detectedCents.toStringAsFixed(1)} cents',
                    style: TextStyle(
                      color: inTune
                          ? palette.correctPitchColor
                          : (detectedCents.abs() <= tol * 1.5
                              ? palette.secondaryAccent
                              : palette.errorPitchColor),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Text(
                    isListening
                        ? 'Esperando emisión sonora...'
                        : 'Micrófono inactivo. Inicia afinación para comenzar.',
                    style: TextStyle(
                      color: palette.textMutedColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Barra de Progreso del Tiempo Sostenido
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    key: const Key('lesson_progress_bar'),
                    value: progressRatio,
                    minHeight: 12,
                    backgroundColor: palette.staffLinesColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress.isStepComplete
                          ? palette.correctPitchColor
                          : palette.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sostenido: ${progress.sustainedSeconds.toStringAsFixed(1)}s / ${step.targetDurationSeconds.toStringAsFixed(1)}s',
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progressRatio * 100).toInt()}%',
                      style: TextStyle(
                        color: progress.isStepComplete
                            ? palette.correctPitchColor
                            : palette.primaryAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tarjeta de Consejo Biomecánico & Pedagógico
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: palette.secondaryAccent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consejo Pedagógico',
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.feedbackTip,
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botonera de Control: Tono Guía & Acciones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('lesson_reference_tone_btn'),
                  onPressed: () {
                    viewModel.playReferenceTone(step.targetNoteName);
                  },
                  icon: Icon(Icons.volume_up, size: 16, color: palette.primaryAccent),
                  label: const Text('Escuchar Tono Guía'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.primaryAccent,
                    side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('switch_or_cancel_lesson_btn'),
                onPressed: () => viewModel.cancelGuidedLesson(),
                icon: Icon(Icons.list, size: 16, color: palette.textColor),
                label: const Text('Cambiar Lección'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textColor,
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          // Estado de Lección Completa
          if (progress.isLessonComplete) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.correctPitchColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.correctPitchColor),
              ),
              child: Column(
                children: [
                  Text(
                    'Lección Completada con Éxito',
                    style: TextStyle(
                      color: palette.correctPitchColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Has sostenido todas las notas con la tolerancia requerida. ¡Excelente control biomecánico!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const Key('lesson_restart_btn'),
                    onPressed: () => viewModel.startGuidedLesson(progress.lesson),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.correctPitchColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Repetir Lección',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lista de catálogo de lecciones curadas disponibles.
class _LessonCatalogListView extends StatelessWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;

  const _LessonCatalogListView({
    required this.viewModel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final lessons = viewModel.availableGuidedLessons;
    final activeInstrument = viewModel.activeInstrument;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: lessons.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.secondaryAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.secondaryAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 20, color: palette.secondaryAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lecciones adaptadas automáticamente a ${activeInstrument.name} (Tesitura: ${activeInstrument.family.displayName}, ${activeInstrument.key.displayName}).',
                    style: TextStyle(
                      color: palette.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final lesson = lessons[index - 1];
        final difficultyLabel = _difficultyLabel(lesson.difficulty);
        final difficultyColor = _difficultyColor(lesson.difficulty, palette);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: palette.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: difficultyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        difficultyLabel,
                        style: TextStyle(
                          color: difficultyColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${lesson.totalSteps} pasos',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lesson.title,
                  style: TextStyle(
                    color: palette.textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.description,
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Resumen de notas en chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: lesson.steps.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.staffLinesColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${s.targetNoteName} (${s.targetDurationSeconds.toStringAsFixed(0)}s)',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Botón Iniciar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: Key('start_lesson_${lesson.id}'),
                    onPressed: () {
                      viewModel.startGuidedLesson(lesson);
                    },
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Comenzar Lección'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _difficultyLabel(String diff) {
    return diff;
  }

  Color _difficultyColor(String diff, TunnerThemePalette palette) {
    switch (diff.toLowerCase()) {
      case 'principiante':
        return palette.correctPitchColor;
      case 'intermedio':
        return palette.secondaryAccent;
      case 'avanzado':
      default:
        return palette.primaryAccent;
    }
  }
}
