import 'package:flutter/material.dart';

import '../../domain/dj_action.dart';
import '../../domain/dj_deck_entity.dart';

/// Grilla reutilizable de 4 pads Hot Cue compartida entre [DjConsoleModal] y [DjStudioWorkstationView].
class DjHotCuePadGrid extends StatelessWidget {
  final String deckId;
  final DjDeckEntity deck;
  final Color accentColor;
  final Color inactiveTextColor;
  final Color inactiveBorderColor;
  final DjAction? momentaryLitAction;
  final void Function(int slotIndex) onTriggerHotCue;
  final void Function(int slotIndex) onClearHotCue;
  final double verticalPadding;
  final double fontSize;
  final bool compactMinimumSize;

  const DjHotCuePadGrid({
    super.key,
    required this.deckId,
    required this.deck,
    required this.accentColor,
    required this.onTriggerHotCue,
    required this.onClearHotCue,
    this.momentaryLitAction,
    this.inactiveTextColor = Colors.white54,
    this.inactiveBorderColor = Colors.white12,
    this.verticalPadding = 6,
    this.fontSize = 10,
    this.compactMinimumSize = true,
  });

  @override
  Widget build(BuildContext context) {
    final actions = deckId == 'A'
        ? const [DjAction.deckAHotCue1, DjAction.deckAHotCue2, DjAction.deckAHotCue3, DjAction.deckAHotCue4]
        : const [DjAction.deckBHotCue1, DjAction.deckBHotCue2, DjAction.deckBHotCue3, DjAction.deckBHotCue4];

    return Row(
      children: List.generate(4, (idx) {
        final isSet = deck.hotCues[idx] != null || deck.hotCues[idx + 1] != null;
        final isHotCuePushed = momentaryLitAction == actions[idx];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: idx < 3 ? 4 : 0),
            child: OutlinedButton(
              key: Key('deck_${deckId}_hotcue_$idx'),
              onPressed: () => onTriggerHotCue(idx),
              onLongPress: () => onClearHotCue(idx),
              style: OutlinedButton.styleFrom(
                backgroundColor: isHotCuePushed
                    ? accentColor
                    : (isSet ? accentColor.withValues(alpha: 0.35) : Colors.transparent),
                side: BorderSide(
                  color: isHotCuePushed
                      ? Colors.white
                      : (isSet ? accentColor : inactiveBorderColor),
                  width: isHotCuePushed ? 2.0 : 1.0,
                ),
                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                minimumSize: compactMinimumSize ? Size.zero : null,
              ),
              child: Text(
                '${idx + 1}',
                style: TextStyle(
                  color: isHotCuePushed
                      ? Colors.black
                      : (isSet ? accentColor : inactiveTextColor),
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
