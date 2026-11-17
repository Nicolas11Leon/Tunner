import 'package:flutter/material.dart';

import '../../../core/design_system/studio_design_tokens.dart';

/// CustomPainter rendering the quantized beatgrid lines, time ruler ticks,
/// and playhead indicator behind the multi-track timeline lanes using
/// [StudioDesignTokens].
class TimelineArrangementPainter extends CustomPainter {
  final double masterBpm;
  final double pixelsPerSecond;
  final int playheadMs;
  final bool snapToBeatgrid;
  final StudioDesignTokens tokens;

  const TimelineArrangementPainter({
    required this.masterBpm,
    required this.pixelsPerSecond,
    required this.playheadMs,
    required this.snapToBeatgrid,
    this.tokens = StudioDesignTokens.studioDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = tokens.inputSurface;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Beatgrid lines
    final beatSeconds = 60.0 / masterBpm.clamp(40.0, 240.0);
    final beatPixels = beatSeconds * pixelsPerSecond;
    final minorGridPaint = Paint()
      ..color = snapToBeatgrid ? tokens.borderSubtle : tokens.borderSubtle.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    final barGridPaint = Paint()
      ..color = tokens.borderHairline
      ..strokeWidth = 1.2;

    if (beatPixels >= 4.0) {
      int beatIndex = 0;
      for (double x = 0.0; x < size.width; x += beatPixels) {
        final isBar = beatIndex % 4 == 0;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          isBar ? barGridPaint : minorGridPaint,
        );
        beatIndex++;
      }
    }

    // Playhead cursor
    final playheadX = (playheadMs / 1000.0) * pixelsPerSecond;
    if (playheadX >= 0 && playheadX <= size.width) {
      final playheadPaint = Paint()
        ..color = tokens.accentPrimary
        ..strokeWidth = 1.8;
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        playheadPaint,
      );
      final headPath = Path()
        ..moveTo(playheadX - 5, 0)
        ..lineTo(playheadX + 5, 0)
        ..lineTo(playheadX, 7)
        ..close();
      canvas.drawPath(headPath, Paint()..color = tokens.accentPrimary);
    }
  }

  @override
  bool shouldRepaint(covariant TimelineArrangementPainter oldDelegate) {
    return oldDelegate.masterBpm != masterBpm ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.playheadMs != playheadMs ||
        oldDelegate.snapToBeatgrid != snapToBeatgrid ||
        oldDelegate.tokens.id != tokens.id;
  }
}
