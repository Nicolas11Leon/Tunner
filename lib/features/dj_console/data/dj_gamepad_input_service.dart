import 'dart:async';
import '../domain/dj_action.dart';
import '../domain/dj_controller_profile_entity.dart';

/// Callback when an action is triggered by any input device.
typedef DjActionTriggerCallback = void Function(DjAction action);

/// Callback when in Learn Mode and an input token is captured.
typedef DjInputCapturedCallback = void Function(String inputToken);

/// Ingests hardware inputs (Keyboard, Xbox/PS gamepads) and triggers DJ actions.
class DjGamepadInputService {
  DjControllerProfileEntity _profile;
  DjActionTriggerCallback? onActionTriggered;
  DjInputCapturedCallback? onInputCaptured;
  bool _isLearnModeActive = false;

  final _activeHeldInputs = <String>{};
  final _inputEventStreamController = StreamController<String>.broadcast();

  DjGamepadInputService({
    DjControllerProfileEntity? profile,
    this.onActionTriggered,
    this.onInputCaptured,
  }) : _profile = profile ?? DjControllerProfileEntity.defaultUnified();

  DjControllerProfileEntity get profile => _profile;
  bool get isLearnModeActive => _isLearnModeActive;
  Set<String> get activeHeldInputs => Set.unmodifiable(_activeHeldInputs);
  Stream<String> get inputEvents => _inputEventStreamController.stream;

  /// Updates active controller profile.
  void setProfile(DjControllerProfileEntity newProfile) {
    _profile = newProfile;
  }

  /// Sets Learn Mode state.
  void setLearnMode(bool active) {
    _isLearnModeActive = active;
  }

  /// Handles incoming physical input tokens (e.g. 'Key W', 'Xbox_A', 'Xbox_LT').
  bool handleInputDown(String inputToken) {
    _activeHeldInputs.add(inputToken);
    _inputEventStreamController.add(inputToken);

    if (_isLearnModeActive) {
      onInputCaptured?.call(inputToken);
      return true;
    }

    final action = _profile.findAction(inputToken);
    if (action != null) {
      onActionTriggered?.call(action);
      return true;
    }
    return false;
  }

  /// Handles input release for continuous/held inputs.
  void handleInputUp(String inputToken) {
    _activeHeldInputs.remove(inputToken);
  }

  /// Simulates or injects a gamepad button press event (e.g. Xbox Controller button).
  bool injectGamepadButton(String buttonCode, {bool isDown = true}) {
    if (isDown) {
      return handleInputDown(buttonCode);
    } else {
      handleInputUp(buttonCode);
      return true;
    }
  }

  /// Maps an input token to a given DJ action and updates profile.
  void bindInput(String inputToken, DjAction action) {
    _profile = _profile.bindInput(inputToken, action);
  }

  /// Disposes internal streams.
  void dispose() {
    _inputEventStreamController.close();
  }
}
