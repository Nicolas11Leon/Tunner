import 'package:flutter/material.dart';
import '../../../../core/theme/tunner_theme.dart';
import '../../domain/instrument_profile_entity.dart';
import '../../domain/smart_instrument_detector.dart';

/// Átomo visual interactivo que exhibe el estado del reconocimiento tímbrico inteligente
/// y sugiere la adaptación automática de tesitura, transposición y SoundFont (UC-59).
class SmartInstrumentBadge extends StatelessWidget {
  final bool isSmartTuningActive;
  final bool autoSwitchEnabled;
  final SmartInstrumentMatch? match;
  final InstrumentProfileEntity activeInstrument;
  final TunnerThemePalette palette;
  final VoidCallback onToggleSmartTuning;
  final VoidCallback onToggleAutoSwitch;
  final ValueChanged<SmartInstrumentMatch>? onApplyMatch;
  final VoidCallback? onDismissMatch;
  final VoidCallback? onOpenSelector;
  final bool showWhenInactive;

  const SmartInstrumentBadge({
    super.key,
    required this.isSmartTuningActive,
    required this.autoSwitchEnabled,
    required this.match,
    required this.activeInstrument,
    required this.palette,
    required this.onToggleSmartTuning,
    required this.onToggleAutoSwitch,
    this.onApplyMatch,
    this.onDismissMatch,
    this.onOpenSelector,
    this.showWhenInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSmartTuningActive) {
      if (!showWhenInactive) {
        return const SizedBox.shrink();
      }
      return InkWell(
        key: const Key('smart_instrument_badge_inactive'),
        onTap: onToggleSmartTuning,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, size: 14, color: palette.textMutedColor),
              const SizedBox(width: 5),
              Text(
                'Afinador Inteligente',
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final detectedMatch = match;
    final isMatchingCurrent = detectedMatch != null &&
        detectedMatch.instrument.id == activeInstrument.id;

    final isDifferentSuggestion = detectedMatch != null &&
        detectedMatch.instrument.id != activeInstrument.id;

    final badgeColor = isDifferentSuggestion
        ? const Color(0xFFF59E0B) // Ámbar de sugerencia / adaptación
        : (isMatchingCurrent ? const Color(0xFF10B981) : palette.primaryAccent);

    return Container(
      key: const Key('smart_instrument_badge_active'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggleSmartTuning,
            child: Icon(Icons.auto_awesome, size: 15, color: badgeColor),
          ),
          const SizedBox(width: 6),
          if (detectedMatch == null) ...[
            Text(
              'Escuchando timbre...',
              style: TextStyle(
                color: palette.textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (isDifferentSuggestion) ...[
            Text(
              '¿${detectedMatch.instrument.name}? (${(detectedMatch.confidence * 100).toInt()}%)',
              style: TextStyle(
                color: palette.textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              key: const Key('smart_instrument_adapt_btn'),
              onTap: () => onApplyMatch?.call(detectedMatch),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Adaptar',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (onDismissMatch != null) ...[
              const SizedBox(width: 4),
              InkWell(
                key: const Key('smart_instrument_dismiss_btn'),
                onTap: onDismissMatch,
                child: Icon(Icons.close, size: 14, color: palette.textMutedColor),
              ),
            ],
          ] else ...[
            Text(
              '${detectedMatch.instrument.name} (${(detectedMatch.confidence * 100).toInt()}%)',
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 13, color: badgeColor),
          ],
        ],
      ),
    );
  }
}
