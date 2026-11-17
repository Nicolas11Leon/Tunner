import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Estado operativo reflejado por el micro-LED de estudio.
enum StudioLedState {
  off,
  active,
  success,
  warning,
  danger,
}

/// Átomo de UI: Micro-indicador LED de Estado de Estudio (StudioStatusLed).
///
/// Sustituye textos recargados y emojis por un punto luminoso de 4px a 8px
/// con halo difuso tenue, emulando la instrumentación de hardware de estudio.
class StudioStatusLed extends StatelessWidget {
  final StudioLedState state;
  final double size;
  final String? label;

  const StudioStatusLed({
    super.key,
    required this.state,
    this.size = 6.0,
    this.label,
  });

  Color _resolveColor(BuildContext context, StudioLedState ledState) {
    final tokens = StudioThemeScope.tokensOf(context);
    switch (ledState) {
      case StudioLedState.off:
        return tokens.borderHairline;
      case StudioLedState.active:
        return tokens.accentPrimary;
      case StudioLedState.success:
        return tokens.accentSuccess;
      case StudioLedState.warning:
        return tokens.accentWarning;
      case StudioLedState.danger:
        return tokens.accentDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final ledColor = _resolveColor(context, state);
    final isGlowing = state != StudioLedState.off;

    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ledColor,
        shape: BoxShape.circle,
        boxShadow: isGlowing
            ? [
                BoxShadow(
                  color: ledColor.withValues(alpha: 0.5),
                  blurRadius: size * 0.8,
                  spreadRadius: 1.0,
                ),
              ]
            : null,
      ),
    );

    if (label == null || label!.isEmpty) {
      return dot;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label!.toUpperCase(),
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
