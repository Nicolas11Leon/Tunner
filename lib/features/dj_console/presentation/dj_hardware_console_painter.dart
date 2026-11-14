import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/dj_hardware_skin_entity.dart';
import '../domain/dj_skin_zone_entity.dart';

/// Renders a responsive, ultra-crisp vector skin mimicking real DJ hardware.
class DjHardwareConsolePainter extends CustomPainter {
  final DjHardwareSkinEntity skin;
  final DjSkinZoneEntity? selectedZone;
  final bool isLearnModeActive;
  final double jogRotationA;
  final double jogRotationB;

  DjHardwareConsolePainter({
    required this.skin,
    this.selectedZone,
    this.isLearnModeActive = false,
    this.jogRotationA = 0.0,
    this.jogRotationB = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw Hardware Chassis
    final chassisRect = Offset.zero & size;
    final chassisPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(skin.chassisColor),
          const Color(0xFF0A0A0C),
        ],
      ).createShader(chassisRect);

    final chassisRRect = RRect.fromRectAndRadius(chassisRect, const Radius.circular(16.0));
    canvas.drawRRect(chassisRRect, chassisPaint);

    // Chassis bevel / outer rim border
    final borderPaint = Paint()
      ..color = const Color(0xFF2A2A30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(chassisRRect, borderPaint);

    // Subtle brushed metal separator between Decks and Mixer
    final mixerSeparatorPaint = Paint()
      ..color = const Color(0xFF1E1E24)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width * 0.38, 12),
      Offset(size.width * 0.38, size.height - 12),
      mixerSeparatorPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, 12),
      Offset(size.width * 0.62, size.height - 12),
      mixerSeparatorPaint,
    );

    // 2. Render all interactive skin zones
    for (final zone in skin.zones) {
      _paintZone(canvas, size, zone);
    }

    // 3. Highlight selected zone in Learn Mode
    if (isLearnModeActive && selectedZone != null) {
      _paintSelectedZoneHighlight(canvas, size, selectedZone!);
    }
  }

  void _paintZone(Canvas canvas, Size size, DjSkinZoneEntity zone) {
    final rect = Rect.fromLTWH(
      zone.normalizedX * size.width,
      zone.normalizedY * size.height,
      zone.normalizedWidth * size.width,
      zone.normalizedHeight * size.height,
    );

    switch (zone.controlType) {
      case DjControlType.jogWheel:
        _paintJogWheel(canvas, rect, zone);
        break;
      case DjControlType.button:
        _paintButton(canvas, rect, zone);
        break;
      case DjControlType.pad:
        _paintPerformancePad(canvas, rect, zone);
        break;
      case DjControlType.knob:
        _paintKnob(canvas, rect, zone);
        break;
      case DjControlType.fader:
        _paintFader(canvas, rect, zone);
        break;
    }
  }

  void _paintJogWheel(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2.0;

    // Outer plinth / bevel
    final plinthPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF222228),
          const Color(0xFF0E0E12),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, plinthPaint);

    // Metallic grooved platter (Vinyl feel)
    final platterPaint = Paint()
      ..color = const Color(0xFF16161A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.90, platterPaint);

    // Platter grooves rings
    final groovePaint = Paint()
      ..color = const Color(0xFF26262D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (double r = radius * 0.45; r < radius * 0.88; r += 6.0) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Rotating center marker / needle
    final rotation = zone.deckId == 'deckB' ? jogRotationB : jogRotationA;
    final needleEnd = Offset(
      center.dx + (radius * 0.75) * math.cos(rotation),
      center.dy + (radius * 0.75) * math.sin(rotation),
    );

    final needlePaint = Paint()
      ..color = zone.isLedLit ? Color(zone.ledColor) : const Color(0xFF00E5FF)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Center display / hub
    final centerHubPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2E2E38),
          const Color(0xFF121216),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.35));
    canvas.drawCircle(center, radius * 0.35, centerHubPaint);

    final hubBorderPaint = Paint()
      ..color = zone.isLedLit ? Color(zone.ledColor) : const Color(0xFF40404C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.35, hubBorderPaint);

    // Center label
    _paintText(
      canvas,
      zone.deckId == 'deckB' ? 'DECK B' : 'DECK A',
      center,
      fontSize: 10.0,
      textColor: const Color(0xFFB0B0C0),
    );
  }

  void _paintButton(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final isLit = zone.isLedLit;
    final baseColor = Color(zone.ledColor);

    // Glow effect if active
    if (isLit) {
      final glowPaint = Paint()
        ..color = baseColor.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), glowPaint);
    }

    final btnRRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final btnPaint = Paint()
      ..color = isLit ? baseColor : const Color(0xFF1E1E26)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(btnRRect, btnPaint);

    final btnBorderPaint = Paint()
      ..color = isLit ? Colors.white : const Color(0xFF383844)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(btnRRect, btnBorderPaint);

    // Text Label
    _paintText(
      canvas,
      zone.label,
      rect.center,
      fontSize: 9.0,
      textColor: isLit ? Colors.black : Colors.white,
      bold: true,
    );
  }

  void _paintPerformancePad(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final isLit = zone.isLedLit;
    final padColor = Color(zone.ledColor);

    if (isLit) {
      final glowPaint = Paint()
        ..color = padColor.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), glowPaint);
    }

    final padRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final padPaint = Paint()
      ..color = isLit ? padColor : const Color(0xFF24242E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(padRRect, padPaint);

    final padBorderPaint = Paint()
      ..color = isLit ? Colors.white : padColor.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(padRRect, padBorderPaint);

    _paintText(
      canvas,
      zone.label,
      rect.center,
      fontSize: 8.5,
      textColor: isLit ? Colors.black : const Color(0xFFD0D0E0),
      bold: true,
    );
  }

  void _paintKnob(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2.0;

    // Outer knob shadow & body
    final knobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2C2C36),
          const Color(0xFF141418),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, knobPaint);

    final knobBorderPaint = Paint()
      ..color = const Color(0xFF484856)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, knobBorderPaint);

    // Top indicator pip/notch
    final indicatorPaint = Paint()
      ..color = zone.isLedLit ? Color(zone.ledColor) : const Color(0xFFEEEEEE)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final notchStart = Offset(center.dx, center.dy - radius * 0.3);
    final notchEnd = Offset(center.dx, center.dy - radius * 0.85);
    canvas.drawLine(notchStart, notchEnd, indicatorPaint);

    // Label under knob
    _paintText(
      canvas,
      zone.label,
      Offset(center.dx, center.dy + radius + 7.0),
      fontSize: 7.5,
      textColor: const Color(0xFF9090A0),
    );
  }

  void _paintFader(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final isHorizontal = rect.width > rect.height;

    // Fader groove / track
    final trackPaint = Paint()
      ..color = const Color(0xFF0C0C10)
      ..style = PaintingStyle.fill;

    if (isHorizontal) {
      final trackRect = Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.85,
        height: 6.0,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(3)), trackPaint);

      // Fader cap
      final capRect = Rect.fromCenter(
        center: rect.center,
        width: 14.0,
        height: rect.height * 0.75,
      );
      _paintFaderCap(canvas, capRect);
    } else {
      final trackRect = Rect.fromCenter(
        center: rect.center,
        width: 6.0,
        height: rect.height * 0.85,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(3)), trackPaint);

      // Fader cap
      final capRect = Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.80,
        height: 12.0,
      );
      _paintFaderCap(canvas, capRect);
    }

    _paintText(
      canvas,
      zone.label,
      Offset(rect.center.dx, rect.bottom + 6.0),
      fontSize: 7.5,
      textColor: const Color(0xFF888898),
    );
  }

  void _paintFaderCap(Canvas canvas, Rect capRect) {
    final capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFEEEEEE),
          const Color(0xFF888890),
        ],
      ).createShader(capRect);
    canvas.drawRRect(RRect.fromRectAndRadius(capRect, const Radius.circular(3)), capPaint);

    final capLinePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(capRect.left, capRect.center.dy),
      Offset(capRect.right, capRect.center.dy),
      capLinePaint,
    );
  }

  void _paintSelectedZoneHighlight(Canvas canvas, Size size, DjSkinZoneEntity zone) {
    final rect = Rect.fromLTWH(
      zone.normalizedX * size.width - 3,
      zone.normalizedY * size.height - 3,
      zone.normalizedWidth * size.width + 6,
      zone.normalizedHeight * size.height + 6,
    );

    final highlightPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), highlightPaint);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required double fontSize,
    required Color textColor,
    bool bold = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      position.dx - (textPainter.width / 2.0),
      position.dy - (textPainter.height / 2.0),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant DjHardwareConsolePainter oldDelegate) {
    return oldDelegate.skin != skin ||
        oldDelegate.selectedZone != selectedZone ||
        oldDelegate.isLearnModeActive != isLearnModeActive ||
        oldDelegate.jogRotationA != jogRotationA ||
        oldDelegate.jogRotationB != jogRotationB;
  }
}
