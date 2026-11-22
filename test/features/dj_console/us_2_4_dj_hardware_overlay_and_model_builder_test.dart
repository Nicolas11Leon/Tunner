import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_console_blueprint_storage_service.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_console_blueprint_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_hardware_catalog.dart';
import 'package:tunner/features/dj_console/domain/dj_hardware_skin_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_keymap_profile_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_skin_zone_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_hardware_console_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-2.4: Hardware Overlay, Controles Continuos y Model Builder', () {
    late DjConsoleViewModel viewModel;

    setUp(() {
      viewModel = DjConsoleViewModel();
      DjHardwareCatalog.clearCustomSkins();
    });

    tearDown(() {
      viewModel.dispose();
      DjHardwareCatalog.clearCustomSkins();
    });

    test('getControlValue calcula valores normalizados para faders, knobs y jogs', () {
      // 1. Crossfader: default position = 0.0 -> normalized 0.5
      const crossfaderZone = DjSkinZoneEntity(
        id: 'ddj_flx4_crossfader',
        label: 'X-FADER',
        controlType: DjControlType.fader,
        action: DjAction.crossfaderCenter,
        normalizedX: 0.40,
        normalizedY: 0.85,
        normalizedWidth: 0.20,
        normalizedHeight: 0.09,
      );
      expect(viewModel.getControlValue(crossfaderZone), closeTo(0.5, 0.01));

      viewModel.setCrossfaderPosition(-1.0);
      expect(viewModel.getControlValue(crossfaderZone), closeTo(0.0, 0.01));

      viewModel.setCrossfaderPosition(1.0);
      expect(viewModel.getControlValue(crossfaderZone), closeTo(1.0, 0.01));

      // 2. Channel Fader Deck A
      const chFaderAZone = DjSkinZoneEntity(
        id: 'ddj_flx4_ch_fader_a',
        label: 'CH 1',
        deckId: 'deckA',
        controlType: DjControlType.fader,
        action: DjAction.deckAToggleDelay,
        normalizedX: 0.41,
        normalizedY: 0.55,
        normalizedWidth: 0.035,
        normalizedHeight: 0.22,
      );
      viewModel.setDeckVolume('A', 0.8);
      expect(viewModel.getControlValue(chFaderAZone), closeTo(0.8, 0.01));

      // 3. Filter Knob Deck A (bipolar [-1.0, 1.0] -> [0.0, 1.0])
      const filterZone = DjSkinZoneEntity(
        id: 'ddj_flx4_filter_a',
        label: 'FILTER A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAFilterSweepRight,
        normalizedX: 0.40,
        normalizedY: 0.42,
        normalizedWidth: 0.05,
        normalizedHeight: 0.09,
      );
      viewModel.setChannelFilter('A', 0.0);
      expect(viewModel.getControlValue(filterZone), closeTo(0.5, 0.01));

      viewModel.setChannelFilter('A', -1.0);
      expect(viewModel.getControlValue(filterZone), closeTo(0.0, 0.01));

      // 4. EQ Low Knob Deck A ([0.0, 1.5] -> [0.0, 1.0])
      const eqLowZone = DjSkinZoneEntity(
        id: 'ddj_flx4_eq_a_low',
        label: 'LOW A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAKillLow,
        normalizedX: 0.40,
        normalizedY: 0.30,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
      );
      viewModel.setEqGains('A', low: 1.5);
      expect(viewModel.getControlValue(eqLowZone), closeTo(1.0, 0.01));

      viewModel.setEqGains('A', low: 0.0);
      expect(viewModel.getControlValue(eqLowZone), closeTo(0.0, 0.01));
    });

    test('updateContinuousControl muta suavemente parametros acusticos', () {
      const crossfaderZone = DjSkinZoneEntity(
        id: 'ddj_flx4_crossfader',
        label: 'X-FADER',
        controlType: DjControlType.fader,
        action: DjAction.crossfaderCenter,
        normalizedX: 0.40,
        normalizedY: 0.85,
        normalizedWidth: 0.20,
        normalizedHeight: 0.09,
      );

      viewModel.setCrossfaderPosition(0.0);
      // Arrastre hacia la derecha (+0.2 delta)
      viewModel.updateContinuousControl(crossfaderZone, 0.2);
      expect(viewModel.crossfader.position, closeTo(0.4, 0.05));

      // Arrastre en channel fader A (arrastrar hacia arriba = -delta)
      const chFaderAZone = DjSkinZoneEntity(
        id: 'ddj_flx4_ch_fader_a',
        label: 'CH 1',
        deckId: 'deckA',
        controlType: DjControlType.fader,
        action: DjAction.deckAToggleDelay,
        normalizedX: 0.41,
        normalizedY: 0.55,
        normalizedWidth: 0.035,
        normalizedHeight: 0.22,
      );
      viewModel.setDeckVolume('A', 0.5);
      viewModel.updateContinuousControl(chFaderAZone, -0.2); // arrastre arriba
      expect(viewModel.deckA.volume, closeTo(0.7, 0.05));

      // Arrastre en filtro bipolar Deck A
      const filterZone = DjSkinZoneEntity(
        id: 'ddj_flx4_filter_a',
        label: 'FILTER A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAFilterSweepRight,
        normalizedX: 0.40,
        normalizedY: 0.42,
        normalizedWidth: 0.05,
        normalizedHeight: 0.09,
      );
      viewModel.setChannelFilter('A', 0.0);
      viewModel.updateContinuousControl(filterZone, -0.2);
      expect(viewModel.fxA.filterPosition, closeTo(0.4, 0.05));
    });

    test('DjHardwareConsolePainter renderiza sin errores con getControlValue reactivo', () {
      final skin = DjHardwareCatalog.ddjFlx4();
      final painter = DjHardwareConsolePainter(
        skin: skin,
        jogRotationA: 0.45,
        jogRotationB: 1.20,
        getControlValue: (zone) => viewModel.getControlValue(zone),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(800, 480);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('Blueprint persistido en StorageService se registra en DjHardwareCatalog', () async {
      final storage = DjConsoleBlueprintStorageService(
        documentsPathProvider: () async => Directory.systemTemp.path,
      );
      const uniqueSkinId = 'emulated_custom_controller_12345';

      final blueprint = DjConsoleBlueprintEntity(
        id: uniqueSkinId,
        name: 'Custom Controller Pro',
        manufacturer: 'Numark Custom',
        aspectRatio: 1.8,
        chassisColor: 0xFF1A1A24,
        zones: const [
          DjSkinZoneEntity(
            id: 'zone_custom_play',
            label: 'PLAY',
            deckId: 'deckA',
            controlType: DjControlType.button,
            action: DjAction.deckAPlayPause,
            normalizedX: 0.1,
            normalizedY: 0.8,
            normalizedWidth: 0.08,
            normalizedHeight: 0.12,
          ),
        ],
        keyBindings: const {
          'Key W': DjAction.deckAPlayPause,
        },
      );

      await storage.saveBlueprint(blueprint);

      final skin = DjHardwareSkinEntity(
        id: blueprint.id,
        name: blueprint.name,
        manufacturer: blueprint.manufacturer,
        aspectRatio: blueprint.aspectRatio,
        chassisColor: blueprint.chassisColor,
        zones: blueprint.zones,
      );
      DjHardwareCatalog.registerCustomSkin(skin);

      final foundSkin = DjHardwareCatalog.findById(uniqueSkinId);
      expect(foundSkin.id, equals(uniqueSkinId));
      expect(foundSkin.name, equals('Custom Controller Pro'));

      // Verificar Keymap profile badge
      final keymap = DjKeymapProfileEntity(
        id: 'keymap_$uniqueSkinId',
        name: 'Mapeo Custom',
        keyBindings: blueprint.keyBindings,
      );
      expect(keymap.findKeyBadgeForAction(DjAction.deckAPlayPause), equals('W'));
    });
  });
}
