import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/molecules/studio_hover_info_view.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  Widget buildShell({
    bool initialInspectorVisible = false,
    Widget? rightInspectorContent,
  }) {
    return MaterialApp(
      home: StudioDesktopAppShell(
        currentBreadcrumb: 'tunner / Afinador / Estudio',
        activeItemId: 'item_tuner',
        navigationSections: const [
          StudioTreeSection(
            title: 'Projects',
            folders: [],
          ),
        ],
        activeView: Container(
          key: const Key('test_active_view'),
          color: Colors.transparent,
          child: const Center(child: Text('LIENZO ACTIVO')),
        ),
        onOpenSearch: () {},
        onOpenShortcuts: () {},
        initialInspectorVisible: initialInspectorVisible,
        rightInspectorContent: rightInspectorContent,
        a4Hz: 442.0,
        tempoBpm: 128.0,
        activeInstrumentName: 'Violín Concertino',
      ),
    );
  }

  group('US-UX-05: Right Contextual Inspector & Ableton-Style Hover Info View', () {
    setUp(() {
      StudioHoverInfoController.instance.resetToDefault();
    });

    testWidgets(
      'btn_toggle_right_inspector opens and closes studio_right_contextual_inspector_panel',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildShell());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_toggle_right_inspector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('studio_right_contextual_inspector_panel')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('btn_toggle_right_inspector')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studio_right_contextual_inspector_panel')),
          findsOneWidget,
        );
        expect(find.text('INSPECTOR CONTEXTUAL'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_toggle_right_inspector')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studio_right_contextual_inspector_panel')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '2-level Progressive Disclosure shows Level 1 essentials immediately and expands Level 2 DSP parameters on demand',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildShell(initialInspectorVisible: true));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('inspector_level_1_essential_section')),
          findsOneWidget,
        );
        expect(find.text('442.0 Hz'), findsOneWidget);
        expect(find.text('128 BPM'), findsOneWidget);
        expect(find.text('Violín Concertino'), findsOneWidget);
        expect(
          find.byKey(const Key('inspector_level_2_advanced_content')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('inspector_level_2_advanced_toggle')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('inspector_level_2_advanced_content')),
          findsOneWidget,
        );
        expect(find.text('EN LÍNEA (ACTIVO)'), findsOneWidget);
      },
    );

    testWidgets(
      'StudioHoverInfoViewPanel updates title, description, acousticFormula, and shortcut reactively',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildShell(initialInspectorVisible: true));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studio_hover_info_view_panel')),
          findsOneWidget,
        );
        expect(find.text('Inspector & Info View Activo'), findsOneWidget);

        StudioHoverInfoController.instance.setHoverInfo(
          const StudioHoverInfoItem(
            title: 'Calibración Estroboscópica de Fase',
            description: 'Mide la diferencia de fase instantánea en sub-cents.',
            shortcut: 'Alt+S',
            acousticFormula: 'cents = 1200 * log2(f / f_ref)',
            category: 'ACÚSTICA',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Calibración Estroboscópica de Fase'), findsOneWidget);
        expect(
          find.text('Mide la diferencia de fase instantánea en sub-cents.'),
          findsOneWidget,
        );
        expect(find.text('cents = 1200 * log2(f / f_ref)'), findsOneWidget);
        expect(find.text('Alt+S'), findsOneWidget);
      },
    );
  });
}
