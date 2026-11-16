import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  group('Studio Atoms and Molecules Unit Tests', () {
    testWidgets('StudioIcon renders technical glyphs without exceptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                StudioIcon(glyph: StudioGlyphType.strobeTuner),
                StudioIcon(glyph: StudioGlyphType.metronome),
                StudioIcon(glyph: StudioGlyphType.audioWave),
                StudioIcon(glyph: StudioGlyphType.earTraining),
                StudioIcon(glyph: StudioGlyphType.violin),
                StudioIcon(glyph: StudioGlyphType.synthesizer),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(StudioIcon), findsNWidgets(6));
      expect(find.byType(Icon), findsNWidgets(6));
    });

    testWidgets('StudioMetricDisplay displays label, tabular value and unit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioMetricDisplay(
              label: 'PITCH',
              value: '440.0',
              unit: 'Hz',
            ),
          ),
        ),
      );

      expect(find.text('PITCH'), findsOneWidget);
      expect(find.text('440.0'), findsOneWidget);
      expect(find.text('Hz'), findsOneWidget);
    });

    testWidgets('StudioStatusLed changes color based on operational state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                StudioStatusLed(state: StudioLedState.active, label: 'ON'),
                StudioStatusLed(state: StudioLedState.success, label: 'LOCKED'),
                StudioStatusLed(state: StudioLedState.danger, label: 'CLIP'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ON'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('CLIP'), findsOneWidget);
      expect(find.byType(StudioStatusLed), findsNWidgets(3));
    });

    testWidgets('StudioHairline renders 1px line in horizontal and vertical orientations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StudioHairline(orientation: Axis.horizontal),
                StudioHairline(orientation: Axis.vertical, length: 40),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(StudioHairline), findsNWidgets(2));
    });

    testWidgets('StudioSegmentedControl triggers callback on segment selection', (tester) async {
      String selected = 'bpm';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: StudioSegmentedControl<String>(
                  segments: const [
                    StudioSegment(value: 'bpm', label: 'BPM'),
                    StudioSegment(value: 'tap', label: 'TAP'),
                    StudioSegment(value: 'sub', label: 'SUB'),
                  ],
                  selectedValue: selected,
                  onValueChanged: (val) {
                    setState(() => selected = val);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('TAP'), findsOneWidget);

      await tester.tap(find.text('TAP'));
      await tester.pumpAndSettle();

      expect(selected, 'tap');
    });

    testWidgets('StudioVuMeter renders active level without overflowing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioVuMeter(
              normalizedLevel: 0.75,
              width: 100,
              height: 10,
            ),
          ),
        ),
      );

      expect(find.byType(StudioVuMeter), findsOneWidget);
    });

    testWidgets('StudioWorkbenchShell mounts toolbar, viewport and status bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudioWorkbenchShell(
            headerTitle: Text('TUNNER WORKSTATION'),
            bottomStatusBar: Text('STATUS: DSP 60 FPS'),
            body: Center(child: Text('VIEWPORT CONTENT')),
          ),
        ),
      );

      expect(find.text('TUNNER WORKSTATION'), findsOneWidget);
      expect(find.text('VIEWPORT CONTENT'), findsOneWidget);
      expect(find.text('STATUS: DSP 60 FPS'), findsOneWidget);
      expect(find.byType(StudioWorkbenchShell), findsOneWidget);
    });
  });
}
