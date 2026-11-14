import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_hardware_catalog.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_controller_profile_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_hardware_skin_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_skin_zone_entity.dart';

void main() {
  group('DjSkinZoneEntity Tests', () {
    test('containsNormalized correctly detects boundary hits', () {
      const zone = DjSkinZoneEntity(
        id: 'test_zone',
        label: 'TEST',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.1,
        normalizedY: 0.2,
        normalizedWidth: 0.15,
        normalizedHeight: 0.1,
      );

      // Inside
      expect(zone.containsNormalized(0.15, 0.25), isTrue);
      // Boundary
      expect(zone.containsNormalized(0.1, 0.2), isTrue);
      expect(zone.containsNormalized(0.25, 0.3), isTrue);
      // Outside
      expect(zone.containsNormalized(0.05, 0.25), isFalse);
      expect(zone.containsNormalized(0.15, 0.35), isFalse);
    });

    test('toJson and fromJson preserves all attributes', () {
      const zone = DjSkinZoneEntity(
        id: 'play_a',
        label: 'PLAY',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.05,
        normalizedY: 0.8,
        normalizedWidth: 0.07,
        normalizedHeight: 0.12,
        ledColor: 0xFF00E676,
      );

      final json = zone.toJson();
      final revived = DjSkinZoneEntity.fromJson(json);

      expect(revived.id, equals('play_a'));
      expect(revived.label, equals('PLAY'));
      expect(revived.deckId, equals('deckA'));
      expect(revived.controlType, equals(DjControlType.button));
      expect(revived.action, equals(DjAction.deckAPlayPause));
      expect(revived.normalizedX, closeTo(0.05, 1e-4));
      expect(revived.ledColor, equals(0xFF00E676));
    });
  });

  group('DjHardwareSkinEntity Tests', () {
    test('findZoneById and findZoneAt return matching elements', () {
      const zone1 = DjSkinZoneEntity(
        id: 'z1',
        label: 'Z1',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue1,
        normalizedX: 0.1,
        normalizedY: 0.1,
        normalizedWidth: 0.2,
        normalizedHeight: 0.2,
      );
      const zone2 = DjSkinZoneEntity(
        id: 'z2',
        label: 'Z2',
        controlType: DjControlType.knob,
        action: DjAction.crossfaderCenter,
        normalizedX: 0.5,
        normalizedY: 0.5,
        normalizedWidth: 0.2,
        normalizedHeight: 0.2,
      );

      const skin = DjHardwareSkinEntity(
        id: 'custom_skin',
        name: 'Custom Console',
        manufacturer: 'Tunner Lab',
        zones: [zone1, zone2],
      );

      expect(skin.findZoneById('z1')?.label, equals('Z1'));
      expect(skin.findZoneById('unknown'), isNull);

      expect(skin.findZoneAt(0.15, 0.15)?.id, equals('z1'));
      expect(skin.findZoneAt(0.60, 0.60)?.id, equals('z2'));
      expect(skin.findZoneAt(0.9, 0.9), isNull);

      final cueZones = skin.findZonesByAction(DjAction.deckAHotCue1);
      expect(cueZones.length, equals(1));
      expect(cueZones.first.id, equals('z1'));
    });

    test('withActiveActions lights up corresponding zone LEDs', () {
      const zonePlay = DjSkinZoneEntity(
        id: 'play_a',
        label: 'PLAY',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.1,
        normalizedY: 0.1,
        normalizedWidth: 0.1,
        normalizedHeight: 0.1,
        isLedLit: false,
      );

      const skin = DjHardwareSkinEntity(
        id: 'test_skin',
        name: 'Test',
        manufacturer: 'Test',
        zones: [zonePlay],
      );

      final litSkin = skin.withActiveActions({DjAction.deckAPlayPause});
      expect(litSkin.zones.first.isLedLit, isTrue);

      final unlitSkin = litSkin.withActiveActions({});
      expect(unlitSkin.zones.first.isLedLit, isFalse);
    });

    test('DjHardwareCatalog contains DDJ-FLX4, CDJ-3000, and Traktor S4', () {
      final skins = DjHardwareCatalog.allSkins();
      expect(skins.length, equals(3));

      final flx4 = DjHardwareCatalog.findById('pioneer_ddj_flx4');
      expect(flx4.name, contains('FLX4'));
      expect(flx4.zones.isNotEmpty, isTrue);

      final cdj = DjHardwareCatalog.findById('pioneer_cdj_3000');
      expect(cdj.name, contains('CDJ-3000'));
      expect(cdj.zones.isNotEmpty, isTrue);

      final s4 = DjHardwareCatalog.findById('traktor_kontrol_s4');
      expect(s4.name, contains('Traktor'));
      expect(s4.zones.isNotEmpty, isTrue);

      // Fallback for unknown
      final fallback = DjHardwareCatalog.findById('non_existent');
      expect(fallback.id, equals('pioneer_ddj_flx4'));
    });
  });

  group('DjControllerProfileEntity Tests', () {
    test('defaultUnified profile binds keyboard and xbox inputs', () {
      final profile = DjControllerProfileEntity.defaultUnified();

      // Keyboard bindings
      expect(profile.findAction('Key W'), equals(DjAction.deckAPlayPause));
      expect(profile.findAction('Key I'), equals(DjAction.deckBPlayPause));
      expect(profile.findAction('Key B'), equals(DjAction.crossfaderShiftLeft));

      // Gamepad bindings
      expect(profile.findAction('Xbox_A'), equals(DjAction.deckAPlayPause));
      expect(profile.findAction('Xbox_B'), equals(DjAction.deckBPlayPause));
      expect(profile.findAction('Xbox_LB'), equals(DjAction.deckASync));
      expect(profile.findAction('Xbox_RB'), equals(DjAction.deckBSync));
      expect(profile.findAction('Xbox_LT'), equals(DjAction.deckAFilterSweepLeft));
      expect(profile.findAction('Xbox_RT'), equals(DjAction.deckBFilterSweepRight));
    });

    test('bindInput and unbindInput modify profile immutably', () {
      final initial = DjControllerProfileEntity.defaultXboxGamepad();
      final updated = initial.bindInput('Custom_Button', DjAction.crossfaderHardLeft);

      expect(updated.findAction('Custom_Button'), equals(DjAction.crossfaderHardLeft));
      expect(initial.findAction('Custom_Button'), isNull);

      final unbinded = updated.unbindInput('Custom_Button');
      expect(unbinded.findAction('Custom_Button'), isNull);
    });

    test('profile JSON serialization roundtrip', () {
      final profile = DjControllerProfileEntity.defaultXboxGamepad();
      final json = profile.toJson();
      final revived = DjControllerProfileEntity.fromJson(json);

      expect(revived.id, equals(profile.id));
      expect(revived.deviceType, equals(profile.deviceType));
      expect(revived.findAction('Xbox_A'), equals(DjAction.deckAPlayPause));
    });
  });
}
