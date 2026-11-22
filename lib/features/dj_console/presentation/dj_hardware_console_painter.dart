import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/dj_action.dart';
import '../domain/dj_hardware_skin_entity.dart';
import '../domain/dj_keymap_profile_entity.dart';
import '../domain/dj_skin_zone_entity.dart';

/// Renders a responsive, ultra-crisp vector skin mimicking real DJ hardware controllers.
///
/// Features authentic industrial metal textures, vinyl grooves, illuminated jog displays,
/// Pioneer/Club style play & cue buttons, rubber performance pads, rotary potentiometers with graduation ticks,
/// and overlaid interactive QWERTY key badges.
class DjHardwareConsolePainter extends CustomPainter {
  final DjHardwareSkinEntity skin;
  final DjSkinZoneEntity? selectedZone;
  final bool isLearnModeActive;
  final double jogRotationA;
  final double jogRotationB;
  final DjKeymapProfileEntity? keymapProfile;
  final bool showKeyBadges;
  final double Function(DjSkinZoneEntity zone)? getControlValue;

  DjHardwareConsolePainter({
    required this.skin,
    this.selectedZone,
    this.isLearnModeActive = false,
    this.jogRotationA = 0.0,
    this.jogRotationB = 0.0,
    this.keymapProfile,
    this.showKeyBadges = true,
    this.getControlValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw Hardware Chassis (Industrial Dark Matte Brushed Aluminum)
    final chassisRect = Offset.zero & size;
    final chassisPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(skin.chassisColor),
          const Color(0xFF070709),
        ],
      ).createShader(chassisRect);

    final chassisRRect = RRect.fromRectAndRadius(chassisRect, const Radius.circular(12.0));
    canvas.drawRRect(chassisRRect, chassisPaint);

    // Chassis bevel / outer rim border
    final borderPaint = Paint()
      ..color = const Color(0xFF282832)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(chassisRRect, borderPaint);

    // Corner Hex Screws (Industrial hardware feel)
    _paintCornerScrews(canvas, size);

    // Mixer section plate boundary
    _paintMixerFaceplate(canvas, size);

    // Manufacturer & Model Branding Plaque (Top Center)
    _paintBrandingPlaque(canvas, size);

    // 2. Render all interactive skin zones
    for (final zone in skin.zones) {
      _paintZone(canvas, size, zone);
    }

