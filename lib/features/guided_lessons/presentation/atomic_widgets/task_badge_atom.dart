import 'package:flutter/material.dart';
import '../../../../core/theme/tunner_theme.dart';
import '../../domain/pedagogical_task_contract.dart';
import '../../domain/task_taxonomy_code.dart';

/// Átomo visual que renderiza el Código Canónico de Taxonomía de Tareas (TTC).
class TaskCodeBadge extends StatelessWidget {
  final TaskTaxonomyCode code;
  final TunnerThemePalette palette;
  final bool compact;

  const TaskCodeBadge({
    super.key,
    required this.code,
    required this.palette,
    this.compact = false,
  });

  Color _getDomainColor(TaskDomain domain) {
    switch (domain) {
      case TaskDomain.ear:
        return const Color(0xFFA855F7); // Púrpura audición
      case TaskDomain.rhythm:
        return const Color(0xFFF59E0B); // Ámbar ritmo
      case TaskDomain.pitch:
        return const Color(0xFF38BDF8); // Azul celeste afinación
      case TaskDomain.sightReading:
        return const Color(0xFF10B981); // Esmeralda lectura
      case TaskDomain.harmony:
        return const Color(0xFFEC4899); // Rosa armonía
      case TaskDomain.technique:
        return const Color(0xFF6366F1); // Índigo técnica
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getDomainColor(code.domain);

    return Container(
      key: Key('task_code_badge_${code.formatted}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Text(
        compact ? code.shortCode : code.formatted,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9.5 : 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Átomo visual para el Nivel de Dificultad (01 a 05).
class TaskLevelPill extends StatelessWidget {
  final TaskLevel level;
  final TunnerThemePalette palette;

  const TaskLevelPill({
    super.key,
    required this.level,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('task_level_pill_${level.code}'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.staffLinesColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(5, (i) {
              final isFilled = i < level.numericValue;
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? palette.primaryAccent : Colors.white24,
                ),
              );
            }),
          ),
          const SizedBox(width: 4),
          Text(
            'NV ${level.code}',
            style: TextStyle(
              color: palette.textColor.withValues(alpha: 0.75),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Átomo visual para la Estampa de Calificación ([S], [A], [B], [C], [Pendiente]).
class TaskGradeStamp extends StatelessWidget {
  final TaskGrade grade;
  final TaskCompletionStatus status;
  final TunnerThemePalette palette;

  const TaskGradeStamp({
    super.key,
    required this.grade,
    required this.status,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (status == TaskCompletionStatus.notStarted || grade == TaskGrade.none) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'PENDIENTE',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    Color gradeColor;
    switch (grade) {
      case TaskGrade.s:
        gradeColor = const Color(0xFF10B981); // Oro / Esmeralda
        break;
      case TaskGrade.a:
        gradeColor = const Color(0xFF38BDF8); // Azul
        break;
      case TaskGrade.b:
        gradeColor = const Color(0xFFA855F7); // Púrpura
        break;
      case TaskGrade.c:
        gradeColor = const Color(0xFFF59E0B); // Ámbar
        break;
      case TaskGrade.none:
        gradeColor = Colors.white54;
        break;
    }

    return Container(
      key: Key('task_grade_stamp_${grade.letter}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: gradeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gradeColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: gradeColor, size: 12),
          const SizedBox(width: 3),
          Text(
            'GRADO ${grade.letter}',
            style: TextStyle(
              color: gradeColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Átomo visual que destaca tareas conjuntas multi-herramienta (>= 3 herramientas orquestadas).
class MultiToolSynergyBadge extends StatelessWidget {
  final List<String> toolIds;
  final TunnerThemePalette palette;
  final bool compact;

  const MultiToolSynergyBadge({
    super.key,
    required this.toolIds,
    required this.palette,
    this.compact = false,
  });

  static IconData getToolIcon(String toolId) {
    switch (toolId) {
      case 'strobe_tuner':
        return Icons.tune;
      case 'metronome':
        return Icons.access_time;
      case 'score_notation':
        return Icons.menu_book;
      case 'practice_recorder':
        return Icons.fiber_manual_record;
      case 'vocal_autotune':
        return Icons.auto_fix_high;
      case 'harmonic_drone':
        return Icons.graphic_eq;
      case 'spectrogram':
        return Icons.equalizer;
      case 'chord_analyzer':
      case 'master_keyboard':
        return Icons.piano;
      case 'guided_lessons':
        return Icons.school;
      case 'ear_trainer':
        return Icons.hearing;
      case 'modular_rack':
        return Icons.view_comfortable;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (toolIds.length < 3) return const SizedBox.shrink();

    final accentColor = palette.secondaryAccent;

    return Container(
      key: Key('multi_tool_synergy_badge_${toolIds.length}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub, color: accentColor, size: compact ? 11 : 13),
          const SizedBox(width: 4),
          Text(
            compact ? '${toolIds.length}X SINERGIA' : 'HIPER-SINERGIA (${toolIds.length} TOOLS)',
            style: TextStyle(
              color: accentColor,
              fontSize: compact ? 9.0 : 10.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            ...toolIds.map((id) => Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(
                    getToolIcon(id),
                    size: 11,
                    color: accentColor.withValues(alpha: 0.8),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
