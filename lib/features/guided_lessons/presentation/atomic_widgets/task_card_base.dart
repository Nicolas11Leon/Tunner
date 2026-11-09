import 'package:flutter/material.dart';
import '../../../../core/theme/tunner_theme.dart';
import '../../domain/pedagogical_task_contract.dart';
import 'task_badge_atom.dart';

/// Widget base abstracto y heredable para la representación de tareas pedagógicas.
///
/// Implementa el patrón Template Method y Atomic Design: encapsula la gestión de
/// bordes, estados de selección, cabecera taxonómica y estampas de calificación,
/// permitiendo a las subclases especializar el cuerpo o las acciones interactivas.
abstract class TaskCardBase<T extends PedagogicalTaskEntity> extends StatelessWidget {
  final T task;
  final TunnerThemePalette palette;
  final bool isSelected;
  final VoidCallback? onTap;

  const TaskCardBase({
    super.key,
    required this.task,
    required this.palette,
    this.isSelected = false,
    this.onTap,
  });

  /// Gancho de personalización para el cuerpo central de la tarjeta.
  Widget buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: TextStyle(
            color: palette.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          task.description,
          style: TextStyle(
            color: palette.textColor.withValues(alpha: 0.65),
            fontSize: 11,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Gancho de personalización para la barra inferior de acciones o métricas.
  Widget buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 12, color: palette.textColor.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              '${task.estimatedDurationMinutes} min',
              style: TextStyle(
                color: palette.textColor.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        TaskGradeStamp(
          grade: task.bestGrade,
          status: task.status,
          palette: palette,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('task_card_${task.code.formatted}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primaryAccent.withValues(alpha: 0.12)
              : palette.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? palette.primaryAccent
                : palette.staffLinesColor.withValues(alpha: 0.25),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.primaryAccent.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera taxonómica
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TaskCodeBadge(code: task.code, palette: palette),
                TaskLevelPill(level: task.code.level, palette: palette),
              ],
            ),
            const SizedBox(height: 8),
            // Cuerpo
            buildBody(context),
            const SizedBox(height: 10),
            // Pie
            buildFooter(context),
          ],
        ),
      ),
    );
  }
}

/// Implementación estándar concreta de la tarjeta de tarea.
class StandardTaskCard extends TaskCardBase<StandardPedagogicalTask> {
  const StandardTaskCard({
    super.key,
    required super.task,
    required super.palette,
    super.isSelected,
    super.onTap,
  });
}
