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

  /// VirtualDJ Standard club-style offline layout.
  factory DjKeymapProfileEntity.virtualDjStandard() {
    return const DjKeymapProfileEntity(
      id: 'virtualdj_standard',
      name: 'VirtualDJ Estándar',
      keyBindings: {
        // Deck A
        'Space': DjAction.deckAPlayPause,
        'Key C': DjAction.deckACue,
        'Key F': DjAction.deckASync,
        'Digit 1': DjAction.deckAHotCue1,
        'Digit 2': DjAction.deckAHotCue2,
        'Digit 3': DjAction.deckAHotCue3,
        'Digit 4': DjAction.deckAHotCue4,
        'Key Q': DjAction.deckAPitchUp,
        'Key A': DjAction.deckAPitchDown,
        'Key Z': DjAction.deckAKillLow,
        'Key X': DjAction.deckAKillMid,

        // Deck B
        'Enter': DjAction.deckBPlayPause,
        'Key M': DjAction.deckBCue,
        'Key J': DjAction.deckBSync,
        'Digit 7': DjAction.deckBHotCue1,
        'Digit 8': DjAction.deckBHotCue2,
        'Digit 9': DjAction.deckBHotCue3,
        'Digit 0': DjAction.deckBHotCue4,
        'Key P': DjAction.deckBPitchUp,
        'Key L': DjAction.deckBPitchDown,
        'Period': DjAction.deckBKillLow,
        'Slash': DjAction.deckBKillMid,

        // Crossfader
        'Key B': DjAction.crossfaderShiftLeft,
        'Key N': DjAction.crossfaderCenter,
        'Key V': DjAction.crossfaderShiftRight,
      },
    );
  }

  /// Serato DJ Pro standard offline keyboard shortcut profile.
  factory DjKeymapProfileEntity.seratoDjStandard() {
    return const DjKeymapProfileEntity(
      id: 'serato_dj_standard',
      name: 'Serato DJ Pro Estándar',
      keyBindings: {
        // Deck A
        'Key D': DjAction.deckACue,
        'Key W': DjAction.deckASync,
        'Key S': DjAction.deckAPlayPause,
        'Digit 1': DjAction.deckAHotCue1,
        'Digit 2': DjAction.deckAHotCue2,
        'Digit 3': DjAction.deckAHotCue3,
        'Digit 4': DjAction.deckAHotCue4,
        'Key T': DjAction.deckAPitchUp,
        'Key G': DjAction.deckAPitchDown,

        // Deck B
        'Key K': DjAction.deckBCue,
        'Key O': DjAction.deckBSync,
        'Key L': DjAction.deckBPlayPause,
        'Digit 6': DjAction.deckBHotCue1,
        'Digit 7': DjAction.deckBHotCue2,
        'Digit 8': DjAction.deckBHotCue3,
        'Digit 9': DjAction.deckBHotCue4,
        'Key Y': DjAction.deckBPitchUp,
        'Key H': DjAction.deckBPitchDown,

        // Crossfader
        'Bracket Left': DjAction.crossfaderShiftLeft,
        'Bracket Right': DjAction.crossfaderShiftRight,
        'Backslash': DjAction.crossfaderCenter,
      },
    );
  }

  /// Traktor Pro standard ergonomic keyboard profile.
  factory DjKeymapProfileEntity.traktorProStandard() {
    return const DjKeymapProfileEntity(
      id: 'traktor_pro_standard',
      name: 'Traktor Pro 3 Estándar',
      keyBindings: {
        'Key Q': DjAction.deckACue,
        'Key W': DjAction.deckAPlayPause,
        'Key E': DjAction.deckASync,
        'Digit 1': DjAction.deckAHotCue1,
        'Digit 2': DjAction.deckAHotCue2,
        'Digit 3': DjAction.deckAHotCue3,
        'Digit 4': DjAction.deckAHotCue4,
        'Key A': DjAction.deckAPitchDown,
        'Key S': DjAction.deckAPitchUp,
        'Key Z': DjAction.deckAKillLow,
        'Key X': DjAction.deckAKillMid,
        'Key C': DjAction.deckAKillHigh,

        'Key U': DjAction.deckBCue,
        'Key I': DjAction.deckBPlayPause,
        'Key O': DjAction.deckBSync,
        'Digit 7': DjAction.deckBHotCue1,
        'Digit 8': DjAction.deckBHotCue2,
        'Digit 9': DjAction.deckBHotCue3,
        'Digit 0': DjAction.deckBHotCue4,
        'Key J': DjAction.deckBPitchDown,
        'Key K': DjAction.deckBPitchUp,
        'Key M': DjAction.deckBKillLow,
        'Comma': DjAction.deckBKillMid,
        'Period': DjAction.deckBKillHigh,

        'Key B': DjAction.crossfaderShiftLeft,
        'Key N': DjAction.crossfaderCenter,
        'Key V': DjAction.crossfaderShiftRight,
      },
    );
  }

  /// All factory built-in industry keymap profiles.
  static List<DjKeymapProfileEntity> factoryProfiles() => [
        DjKeymapProfileEntity.defaultErgonomic(),
        DjKeymapProfileEntity.virtualDjStandard(),
        DjKeymapProfileEntity.seratoDjStandard(),
        DjKeymapProfileEntity.traktorProStandard(),
      ];

  /// Cleans a raw key label (e.g. 'Key W' -> 'W', 'Digit 1' -> '1', 'Space' -> 'SPACE').
  static String cleanKeyLabel(String key) {
    if (key.startsWith('Key ')) return key.substring(4);
    if (key.startsWith('Digit ')) return key.substring(6);
    if (key == 'Space' || key == ' ') return 'SPACE';
    if (key == 'Enter' || key == '\n') return 'ENTER';
    if (key == 'Tab') return 'TAB';
    if (key == 'Bracket Left') return '[';
    if (key == 'Bracket Right') return ']';
    if (key == 'Comma') return ',';
    if (key == 'Period') return '.';
    if (key == 'Slash') return '/';
    if (key == 'Backslash') return r'\';
    if (key == 'Minus') return '-';
    if (key == 'Equal') return '=';
    return key.toUpperCase();
  }

  /// Resolves an action for a given key string, handling various casing/prefix variants.
  DjAction? resolveAction(String token) {
    if (keyBindings.containsKey(token)) {
      return keyBindings[token];
    }
    final upper = token.toUpperCase();
    if (keyBindings.containsKey(upper)) {
      return keyBindings[upper];
    }
    final keyVariant = 'Key $upper';
    if (keyBindings.containsKey(keyVariant)) {
      return keyBindings[keyVariant];
    }
    final digitVariant = 'Digit $token';
    if (keyBindings.containsKey(digitVariant)) {
      return keyBindings[digitVariant];
    }
    for (final entry in keyBindings.entries) {
      if (cleanKeyLabel(entry.key) == cleanKeyLabel(token)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Finds the primary display badge for a given action (e.g. 'W' or 'SPACE').
  String? findKeyBadgeForAction(DjAction action) {
    for (final entry in keyBindings.entries) {
      if (entry.value == action) {
        return cleanKeyLabel(entry.key);
      }
    }
    return null;
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
