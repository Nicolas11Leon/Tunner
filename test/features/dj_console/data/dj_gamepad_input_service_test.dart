import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_gamepad_input_service.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_controller_profile_entity.dart';

void main() {
  group('DjGamepadInputService Tests', () {
    late DjGamepadInputService service;
    late List<DjAction> triggeredActions;
    late List<String> capturedInputs;

    setUp(() {
      triggeredActions = [];
      capturedInputs = [];
      service = DjGamepadInputService(
        profile: DjControllerProfileEntity.defaultUnified(),
        onActionTriggered: (action) => triggeredActions.add(action),
        onInputCaptured: (token) => capturedInputs.add(token),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('handleInputDown triggers action when input matches profile', () {
      final handled = service.handleInputDown('Xbox_A');
      expect(handled, isTrue);
      expect(triggeredActions, contains(DjAction.deckAPlayPause));
      expect(service.activeHeldInputs, contains('Xbox_A'));

      service.handleInputUp('Xbox_A');
      expect(service.activeHeldInputs, isNot(contains('Xbox_A')));
    });

    test('handleInputDown returns false for unmapped token', () {
      final handled = service.handleInputDown('Unknown_Key_999');
      expect(handled, isFalse);
      expect(triggeredActions, isEmpty);
    });

    test('learn mode captures input tokens instead of executing action', () {
      service.setLearnMode(true);
      expect(service.isLearnModeActive, isTrue);

      final handled = service.handleInputDown('Xbox_X');
      expect(handled, isTrue);
      expect(triggeredActions, isEmpty); // Shouldn't trigger during learn
      expect(capturedInputs, contains('Xbox_X'));
    });

    test('injectGamepadButton works for down and up transitions', () {
      final resDown = service.injectGamepadButton('Xbox_B', isDown: true);
      expect(resDown, isTrue);
      expect(triggeredActions, contains(DjAction.deckBPlayPause));
      expect(service.activeHeldInputs, contains('Xbox_B'));

      final resUp = service.injectGamepadButton('Xbox_B', isDown: false);
      expect(resUp, isTrue);
      expect(service.activeHeldInputs, isNot(contains('Xbox_B')));
    });

    test('bindInput updates service profile mapping dynamically', () {
      service.bindInput('Key_Z', DjAction.crossfaderCenter);
      service.handleInputDown('Key_Z');
      expect(triggeredActions, contains(DjAction.crossfaderCenter));
    });
  });
}
