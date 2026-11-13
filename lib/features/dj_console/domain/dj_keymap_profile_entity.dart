import 'dj_action.dart';

/// Represents a mapping between physical keyboard keys and virtual DJ actions.
class DjKeymapProfileEntity {
  final String id;
  final String name;

  /// Map of physical key identifier (e.g. 'Key W', 'Key Q', 'Space') to DjAction.
  final Map<String, DjAction> keyBindings;

  const DjKeymapProfileEntity({
    required this.id,
    required this.name,
    required this.keyBindings,
  });

  /// Canonical ergonomic default keymap inspired by industry software (VirtualDJ / Traktor).
  ///
  /// Left hand controls Deck A, right hand controls Deck B, center controls Crossfader.
  factory DjKeymapProfileEntity.defaultErgonomic() {
    return const DjKeymapProfileEntity(
      id: 'default_ergonomic',
      name: 'Default Ergonomico (QWERTY)',
      keyBindings: {
        // Deck A Controls (Left hand)
        'Key W': DjAction.deckAPlayPause,
        'Key Q': DjAction.deckACue,
        'Key E': DjAction.deckASync,
        'Key A': DjAction.deckAPitchDown,
        'Key S': DjAction.deckAPitchUp,
        'Key D': DjAction.deckAPitchReset,
        'Digit 1': DjAction.deckAHotCue1,
        'Digit 2': DjAction.deckAHotCue2,
        'Digit 3': DjAction.deckAHotCue3,
        'Digit 4': DjAction.deckAHotCue4,
        'Key Z': DjAction.deckAKillLow,
        'Key X': DjAction.deckAKillMid,
        'Key C': DjAction.deckAKillHigh,

        // Deck B Controls (Right hand)
        'Key I': DjAction.deckBPlayPause,
        'Key U': DjAction.deckBCue,
        'Key O': DjAction.deckBSync,
        'Key J': DjAction.deckBPitchDown,
        'Key K': DjAction.deckBPitchUp,
        'Key L': DjAction.deckBPitchReset,
        'Digit 7': DjAction.deckBHotCue1,
        'Digit 8': DjAction.deckBHotCue2,
        'Digit 9': DjAction.deckBHotCue3,
        'Digit 0': DjAction.deckBHotCue4,
        'Key M': DjAction.deckBKillLow,
        'Comma': DjAction.deckBKillMid,
        'Period': DjAction.deckBKillHigh,

        // Crossfader Controls
        'Key B': DjAction.crossfaderShiftLeft,
        'Key N': DjAction.crossfaderCenter,
        'Key V': DjAction.crossfaderShiftRight,
        'Bracket Left': DjAction.crossfaderHardLeft,
        'Bracket Right': DjAction.crossfaderHardRight,

        // Master Volume
        'Equal': DjAction.masterVolumeUp,
        'Minus': DjAction.masterVolumeDown,
      },
    );
  }

  /// Binds or replaces an action for the specified key.
  DjKeymapProfileEntity bindKey(String keyLabel, DjAction action) {
    final updated = Map<String, DjAction>.from(keyBindings);
    updated[keyLabel] = action;
    return DjKeymapProfileEntity(
      id: id,
      name: name,
      keyBindings: updated,
    );
  }

  /// Removes an existing key binding.
  DjKeymapProfileEntity unbindKey(String keyLabel) {
    final updated = Map<String, DjAction>.from(keyBindings);
    updated.remove(keyLabel);
    return DjKeymapProfileEntity(
      id: id,
      name: name,
      keyBindings: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'keyBindings': keyBindings.map((key, action) => MapEntry(key, action.name)),
    };
  }

  factory DjKeymapProfileEntity.fromJson(Map<String, dynamic> json) {
    final rawBindings = json['keyBindings'] as Map<String, dynamic>? ?? {};
    final bindings = <String, DjAction>{};
    for (final entry in rawBindings.entries) {
      try {
        final action = DjAction.values.byName(entry.value.toString());
        bindings[entry.key] = action;
      } catch (_) {
        // Ignore unrecognized action safely
      }
    }
    return DjKeymapProfileEntity(
      id: json['id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Personalizado',
      keyBindings: bindings,
    );
  }
}
