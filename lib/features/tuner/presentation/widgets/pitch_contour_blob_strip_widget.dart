import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design_system/atoms/studio_icon.dart';
import '../../../../core/design_system/domain/studio_icon_catalog.dart';
import '../../../../core/design_system/studio_design_tokens.dart';
import '../../../../core/design_system/studio_theme_provider.dart';

/// Instantánea discreta de tono para renderizado de *Pitch Blobs* estilo Melodyne 5.
class PitchBlobSample {
  final String note;
  final double frequency;
  final double cents;
  final DateTime timestamp;

  const PitchBlobSample({
    required this.note,
    required this.frequency,
    required this.cents,
    required this.timestamp,
  });
}

/// Tira de contorno tonal y *Pitch Blobs* inspirada en Celemony Melodyne 5 (US-UX-06).
///
/// Visualiza:
/// - Cuadrícula Tonal de Fondo (*Pitch Grid*: $0\text{ ct}$, $\pm 15\text{ ct}$, $\pm 50\text{ ct}$).
/// - Marco Fantasma de Intención (*Intended Note Target Frame*).
/// - Cuerpo Orgánico del Blob (*Melodyne Note Blob*) con código semántico de estabilidad
///   (Verde Esmeralda $|\Delta c| \le 15$, Ámbar $15 < |\Delta c| \le 35$, Rojo Coral $> 35$).
/// - Curva Interna de Micro-Entonación (*Pitch Drift & Vibrato Curve*).
class PitchContourBlobStripWidget extends StatefulWidget {
  final String note;
  final double frequency;
  final double cents;
  final bool isListening;
  final List<PitchBlobSample>? initialSamples;

  const PitchContourBlobStripWidget({
    super.key = const Key('melodyne_pitch_contour_blob_strip'),
    required this.note,
    required this.frequency,
    required this.cents,
    required this.isListening,
    this.initialSamples,
  });

  @override
  State<PitchContourBlobStripWidget> createState() =>
      _PitchContourBlobStripWidgetState();
}

