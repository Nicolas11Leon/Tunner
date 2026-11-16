import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/atoms/studio_badge.dart';
import 'package:tunner/core/design_system/atoms/studio_button.dart';
import 'package:tunner/core/design_system/atoms/studio_panel.dart';
import 'package:tunner/core/design_system/atoms/studio_theme_switcher.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';

void main() {
  group('Atomized Studio Design System Tests', () {
    testWidgets('StudioThemeSwitcher swaps tokens independently of functional state',
        (tester) async {
      final controller = StudioThemeController(
        initialTokens: StudioDesignTokens.adobeSpectrumDark,
      );
      addTearDown(controller.dispose);

      int functionalCounter = 42;

      await tester.pumpWidget(
        StudioThemeScope(
          controller: controller,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final tokens = StudioThemeScope.of(context);
                  return StudioPanel(
                    title: 'Studio Inspector',
                    trailing: const StudioThemeSwitcher(),
                    child: Column(
                      children: <Widget>[
                        StudioBadge(label: 'VAL: $functionalCounter'),
                        StudioButton(
                          label: 'Action',
                          onPressed: () => functionalCounter++,
                        ),
                        Container(
                          key: const Key('canvas_probe'),
                          color: tokens.canvasBackground,
                          width: 20,
                          height: 20,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Container probe = tester.widget(find.byKey(const Key('canvas_probe')));
      expect(probe.color, StudioDesignTokens.adobeSpectrumDark.canvasBackground);

      await tester.tap(find.byKey(const Key('studio_theme_switcher_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adobe Light').last);
      await tester.pumpAndSettle();

      probe = tester.widget(find.byKey(const Key('canvas_probe')));
      expect(probe.color, StudioDesignTokens.adobeSpectrumLight.canvasBackground);
      expect(functionalCounter, 42);
    });
  });
}
