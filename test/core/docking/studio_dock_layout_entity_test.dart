import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/docking/domain/studio_dock_layout_entity.dart';
import 'package:tunner/core/docking/domain/studio_dock_zone.dart';
import 'package:tunner/core/docking/domain/studio_panel_descriptor.dart';

void main() {
  group('StudioDockLayoutEntity Unit Tests', () {
    test('defaultLayout initializes center panel and empty side zones', () {
      final layout = StudioDockLayoutEntity.defaultLayout();
      expect(layout.zonePanelIds[StudioDockZone.center], ['dj_console_main']);
      expect(layout.zonePanelIds[StudioDockZone.left], isEmpty);
      expect(layout.zonePanelIds[StudioDockZone.right], isEmpty);
      expect(layout.zonePanelIds[StudioDockZone.bottom], isEmpty);
      expect(layout.zonePanelIds[StudioDockZone.floating], isEmpty);
      expect(layout.findZoneOfPanel('dj_console_main'), StudioDockZone.center);
      expect(layout.findZoneOfPanel('non_existent'), isNull);
    });

    test('movePanel relocates panel without duplication across zones', () {
      final layout = StudioDockLayoutEntity.presetClubClassic();
      expect(layout.findZoneOfPanel('panel_club_mixer'), StudioDockZone.right);

      final moved = layout.movePanel('panel_club_mixer', StudioDockZone.left);
      expect(moved.findZoneOfPanel('panel_club_mixer'), StudioDockZone.left);
      expect(moved.zonePanelIds[StudioDockZone.right], isNot(contains('panel_club_mixer')));
      expect(moved.zonePanelIds[StudioDockZone.left], contains('panel_club_mixer'));
    });

    test('updateRatio clamps split ratios to [0.15, 0.60]', () {
      final layout = StudioDockLayoutEntity.defaultLayout();
      final updated = layout.updateRatio(left: 0.02, right: 0.95, bottom: 0.40);
      expect(updated.leftSplitRatio, 0.15);
      expect(updated.rightSplitRatio, 0.60);
      expect(updated.bottomSplitRatio, 0.40);
    });

    test('presets configure expected dock zones and StudioPanelDescriptor holds pure metadata', () {
      final focus = StudioDockLayoutEntity.presetHardwareFocus();
      expect(focus.bottomSplitRatio, 0.20);
      expect(focus.findZoneOfPanel('panel_hardware_console'), StudioDockZone.center);

      final stems = StudioDockLayoutEntity.presetStemsStudio();
      expect(stems.findZoneOfPanel('panel_club_mixer'), StudioDockZone.left);

      final threeCols = StudioDockLayoutEntity.presetThreeColumns();
      expect(threeCols.findZoneOfPanel('panel_stems_sampler'), StudioDockZone.left);

      const descriptor = StudioPanelDescriptor(
        id: 'panel_hardware_console',
        title: 'Hardware Console',
        isClosable: false,
      );
      expect(descriptor.id, 'panel_hardware_console');
      expect(descriptor.isClosable, isFalse);
    });
  });
}
