import 'package:flutter/material.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import '../domain/practice_report_entity.dart';

/// Modal analítico de alta fidelidad que presenta el reporte de desempeño
/// y la tendencia histórica de progreso pedagógico.
class PracticeReportModal extends StatelessWidget {
  final PracticeReportEntity report;
  final TunnerThemePalette palette;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const PracticeReportModal({
    super.key,
    required this.report,
    required this.palette,
    required this.onRetry,
    required this.onClose,
  });

  static Future<void> show({
    required BuildContext context,
    required PracticeReportEntity report,
    required TunnerThemePalette palette,
    required VoidCallback onRetry,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PracticeReportModal(
        report: report,
        palette: palette,
        onRetry: () {
          Navigator.of(ctx).pop();
          onRetry();
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Color _getGradeColor(PerformanceGrade grade) {
    switch (grade) {
      case PerformanceGrade.s:
        return const Color(0xFFFFD700); // Gold
      case PerformanceGrade.a:
        return const Color(0xFF00E676); // Emerald
      case PerformanceGrade.b:
        return const Color(0xFF00E5FF); // Cyan
      case PerformanceGrade.c:
        return const Color(0xFFFFB300); // Amber
      case PerformanceGrade.d:
        return const Color(0xFFFF5252); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor(report.grade);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: gradeColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gradeColor.withValues(alpha: 0.15),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header con Badge de Grado y Título
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [gradeColor, gradeColor.withValues(alpha: 0.4)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gradeColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      report.grade.letter,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              report.grade.title.toUpperCase(),
                              style: TextStyle(
                                color: gradeColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${report.overallScore.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: palette.textColor,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.songTitle,
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          report.grade.description,
                          style: TextStyle(
                            color: palette.textMutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Banner de Análisis de Tendencia (Mejora o Declive)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: report.trendDeltaPercentage >= 0
                      ? palette.correctPitchColor.withValues(alpha: 0.12)
                      : palette.warningPitchColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: report.trendDeltaPercentage >= 0
                        ? palette.correctPitchColor.withValues(alpha: 0.3)
                        : palette.warningPitchColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      report.trendDeltaPercentage >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: report.trendDeltaPercentage >= 0
                          ? palette.correctPitchColor
                          : palette.warningPitchColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ANALÍTICA DE PROGRESO',
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            report.trendAnalysisText,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Telemetría Cuantitativa: 3 Cards (Afinación, Ritmo, Aciertos)
              Row(
                children: [
                  _buildMetricTile(
                    title: 'AFINACIÓN',
                    value: '${report.pitchAccuracyPercentage}%',
                    subtitle: '±${report.averageCentsDeviation} cents med.',
                    color: palette.correctPitchColor,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricTile(
                    title: 'PULSO RÍTMICO',
                    value: '${report.rhythmAccuracyPercentage}%',
                    subtitle: 'precisión temporal',
                    color: palette.primaryAccent,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricTile(
                    title: 'NOTAS ACIDAS',
                    value: '${report.hitNotes}/${report.totalNotes}',
                    subtitle: '${((report.hitNotes / (report.totalNotes > 0 ? report.totalNotes : 1)) * 100).round()}% total',
                    color: gradeColor,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Desglose de Notas: Dominadas vs Críticas (Mapa de Calor Pedagógico)
              if (report.masteredNotes.isNotEmpty || report.criticalNotes.isNotEmpty) ...[
                Text(
                  'DESGLOSE PEDAGÓGICO DE DIGITACIÓN',
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...report.masteredNotes.map(
                      (note) => _buildNoteChip(
                        note: note,
                        accuracy: report.noteAccuracyMap[note] ?? 100.0,
                        isCritical: false,
                      ),
                    ),
                    ...report.criticalNotes.map(
                      (note) => _buildNoteChip(
                        note: note,
                        accuracy: report.noteAccuracyMap[note] ?? 50.0,
                        isCritical: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Botones de Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textColor,
                        side: BorderSide(color: palette.textMutedColor.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onClose,
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        'Repetir Práctica',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: palette.scaffoldBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.textMutedColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: palette.textMutedColor,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteChip({
    required String note,
    required double accuracy,
    required bool isCritical,
  }) {
    final chipColor = isCritical ? palette.warningPitchColor : palette.correctPitchColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCritical ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
            color: chipColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '$note: ${accuracy.round()}%',
            style: TextStyle(
              color: palette.textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
