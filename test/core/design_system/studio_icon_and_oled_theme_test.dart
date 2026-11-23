import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/atoms/studio_icon.dart';
import 'package:tunner/core/design_system/domain/studio_icon_catalog.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/navigation/presentation/home_dashboard_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  group('UC-174: OLED Monochrome Theme & Progressive StudioIcon System', () {
    test('StudioIconCatalog exposes 44 unique canonical IDs and asset paths', () {
      final specs = StudioIconCatalog.allSpecs;
      expect(specs.length, 44);
      final keys = specs.map((s) => s.id.assetKey).toSet();
      expect(keys.length, 44);
      expect(
        StudioIconCatalog.specFor(StudioIconId.moduleTuner).pngAssetPath,
        'assets/icons/png/module_tuner.png',
      );
      expect(
        StudioIconCatalog.specFor(StudioIconId.moduleTuner).svgAssetPath,
        'assets/icons/svg/module_tuner.svg',
      );
    });

    test('StudioThemeController defaults to OLED Monochrome', () {
      final controller = StudioThemeController();
      expect(controller.tokens.id, 'studio_oled_monochrome');
      expect(controller.tokens.canvasBackground, const Color(0xFF000000));
      expect(controller.tokens.accentPrimary, const Color(0xFFE5E9F0));
    });

    testWidgets('StudioIcon renders PNG when present and falls back when absent',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                StudioIcon(
                  StudioIconId.moduleTuner,
                  size: 20,
                  color: Colors.white,
                ),
                StudioIcon(
                  StudioIconId.modulePianoRoll,
                  size: 20,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.piano), findsOneWidget);
    });

    testWidgets('HomeDashboardScreen renders Pro OLED hub with preserved keys',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vm = TunerViewModel(seedDefaults: false);
      final themeController = StudioThemeController();
      int? navigatedTab;

      await tester.pumpWidget(
        ChangeNotifierProvider<TunerViewModel>.value(
          value: vm,
          child: StudioThemeScope(
            controller: themeController,
            child: MaterialApp(
              home: HomeDashboardScreen(
                onNavigateToTab: (idx) => navigatedTab = idx,
                onOpenTerminal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('home_search_trigger_bar')), findsOneWidget);
      expect(find.byKey(const Key('home_core_audio_hud')), findsOneWidget);
      expect(find.byKey(const Key('card_action_tuner')), findsOneWidget);
      expect(find.byKey(const Key('card_action_dj')), findsOneWidget);
      expect(find.byKey(const Key('template_score_bach')), findsOneWidget);
      expect(find.byKey(const Key('home_quick_mic_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('card_action_tuner')));
      expect(navigatedTab, 1);

      vm.dispose();
    });
  });
}
