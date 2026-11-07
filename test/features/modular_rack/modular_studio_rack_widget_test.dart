import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_studio_rack_view.dart';
import 'package:tunner/features/modular_rack/presentation/multitask_master_console_widget.dart';
import 'package:tunner/features/modular_rack/presentation/rack_unit_card.dart';

void main() {
  group('ModularStudioRack & Multitask Console Widget Tests', () {
    testWidgets('renders master console and initial rack units', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: ModularStudioRackView(),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que la consola multitarea esté presente
      expect(find.byType(MultitaskMasterConsoleWidget), findsOneWidget);
      expect(find.textContaining('MULTITAREA'), findsOneWidget);

      // Verificar que los módulos por defecto estén montados
      expect(find.byType(RackUnitCard), findsNWidgets(4));
      expect(find.textContaining('AFINADOR ESTROBOSCÓPICO PRO'), findsOneWidget);
      expect(find.textContaining('METRÓNOMO DETERMINISTA'), findsOneWidget);
      expect(find.textContaining('PENTAGRAMA EN VIVO & PARTITURA'), findsOneWidget);
      expect(find.textContaining('GRABADOR DE AUDIO & AUTO-ESCUCHA'), findsOneWidget);
    });

    testWidgets('transport controls toggle master session running and recording states', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final viewModel = ModularRackViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: viewModel,
            child: Scaffold(
              body: MultitaskMasterConsoleWidget(viewModel: viewModel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(viewModel.isSessionRunning, isFalse);

      // Pulsar botón Play Maestro
      final playBtn = find.byTooltip('Iniciar Sesión');
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      expect(viewModel.isSessionRunning, isTrue);

      // Pulsar botón Grabar Maestro
      final recBtn = find.byTooltip('Grabar Sesión');
      expect(recBtn, findsOneWidget);
      await tester.tap(recBtn);
      await tester.pumpAndSettle();

      expect(viewModel.isRecording, isTrue);

      // Pulsar botón Stop Maestro
      final stopBtn = find.byTooltip('Detener Todo');
      expect(stopBtn, findsOneWidget);
      await tester.tap(stopBtn);
      await tester.pumpAndSettle();

      expect(viewModel.isSessionRunning, isFalse);
      expect(viewModel.isRecording, isFalse);
    });

    testWidgets('can toggle module power and compact view mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final viewModel = ModularRackViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: viewModel,
            child: Scaffold(
              body: ListView.builder(
                itemCount: viewModel.activeModules.length,
                itemBuilder: (ctx, idx) => RackUnitCard(
                  module: viewModel.activeModules[idx],
                  viewModel: viewModel,
                  index: idx,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // El primer módulo debe estar ON inicialmente
      expect(viewModel.activeModules.first.isPoweredOn, isTrue);

      // Alternar vista compacta
      final compactBtn = find.byTooltip('Modo Compacto').first;
      await tester.tap(compactBtn);
      await tester.pumpAndSettle();

      expect(viewModel.activeModules.first.viewMode, ModuleViewMode.compact);
    });

    testWidgets('floating action button opens module library sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: ModularStudioRackView(),
        ),
      );
      await tester.pumpAndSettle();

      final fab = find.text('AGREGAR MÓDULO');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Debe abrir la hoja modal de la biblioteca de módulos
      expect(find.text('BIBLIOTECA DE MÓDULOS DE ESTUDIO'), findsOneWidget);
    });
  });
}
