import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';

class FakePitchDetectorService implements IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;

  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class FakeMetronomeService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TunnerThemePalette - Domain & Presets Tests', () {
    test('All 7 curated presets are defined with valid IDs and contrast tokens', () {
      expect(TunnerThemePalette.allPresets.length, 7);

      final ids = TunnerThemePalette.allPresets.map((p) => p.id).toSet();
      expect(ids.length, 7, reason: 'All preset IDs must be unique');

      for (final p in TunnerThemePalette.allPresets) {
        expect(p.displayName.isNotEmpty, isTrue);
        expect(p.isCustom, isFalse);
        expect(p.scaffoldBackground.a, 1.0);
        expect(p.staffBackground.a, 1.0);
        expect(p.primaryAccent.a, 1.0);
        expect(p.secondaryAccent.a, 1.0);
        expect(p.surfaceBorderColor.a, greaterThan(0.0));
        expect(p.surfaceHighlightColor.a, greaterThan(0.0));
      }
    });

    test('Obsidian Studio has dark brightness and acoustic emerald accents', () {
      final p = TunnerThemePalette.obsidianStudio;
      expect(p.id, 'obsidian_studio');
      expect(p.mode, TunnerThemeMode.obsidianStudio);
      expect(p.brightness, Brightness.dark);
      expect(p.primaryAccent, const Color(0xFF00E676));
    });

    test('OLED Pure Black has pure black scaffold and staff backgrounds', () {
      final p = TunnerThemePalette.oledPureBlack;
      expect(p.id, 'oled_pure_black');
      expect(p.scaffoldBackground, Colors.black);
      expect(p.staffBackground, Colors.black);
      expect(p.brightness, Brightness.dark);
    });

    test('Nordic Frost has light brightness and crisp dark text', () {
      final p = TunnerThemePalette.nordicFrost;
      expect(p.id, 'nordic_frost');
      expect(p.brightness, Brightness.light);
      expect(p.textColor, const Color(0xFF0F172A));
      expect(p.onPrimaryColor, const Color(0xFFFFFFFF));
    });

    test('fromMode correctly maps all legacy enum values', () {
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.obsidianStudio).id, 'obsidian_studio');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.oledPureBlack).id, 'oled_pure_black');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.royalSymphony).id, 'royal_symphony');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.acousticWood).id, 'acoustic_wood');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.neonStage).id, 'neon_stage');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.vintageParchment).id, 'vintage_parchment');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.nordicFrost).id, 'nordic_frost');
      expect(TunnerThemePalette.fromMode(TunnerThemeMode.custom).id, 'obsidian_studio');
    });

    test('createCustom creates valid palettes for all 4 base tones', () {
      final oledCustom = TunnerThemePalette.createCustom(
        name: 'Mi OLED Neón',
        baseStyle: 'oled',
        primaryAccent: const Color(0xFFFF007F),
      );
      expect(oledCustom.isCustom, isTrue);
      expect(oledCustom.scaffoldBackground, Colors.black);
      expect(oledCustom.primaryAccent, const Color(0xFFFF007F));

      final woodCustom = TunnerThemePalette.createCustom(
        name: 'Mi Palisandro',
        baseStyle: 'wood',
        primaryAccent: const Color(0xFFF59E0B),
      );
      expect(woodCustom.isCustom, isTrue);
      expect(woodCustom.scaffoldBackground, const Color(0xFF1B1410));

      final lightCustom = TunnerThemePalette.createCustom(
        name: 'Mi Conservatorio Claro',
        baseStyle: 'light',
        primaryAccent: const Color(0xFF2563EB),
      );
      expect(lightCustom.isCustom, isTrue);
      expect(lightCustom.brightness, Brightness.light);

      final darkCustom = TunnerThemePalette.createCustom(
        name: 'Mi Estudio Grafito',
        baseStyle: 'dark',
        primaryAccent: const Color(0xFFA855F7),
      );
      expect(darkCustom.isCustom, isTrue);
      expect(darkCustom.brightness, Brightness.dark);
    });

    test('copyWith modifies targeted attributes while preserving others', () {
      final original = TunnerThemePalette.obsidianStudio;
      final modified = original.copyWith(
        displayName: 'Obsidian Modificado',
        primaryAccent: const Color(0xFFE040FB),
      );

      expect(modified.displayName, 'Obsidian Modificado');
      expect(modified.primaryAccent, const Color(0xFFE040FB));
      expect(modified.scaffoldBackground, original.scaffoldBackground);
      expect(modified.staffBackground, original.staffBackground);
    });

    test('toJson and fromJson provide lossless round-trip serialization', () {
      final custom = TunnerThemePalette.createCustom(
        name: 'Estudio Púrpura',
        baseStyle: 'dark',
        primaryAccent: const Color(0xFFA855F7),
        secondaryAccent: const Color(0xFFFFD54F),
      );

      final jsonMap = custom.toJson();
      final serialized = jsonEncode(jsonMap);
      final deserialized = jsonDecode(serialized) as Map<String, dynamic>;

      final restored = TunnerThemePalette.fromJson(deserialized);

      expect(restored.displayName, custom.displayName);
      expect(restored.isCustom, isTrue);
      expect(restored.brightness, custom.brightness);
      expect(restored.scaffoldBackground.toARGB32(), custom.scaffoldBackground.toARGB32());
      expect(restored.primaryAccent.toARGB32(), custom.primaryAccent.toARGB32());
      expect(restored.secondaryAccent.toARGB32(), custom.secondaryAccent.toARGB32());
    });
  });

  group('TunerViewModel - Theme Management State Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: FakePitchDetectorService(),
        metronomeService: FakeMetronomeService(),
      );
    });

    test('Initializes with Obsidian Studio as default theme', () {
      expect(viewModel.currentPalette.id, 'obsidian_studio');
      expect(viewModel.themeMode, TunnerThemeMode.obsidianStudio);
      expect(viewModel.availablePalettes.length, 7);
      expect(viewModel.customPalettes.isEmpty, isTrue);
    });

    test('setPalette updates active palette and notifies listeners', () {
      bool notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setPalette(TunnerThemePalette.royalSymphony);

      expect(viewModel.currentPalette.id, 'royal_symphony');
      expect(viewModel.themeMode, TunnerThemeMode.royalSymphony);
      expect(notified, isTrue);
    });

    test('addCustomPalette registers theme, selects it and exposes it in availablePalettes', () {
      final custom = TunnerThemePalette.createCustom(
        name: 'Jazz Club Nocturno',
        baseStyle: 'wood',
        primaryAccent: const Color(0xFFFFB300),
      );

      viewModel.addCustomPalette(custom);

      expect(viewModel.customPalettes.length, 1);
      expect(viewModel.availablePalettes.length, 8);
      expect(viewModel.currentPalette.displayName, 'Jazz Club Nocturno');
      expect(viewModel.currentPalette.isCustom, isTrue);
    });

    test('updateCustomPalette replaces theme and updates active palette if selected', () {
      final custom = TunnerThemePalette.createCustom(
        name: 'Beta Theme',
        baseStyle: 'dark',
        primaryAccent: const Color(0xFF00F0FF),
      );
      viewModel.addCustomPalette(custom);

      final updated = custom.copyWith(displayName: 'Release Theme');
      viewModel.updateCustomPalette(updated);

      expect(viewModel.currentPalette.displayName, 'Release Theme');
      expect(viewModel.customPalettes.first.displayName, 'Release Theme');
    });

    test('deleteCustomPalette removes theme and falls back to Obsidian Studio if active', () {
      final custom = TunnerThemePalette.createCustom(
        name: 'Tema Temporal',
        baseStyle: 'oled',
        primaryAccent: const Color(0xFFFF0055),
      );
      viewModel.addCustomPalette(custom);
      expect(viewModel.currentPalette.id, custom.id);

      viewModel.deleteCustomPalette(custom.id);

      expect(viewModel.customPalettes.isEmpty, isTrue);
      expect(viewModel.availablePalettes.length, 7);
      expect(viewModel.currentPalette.id, 'obsidian_studio');
    });

    test('importPaletteFromJson successfully loads and activates valid JSON', () {
      final custom = TunnerThemePalette.createCustom(
        name: 'Importado de Amigo',
        baseStyle: 'light',
        primaryAccent: const Color(0xFF2563EB),
      );
      final jsonStr = jsonEncode(custom.toJson());

      final result = viewModel.importPaletteFromJson(jsonStr);

      expect(result, isTrue);
      expect(viewModel.currentPalette.displayName, 'Importado de Amigo');
      expect(viewModel.customPalettes.length, 1);
    });

    test('importPaletteFromJson gracefully rejects malformed string', () {
      final result = viewModel.importPaletteFromJson('{esto no es un json valido}');
      expect(result, isFalse);
    });
  });
}