class _PitchContourBlobStripWidgetState
    extends State<PitchContourBlobStripWidget> {
  static const int _maxSamples = 24;
  final List<PitchBlobSample> _samples = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSamples != null) {
      _samples.addAll(widget.initialSamples!.take(_maxSamples));
    }
    _ingestCurrentSampleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant PitchContourBlobStripWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frequency != widget.frequency ||
        oldWidget.cents != widget.cents ||
        oldWidget.note != widget.note) {
      _ingestCurrentSampleIfNeeded();
    }
  }

  void _ingestCurrentSampleIfNeeded() {
    if (widget.frequency <= 0 || widget.note.isEmpty || widget.note == '--') {
      return;
    }
    _samples.add(
      PitchBlobSample(
        note: widget.note,
        frequency: widget.frequency,
        cents: widget.cents.clamp(-50.0, 50.0),
        timestamp: DateTime.now(),
      ),
    );
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
  }

  void _clearSamples() {
    setState(() {
      _samples.clear();
    });
  }

  Color _resolveSemanticBlobColor(double absCents, StudioDesignTokens tokens) {
    if (absCents <= 15.0) {
      return tokens.accentSuccess; // Verde Esmeralda
    } else if (absCents <= 35.0) {
      return tokens.accentWarning; // Ámbar
    }
    return tokens.accentDanger; // Rojo Coral
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final hasActiveSignal =
        widget.frequency > 0 && widget.note.isNotEmpty && widget.note != '--';
    final absCents = widget.cents.abs();
    final activeColor = hasActiveSignal
        ? _resolveSemanticBlobColor(absCents, tokens)
        : tokens.textMuted;

    final centsLabel = hasActiveSignal
        ? '${widget.cents >= 0 ? '+' : ''}${widget.cents.toStringAsFixed(1)} ct'
        : '±0.0 ct';
    final freqLabel =
        hasActiveSignal ? '${widget.frequency.toStringAsFixed(1)} Hz' : '-- Hz';
    final noteLabel = hasActiveSignal ? widget.note : '--';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
        border: Border.all(
          color: hasActiveSignal
              ? activeColor.withValues(alpha: 0.45)
              : tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StudioIcon(
                StudioIconId.moduleAutotune,
                size: 13,
                color: activeColor,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CONTORNO TONAL & BLOBS (MELODYNE VIEW)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                key: const Key('melodyne_blob_live_readout_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$noteLabel · $freqLabel · $centsLabel',
                  style: TextStyle(
                    color: hasActiveSignal ? activeColor : tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Blobs: ${_samples.length}',
                key: const Key('melodyne_blob_count_text'),
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                key: const Key('btn_clear_pitch_blobs'),
                onTap: _clearSamples,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StudioIcon(
                        StudioIconId.uiCloseConfirm,
                        size: 11,
                        color: tokens.textMuted,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Limpiar',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              child: CustomPaint(
                key: const Key('melodyne_pitch_blob_canvas'),
                painter: MelodynePitchBlobPainter(
                  samples: List<PitchBlobSample>.unmodifiable(_samples),
                  activeNote: noteLabel,
                  activeCents: widget.cents,
                  hasActiveSignal: hasActiveSignal,
                  isListening: widget.isListening,
                  tokens: tokens,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renderizador vectorial de *Pitch Blobs* y curva de micro-entonación estilo Celemony Melodyne 5.
class MelodynePitchBlobPainter extends CustomPainter {
  final List<PitchBlobSample> samples;
  final String activeNote;
  final double activeCents;
  final bool hasActiveSignal;
  final bool isListening;
  final StudioDesignTokens tokens;

  const MelodynePitchBlobPainter({
    required this.samples,
    required this.activeNote,
    required this.activeCents,
    required this.hasActiveSignal,
    required this.isListening,
    required this.tokens,
  });

  Color _colorForCents(double cents) {
    final abs = cents.abs();
    if (abs <= 15.0) return tokens.accentSuccess;
    if (abs <= 35.0) return tokens.accentWarning;
    return tokens.accentDanger;
  }

  double _yForCents(double cents, double height) {
    final normalized = (cents.clamp(-50.0, 50.0) / 50.0); // -1.0 a +1.0
    final centerY = height / 2.0;
    return centerY - normalized * (height * 0.40);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = tokens.elevatedSurface;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final centerY = size.height / 2.0;
    final yPlus15 = _yForCents(15.0, size.height);
    final yMinus15 = _yForCents(-15.0, size.height);

    // 1. Marco Fantasma de Intención (Intended Note Target Frame ±15 cents)
    final targetFrameRect = Rect.fromLTRB(4, yPlus15, size.width - 4, yMinus15);
    final targetFillPaint = Paint()
      ..color = tokens.accentSuccess.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final targetBorderPaint = Paint()
      ..color = tokens.accentSuccess.withValues(alpha: 0.24)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetFrameRect, const Radius.circular(4)),
      targetFillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetFrameRect, const Radius.circular(4)),
      targetBorderPaint,
    );

    // 2. Cuadrícula Tonal de Fondo (Pitch Grid: 0 cents, ±15 cents, ±50 cents)
    final centerLinePaint = Paint()
      ..color = tokens.accentPrimary.withValues(alpha: 0.35)
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );

    // 3. Renderizado de Blobs Históricos + Blob Activo
    final effectiveSamples = samples.isNotEmpty
        ? samples
        : (hasActiveSignal
            ? [
                PitchBlobSample(
                  note: activeNote,
                  frequency: 440.0,
                  cents: activeCents,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
                ),
              ]
            : const <PitchBlobSample>[]);

    if (effectiveSamples.isEmpty) {
      return;
    }

    const maxSlots = 24;
    final slotWidth = size.width / maxSlots;
    final startSlot = math.max(0, maxSlots - effectiveSamples.length);

    final driftPath = Path();
    var hasStartedPath = false;

    for (var i = 0; i < effectiveSamples.length; i++) {
      final sample = effectiveSamples[i];
      final slotIndex = startSlot + i;
      final xCenter = (slotIndex + 0.5) * slotWidth;
      final yCenter = _yForCents(sample.cents, size.height);
      final blobColor = _colorForCents(sample.cents);
      final isLatest = i == effectiveSamples.length - 1;

      final blobWidth = math.max(10.0, slotWidth * (isLatest ? 0.92 : 0.78));
      final blobHeight = isLatest ? 14.0 : 11.0;

      final blobRect = Rect.fromCenter(
        center: Offset(xCenter, yCenter),
        width: blobWidth,
        height: blobHeight,
      );
      final blobRRect = RRect.fromRectAndRadius(
        blobRect,
        Radius.circular(blobHeight / 2),
      );

      // Cuerpo Orgánico del Blob (Melodyne Note Blob)
      final fillPaint = Paint()
        ..color = blobColor.withValues(alpha: isLatest ? 0.36 : 0.22)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = blobColor.withValues(alpha: isLatest ? 0.95 : 0.60)
        ..strokeWidth = isLatest ? 1.5 : 1.1
        ..style = PaintingStyle.stroke;

      canvas.drawRRect(blobRRect, fillPaint);
      canvas.drawRRect(blobRRect, strokePaint);

      // Punto de anclaje en la curva interna de micro-entonación
      if (!hasStartedPath) {
        driftPath.moveTo(xCenter, yCenter);
        hasStartedPath = true;
      } else {
        driftPath.lineTo(xCenter, yCenter);
      }
    }

    // 4. Curva Interna de Micro-Entonación (Pitch Drift & Vibrato Curve)
    if (effectiveSamples.length >= 2) {
      final curvePaint = Paint()
        ..color = tokens.textPrimary.withValues(alpha: 0.85)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(driftPath, curvePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MelodynePitchBlobPainter oldDelegate) {
    return oldDelegate.samples.length != samples.length ||
        oldDelegate.activeNote != activeNote ||
        oldDelegate.activeCents != activeCents ||
        oldDelegate.hasActiveSignal != hasActiveSignal ||
        oldDelegate.isListening != isListening;
  }
}
