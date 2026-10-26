import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';

class StrobeTunerWidget extends StatefulWidget {
  final double cents;
  final double frequency;
  final String noteName;
  final bool isRecording;
  final VoidCallback? onPlayReferenceTone;
  final TunnerThemePalette? palette;

  const StrobeTunerWidget({
    super.key,
    required this.cents,
    required this.frequency,
    required this.noteName,
    required this.isRecording,
    this.onPlayReferenceTone,
    this.palette,
  });

  @override
  State<StrobeTunerWidget> createState() => _StrobeTunerWidgetState();
}

class _StrobeTunerWidgetState extends State<StrobeTunerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _phase = 0.0;
  double _smoothCents = 0.0;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onRenderTick);
    _controller.repeat();
  }

  void _onRenderTick() {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMicroseconds / 1000000.0;
    _lastTick = now;

    if (widget.isRecording && widget.noteName != "--" && widget.frequency > 20) {
      // Suavizado exponencial para evitar tirones manteniendo agilidad
      _smoothCents += (widget.cents - _smoothCents) * min(1.0, dt * 15.0);
      
      // Velocidad angular proporcional al error microtonal:
      // Si cents < 0 (flat), gira a la izquierda (velocidad negativa)
      // Si cents > 0 (sharp), gira a la derecha (velocidad positiva)
      // Si |cents| < 0.2, la velocidad es prácticamente 0 (congelamiento estroboscópico)
      final angularVelocity = _smoothCents * 0.08;
      _phase = (_phase + (angularVelocity * dt * 2 * pi)) % (2 * pi);
    } else {
      // Amortiguamiento suave en reposo
      _smoothCents *= max(0.0, 1.0 - (dt * 5.0));
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onRenderTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSound = widget.isRecording && widget.noteName != "--";
    final bool isDeadCenter = hasSound && widget.cents.abs() <= 3.0; // Precisión de conservatorio: +-3 cents
    final bool isFairlyTuned = hasSound && widget.cents.abs() <= 10.0;

    final p = widget.palette ?? TunnerThemePalette.obsidianStudio;

    final Color statusColor = isDeadCenter
        ? p.correctPitchColor // Afinación clavada de estudio
        : isFairlyTuned
            ? p.correctPitchColor.withValues(alpha: 0.8)
            : widget.cents < 0
                ? const Color(0xFF3399FF) // Bemol
                : p.warningPitchColor;    // Sostenido

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDeadCenter ? p.correctPitchColor.withValues(alpha: 0.6) : p.staffLinesColor.withValues(alpha: 0.25),
          width: isDeadCenter ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (isDeadCenter)
            BoxShadow(
              color: p.correctPitchColor.withValues(alpha: 0.25),
              blurRadius: 25,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila superior: Nota gigante y Frecuencia exacta en Hz
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "NOTA FUNDAMENTAL",
                        style: TextStyle(
                          color: p.textMutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (widget.onPlayReferenceTone != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onPlayReferenceTone,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.correctPitchColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: p.correctPitchColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.volume_up, size: 10, color: p.correctPitchColor),
                                const SizedBox(width: 3),
                                Text(
                                  "ESCUCHAR A4",
                                  style: TextStyle(fontSize: 8, color: p.correctPitchColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.noteName,
                    style: TextStyle(
                      color: hasSound ? statusColor : p.textMutedColor,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasSound ? "${widget.frequency.toStringAsFixed(1)} Hz" : "-- Hz",
                    style: TextStyle(
                      color: p.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      hasSound
                          ? "${widget.cents >= 0 ? '+' : ''}${widget.cents.toStringAsFixed(1)} cents"
                          : "-- cents",
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pantalla Estroboscópica Virtual
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _StrobePainter(
                  phase: _phase,
                  hasSound: hasSound,
                  cents: widget.cents,
                  statusColor: statusColor,
                  palette: p,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Regla microtonal de -50 a +50 cents
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("-50", style: TextStyle(color: p.textMutedColor, fontSize: 10)),
              Text("-25", style: TextStyle(color: p.textMutedColor, fontSize: 10)),
              Text("PERFECTO (0)", style: TextStyle(color: isDeadCenter ? p.correctPitchColor : p.textMutedColor, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("+25", style: TextStyle(color: p.textMutedColor, fontSize: 10)),
              Text("+50", style: TextStyle(color: p.textMutedColor, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrobePainter extends CustomPainter {
  final double phase;
  final bool hasSound;
  final double cents;
  final Color statusColor;
  final TunnerThemePalette palette;

  _StrobePainter({
    required this.phase,
    required this.hasSound,
    required this.cents,
    required this.statusColor,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo de la cámara estroboscópica adaptado al brillo
    final bgPaint = Paint()..color = palette.brightness == Brightness.dark ? const Color(0xFF0A0B10) : const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final double barWidth = 14.0;
    final double gap = 10.0;
    final double cycle = barWidth + gap;
    final int count = (size.width / cycle).ceil() + 4;

    // Desplazamiento horizontal derivado de la fase
    final double normalizedOffset = (phase / (2 * pi)) * cycle;

    final barPaint = Paint()
      ..color = hasSound
          ? statusColor.withValues(alpha: 0.85)
          : palette.textMutedColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Dibujo de las bandas estroboscópicas que rotan
    for (int i = -2; i < count; i++) {
      final double x = (i * cycle) + normalizedOffset;
      if (x + barWidth >= 0 && x <= size.width) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 4, barWidth, size.height - 8),
          const Radius.circular(3),
        );
        canvas.drawRRect(rrect, barPaint);
      }
    }

    // Línea central de referencia fija (Target Centerline)
    final double centerX = size.width / 2;
    final centerLinePaint = Paint()
      ..color = hasSound && cents.abs() <= 3.0 ? palette.correctPitchColor : palette.textColor
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      centerLinePaint,
    );

    // Triángulos de guía superior e inferior
    final trianglePaint = Paint()
      ..color = hasSound && cents.abs() <= 3.0 ? palette.correctPitchColor : palette.textMutedColor
      ..style = PaintingStyle.fill;

    final topPath = Path()
      ..moveTo(centerX - 5, 0)
      ..lineTo(centerX + 5, 0)
      ..lineTo(centerX, 5)
      ..close();
    canvas.drawPath(topPath, trianglePaint);

    final bottomPath = Path()
      ..moveTo(centerX - 5, size.height)
      ..lineTo(centerX + 5, size.height)
      ..lineTo(centerX, size.height - 5)
      ..close();
    canvas.drawPath(bottomPath, trianglePaint);
  }

  @override
  bool shouldRepaint(covariant _StrobePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.cents != cents ||
        oldDelegate.hasSound != hasSound ||
        oldDelegate.statusColor != statusColor ||
        oldDelegate.palette != palette;
  }
}
