import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/data/studio_theme_catalog_service.dart';
import 'package:tunner/core/design_system/domain/studio_theme_skin_entity.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';

void main() {
  group('StudioThemeSkinEntity & Presets Tests', () {
    test('canonical skins contain valid IDs and required design tokens', () {
      const skins = [
        StudioThemeSkinEntity.obsidianPro,
        StudioThemeSkinEntity.neve88rs,
        StudioThemeSkinEntity.cyberpunkSynth,
        StudioThemeSkinEntity.nordCrimson,
        StudioThemeSkinEntity.conservatoryIvory,
      ];

      expect(skins.length, equals(5));
      for (final s in skins) {
        expect(s.id.isNotEmpty, isTrue);
        expect(s.name.isNotEmpty, isTrue);
        expect(s.author.isNotEmpty, isTrue);
        expect(s.canvasBackgroundHex, greaterThan(0));
        expect(s.panelBackgroundHex, greaterThan(0));
        expect(s.accentPrimaryHex, greaterThan(0));

        final tokens = s.toDesignTokens();
        expect(tokens, isNotNull);
        expect(tokens.canvasBackground, isNotNull);
        expect(tokens.accentPrimary, isNotNull);
      }
    });

    test('toJson and fromJson preserves skin fidelity and token mapping', () {
      const original = StudioThemeSkinEntity.neve88rs;
      final jsonMap = original.toJson();
      final reconstructed = StudioThemeSkinEntity.fromJson(jsonMap);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.name, equals(original.name));
      expect(reconstructed.accentPrimaryHex, equals(original.accentPrimaryHex));
      expect(reconstructed.borderHairlineHex, equals(original.borderHairlineHex));
    });

    test('StudioDesignTokens presets include canonical studio skins', () {
      final presetIds = StudioDesignTokens.presets.map((p) => p.id).toSet();
      expect(presetIds.contains('skin_obsidian_pro'), isTrue);
      expect(presetIds.contains('skin_neve_88rs'), isTrue);
      expect(presetIds.contains('skin_cyberpunk_synth'), isTrue);
      expect(presetIds.contains('skin_nord_crimson'), isTrue);
      expect(presetIds.contains('skin_conservatory_ivory'), isTrue);
    });
  });

  group('StudioThemeCatalogService Tests', () {
    late StudioThemeCatalogService catalog;

    setUp(() {
      catalog = StudioThemeCatalogService();
      catalog.resetToDefaults();
    });

    test('initial state has default skin and full catalog', () {
      expect(catalog.availableSkins.length, greaterThanOrEqualTo(5));
      expect(catalog.activeSkin.id, equals('skin_obsidian_pro'));
    });

    test('selectSkin updates active skin and notifies listeners', () {
      var notified = false;
      catalog.addListener(() => notified = true);

      catalog.selectSkin('skin_neve_88rs');
      expect(catalog.activeSkin.id, equals('skin_neve_88rs'));
      expect(notified, isTrue);
    });

    test('exportThemeToJson returns formatted valid JSON', () {
      final jsonStr = catalog.exportThemeToJson('skin_cyberpunk_synth');
      expect(jsonStr, isNotNull);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['id'], equals('skin_cyberpunk_synth'));
      expect(decoded['name'], contains('Cyberpunk'));
    });

    test('importThemeFromJson parses, registers, and activates custom skin', () {
      final customSkin = StudioThemeSkinEntity.neve88rs;
      final customMap = customSkin.toJson();
      customMap['id'] = 'custom_analog_gold';
      customMap['name'] = 'Custom Analog Gold';
      final customJsonStr = jsonEncode(customMap);

      final imported = catalog.importThemeFromJson(customJsonStr);
      expect(imported, isNotNull);
      expect(imported.id, equals('custom_analog_gold'));
      expect(catalog.activeSkin.id, equals('custom_analog_gold'));
      expect(catalog.availableSkins.any((s) => s.id == 'custom_analog_gold'), isTrue);
    });
  });
}
