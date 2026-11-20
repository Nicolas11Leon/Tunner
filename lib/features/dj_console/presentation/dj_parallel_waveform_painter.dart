import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/dj_transition_sfx_synthesizer.dart';
import '../domain/dj_deck_entity.dart';

/// 60/120 FPS Dual Parallel RGB Spectral Waveform & Beatgrid Phase Meter Painter.
///
/// Colors spectral bands like industry hardware (CDJ-3000 / Rekordbox / Serato):
/// - Red/Orange: Bass & Kick (< 220 Hz)
/// - Green: Midrange & Vocals (220 Hz - 3.8 kHz)
/// - Cyan/Blue: Highs & Hi-Hats (> 3.8 kHz)
class DjParallelWaveformPainter extends CustomPainter {
  final DjDeckEntity deckA;
  final DjDeckEntity deckB;
  final List<SpectralWaveformBucket> waveformA;
  final List<SpectralWaveformBucket> waveformB;

  const DjParallelWaveformPainter({
    required this.deckA,
    required this.deckB,
    required this.waveformA,
    required this.waveformB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Background studio slate
    final bgRect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFF0A0A0E),
    );

    const double phaseMeterHeight = 16.0;
    final double laneHeight = (size.height - phaseMeterHeight - 6.0) / 2.0;

    // 1. Phase Alignment Meter at top
    _paintPhaseMeter(canvas, Rect.fromLTWH(0, 0, size.width, phaseMeterHeight));

    // 2. Deck A Waveform Lane
    final rectA = Rect.fromLTWH(0, phaseMeterHeight + 2.0, size.width, laneHeight);
    _paintWaveformLane(canvas, rectA, deckA, waveformA, const Color(0xFF00E676));

    // Divider line
    canvas.drawLine(
      Offset(0, phaseMeterHeight + laneHeight + 3.0),
      Offset(size.width, phaseMeterHeight + laneHeight + 3.0),
      Paint()
        ..color = const Color(0xFF282834)
        ..strokeWidth = 1.0,
    );

    // 3. Deck B Waveform Lane
    final rectB = Rect.fromLTWH(0, phaseMeterHeight + laneHeight + 5.0, size.width, laneHeight);
    _paintWaveformLane(canvas, rectB, deckB, waveformB, const Color(0xFF2979FF));
  }

  void _paintPhaseMeter(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF14141C));

    final centerX = rect.center.dx;
    // Beat phase offset between Deck A and Deck B in [-0.5, +0.5]
    final beatMsA = 60000.0 / math.max(1.0, deckA.effectiveBpm);
    final beatMsB = 60000.0 / math.max(1.0, deckB.effectiveBpm);
    final phaseA = (deckA.currentPositionMs % beatMsA) / beatMsA;
    final phaseB = (deckB.currentPositionMs % beatMsB) / beatMsB;

    double diff = phaseB - phaseA;
    if (diff > 0.5) diff -= 1.0;
    if (diff < -0.5) diff += 1.0;

    final isLocked = diff.abs() < 0.08;
    final indicatorColor = isLocked ? const Color(0xFF00E676) : const Color(0xFFFF9100);
    final indicatorX = (centerX + (diff * rect.width * 0.45)).clamp(rect.left + 8, rect.right - 8);

    // Center tick
    canvas.drawLine(
      Offset(centerX, rect.top + 2),
      Offset(centerX, rect.bottom - 2),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1.5,
    );

    // Phase block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(indicatorX, rect.center.dy), width: 14, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = indicatorColor,
    );
  }

  void _paintWaveformLane(
    Canvas canvas,
    Rect rect,
    DjDeckEntity deck,
    List<SpectralWaveformBucket> buckets,
    Color deckAccent,
  ) {
    canvas.save();
    canvas.clipRect(rect);

    final centerY = rect.center.dy;
    final halfH = rect.height * 0.45;
    final count = math.max(1, buckets.length);
    final barWidth = rect.width / count;

    // Loop highlight region
    if (deck.isLoopActive && deck.durationMs > 0) {
      final startFrac = (deck.loopStartMs / deck.durationMs).clamp(0.0, 1.0);
      final endFrac = (deck.loopEndMs / deck.durationMs).clamp(0.0, 1.0);
      final loopRect = Rect.fromLTRB(
        rect.left + (startFrac * rect.width),
        rect.top,
        rect.left + (endFrac * rect.width),
        rect.bottom,
      );
      canvas.drawRect(
        loopRect,
        Paint()..color = const Color(0xFFFFD700).withAlpha(45),
      );
    }

    // Spectral RGB bars + Beatgrid ticks
    for (int i = 0; i < count; i++) {
      final b = buckets[i];
      final x = rect.left + (i * barWidth);

      // RGB weighted color from low (red), mid (green), high (blue/cyan)
      final r = (b.lowEnergy * 255).round().clamp(30, 255);
      final g = (b.midEnergy * 255).round().clamp(30, 255);
      final bl = (b.highEnergy * 255).round().clamp(40, 255);

      final barHeight = (b.peakAmplitude * halfH).clamp(2.0, halfH);
      final barRect = Rect.fromCenter(
        center: Offset(x + (barWidth * 0.5), centerY),
        width: math.max(1.5, barWidth * 0.72),
        height: barHeight * 2.0,
      );

      canvas.drawRect(
        barRect,
        Paint()..color = Color.fromARGB(235, r, g, bl),
      );

      // Beatgrid lines every 6 buckets (downbeat red, beat subtle white)
      if (i % 6 == 0) {
        final isBarDownbeat = (i % 24 == 0);
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x, rect.bottom),
          Paint()
            ..color = isBarDownbeat ? const Color(0xFFFF5252).withAlpha(170) : Colors.white12
            ..strokeWidth = isBarDownbeat ? 1.5 : 0.8,
        );
      }
    }

    // Slip Mode phantom needle (if active)
    if (deck.isSlipModeActive && deck.durationMs > 0) {
      final slipX = rect.left + ((deck.slipPositionMs / deck.durationMs).clamp(0.0, 1.0) * rect.width);
      canvas.drawLine(
        Offset(slipX, rect.top),
        Offset(slipX, rect.bottom),
        Paint()
          ..color = const Color(0xFFFF9100)
          ..strokeWidth = 2.0,
      );
    }

    // Playhead needle
    final playX = rect.left + (deck.progressFraction * rect.width);
    canvas.drawLine(
      Offset(playX, rect.top),
      Offset(playX, rect.bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0,
    );

    // Deck badge tag
    final tp = TextPainter(
      text: TextSpan(
        text: 'DECK ${deck.deckId}  ${deck.effectiveBpm.toStringAsFixed(1)} BPM  [${deck.effectiveCamelotKey.code}]',
        style: TextStyle(
          color: deckAccent,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          backgroundColor: const Color(0xAA000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rect.left + 6, rect.top + 3));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DjParallelWaveformPainter oldDelegate) {
    return oldDelegate.deckA.currentPositionMs != deckA.currentPositionMs ||
        oldDelegate.deckB.currentPositionMs != deckB.currentPositionMs ||
        oldDelegate.deckA.isLoopActive != deckA.isLoopActive ||
        oldDelegate.deckB.isLoopActive != deckB.isLoopActive ||
        oldDelegate.deckA.effectiveBpm != deckA.effectiveBpm ||
        oldDelegate.deckB.effectiveBpm != deckB.effectiveBpm ||
        oldDelegate.deckA.pitchSemitonesShift != deckA.pitchSemitonesShift ||
        oldDelegate.deckB.pitchSemitonesShift != deckB.pitchSemitonesShift;
  }
}
