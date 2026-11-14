import 'dj_action.dart';

/// Supported controller types.
enum DjControllerDeviceType {
  keyboard,
  gamepadXbox,
  gamepadPlaystation,
  genericGamepad,
}

/// Unified controller profile mapping hardware inputs (Keyboard & Gamepads) to DjActions.
class DjControllerProfileEntity {
  final String id;
  final String name;
  final DjControllerDeviceType deviceType;
  final Map<String, DjAction> inputBindings;

  const DjControllerProfileEntity({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.inputBindings,
  });

  /// Canonical unified profile covering standard QWERTY keyboard and Xbox gamepads.
  factory DjControllerProfileEntity.defaultUnified() {
    return const DjControllerProfileEntity(
      id: 'default_unified_profile',
      name: 'Perfil Universal (Teclado + Xbox Gamepad)',
      deviceType: DjControllerDeviceType.genericGamepad,
      inputBindings: {
        // Keyboard Deck A (Left Hand)
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
        'Key R': DjAction.deckAFilterSweepLeft,
        'Key T': DjAction.deckAFilterSweepRight,
        'Key F': DjAction.deckAToggleDelay,

        // Keyboard Deck B (Right Hand)
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
        'Key Y': DjAction.deckBFilterSweepLeft,
        'Key P': DjAction.deckBFilterSweepRight,
        'Key H': DjAction.deckBToggleDelay,

        // Keyboard Crossfader & Master
        'Key B': DjAction.crossfaderShiftLeft,
        'Key N': DjAction.crossfaderCenter,
        'Key V': DjAction.crossfaderShiftRight,
        'Bracket Left': DjAction.crossfaderHardLeft,
        'Bracket Right': DjAction.crossfaderHardRight,
        'Equal': DjAction.masterVolumeUp,
        'Minus': DjAction.masterVolumeDown,
        'Key G': DjAction.toggleMixRecording,

        // Gamepad Xbox / Playstation mappings
        // Face Buttons
        'Xbox_A': DjAction.deckAPlayPause,
        'Xbox_X': DjAction.deckACue,
        'Xbox_B': DjAction.deckBPlayPause,
        'Xbox_Y': DjAction.deckBCue,

        // Bumpers (Sync)
        'Xbox_LB': DjAction.deckASync,
        'Xbox_RB': DjAction.deckBSync,

        // D-Pad (Pitch fine-nudging)
        'Xbox_Dpad_Up': DjAction.deckAPitchUp,
        'Xbox_Dpad_Down': DjAction.deckAPitchDown,
        'Xbox_Dpad_Left': DjAction.deckBPitchDown,
        'Xbox_Dpad_Right': DjAction.deckBPitchUp,

        // Triggers (Filter Sweeps / FX)
        'Xbox_LT': DjAction.deckAFilterSweepLeft,
        'Xbox_RT': DjAction.deckBFilterSweepRight,

        // Thumbstick Buttons (Crossfader quick-snap)
        'Xbox_LS': DjAction.crossfaderHardLeft,
        'Xbox_RS': DjAction.crossfaderHardRight,
        'Xbox_Select': DjAction.crossfaderCenter,
        'Xbox_Start': DjAction.toggleMixRecording,
      },
    );
  }

  /// Factory for standalone Xbox Gamepad.
  factory DjControllerProfileEntity.defaultXboxGamepad() {
    return const DjControllerProfileEntity(
      id: 'default_xbox_gamepad',
      name: 'Xbox Wireless Controller',
      deviceType: DjControllerDeviceType.gamepadXbox,
      inputBindings: {
        'Xbox_A': DjAction.deckAPlayPause,
        'Xbox_X': DjAction.deckACue,
        'Xbox_B': DjAction.deckBPlayPause,
        'Xbox_Y': DjAction.deckBCue,
        'Xbox_LB': DjAction.deckASync,
        'Xbox_RB': DjAction.deckBSync,
        'Xbox_Dpad_Up': DjAction.deckAPitchUp,
        'Xbox_Dpad_Down': DjAction.deckAPitchDown,
        'Xbox_Dpad_Left': DjAction.deckBPitchDown,
        'Xbox_Dpad_Right': DjAction.deckBPitchUp,
        'Xbox_LT': DjAction.deckAFilterSweepLeft,
        'Xbox_RT': DjAction.deckBFilterSweepRight,
        'Xbox_LS': DjAction.crossfaderHardLeft,
        'Xbox_RS': DjAction.crossfaderHardRight,
        'Xbox_Select': DjAction.crossfaderCenter,
        'Xbox_Start': DjAction.toggleMixRecording,
      },
    );
  }

  /// Binds or updates an action for a given input token.
  DjControllerProfileEntity bindInput(String inputKey, DjAction action) {
    final updated = Map<String, DjAction>.from(inputBindings);
    updated[inputKey] = action;
    return DjControllerProfileEntity(
      id: id,
      name: name,
      deviceType: deviceType,
      inputBindings: updated,
    );
  }

  /// Removes an input binding.
  DjControllerProfileEntity unbindInput(String inputKey) {
    final updated = Map<String, DjAction>.from(inputBindings);
    updated.remove(inputKey);
    return DjControllerProfileEntity(
      id: id,
      name: name,
      deviceType: deviceType,
      inputBindings: updated,
    );
  }

  /// Finds the action tied to an input key if present.
  DjAction? findAction(String inputKey) => inputBindings[inputKey];

  /// Finds all input keys mapped to the given action.
  List<String> findInputsForAction(DjAction action) {
    return inputBindings.entries
        .where((e) => e.value == action)
        .map((e) => e.key)
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceType': deviceType.name,
        'inputBindings':
            inputBindings.map((key, action) => MapEntry(key, action.name)),
      };

  factory DjControllerProfileEntity.fromJson(Map<String, dynamic> json) {
    final rawBindings =
        json['inputBindings'] as Map<String, dynamic>? ?? {};
    final bindings = <String, DjAction>{};
    for (final entry in rawBindings.entries) {
      final action = DjAction.values.firstWhere(
        (a) => a.name == entry.value,
        orElse: () => DjAction.deckAPlayPause,
      );
      bindings[entry.key] = action;
    }

    return DjControllerProfileEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceType: DjControllerDeviceType.values.firstWhere(
        (t) => t.name == json['deviceType'],
        orElse: () => DjControllerDeviceType.genericGamepad,
      ),
      inputBindings: bindings,
    );
  }
}