    // 3. Highlight selected zone in Learn Mode
    if (isLearnModeActive && selectedZone != null) {
      _paintSelectedZoneHighlight(canvas, size, selectedZone!);
    }
  }

  void _paintCornerScrews(Canvas canvas, Size size) {
    final screwOffsets = [
      const Offset(10, 10),
      Offset(size.width - 10, 10),
      Offset(10, size.height - 10),
      Offset(size.width - 10, size.height - 10),
    ];

    final screwOuter = Paint()..color = const Color(0xFF1E1E24);
    final screwInner = Paint()..color = const Color(0xFF383842);
    final screwSlot = Paint()
      ..color = const Color(0xFF0C0C10)
      ..strokeWidth = 1.0;

    for (final o in screwOffsets) {
      canvas.drawCircle(o, 4.0, screwOuter);
      canvas.drawCircle(o, 3.0, screwInner);
      canvas.drawLine(Offset(o.dx - 2.0, o.dy), Offset(o.dx + 2.0, o.dy), screwSlot);
    }
  }

  void _paintMixerFaceplate(Canvas canvas, Size size) {
    final mixerLeft = size.width * 0.36;
    final mixerRight = size.width * 0.64;

    // Dark brushed steel background for central mixer
    final mixerRect = Rect.fromLTWH(mixerLeft, 6, mixerRight - mixerLeft, size.height - 12);
    final mixerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF141418),
          const Color(0xFF0E0E12),
        ],
      ).createShader(mixerRect);
    canvas.drawRRect(RRect.fromRectAndRadius(mixerRect, const Radius.circular(6)), mixerPaint);

    // Boundary vertical grooves
    final separatorPaint = Paint()
      ..color = const Color(0xFF262630)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(mixerLeft, 6), Offset(mixerLeft, size.height - 6), separatorPaint);
    canvas.drawLine(Offset(mixerRight, 6), Offset(mixerRight, size.height - 6), separatorPaint);
  }

  void _paintBrandingPlaque(Canvas canvas, Size size) {
    final plaqueRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, 14),
      width: 180,
      height: 18,
    );

    final plaquePaint = Paint()..color = const Color(0xFF0A0A0E);
    canvas.drawRRect(RRect.fromRectAndRadius(plaqueRect, const Radius.circular(4)), plaquePaint);

    final border = Paint()
      ..color = const Color(0xFF2C2C38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(plaqueRect, const Radius.circular(4)), border);

    _paintText(
      canvas,
      '${skin.manufacturer.toUpperCase()} | ${skin.name.toUpperCase()}',
      Offset(size.width * 0.5, 14),
      fontSize: 8.5,
      textColor: const Color(0xFF8E8E9E),
      bold: true,
      letterSpacing: 0.8,
    );
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

    // Overlaid Key Shortcut Badge
    if (showKeyBadges && keymapProfile != null) {
      final badge = keymapProfile!.findKeyBadgeForAction(zone.action);
      if (badge != null && badge.isNotEmpty) {
        _paintKeyBadge(canvas, rect, badge, zone.controlType);
      }
    }
  }

  void _paintJogWheel(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2.0;

    // 1. Outer Aluminum Plinth with knurling dots
    final plinthPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2E2E38),
          const Color(0xFF14141A),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, plinthPaint);

    // Plinth outer rim stroke
    final rimPaint = Paint()
      ..color = const Color(0xFF424250)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, rimPaint);

    // Textured Knurled Grip Ring (Pioneer / Traktor grip teeth)
    final gripPaint = Paint()
      ..color = const Color(0xFF383844)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (double a = 0; a < math.pi * 2; a += math.pi / 24) {
      final p1 = Offset(center.dx + (radius * 0.94) * math.cos(a), center.dy + (radius * 0.94) * math.sin(a));
      final p2 = Offset(center.dx + (radius * 0.88) * math.cos(a), center.dy + (radius * 0.88) * math.sin(a));
      canvas.drawLine(p1, p2, gripPaint);
    }

    // 2. Vinyl Platter (Deep carbon black with subtle circular grooves)
    final platterPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A1A22),
          const Color(0xFF0E0E12),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.88));
    canvas.drawCircle(center, radius * 0.88, platterPaint);

    // Platter grooves (Concentric micro-grooves)
    final groovePaint = Paint()
      ..color = const Color(0xFF24242E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (double r = radius * 0.44; r < radius * 0.86; r += 5.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // 3. Central Digital Display Hub (CDJ / DDJ jog screen)
    final hubRadius = radius * 0.38;
    final hubPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF282834),
          const Color(0xFF0A0A0E),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: hubRadius));
    canvas.drawCircle(center, hubRadius, hubPaint);

    // Outer Hub LED Ring (Red / Cyan / Amber)
    final isDeckB = zone.deckId == 'deckB';
    final deckColor = isDeckB ? const Color(0xFFFFAB00) : const Color(0xFF00E5FF);
    final hubBorderPaint = Paint()
      ..color = deckColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, hubRadius, hubBorderPaint);

    // Rotating Needle / Track Marker (Sub-10ms visual tracking)
    final rotation = isDeckB ? jogRotationB : jogRotationA;
    final needleEnd = Offset(
      center.dx + (hubRadius * 0.88) * math.cos(rotation),
      center.dy + (hubRadius * 0.88) * math.sin(rotation),
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Inner Display Hub (Center Screen info)
    _paintText(
      canvas,
      isDeckB ? 'DECK B' : 'DECK A',
      Offset(center.dx, center.dy - 6.0),
      fontSize: 8.5,
      textColor: deckColor,
      bold: true,
    );
    _paintText(
      canvas,
      'VINYL',
      Offset(center.dx, center.dy + 6.0),
      fontSize: 7.0,
      textColor: const Color(0xFF88889A),
      bold: true,
    );
  }

  void _paintButton(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final isLit = zone.isLedLit;
    final isRoundPioneer = zone.action == DjAction.deckAPlayPause ||
        zone.action == DjAction.deckBPlayPause ||
        zone.action == DjAction.deckACue ||
        zone.action == DjAction.deckBCue;

    final baseColor = Color(zone.ledColor);

    if (isRoundPioneer) {
      // Circular Pioneer DJ Metallic Bezel Button
      final center = rect.center;
      final radius = math.min(rect.width, rect.height) / 2.0;

      // Outer bezel ring
      final bezelPaint = Paint()
        ..color = const Color(0xFF2A2A34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius, bezelPaint);

      // Vivid Neon Halo Glow when button is active/lit
      if (isLit) {
        final glow = Paint()
          ..color = baseColor.withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
        canvas.drawCircle(center, radius * 0.9, glow);
      }

      // Button body
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            isLit ? baseColor.withValues(alpha: 0.5) : const Color(0xFF22222A),
            const Color(0xFF101014),
          ],
        ).createShader(rect);
      canvas.drawCircle(center, radius * 0.88, bodyPaint);

      // Illuminated Ring
      final ringPaint = Paint()
        ..color = isLit ? baseColor : baseColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLit ? 2.5 : 2.0;
      canvas.drawCircle(center, radius * 0.88, ringPaint);

      // Icon / Label
      if (zone.action == DjAction.deckAPlayPause || zone.action == DjAction.deckBPlayPause) {
        // Draw Triangle Play & Pause bars
        _paintPlayPauseIcon(canvas, center, isLit ? Colors.white : baseColor);
      } else {
        _paintText(
          canvas,
          'CUE',
          center,
          fontSize: 9.0,
          textColor: isLit ? Colors.white : baseColor,
          bold: true,
        );
      }
    } else {
      // Standard Rectangular Button with LED rim
      final btnRRect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      if (isLit) {
        final glow = Paint()
          ..color = baseColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawRRect(btnRRect, glow);
      }

      final btnPaint = Paint()
        ..color = isLit ? baseColor.withValues(alpha: 0.3) : const Color(0xFF1C1C24)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(btnRRect, btnPaint);

      final border = Paint()
        ..color = isLit ? baseColor : const Color(0xFF343442)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(btnRRect, border);

      _paintText(
        canvas,
        zone.label,
        rect.center,
        fontSize: 8.5,
        textColor: isLit ? Colors.white : const Color(0xFFB0B0C4),
        bold: true,
      );
    }
  }

  void _paintPlayPauseIcon(Canvas canvas, Offset center, Color color) {
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Play triangle
    final path = Path();
    path.moveTo(center.dx - 4, center.dy - 4);
    path.lineTo(center.dx + 4, center.dy);
    path.lineTo(center.dx - 4, center.dy + 4);
    path.close();
    canvas.drawPath(path, iconPaint);
  }

  void _paintPerformancePad(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final isLit = zone.isLedLit;
    final padColor = Color(zone.ledColor);

    final padRRect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // Glow if pressed
    if (isLit) {
      final glow = Paint()
        ..color = padColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawRRect(padRRect, glow);
    }

    // Translucent silicone rubber body
    final padPaint = Paint()
      ..color = isLit ? padColor : const Color(0xFF22222C)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(padRRect, padPaint);

    final padBorder = Paint()
      ..color = isLit ? Colors.white : padColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(padRRect, padBorder);

    _paintText(
      canvas,
      zone.label,
      rect.center,
      fontSize: 8.0,
      textColor: isLit ? Colors.black : const Color(0xFFE0E0F0),
      bold: true,
    );
  }

  void _paintKnob(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2.0;

    // Knob Perimeter Graduation Ticks (7 o'clock to 5 o'clock)
    final tickPaint = Paint()
      ..color = const Color(0xFF3C3C4A)
      ..strokeWidth = 1.0;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;
    for (int i = 0; i <= 10; i++) {
      final a = startAngle + (sweepAngle * (i / 10.0));
      final p1 = Offset(center.dx + (radius + 2.0) * math.cos(a), center.dy + (radius + 2.0) * math.sin(a));
      final p2 = Offset(center.dx + (radius + 4.5) * math.cos(a), center.dy + (radius + 4.5) * math.sin(a));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Outer knob body
    final knobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2C2C36),
          const Color(0xFF141418),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, knobPaint);

    final knobBorder = Paint()
      ..color = const Color(0xFF484858)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, knobBorder);

    // Indicator Pip / Needle Notch oriented along real analog rotary dial
    final indicatorPaint = Paint()
      ..color = zone.isLedLit ? Color(zone.ledColor) : const Color(0xFF00E5FF)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final value = (getControlValue?.call(zone) ?? 0.5).clamp(0.0, 1.0);
    final dialAngle = startAngle + (sweepAngle * value);

    final notchStart = Offset(
      center.dx + (radius * 0.25) * math.cos(dialAngle),
      center.dy + (radius * 0.25) * math.sin(dialAngle),
    );
    final notchEnd = Offset(
      center.dx + (radius * 0.85) * math.cos(dialAngle),
      center.dy + (radius * 0.85) * math.sin(dialAngle),
    );
    canvas.drawLine(notchStart, notchEnd, indicatorPaint);

    // Label under knob
    _paintText(
      canvas,
      zone.label,
      Offset(center.dx, center.dy + radius + 6.0),
      fontSize: 7.0,
      textColor: const Color(0xFF88889A),
    );
  }

  void _paintFader(Canvas canvas, Rect rect, DjSkinZoneEntity zone) {
    final isHorizontal = rect.width > rect.height;
    final value = (getControlValue?.call(zone) ?? 0.5).clamp(0.0, 1.0);

    // Track Groove
    final trackPaint = Paint()
      ..color = const Color(0xFF0A0A0E)
      ..style = PaintingStyle.fill;

    if (isHorizontal) {
      // Horizontal Crossfader
      final trackRect = Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.88,
        height: 6.0,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(3)), trackPaint);

      // Track Border
      final border = Paint()
        ..color = const Color(0xFF242430)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(3)), border);

      // Fader Cap positioned by value [0.0..1.0]
      const capWidth = 14.0;
      final minCapX = trackRect.left + (capWidth / 2);
      final maxCapX = trackRect.right - (capWidth / 2);
      final capCenterX = minCapX + (value * (maxCapX - minCapX));

      final capRect = Rect.fromCenter(
        center: Offset(capCenterX, trackRect.center.dy),
        width: capWidth,
        height: rect.height * 0.75,
      );
      _paintFaderCap(canvas, capRect);
    } else {
      // Vertical Channel Fader / Pitch Fader
      final trackRect = Rect.fromCenter(
        center: rect.center,
        width: 6.0,
        height: rect.height * 0.86,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(3)), trackPaint);

      // Track Border
      final border = Paint()
        ..color = const Color(0xFF242430)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(trackRect, const Radius.circular(3)), border);

      // dB Level Hash Marks
      final hashPaint = Paint()
        ..color = const Color(0xFF383848)
        ..strokeWidth = 1.0;
      for (double y = trackRect.top + 4; y <= trackRect.bottom - 4; y += 12) {
        canvas.drawLine(Offset(trackRect.left - 4, y), Offset(trackRect.left - 1, y), hashPaint);
        canvas.drawLine(Offset(trackRect.right + 1, y), Offset(trackRect.right + 4, y), hashPaint);
      }

      // Fader Cap positioned by value [0.0..1.0] (1.0 at top, 0.0 at bottom)
      const capHeight = 12.0;
      final minCapY = trackRect.bottom - (capHeight / 2);
      final maxCapY = trackRect.top + (capHeight / 2);
      final capCenterY = minCapY - (value * (minCapY - maxCapY));

      final capRect = Rect.fromCenter(
        center: Offset(trackRect.center.dx, capCenterY),
        width: rect.width * 0.75,
        height: capHeight,
      );
      _paintFaderCap(canvas, capRect);
    }

    _paintText(
      canvas,
      zone.label,
      Offset(rect.center.dx, rect.bottom + 5.0),
      fontSize: 7.0,
      textColor: const Color(0xFF88889A),
    );
  }

  void _paintFaderCap(Canvas canvas, Rect capRect) {
    final capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFD4D4E0),
          const Color(0xFF6E6E7A),
        ],
      ).createShader(capRect);
    canvas.drawRRect(RRect.fromRectAndRadius(capRect, const Radius.circular(2)), capPaint);

    // Center white indicator line
    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(capRect.left, capRect.center.dy),
      Offset(capRect.right, capRect.center.dy),
      linePaint,
    );
  }

  void _paintKeyBadge(Canvas canvas, Rect rect, String badge, DjControlType type) {
    // Determine optimal position for the key badge based on control type
    final badgeWidth = math.max(18.0, badge.length * 7.0 + 8.0);
    const badgeHeight = 13.0;

    Offset badgeCenter;
    if (type == DjControlType.jogWheel) {
      badgeCenter = Offset(rect.center.dx, rect.bottom - 12);
    } else if (type == DjControlType.fader) {
      badgeCenter = Offset(rect.center.dx, rect.top - 6);
    } else {
      badgeCenter = Offset(rect.right - 2, rect.top + 2);
    }

    final badgeRect = Rect.fromCenter(
      center: badgeCenter,
      width: badgeWidth,
      height: badgeHeight,
    );

    // Pill background
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), borderPaint);

    _paintText(
      canvas,
      badge,
      badgeCenter,
      fontSize: 7.5,
      textColor: const Color(0xFF00E5FF),
      bold: true,
    );
  }

  void _paintSelectedZoneHighlight(Canvas canvas, Size size, DjSkinZoneEntity zone) {
    final rect = Rect.fromLTWH(
      zone.normalizedX * size.width - 4,
      zone.normalizedY * size.height - 4,
      zone.normalizedWidth * size.width + 8,
      zone.normalizedHeight * size.height + 8,
    );

    final haloPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), haloPaint);

    final highlightPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), highlightPaint);

    // Prompt badge over selected zone
    final bannerRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top - 12),
      width: 100,
      height: 16,
    );
    final bannerBg = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRRect(RRect.fromRectAndRadius(bannerRect, const Radius.circular(4)), bannerBg);

    _paintText(
      canvas,
      'PULSAR TECLA',
      Offset(rect.center.dx, rect.top - 12),
      fontSize: 8.0,
      textColor: Colors.black,
      bold: true,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required double fontSize,
    required Color textColor,
    bool bold = false,
    double letterSpacing = 0.0,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        fontFamily: 'monospace',
        letterSpacing: letterSpacing,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final drawOffset = Offset(
      position.dx - (textPainter.width / 2.0),
      position.dy - (textPainter.height / 2.0),
    );
    textPainter.paint(canvas, drawOffset);
  }

  @override
  bool shouldRepaint(covariant DjHardwareConsolePainter oldDelegate) {
    return oldDelegate.skin.id != skin.id ||
        oldDelegate.selectedZone?.id != selectedZone?.id ||
        oldDelegate.isLearnModeActive != isLearnModeActive ||
        oldDelegate.jogRotationA != jogRotationA ||
        oldDelegate.jogRotationB != jogRotationB ||
        oldDelegate.showKeyBadges != showKeyBadges ||
        oldDelegate.keymapProfile != keymapProfile;
  }
}
