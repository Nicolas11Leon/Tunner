import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/instrument/domain/smart_instrument_detector.dart';
import 'package:tunner/features/instrument/presentation/widgets/smart_instrument_badge.dart';

void main() {
  const palette = TunnerThemePalette.obsidianStudio;

  group('SmartInstrumentBadge Widget Tests', () {
    testWidgets('Renders inactive state and triggers onToggleSmartTuning', (tester) async {
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartInstrumentBadge(
              isSmartTuningActive: false,
              autoSwitchEnabled: false,
              match: null,
              activeInstrument: InstrumentProfileEntity.flute,
              palette: palette,
              showWhenInactive: true,
              onToggleSmartTuning: () => toggled = true,
              onToggleAutoSwitch: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('smart_instrument_badge_inactive')), findsOneWidget);
      expect(find.text('Afinador Inteligente'), findsOneWidget);

      await tester.tap(find.byKey(const Key('smart_instrument_badge_inactive')));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });

    testWidgets('Renders listening state when active without match', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartInstrumentBadge(
              isSmartTuningActive: true,
              autoSwitchEnabled: false,
              match: null,
              activeInstrument: InstrumentProfileEntity.flute,
              palette: palette,
              onToggleSmartTuning: () {},
              onToggleAutoSwitch: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('smart_instrument_badge_active')), findsOneWidget);
      expect(find.text('Escuchando timbre...'), findsOneWidget);
    });

    testWidgets('Renders suggestion chip when detected match differs from active instrument', (tester) async {
      SmartInstrumentMatch? appliedMatch;
      bool dismissed = false;

      const detectedMatch = SmartInstrumentMatch(
        instrument: InstrumentProfileEntity.bbTrumpet,
        confidence: 0.91,
        detectionReason: 'Timbre brillante y espectro metálico de alta energía en H2..H6',
        soundFontPatch: 56,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartInstrumentBadge(
              isSmartTuningActive: true,
              autoSwitchEnabled: false,
              match: detectedMatch,
              activeInstrument: InstrumentProfileEntity.flute,
              palette: palette,
              onToggleSmartTuning: () {},
              onToggleAutoSwitch: () {},
              onApplyMatch: (m) => appliedMatch = m,
              onDismissMatch: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('smart_instrument_badge_active')), findsOneWidget);
      expect(find.text('¿Trompeta en Si♭? (91%)'), findsOneWidget);
      expect(find.byKey(const Key('smart_instrument_adapt_btn')), findsOneWidget);
      expect(find.byKey(const Key('smart_instrument_dismiss_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('smart_instrument_adapt_btn')));
      await tester.pumpAndSettle();
      expect(appliedMatch, equals(detectedMatch));

      await tester.tap(find.byKey(const Key('smart_instrument_dismiss_btn')));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('Renders confirmed badge when detected match equals active instrument', (tester) async {
      const confirmedMatch = SmartInstrumentMatch(
        instrument: InstrumentProfileEntity.flute,
        confidence: 0.94,
        detectionReason: 'Predominio casi puro de fundamental con mínima distorsión armónica',
        soundFontPatch: 73,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartInstrumentBadge(
              isSmartTuningActive: true,
              autoSwitchEnabled: false,
              match: confirmedMatch,
              activeInstrument: InstrumentProfileEntity.flute,
              palette: palette,
              onToggleSmartTuning: () {},
              onToggleAutoSwitch: () {},
            ),
          ),
        ),
      );

      expect(find.text('Flauta Traversa (94%)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byKey(const Key('smart_instrument_adapt_btn')), findsNothing);
    });
  });
}
